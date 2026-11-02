extends Control

const Puzzle = preload("res://puzzle.gd")

const WORDS := [
	"",
	"one", "two", "three", "four", "five",
	"six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen",
	"sixteen", "seventeen", "eighteen", "nineteen", "twenty",
	"twenty-one", "twenty-two", "twenty-three", "twenty-four",
]
const ROW_COLORS := [
	Color("b7e4ec"),
	Color("f6c3b4"),
	Color("f6e27a"),
	Color("cbbfe8"),
	Color("b7e4ec"),
]

var board: Array = []
var tiles := {}
var slots: Array = []
var undo_stack: Array = []
var history: Array = []
var move_count := 0
var busy := false
var play_token := 0
var source_text := "照片局面"
var note_text := "方向键移动空格。点击与空格同一行或同一列的数字，会一格格滑过去。红边是还没归位的块。"

var verdict_label: Label
var stats_label: Label
var note_label: Label
var history_label: Label
var banner: Panel
var action_buttons: Array = []
var font_regular: Font
var font_bold: Font
var tile_px := 140.0
var gap_px := 12.0
var frame_px := 14.0
var board_host: Control
var board_root: Panel
var number_labels := {}
var word_labels := {}
var laying_out := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font_regular = _make_font(400)
	font_bold = _make_font(700)
	var theme := Theme.new()
	theme.default_font = font_regular
	theme.default_font_size = 28
	self.theme = theme

	var background := ColorRect.new()
	background.color = Color("f4f0e7")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var title := Label.new()
	title.text = "数字华容道 · 还原验证"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("1d1a17"))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ruizb Sliding Block Puzzle    还原顺序 · 挑战思维"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.add_theme_color_override("font_color", Color("5e584f"))
	column.add_child(subtitle)

	board_host = Control.new()
	board_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_host.resized.connect(_layout_board)
	column.add_child(board_host)
	board_root = _build_board()
	board_host.add_child(board_root)

	banner = Panel.new()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.custom_minimum_size = Vector2(0, 64)
	column.add_child(banner)
	verdict_label = Label.new()
	verdict_label.name = "Verdict"
	verdict_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	verdict_label.add_theme_font_override("font", font_bold)
	verdict_label.add_theme_font_size_override("font_size", 32)
	banner.add_child(verdict_label)

	stats_label = _body_label()
	column.add_child(stats_label)
	note_label = _body_label()
	note_label.add_theme_color_override("font_color", Color("3f3a34"))
	column.add_child(note_label)

	var button_grid := GridContainer.new()
	button_grid.columns = 3
	button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_grid.add_theme_constant_override("h_separation", 8)
	button_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(button_grid)
	button_grid.add_child(_action_button("重置照片", Color("efe6d6"), _on_reset))
	button_grid.add_child(_action_button("撤销", Color("e4def4"), _on_undo))
	button_grid.add_child(_action_button("交换 23/24", Color("f3c1b0"), _on_swap))
	button_grid.add_child(_action_button("随机开局", Color("9fd4ef"), _on_random_deal))
	button_grid.add_child(_action_button("8 步浅局", Color("f6e27a"), _on_scramble))
	button_grid.add_child(_action_button("自动还原", Color("b7e3c8"), _on_solve))

	history_label = _body_label()
	column.add_child(history_label)

	_load_photo()
	resized.connect(_layout_board)
	get_viewport().size_changed.connect(_layout_board)


func _make_font(weight: int) -> Font:
	if FileAccess.file_exists("res://fonts/NotoSansSC.ttf"):
		var bundled := load("res://fonts/NotoSansSC.ttf") as Font
		if bundled != null:
			var variation := FontVariation.new()
			variation.base_font = bundled
			variation.variation_opentype = {"wght": weight}
			return variation
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray([
		"PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "Heiti SC", "Droid Sans Fallback",
	])
	fallback.font_weight = weight
	return fallback


func _build_board() -> Panel:
	var root := Panel.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := StyleBoxFlat.new()
	tray.bg_color = Color("fbf8f2")
	tray.set_corner_radius_all(28)
	tray.shadow_color = Color(0, 0, 0, 0.08)
	tray.shadow_size = 10
	tray.shadow_offset = Vector2(0, 4)
	root.add_theme_stylebox_override("panel", tray)

	for index in range(Puzzle.N * Puzzle.N):
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(slot)
		slots.append(slot)

	for value in range(1, Puzzle.N * Puzzle.N):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var number := Label.new()
		number.name = "Number"
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = str(value)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_override("font", font_bold)
		number.add_theme_color_override("font_color", Color("1c1c1c"))
		button.add_child(number)
		var word := Label.new()
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.text = WORDS[value]
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.add_theme_color_override("font_color", Color("243038"))
		button.add_child(word)
		button.pressed.connect(_on_tile.bind(value))
		root.add_child(button)
		tiles[value] = button
		number_labels[value] = number
		word_labels[value] = word
	return root


func _layout_board() -> void:
	if laying_out or board_host == null:
		return
	var avail := board_host.size
	if avail.x < 80.0 or avail.y < 80.0:
		return
	laying_out = true
	var side := minf(avail.x, avail.y)
	frame_px = clampf(side * 0.01, 4.0, 14.0)
	gap_px = clampf(side * 0.012, 4.0, 12.0)
	tile_px = (side - frame_px * 2.0 - gap_px * 4.0) / float(Puzzle.N)
	board_root.custom_minimum_size = Vector2.ZERO
	board_root.size = Vector2(side, side)
	board_root.position = Vector2((avail.x - side) * 0.5, (avail.y - side) * 0.5)
	var radius := maxi(int(tile_px * 0.16), 8)
	var number_size := int(tile_px * 0.56)
	var word_size := mini(int(tile_px * 0.13), int((tile_px - 8.0) / 6.6))
	word_size = maxi(word_size, 11)
	for index in range(slots.size()):
		var slot: Panel = slots[index]
		slot.position = _cell_origin(index)
		slot.size = Vector2(tile_px, tile_px)
		slot.custom_minimum_size = Vector2.ZERO
	for value in range(1, Puzzle.N * Puzzle.N):
		var button: Button = tiles[value]
		button.custom_minimum_size = Vector2.ZERO
		button.size = Vector2(tile_px, tile_px)
		var number: Label = number_labels[value]
		number.position = Vector2(0, tile_px * 0.02)
		number.size = Vector2(tile_px, tile_px * 0.60)
		number.add_theme_font_size_override("font_size", number_size)
		var word: Label = word_labels[value]
		word.position = Vector2(2, tile_px * 0.60)
		word.size = Vector2(tile_px - 4, tile_px * 0.34)
		word.clip_text = true
		word.add_theme_font_size_override("font_size", word_size)
	var tray := board_root.get_theme_stylebox("panel") as StyleBoxFlat
	if tray != null:
		tray.set_corner_radius_all(radius)
	if not board.is_empty():
		_place_tiles()
	laying_out = false


func _action_button(text: String, color: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color("1c140f"))
	button.add_theme_color_override("font_hover_color", Color("1c140f"))
	button.add_theme_color_override("font_pressed_color", Color("1c140f"))
	button.add_theme_color_override("font_disabled_color", Color(0.11, 0.08, 0.06, 0.45))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.bg_color = color
		if state == "hover":
			style.bg_color = color.lightened(0.06)
		elif state == "pressed":
			style.bg_color = color.darkened(0.08)
		elif state == "disabled":
			style.bg_color = color.darkened(0.12)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	action_buttons.append(button)
	return button


func _body_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("2c2824"))
	return label


func _cell_origin(index: int) -> Vector2:
	var row := int(index / Puzzle.N)
	var col := index % Puzzle.N
	return Vector2(frame_px + col * (tile_px + gap_px), frame_px + row * (tile_px + gap_px))


func _load_photo() -> void:
	play_token += 1
	board = Puzzle.photo_board()
	move_count = 0
	undo_stack.clear()
	history.clear()
	source_text = "照片局面"
	note_text = "照片里只有 23 和 24 互换。数字逆序数是奇数，滑动改不了这个奇偶。"
	_place_tiles()
	_refresh()


func _place_tiles() -> void:
	for index in range(board.size()):
		var value := int(board[index])
		if value == 0:
			continue
		var button: Button = tiles[value]
		button.position = _cell_origin(index)
		button.size = Vector2(tile_px, tile_px)
	_restyle()


func _restyle() -> void:
	var blank := int(board.find(0))
	for index in range(slots.size()):
		var slot: Panel = slots[index]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(maxi(int(tile_px * 0.16), 10))
		style.bg_color = Color("d9d3c7") if index == blank else Color("ece7dc")
		slot.add_theme_stylebox_override("panel", style)
	for value in range(1, Puzzle.N * Puzzle.N):
		var home := value - 1
		var here := int(board.find(value))
		var button: Button = tiles[value]
		var style := StyleBoxFlat.new()
		style.bg_color = ROW_COLORS[int((value - 1) / Puzzle.N)]
		style.set_corner_radius_all(maxi(int(tile_px * 0.16), 10))
		style.shadow_color = Color(0, 0, 0, 0.1)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
		if here != home:
			style.border_color = Color("9d1c22")
			style.set_border_width_all(maxi(int(tile_px * 0.045), 4))
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)


func _refresh() -> void:
	var numbered := Puzzle.numbered_inversions(board)
	var blank_inversions := Puzzle.inversions(board)
	var blank_distance := Puzzle.manhattan_blank(board)
	var distance := Puzzle.tile_manhattan(board)
	var solved := Puzzle.is_solved(board)
	var can_solve := Puzzle.solvable(board)
	var verdict := "已还原" if solved else ("可解" if can_solve else "不可解")
	var color := Color("1b7f4a") if solved else (Color("8a5a12") if can_solve else Color("a3262c"))
	verdict_label.text = "%s    步数 %d" % [verdict, move_count]
	verdict_label.add_theme_color_override("font_color", color)
	var band := StyleBoxFlat.new()
	band.set_corner_radius_all(16)
	band.bg_color = Color("e5f6ea") if solved else (Color("f8efd4") if can_solve else Color("f8e4e1"))
	banner.add_theme_stylebox_override("panel", band)
	stats_label.text = "来源：%s\n数字逆序数（不计空格）%d，奇偶为%s。含空格逆序数 %d，空格曼哈顿 %d。棋子曼哈顿 %d。" % [
		source_text,
		numbered,
		"奇" if numbered % 2 else "偶",
		blank_inversions,
		blank_distance,
		distance,
	]
	note_label.text = note_text
	if history.is_empty():
		history_label.text = "本局滑动：还没有。"
	else:
		var lines: PackedStringArray = PackedStringArray()
		var start := maxi(history.size() - 3, 0)
		for index in range(start, history.size()):
			lines.append(str(history[index]))
		history_label.text = "最近滑动：\n" + "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if busy or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var dr := 0
	var dc := 0
	match key.keycode:
		KEY_LEFT, KEY_A:
			dc = -1
		KEY_RIGHT, KEY_D:
			dc = 1
		KEY_UP, KEY_W:
			dr = -1
		KEY_DOWN, KEY_S:
			dr = 1
		_:
			return
	accept_event()
	_play_steps([{"dr": dr, "dc": dc}])


func _on_tile(value: int) -> void:
	if busy:
		return
	var index := int(board.find(value))
	var blank := int(board.find(0))
	var row := int(index / Puzzle.N)
	var col := index % Puzzle.N
	var blank_row := int(blank / Puzzle.N)
	var blank_col := blank % Puzzle.N
	if row != blank_row and col != blank_col:
		note_text = "只能滑同一行或同一列里的块。"
		_refresh()
		return
	var steps: Array = []
	var cursor_row := blank_row
	var cursor_col := blank_col
	while cursor_row != row or cursor_col != col:
		var dr := 0
		var dc := 0
		if cursor_row != row:
			dr = 1 if row > cursor_row else -1
		else:
			dc = 1 if col > cursor_col else -1
		steps.append({"dr": dr, "dc": dc})
		cursor_row += dr
		cursor_col += dc
	_play_steps(steps)


func _on_reset() -> void:
	if busy:
		return
	_load_photo()


func _on_undo() -> void:
	if busy or undo_stack.is_empty():
		return
	board = undo_stack.pop_back()
	move_count = maxi(move_count - 1, 0)
	if not history.is_empty():
		history.pop_back()
	note_text = "已撤销一步。"
	_place_tiles()
	_refresh()


func _on_swap() -> void:
	if busy:
		return
	var at_23 := int(board.find(23))
	var at_24 := int(board.find(24))
	if at_23 < 0 or at_24 < 0:
		return
	undo_stack.append(board.duplicate())
	var button_23: Button = tiles[23]
	var button_24: Button = tiles[24]
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(button_23, "position", _cell_origin(at_24), 0.28)
	tween.tween_property(button_24, "position", _cell_origin(at_23), 0.28)
	play_token += 1
	var token := play_token
	busy = true
	_set_buttons_disabled(true)
	await tween.finished
	if token != play_token:
		return
	var tmp = board[at_23]
	board[at_23] = board[at_24]
	board[at_24] = tmp
	history.append("拆块：交换 23 和 24（不是滑动）")
	source_text = "已把 23 和 24 拆出来对调"
	note_text = "这一步把两块拿出来交换，不经过空格。照片局面因此直接变成终态。"
	busy = false
	_set_buttons_disabled(false)
	_restyle()
	_refresh()


func _on_random_deal() -> void:
	if busy:
		return
	play_token += 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	board = Puzzle.shuffled_board(100, rng)
	move_count = 0
	undo_stack.clear()
	history.clear()
	source_text = "随机开局"
	var distance := Puzzle.tile_manhattan(board)
	note_text = "从终态随机滑动 100 步生成，一定可解。棋子曼哈顿距离 %d，这是最少还要滑的步数下界。方向键或点击来玩，步数从 0 计。" % distance
	_place_tiles()
	_refresh()


func _on_scramble() -> void:
	if busy:
		return
	play_token += 1
	var token := play_token
	busy = true
	_set_buttons_disabled(true)
	board = Puzzle.solved_board()
	move_count = 0
	undo_stack.clear()
	history.clear()
	source_text = "正在从终态做 8 步合法滑动"
	note_text = "先回到终态，再只沿空格滑动。打乱结果一定可解。"
	_place_tiles()
	_refresh()
	await get_tree().create_timer(0.2).timeout
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var previous_blank := -1
	for _step in range(8):
		if token != play_token:
			return
		var blank := int(board.find(0))
		var options: Array = []
		for move in Puzzle.legal_moves(board):
			var dest := (int(blank / Puzzle.N) + int(move["dr"])) * Puzzle.N + (blank % Puzzle.N + int(move["dc"]))
			if dest == previous_blank:
				continue
			options.append(move)
		if options.is_empty():
			options = Puzzle.legal_moves(board)
		var move: Dictionary = options[rng.randi() % options.size()]
		previous_blank = blank
		var moved := await _animate_step(int(move["dr"]), int(move["dc"]))
		if not moved:
			break
	if token != play_token:
		return
	move_count = 0
	undo_stack.clear()
	history.clear()
	source_text = "从终态打乱的练习局"
	note_text = "这 8 步是合法滑动，所以奇偶和终态相同。可以手滑，也可以点自动还原。"
	busy = false
	_set_buttons_disabled(false)
	_refresh()


func _on_solve() -> void:
	if busy:
		return
	if Puzzle.is_solved(board):
		note_text = "已经是终态，没有需要播放的步骤。"
		_refresh()
		return
	if not Puzzle.solvable(board):
		note_text = "这个局面和终态奇偶不同。自动还原不会开始搜索，因为不存在滑动步骤。"
		_refresh()
		return
	var lower_bound := Puzzle.tile_manhattan(board)
	if lower_bound > 12:
		note_text = "棋子曼哈顿距离是 %d，深过自动还原的 12 步上限。这局请自己滑。" % lower_bound
		_refresh()
		return
	note_text = "正在搜索最短滑动步骤…"
	_refresh()
	busy = true
	_set_buttons_disabled(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var result := Puzzle.solve(board, 14)
	if not result["ok"]:
		busy = false
		note_text = "没有在上限内找到解（%s）。" % str(result["reason"])
		_set_buttons_disabled(false)
		_refresh()
		return
	var count: int = result["moves"].size()
	note_text = "找到 %d 步，开始按最短解播放。" % count
	_refresh()
	await _play_steps(result["moves"])
	if Puzzle.is_solved(board):
		note_text = "自动还原播完，盘面已经和终态逐格相同。"
		_refresh()


func _play_steps(steps: Array) -> void:
	play_token += 1
	var token := play_token
	busy = true
	_set_buttons_disabled(true)
	for step in steps:
		if token != play_token:
			return
		var moved := await _animate_step(int(step["dr"]), int(step["dc"]))
		if not moved:
			note_text = "这一步会滑出棋盘，已停住。"
			break
	if token != play_token:
		return
	busy = false
	_set_buttons_disabled(false)
	_refresh()


func _animate_step(dr: int, dc: int) -> bool:
	var blank := int(board.find(0))
	var row := int(blank / Puzzle.N) + dr
	var col := blank % Puzzle.N + dc
	if row < 0 or row >= Puzzle.N or col < 0 or col >= Puzzle.N:
		return false
	var index := row * Puzzle.N + col
	var tile := int(board[index])
	undo_stack.append(board.duplicate())
	var button: Button = tiles[tile]
	var tween := create_tween()
	tween.tween_property(button, "position", _cell_origin(blank), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	board[blank] = tile
	board[index] = 0
	move_count += 1
	history.append("%d. 空格向%s，%d 向%s" % [move_count, _dir_name(dr, dc), tile, _dir_name(-dr, -dc)])
	if history.size() > 18:
		history.pop_front()
	_restyle()
	_refresh()
	return true


func _dir_name(dr: int, dc: int) -> String:
	if dr < 0:
		return "上"
	if dr > 0:
		return "下"
	if dc < 0:
		return "左"
	return "右"


func _set_buttons_disabled(disabled: bool) -> void:
	for button in action_buttons:
		button.disabled = disabled

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
var subtitle_label: Label
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
var mode := "play"
var deal_steps := 16
var speed_index := 0
var playback := false
var assisted := false
var hint_value := 0
var reject_value := 0
var show_hint := true
var note_is_warn := false
var saved_board: Array = []
var saved_undo: Array = []
var saved_moves := 0
var deal_buttons := {}
var play_only: Array = []
var verify_only: Array = []
var speed_button: Button
var stop_button: Button
var stop_after := -1

const SPEED_LABELS := ["慢速", "中速", "快速"]
const SPEED_SECONDS := [0.36, 0.18, 0.08]
const DEAL_STEPS := [16, 40, 100]
const DEAL_NAMES := ["简单", "普通", "难"]
const HINT_PATH := "user://slide_hint_seen"


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

	show_hint = not FileAccess.file_exists(HINT_PATH)

	var title := Label.new()
	title.text = "数字华容道"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("1d1a17"))
	column.add_child(title)

	subtitle_label = Label.new()
	var subtitle := subtitle_label
	subtitle.text = "核对照片局面。这一局不能靠滑动还原。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("5e584f"))
	subtitle.visible = false
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
	for index in range(DEAL_NAMES.size()):
		var steps: int = int(DEAL_STEPS[index])
		var deal := _action_button(str(DEAL_NAMES[index]), Color("9fd4ef"), _start_deal.bind(steps))
		deal_buttons[steps] = deal
		play_only.append(deal)
		button_grid.add_child(deal)
	play_only.append(_grid_button(button_grid, "撤销", Color("e4def4"), _on_undo))
	play_only.append(_grid_button(button_grid, "提示", Color("f6e27a"), _on_hint))
	play_only.append(_grid_button(button_grid, "核对照片", Color("efe6d6"), _enter_verify))
	verify_only.append(_grid_button(button_grid, "重置照片", Color("efe6d6"), _on_reset))
	verify_only.append(_grid_button(button_grid, "交换 23/24", Color("f3c1b0"), _on_swap))
	verify_only.append(_grid_button(button_grid, "8 步浅局", Color("f6e27a"), _on_scramble))
	button_grid.add_child(_action_button("自动还原", Color("b7e3c8"), _on_solve))
	speed_button = _action_button(SPEED_LABELS[0], Color("d7ebe3"), _on_speed)
	button_grid.add_child(speed_button)
	stop_button = _action_button("停止", Color("f3c1b0"), _on_stop)
	stop_button.disabled = true
	button_grid.add_child(stop_button)
	verify_only.append(_grid_button(button_grid, "返回对局", Color("efe6d6"), _leave_verify))

	_start_deal(16)
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
		button.button_down.connect(_set_word_visible.bind(value, true))
		button.button_up.connect(_set_word_visible.bind(value, false))
		word.visible = false
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
	var number_size := int(tile_px * 0.68)
	var word_size := mini(int(tile_px * 0.16), int((tile_px - 8.0) / 6.6))
	word_size = maxi(word_size, 12)
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
		number.position = Vector2(0, tile_px * 0.08)
		number.size = Vector2(tile_px, tile_px * 0.84)
		number.add_theme_font_size_override("font_size", number_size)
		var word: Label = word_labels[value]
		word.position = Vector2(2, tile_px * 0.62)
		word.size = Vector2(tile_px - 4, tile_px * 0.32)
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


func _grid_button(grid: GridContainer, text: String, color: Color, callback: Callable) -> Button:
	var button := _action_button(text, color, callback)
	grid.add_child(button)
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
	playback = false
	assisted = false
	busy = false
	board = Puzzle.photo_board()
	move_count = 0
	undo_stack.clear()
	history.clear()
	hint_value = 0
	reject_value = 0
	source_text = "照片局面"
	note_is_warn = false
	note_text = "照片里只有 23 和 24 互换。数字逆序数是奇数，滑动改不了这个奇偶。"
	_place_tiles()
	_refresh()


func _step_duration() -> float:
	return float(SPEED_SECONDS[speed_index])


func _idle_note() -> String:
	if mode == "verify":
		return "照片里只有 23 和 24 互换。数字逆序数是奇数，滑动改不了这个奇偶。"
	if Puzzle.is_solved(board):
		return "这局还原了。点再来一局，或换一个难度。"
	if show_hint:
		return "点与空格同一行或同一列的数字，会一格格滑过去。"
	return ""


func _mark_hint_seen() -> void:
	show_hint = false
	var file := FileAccess.open(HINT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()


func _set_word_visible(value: int, shown: bool) -> void:
	var word: Label = word_labels[value]
	word.visible = shown


func _apply_mode() -> void:
	var verifying := mode == "verify"
	for button in play_only:
		button.visible = not verifying
	for button in verify_only:
		button.visible = verifying
	subtitle_label.visible = verifying
	stats_label.visible = verifying
	if speed_button != null:
		speed_button.text = str(SPEED_LABELS[speed_index])
	if stop_button != null:
		stop_button.disabled = not playback
	if verifying:
		return
	for index in range(DEAL_STEPS.size()):
		var steps: int = int(DEAL_STEPS[index])
		var button: Button = deal_buttons[steps]
		if not board.is_empty() and Puzzle.is_solved(board) and steps == deal_steps:
			button.text = "再来一局"
		else:
			button.text = str(DEAL_NAMES[index])


func _start_deal(steps: int) -> void:
	if busy:
		return
	play_token += 1
	playback = false
	assisted = false
	mode = "play"
	deal_steps = steps
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	board = Puzzle.shuffled_board(steps, rng)
	move_count = 0
	undo_stack.clear()
	history.clear()
	saved_board = []
	saved_undo = []
	hint_value = 0
	reject_value = 0
	var deal_index := DEAL_STEPS.find(steps)
	source_text = "%s开局" % str(DEAL_NAMES[deal_index])
	note_is_warn = false
	note_text = _idle_note()
	_place_tiles()
	_refresh()


func _enter_verify() -> void:
	if busy:
		return
	if mode != "verify":
		saved_board = board.duplicate()
		saved_undo = undo_stack.duplicate(true)
		saved_moves = move_count
	mode = "verify"
	_load_photo()


func _leave_verify() -> void:
	if busy:
		return
	mode = "play"
	hint_value = 0
	reject_value = 0
	note_is_warn = false
	if saved_board.is_empty():
		_start_deal(deal_steps)
		return
	board = saved_board.duplicate()
	undo_stack = saved_undo.duplicate(true)
	move_count = saved_moves
	note_text = _idle_note()
	_place_tiles()
	_refresh()


func _on_speed() -> void:
	speed_index = (speed_index + 1) % SPEED_LABELS.size()
	if speed_button != null:
		speed_button.text = str(SPEED_LABELS[speed_index])


func _on_stop() -> void:
	if not playback:
		return
	play_token += 1
	playback = false
	assisted = false
	busy = false
	hint_value = 0
	note_is_warn = false
	note_text = "已停下。"
	_set_buttons_disabled(false)
	_restyle()
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
		if value == hint_value:
			style.border_color = Color("1d4e89")
			style.set_border_width_all(maxi(int(tile_px * 0.09), 8))
		elif value == reject_value:
			style.border_color = Color("c2410c")
			style.set_border_width_all(maxi(int(tile_px * 0.09), 8))
		elif here != home:
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
	if mode == "play" and not solved:
		verdict_label.text = "步数 %d" % move_count
		color = Color("1d1a17")
	else:
		verdict_label.text = "%s    步数 %d" % [verdict, move_count]
	verdict_label.add_theme_color_override("font_color", color)
	var band := StyleBoxFlat.new()
	band.set_corner_radius_all(16)
	band.bg_color = Color("e5f6ea") if solved else (Color("f4f0e7") if mode == "play" else (Color("f8efd4") if can_solve else Color("f8e4e1")))
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
	note_label.visible = note_text != ""
	note_label.add_theme_color_override("font_color", Color("a3262c") if note_is_warn else Color("3f3a34"))
	_apply_mode()


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
		_reject(value)
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


func _reject(value: int) -> void:
	note_text = "只能点同一行或同一列，空格会滑过去。"
	note_is_warn = true
	reject_value = value
	_restyle()
	_refresh()
	var token := play_token
	await get_tree().create_timer(0.9).timeout
	if token != play_token or reject_value != value:
		return
	reject_value = 0
	note_is_warn = false
	note_text = _idle_note()
	_restyle()
	_refresh()


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
	hint_value = 0
	reject_value = 0
	note_is_warn = false
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
	note_is_warn = false
	note_text = "这一步把两块拿出来交换，不经过空格。照片局面因此直接变成终态。"
	busy = false
	_set_buttons_disabled(false)
	_restyle()
	_refresh()


func _on_scramble() -> void:
	if busy:
		return
	play_token += 1
	var token := play_token
	busy = true
	playback = true
	assisted = true
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
		var moved := await _animate_step(int(move["dr"]), int(move["dc"]), _step_duration())
		if not moved:
			break
	if token != play_token:
		return
	move_count = 0
	undo_stack.clear()
	history.clear()
	playback = false
	assisted = false
	source_text = "从终态打乱的练习局"
	note_is_warn = false
	note_text = "这 8 步是合法滑动。可以手滑，也可以点自动还原。速度可以改成慢速、中速或快速。"
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
	note_text = "正在找还原步骤…"
	note_is_warn = false
	_refresh()
	busy = true
	_set_buttons_disabled(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var result := _solution()
	if not result["ok"]:
		busy = false
		note_is_warn = true
		note_text = "没有找到还原步骤（%s）。" % str(result["reason"])
		_set_buttons_disabled(false)
		_refresh()
		return
	var count: int = result["moves"].size()
	var speed_name := str(SPEED_LABELS[speed_index])
	if bool(result["shortest"]):
		note_text = "找到 %d 步最短解，按%s播放。播放中可以改速度或停止。" % [count, speed_name]
	else:
		note_text = "按%s演示 %d 步。这不是最短。播放中可以改速度或停止。" % [speed_name, count]
	_refresh()
	var finished: bool = await _play_steps(result["moves"], true)
	if finished and Puzzle.is_solved(board):
		note_is_warn = false
		note_text = "还原好了。点再来一局，或换一个难度。"
		_refresh()


func _solution() -> Dictionary:
	var lower_bound := Puzzle.tile_manhattan(board)
	if lower_bound <= 12:
		var shortest := Puzzle.solve(board, 14)
		if shortest["ok"]:
			shortest["shortest"] = true
			return shortest
	var demo := Puzzle.solve_demo(board)
	demo["shortest"] = false
	return demo


func _on_hint() -> void:
	if busy:
		return
	if Puzzle.is_solved(board):
		note_is_warn = false
		note_text = "已经还原了。"
		_refresh()
		return
	if not Puzzle.solvable(board):
		note_is_warn = true
		note_text = "这局和终态奇偶不同，没有可以走的下一步。"
		_refresh()
		return
	var result := _solution()
	if not result["ok"] or result["moves"].is_empty():
		note_is_warn = true
		note_text = "没有找到下一步。"
		_refresh()
		return
	hint_value = int(result["moves"][0]["tile"])
	note_is_warn = false
	note_text = "蓝框是下一步可以动的 %d。" % hint_value
	_restyle()
	_refresh()


func _play_steps(steps: Array, paced: bool = false) -> bool:
	play_token += 1
	var token := play_token
	busy = true
	playback = true
	assisted = paced
	hint_value = 0
	_set_buttons_disabled(true)
	_restyle()
	for step in steps:
		if token != play_token:
			return false
		var duration := _step_duration() if paced else 0.14
		var moved := await _animate_step(int(step["dr"]), int(step["dc"]), duration)
		if not moved:
			note_text = "这一步会滑出棋盘，已停住。"
			break
		if paced and stop_after > 0:
			stop_after -= 1
			if stop_after == 0:
				_on_stop()
				return false
	if token != play_token:
		return false
	playback = false
	assisted = false
	busy = false
	_set_buttons_disabled(false)
	_refresh()
	return true


func _animate_step(dr: int, dc: int, duration: float = 0.09) -> bool:
	var blank := int(board.find(0))
	var row := int(blank / Puzzle.N) + dr
	var col := blank % Puzzle.N + dc
	if row < 0 or row >= Puzzle.N or col < 0 or col >= Puzzle.N:
		return false
	var index := row * Puzzle.N + col
	var tile := int(board[index])
	undo_stack.append(board.duplicate())
	if not assisted and show_hint:
		_mark_hint_seen()
	if not assisted:
		note_is_warn = false
		note_text = _idle_note()
	hint_value = 0
	reject_value = 0
	var button: Button = tiles[tile]
	var tween := create_tween()
	tween.tween_property(button, "position", _cell_origin(blank), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
		if button == speed_button or button == stop_button:
			continue
		button.disabled = disabled
	if stop_button != null:
		stop_button.disabled = not playback

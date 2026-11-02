extends SceneTree

const Puzzle = preload("res://puzzle.gd")

func _init() -> void:
	if not _run_logic():
		quit(1)
		return
	_check_scene()


func _check_scene() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var verdict := game.find_child("Verdict", true, false)
	if verdict == null:
		push_error("主场景没有判定条")
		quit(1)
		return
	var text := str(verdict.text)
	if "不可解" not in text:
		push_error("开局判定不是不可解：%s" % text)
		quit(1)
		return
	if int(game.board.find(0)) != 24:
		push_error("空格不在右下角")
		quit(1)
		return
	var tile_24: Control = game.tiles[24]
	var tile_23: Control = game.tiles[23]
	if tile_24.position.x >= tile_23.position.x:
		push_error("24 没有排在 23 左边")
		quit(1)
		return
	if game.tiles[21].position.y <= game.tiles[16].position.y:
		push_error("底行没有在第 4 行下面")
		quit(1)
		return
	var tile_size: Vector2 = game.tiles[1].size
	if absf(tile_size.x - game.TILE) > 1.0 or absf(tile_size.y - game.TILE) > 1.0:
		push_error("格子尺寸不对：%s" % str(tile_size))
		quit(1)
		return
	var step_x: float = game.tiles[2].position.x - game.tiles[1].position.x
	if absf(step_x - float(game.TILE + game.GAP)) > 1.0:
		push_error("相邻格子间距不对：%s" % str(step_x))
		quit(1)
		return
	await game._animate_step(0, -1)
	var after_left := str(game.stats_label.text)
	if "数字逆序数（不计空格）1" not in after_left or "含空格逆序数 2" not in after_left:
		push_error("向左滑之后的面板不对：%s" % after_left)
		quit(1)
		return
	game._on_reset()
	await game._animate_step(-1, 0)
	var after_up := str(game.stats_label.text)
	if "数字逆序数（不计空格）5" not in after_up or "含空格逆序数 10" not in after_up:
		push_error("向上滑之后的面板不对：%s" % after_up)
		quit(1)
		return
	if "不可解" not in str(game.verdict_label.text):
		push_error("滑动后判定变了：%s" % str(game.verdict_label.text))
		quit(1)
		return
	game._on_reset()
	await game._on_swap()
	if not Puzzle.is_solved(game.board) or "已还原" not in str(game.verdict_label.text):
		push_error("拆块对调后没有还原：%s" % str(game.verdict_label.text))
		quit(1)
		return
	await game._on_scramble()
	if not Puzzle.solvable(game.board) or Puzzle.is_solved(game.board):
		push_error("打乱后不是可解的非终态")
		quit(1)
		return
	await game._on_solve()
	if not Puzzle.is_solved(game.board) or "已还原" not in str(game.verdict_label.text):
		push_error("自动还原没有回到终态：%s" % str(game.verdict_label.text))
		quit(1)
		return
	print("UI_OK ", text.replace("\n", " "))
	quit(0)


func _run_logic() -> bool:
	var photo := Puzzle.photo_board()
	if Puzzle.numbered_inversions(photo) != 1:
		push_error("数字逆序数")
		return false
	if Puzzle.inversions(photo) != 1 or Puzzle.manhattan_blank(photo) != 0:
		push_error("含空格逆序或曼哈顿")
		return false
	if Puzzle.tile_manhattan(photo) != 2 or Puzzle.solvable(photo) or Puzzle.is_solved(photo):
		push_error("照片局面可解性")
		return false
	var refused := Puzzle.solve(photo, 4)
	if refused["ok"] or str(refused["reason"]) != "unsolvable":
		push_error("照片局面没有在搜索前被拒绝")
		return false

	var up := photo.duplicate()
	if Puzzle.move_blank(up, -1, 0) != 20:
		push_error("向上滑动的不是 20")
		return false
	if Puzzle.numbered_inversions(up) != 5 or Puzzle.inversions(up) != 10 or Puzzle.manhattan_blank(up) != 1:
		push_error("向上滑动后的不变量不对")
		return false
	if Puzzle.solvable(up):
		push_error("向上滑动后被判成可解")
		return false

	var left := photo.duplicate()
	if Puzzle.move_blank(left, 0, -1) != 23:
		push_error("向左滑动的不是 23")
		return false
	if Puzzle.numbered_inversions(left) != 1 or Puzzle.inversions(left) != 2 or Puzzle.manhattan_blank(left) != 1:
		push_error("向左滑动后的不变量不对")
		return false

	var swapped := photo.duplicate()
	var at_23 := swapped.find(23)
	var at_24 := swapped.find(24)
	var tmp = swapped[at_23]
	swapped[at_23] = swapped[at_24]
	swapped[at_24] = tmp
	if not Puzzle.is_solved(swapped) or not Puzzle.solvable(swapped):
		push_error("对调 23 和 24 之后不是终态")
		return false

	if not _parity_holds(photo, false):
		return false
	if not _parity_holds(Puzzle.solved_board(), true):
		return false

	var deal_rng := RandomNumberGenerator.new()
	deal_rng.seed = 42
	var deal := Puzzle.shuffled_board(100, deal_rng)
	if not Puzzle.solvable(deal) or Puzzle.is_solved(deal):
		push_error("随机开局不可玩")
		return false
	if Puzzle.tile_manhattan(deal) < 8:
		push_error("随机开局太浅：%d" % Puzzle.tile_manhattan(deal))
		return false

	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var board := Puzzle.solved_board()
	var previous_blank := -1
	for _step in range(8):
		var options: Array = []
		var blank := Puzzle.blank_index(board)
		for move in Puzzle.legal_moves(board):
			var dest := (int(blank / 5) + int(move["dr"])) * 5 + (blank % 5 + int(move["dc"]))
			if dest == previous_blank:
				continue
			options.append(move)
		var move: Dictionary = options[rng.randi() % options.size()]
		previous_blank = blank
		Puzzle.move_blank(board, int(move["dr"]), int(move["dc"]))
	if not Puzzle.solvable(board) or Puzzle.is_solved(board):
		push_error("练习打乱没有停在可解的非终态")
		return false
	var started_us := Time.get_ticks_usec()
	var solved := Puzzle.solve(board, 14)
	var elapsed_ms := (Time.get_ticks_usec() - started_us) / 1000.0
	if not solved["ok"]:
		push_error("可解局没有求出解：%s" % str(solved["reason"]))
		return false
	for move in solved["moves"]:
		var tile := Puzzle.move_blank(board, int(move["dr"]), int(move["dc"]))
		if tile != int(move["tile"]):
			push_error("求解步骤和盘面不一致")
			return false
	if not Puzzle.is_solved(board):
		push_error("回放后没有回到终态")
		return false
	print("LOGIC_OK steps=%d ms=%.1f" % [solved["moves"].size(), elapsed_ms])
	return true


func _parity_holds(start: Array, expect_solvable: bool) -> bool:
	var board := start.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if expect_solvable else 11
	var locked := Puzzle.solvable(board)
	var numbered_parity := Puzzle.numbered_inversions(board) % 2
	if locked != expect_solvable:
		push_error("初始可解性和预期不符")
		return false
	for _step in range(300):
		var moves := Puzzle.legal_moves(board)
		var move: Dictionary = moves[rng.randi() % moves.size()]
		Puzzle.move_blank(board, int(move["dr"]), int(move["dc"]))
		if Puzzle.solvable(board) != locked:
			push_error("含空格不变量被滑动改变")
			return false
		if Puzzle.numbered_inversions(board) % 2 != numbered_parity:
			push_error("数字逆序奇偶被滑动改变")
			return false
	return true

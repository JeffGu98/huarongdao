extends RefCounted

const N := 5

const DIRS := [
	{"dr": -1, "dc": 0, "name": "上"},
	{"dr": 1, "dc": 0, "name": "下"},
	{"dr": 0, "dc": -1, "name": "左"},
	{"dr": 0, "dc": 1, "name": "右"},
]


static func solved_board() -> Array:
	var board: Array = []
	for value in range(1, N * N):
		board.append(value)
	board.append(0)
	return board


static func photo_board() -> Array:
	return [
		1, 2, 3, 4, 5,
		6, 7, 8, 9, 10,
		11, 12, 13, 14, 15,
		16, 17, 18, 19, 20,
		21, 22, 24, 23, 0,
	]


static func blank_index(board: Array) -> int:
	return board.find(0)


static func is_solved(board: Array) -> bool:
	if board.size() != N * N:
		return false
	for index in range(N * N - 1):
		if int(board[index]) != index + 1:
			return false
	return int(board[N * N - 1]) == 0


static func numbered_inversions(board: Array) -> int:
	var seq: Array = []
	for value in board:
		if int(value) != 0:
			seq.append(int(value))
	return _count_inversions(seq)


static func inversions(board: Array) -> int:
	var seq: Array = []
	for value in board:
		seq.append(N * N if int(value) == 0 else int(value))
	return _count_inversions(seq)


static func _count_inversions(seq: Array) -> int:
	var count := 0
	for i in range(seq.size()):
		for j in range(i + 1, seq.size()):
			if int(seq[i]) > int(seq[j]):
				count += 1
	return count


static func manhattan_blank(board: Array) -> int:
	var index := blank_index(board)
	var row := int(index / N)
	var col := index % N
	return absi(row - (N - 1)) + absi(col - (N - 1))


static func tile_manhattan(board: Array) -> int:
	var total := 0
	for index in range(board.size()):
		var value := int(board[index])
		if value == 0:
			continue
		var target_row := int((value - 1) / N)
		var target_col := (value - 1) % N
		var row := int(index / N)
		var col := index % N
		total += absi(target_row - row) + absi(target_col - col)
	return total


static func solvable(board: Array) -> bool:
	return (inversions(board) + manhattan_blank(board)) % 2 == 0


static func legal_moves(board: Array) -> Array:
	var moves: Array = []
	var blank := blank_index(board)
	var row := int(blank / N)
	var col := blank % N
	for direction in DIRS:
		var next_row: int = row + int(direction["dr"])
		var next_col: int = col + int(direction["dc"])
		if next_row < 0 or next_row >= N or next_col < 0 or next_col >= N:
			continue
		var index := next_row * N + next_col
		moves.append({
			"dr": int(direction["dr"]),
			"dc": int(direction["dc"]),
			"name": direction["name"],
			"tile": int(board[index]),
		})
	return moves


static func shuffled_board(steps: int, rng: RandomNumberGenerator) -> Array:
	var board := solved_board()
	var previous_blank := -1
	for _step in range(steps):
		var blank := blank_index(board)
		var options: Array = []
		for move in legal_moves(board):
			var dest: int = (int(blank / N) + int(move["dr"])) * N + (blank % N + int(move["dc"]))
			if dest == previous_blank:
				continue
			options.append(move)
		if options.is_empty():
			options = legal_moves(board)
		var move: Dictionary = options[rng.randi() % options.size()]
		previous_blank = blank
		move_blank(board, int(move["dr"]), int(move["dc"]))
	if is_solved(board):
		var nudge: Dictionary = legal_moves(board)[0]
		move_blank(board, int(nudge["dr"]), int(nudge["dc"]))
	return board


static func move_blank(board: Array, dr: int, dc: int) -> int:
	var blank := blank_index(board)
	var row := int(blank / N) + dr
	var col := blank % N + dc
	if row < 0 or row >= N or col < 0 or col >= N:
		return -1
	var index := row * N + col
	var tile := int(board[index])
	board[blank] = tile
	board[index] = 0
	return tile


static func solve(start: Array, max_bound: int = 14) -> Dictionary:
	if not solvable(start):
		return {"ok": false, "reason": "unsolvable", "moves": []}
	if is_solved(start):
		return {"ok": true, "reason": "already", "moves": []}
	var bound := tile_manhattan(start)
	var path_boards: Array = [start.duplicate()]
	var path_moves: Array = []
	while bound <= max_bound:
		var next_bound := _search(path_boards, path_moves, 0, bound, -1)
		if next_bound == -1:
			var moves: Array = []
			for step in path_moves:
				moves.append({
					"dr": int(step["dr"]),
					"dc": int(step["dc"]),
					"tile": int(step["tile"]),
					"name": step["name"],
				})
			return {"ok": true, "reason": "solved", "moves": moves}
		if next_bound >= 1000000000:
			return {"ok": false, "reason": "no path", "moves": []}
		bound = next_bound
	return {"ok": false, "reason": "depth cap", "moves": []}


static func _search(path_boards: Array, path_moves: Array, cost: int, bound: int, previous_blank: int) -> int:
	var board: Array = path_boards[path_boards.size() - 1]
	var heuristic := tile_manhattan(board)
	if cost + heuristic > bound:
		return cost + heuristic
	if heuristic == 0:
		return -1
	var minimum := 1000000000
	var blank := blank_index(board)
	var row := int(blank / N)
	var col := blank % N
	for direction in DIRS:
		var next_row: int = row + int(direction["dr"])
		var next_col: int = col + int(direction["dc"])
		if next_row < 0 or next_row >= N or next_col < 0 or next_col >= N:
			continue
		var index := next_row * N + next_col
		if index == previous_blank:
			continue
		var next_board := board.duplicate()
		var tile := int(next_board[index])
		next_board[blank] = tile
		next_board[index] = 0
		path_boards.append(next_board)
		path_moves.append({
			"dr": int(direction["dr"]),
			"dc": int(direction["dc"]),
			"tile": tile,
			"name": direction["name"],
		})
		var next_bound := _search(path_boards, path_moves, cost + 1, bound, blank)
		if next_bound == -1:
			return -1
		if next_bound < minimum:
			minimum = next_bound
		path_boards.pop_back()
		path_moves.pop_back()
	return minimum


# 深局不求最短。按行、再按列把棋子送回原位，最后 2×2 用穷举。
# 每行末尾两格、每列剩下的两格要一起归位，否则角上只剩一条窄路，棋子进不去。
static func solve_demo(start: Array) -> Dictionary:
	if not solvable(start):
		return {"ok": false, "reason": "unsolvable", "moves": []}
	if is_solved(start):
		return {"ok": true, "reason": "already", "moves": []}
	var board := start.duplicate()
	var moves: Array = []
	var frozen: Array = []
	for row in range(N - 2):
		for col in range(N - 2):
			var tile := row * N + col + 1
			var target := row * N + col
			if not _place_one(board, moves, tile, target, frozen):
				return {"ok": false, "reason": "stuck", "moves": []}
			frozen.append(target)
		var tile_a := row * N + (N - 1)
		var tile_b := row * N + N
		if not _place_two(board, moves, tile_a, row * N + N - 2, tile_b, row * N + N - 1, frozen):
			return {"ok": false, "reason": "stuck", "moves": []}
		frozen.append(row * N + N - 2)
		frozen.append(row * N + N - 1)
	for col in range(N - 2):
		var upper := (N - 2) * N + col + 1
		var lower := (N - 1) * N + col + 1
		if not _place_two(board, moves, upper, (N - 2) * N + col, lower, (N - 1) * N + col, frozen):
			return {"ok": false, "reason": "stuck", "moves": []}
		frozen.append((N - 2) * N + col)
		frozen.append((N - 1) * N + col)
	var cells: Array = []
	for row in [N - 2, N - 1]:
		for col in [N - 2, N - 1]:
			cells.append(row * N + col)
	var corner: Variant = _bfs_region(board, cells)
	if corner == null:
		return {"ok": false, "reason": "stuck", "moves": []}
	_apply_steps(board, moves, corner)
	if not is_solved(board):
		return {"ok": false, "reason": "stuck", "moves": []}
	return {"ok": true, "reason": "demo", "moves": moves}


static func _place_one(board: Array, moves: Array, tile: int, target: int, frozen: Array) -> bool:
	if int(board[target]) == tile:
		return true
	var path: Variant = _bfs_one(board, tile, target, frozen)
	if path == null:
		return false
	_apply_steps(board, moves, path)
	return int(board[target]) == tile


static func _place_two(board: Array, moves: Array, tile_a: int, target_a: int, tile_b: int, target_b: int, frozen: Array) -> bool:
	if int(board[target_a]) == tile_a and int(board[target_b]) == tile_b:
		return true
	var path: Variant = _bfs_two(board, tile_a, target_a, tile_b, target_b, frozen)
	if path == null:
		return false
	_apply_steps(board, moves, path)
	return int(board[target_a]) == tile_a and int(board[target_b]) == tile_b


static func _apply_steps(board: Array, moves: Array, path: Array) -> void:
	for step in path:
		var dr := int(step["dr"])
		var dc := int(step["dc"])
		var tile := move_blank(board, dr, dc)
		moves.append({
			"dr": dr,
			"dc": dc,
			"tile": tile,
			"name": _dir_label(dr, dc),
		})


static func _dir_label(dr: int, dc: int) -> String:
	if dr < 0:
		return "上"
	if dr > 0:
		return "下"
	if dc < 0:
		return "左"
	return "右"


static func _blocked(frozen: Array) -> PackedByteArray:
	var blocked := PackedByteArray()
	blocked.resize(N * N)
	for cell in frozen:
		blocked[int(cell)] = 1
	return blocked


static func _encode_step(dr: int, dc: int) -> int:
	return (dr + 1) * 3 + (dc + 1)


static func _decode_step(code: int) -> Dictionary:
	return {"dr": int(code / 3) - 1, "dc": code % 3 - 1}


static func _walk_back(parent: Dictionary, step_of: Dictionary, found: int, start: int) -> Array:
	var path: Array = []
	var cur := found
	while cur != start:
		path.append(_decode_step(int(step_of[cur])))
		cur = int(parent[cur])
	path.reverse()
	return path


static func _bfs_one(board: Array, tile: int, target: int, frozen: Array) -> Variant:
	var blocked := _blocked(frozen)
	var span := N * N
	var start := int(board.find(tile)) * span + blank_index(board)
	if int(board.find(tile)) == target:
		return []
	var queue: Array = [start]
	var parent := {start: -1}
	var step_of := {}
	var head := 0
	var found := -1
	while head < queue.size():
		var state: int = queue[head]
		head += 1
		var tile_pos := int(state / span)
		var blank_pos := state % span
		if tile_pos == target:
			found = state
			break
		var row := int(blank_pos / N)
		var col := blank_pos % N
		for direction in DIRS:
			var next_row: int = row + int(direction["dr"])
			var next_col: int = col + int(direction["dc"])
			if next_row < 0 or next_row >= N or next_col < 0 or next_col >= N:
				continue
			var index := next_row * N + next_col
			if blocked[index] != 0:
				continue
			var next_tile := tile_pos
			var next_blank := index
			if index == tile_pos:
				next_tile = blank_pos
				next_blank = tile_pos
			var nxt := next_tile * span + next_blank
			if parent.has(nxt):
				continue
			parent[nxt] = state
			step_of[nxt] = _encode_step(int(direction["dr"]), int(direction["dc"]))
			queue.append(nxt)
	if found < 0:
		return null
	return _walk_back(parent, step_of, found, start)


static func _bfs_two(board: Array, tile_a: int, target_a: int, tile_b: int, target_b: int, frozen: Array) -> Variant:
	var blocked := _blocked(frozen)
	var span := N * N
	var pos_a := int(board.find(tile_a))
	var pos_b := int(board.find(tile_b))
	var start := (pos_a * span + pos_b) * span + blank_index(board)
	if pos_a == target_a and pos_b == target_b:
		return []
	var queue: Array = [start]
	var parent := {start: -1}
	var step_of := {}
	var head := 0
	var found := -1
	while head < queue.size():
		var state: int = queue[head]
		head += 1
		var blank_pos := state % span
		var rest := int(state / span)
		var at_b := rest % span
		var at_a := int(rest / span)
		if at_a == target_a and at_b == target_b:
			found = state
			break
		var row := int(blank_pos / N)
		var col := blank_pos % N
		for direction in DIRS:
			var next_row: int = row + int(direction["dr"])
			var next_col: int = col + int(direction["dc"])
			if next_row < 0 or next_row >= N or next_col < 0 or next_col >= N:
				continue
			var index := next_row * N + next_col
			if blocked[index] != 0:
				continue
			var next_a := at_a
			var next_b := at_b
			var next_blank := index
			if index == at_a:
				next_a = blank_pos
				next_blank = at_a
			elif index == at_b:
				next_b = blank_pos
				next_blank = at_b
			var nxt := (next_a * span + next_b) * span + next_blank
			if parent.has(nxt):
				continue
			parent[nxt] = state
			step_of[nxt] = _encode_step(int(direction["dr"]), int(direction["dc"]))
			queue.append(nxt)
	if found < 0:
		return null
	return _walk_back(parent, step_of, found, start)


static func _bfs_region(board: Array, cells: Array) -> Variant:
	var base := N * N
	var slot_of := {}
	var goal := 0
	var start := 0
	for index in range(cells.size()):
		var cell := int(cells[index])
		slot_of[cell] = index
		var goal_value := 0 if cell == N * N - 1 else cell + 1
		goal = goal * base + goal_value
		start = start * base + int(board[cell])
	if start == goal:
		return []
	var queue: Array = [start]
	var parent := {start: -1}
	var step_of := {}
	var head := 0
	var found := -1
	while head < queue.size():
		var state: int = queue[head]
		head += 1
		if state == goal:
			found = state
			break
		var values: Array = []
		values.resize(cells.size())
		var temp := state
		for index in range(cells.size() - 1, -1, -1):
			values[index] = temp % base
			temp = int(temp / base)
		var blank_slot := values.find(0)
		var cell := int(cells[blank_slot])
		var row := int(cell / N)
		var col := cell % N
		for direction in DIRS:
			var next_row: int = row + int(direction["dr"])
			var next_col: int = col + int(direction["dc"])
			if next_row < 0 or next_row >= N or next_col < 0 or next_col >= N:
				continue
			var neighbor := next_row * N + next_col
			if not slot_of.has(neighbor):
				continue
			var other: int = slot_of[neighbor]
			var swapped := values.duplicate()
			var tmp = swapped[blank_slot]
			swapped[blank_slot] = swapped[other]
			swapped[other] = tmp
			var nxt := 0
			for value in swapped:
				nxt = nxt * base + int(value)
			if parent.has(nxt):
				continue
			parent[nxt] = state
			step_of[nxt] = _encode_step(int(direction["dr"]), int(direction["dc"]))
			queue.append(nxt)
	if found < 0:
		return null
	return _walk_back(parent, step_of, found, start)

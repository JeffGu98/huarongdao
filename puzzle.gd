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

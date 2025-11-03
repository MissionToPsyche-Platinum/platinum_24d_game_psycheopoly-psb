extends Node2D

# Current board position (grid coordinates)
var board_x: int = 0
var board_y: int = 0

# Current position on the board (0-39 like Monopoly)
var board_space: int = 0

# Reference to the TileMapLayer
var tile_map: TileMapLayer = null


func _ready() -> void:
	# Find the TileMapLayer in the scene
	tile_map = get_tree().root.find_child("TileMapLayer", true, false)
	if tile_map:
		update_position()


# Move the piece to a board position
func move_to(x: int, y: int) -> void:
	board_x = x
	board_y = y
	board_space = get_space_from_coords(x, y)
	update_position()


# Convert (x, y) coordinates to board space number (0-39)
func get_space_from_coords(x: int, y: int) -> int:
	# Right edge: spaces 0-9 (top to bottom, x=8, y=0 to 9)
	if x == 8:
		return y
	# Bottom edge: spaces 10-19 (right to left, y=9, x=7 to -1)
	if y == 9:
		return 10 + (7 - x)
	# Left edge: spaces 20-29 (bottom to top, x=-1, y=8 to -1)
	if x == -1:
		return 20 + (8 - y)
	# Top edge: spaces 30-39 (left to right, y=0, x=-1 to 7)
	if y == 0:
		return 30 + (x + 1)
	return 0


# Convert board space number to (x, y) coordinates
func get_coords_from_space(space: int) -> Vector2i:
	space = space % 40  # Wrap around the board
	
	# Right edge: spaces 0-9 (x=8, y=0 to 9)
	if space <= 9:
		return Vector2i(8, space)
	# Bottom edge: spaces 10-19 (y=9, x=7 to -1)
	elif space <= 19:
		return Vector2i(7 - (space - 10), 9)
	# Left edge: spaces 20-29 (x=-1, y=8 to -1)
	elif space <= 29:
		return Vector2i(-1, 8 - (space - 20))
	# Top edge: spaces 30-39 (y=0, x=-1 to 7)
	else:
		return Vector2i((space - 30) - 1, 0)


# Roll dice and move (for testing, generates random 2-12)
# TODO: Replace with proper dice rolling mechanism later 
func roll_and_move() -> void:
	var dice1 := randi() % 6 + 1
	var dice2 := randi() % 6 + 1
	var total := dice1 + dice2
	print("Rolled: ", dice1, " + ", dice2, " = ", total)
	move_forward(total)


# Move forward by a number of spaces (clockwise only)
func move_forward(spaces: int) -> void:
	board_space = (board_space + spaces) % 40
	var new_coords := get_coords_from_space(board_space)
	board_x = new_coords.x
	board_y = new_coords.y
	update_position()
	print("Moved to space ", board_space, " at (", board_x, ", ", board_y, ")")


# Convert grid position to world position and update
func update_position() -> void:
	if tile_map:
		var world_pos = tile_map.map_to_local(Vector2i(board_x, board_y))
		position = world_pos


# Check if position is on the board edge
func is_valid_position(x: int, y: int) -> bool:
	# Bottom edge
	if y == 9 and x >= -1 and x <= 8:
		return true
	# Right edge
	if x == 8 and y >= 0 and y <= 9:
		return true
	# Top edge
	if y == 0 and x >= -1 and x <= 8:
		return true
	# Left edge
	if x == -1 and y >= 0 and y <= 9:
		return true
	return false


# Simple keyboard controls for testing
# TODO: Remove or replace with proper input handling later
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Press SPACE to roll dice and move
		if event.keycode == KEY_SPACE:
			roll_and_move()
		# Arrow keys to move forward manually (1 space at a time, clockwise only)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			move_forward(1)
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			move_forward(-1)  # Move backward one space (for testing)

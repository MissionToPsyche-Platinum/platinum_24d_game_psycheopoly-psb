extends Node2D

# Current board position (grid coordinates)
var board_x: int = 0
var board_y: int = 0

# Current position on the board (0-39 like Monopoly)
var board_space: int = 0

# Reference to the TileMapLayer
@export var tile_map: TileMapLayer


func _ready() -> void:
	if tile_map:
		update_position()


# Move the piece to a board position
func move_to(x: int, y: int) -> void:
	board_x = x
	board_y = y
	board_space = get_space_from_coords(x, y)
	update_position()


# Convert (x, y) coordinates to board space number (0-39)
# Monopoly layout: 40 spaces total, 11 per side (corners shared)
func get_space_from_coords(x: int, y: int) -> int:
	# Handle corners explicitly
	if x == 10 and y == 0:
		return 0  # Go (top-right corner)
	if x == 10 and y == 10:
		return 10  # Jail (bottom-right corner)
	if x == 0 and y == 10:
		return 20  # Free Parking (bottom-left corner)
	if x == 0 and y == 0:
		return 30  # Go to Jail (top-left corner)
	# Right edge: spaces 1-9 (x=10, y=1 to 9)
	if x == 10 and y > 0 and y < 10:
		return y
	# Bottom edge: spaces 11-19 (y=10, x=9 to 1)
	if y == 10 and x > 0 and x < 10:
		return 10 + (10 - x)
	# Left edge: spaces 21-29 (x=0, y=9 to 1)
	if x == 0 and y > 0 and y < 10:
		return 20 + (10 - y)
	# Top edge: spaces 31-39 (y=0, x=1 to 9)
	if y == 0 and x > 0 and x < 10:
		return 30 + x
	# Not a valid board space
	return -1


# Convert board space number to (x, y) coordinates
# Space layout (Monopoly-style):
# 0 = (10,0) top-right corner, 10 = (10,10) bottom-right corner
# 20 = (0,10) bottom-left corner, 30 = (0,0) top-left corner
func get_coords_from_space(space: int) -> Vector2i:
	space = space % 40  # Wrap around the board
	
	# Right edge: spaces 0-10 (x=10, y=0 to 10)
	if space <= 10:
		return Vector2i(10, space)
	# Bottom edge: spaces 11-19 (y=10, x=9 to 1)
	elif space <= 19:
		return Vector2i(10 - (space - 10), 10)
	# Left edge: spaces 20-30 (x=0, y=10 to 0)
	elif space <= 30:
		return Vector2i(0, 10 - (space - 20))
	# Top edge: spaces 31-39 (y=0, x=1 to 9)
	else:
		return Vector2i(space - 30, 0)


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
	board_space = ((board_space + spaces) % 40 + 40) % 40
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


# Check if position is on the board edge (Monopoly-style: 11 spaces per side = 40 total)
func is_valid_position(x: int, y: int) -> bool:
	# Bottom edge
	if y == 10 and x >= 0 and x <= 10:
		return true
	# Right edge
	if x == 10 and y >= 0 and y <= 10:
		return true
	# Top edge
	if y == 0 and x >= 0 and x <= 10:
		return true
	# Left edge
	if x == 0 and y >= 0 and y <= 10:
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

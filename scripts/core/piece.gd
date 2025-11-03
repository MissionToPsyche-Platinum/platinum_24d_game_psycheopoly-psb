extends Node2D

# Current board position (grid coordinates)
var board_x: int = 0
var board_y: int = 0

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
	update_position()


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
# TODO: Replace this with movement based on game logic
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var new_x := board_x
		var new_y := board_y
		
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			new_y -= 1
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			new_y += 1
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			new_x -= 1
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			new_x += 1
		
		# Only move if the new position is valid
		if is_valid_position(new_x, new_y):
			board_x = new_x
			board_y = new_y
			update_position()

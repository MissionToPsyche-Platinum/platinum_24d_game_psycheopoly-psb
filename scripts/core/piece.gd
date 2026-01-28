extends Node2D

# Signal emitted when the piece moves to a new space
signal space_changed(space_num: int)
# Signal emitted when the piece finishes all movement steps
signal movement_finished(final_space: int)

# Piece positioning offsets (adjust these to change spacing)
const MAX_PIECE_OFFSET_X: float = 6.0  # Max horizontal spacing (for 6 players)
const MAX_PIECE_OFFSET_Y: float = 4.0  # Max vertical spacing (for 6 players)
const MAX_PLAYER_COUNT: int = 6  # Maximum number of players for scaling

# Current board position (grid coordinates)
var board_x: int = 0
var board_y: int = 0

# Current position on the board (0-39 like Monopoly)
var board_space: int = 0

# Player index (0-5 for positioning offsets)
var player_index: int = 0

# Total number of players (used for offset scaling)
var player_count: int = 6

# Player colors for the shader
const PLAYER_COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2),   # Red
	Color(0.2, 0.5, 0.9),   # Blue
	Color(0.2, 0.8, 0.2),   # Green
	Color(0.9, 0.8, 0.1),   # Yellow
	Color(0.9, 0.5, 0.1),   # Orange
	Color(0.8, 0.3, 0.8),   # Purple
]

# Reference to the TileMapLayer
@export var tile_map: TileMapLayer

@onready var sprite: Sprite2D = $Sprite

# Movement animation settings
var _is_moving: bool = false
var _remaining_steps: int = 0
var _step_delay: float = 0.2  # Time between each step in seconds


func _ready() -> void:
	if tile_map:
		update_position()
	
	_apply_player_color()
	
	# Connect to game state to highlight if it is our turn
	GameState.current_player_changed.connect(_on_player_changed)
	# Check if it's already our turn (for initialization)
	_on_player_changed(GameState.get_current_player())


func _on_player_changed(player: PlayerState) -> void:
	if not player:
		return
	set_highlight(player.player_id == player_index)


func set_highlight(active: bool) -> void:
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("use_outline", active)


func _apply_player_color() -> void:
	if sprite and sprite.material:
		var color_idx = player_index % PLAYER_COLORS.size()
		# Create a unique material instance so each piece can have a different color
		var unique_material = sprite.material.duplicate()
		unique_material.set_shader_parameter("target_color", PLAYER_COLORS[color_idx])
		sprite.material = unique_material


# Move the piece to a board position
func move_to(x: int, y: int) -> void:
	board_x = x
	board_y = y
	board_space = get_space_from_coords(x, y)
	update_position()
	space_changed.emit(board_space)


# Move the piece to a specific space number immediately
func teleport_to_space(space_num: int) -> void:
	board_space = space_num % 40
	var new_coords := get_coords_from_space(board_space)
	board_x = new_coords.x
	board_y = new_coords.y
	update_position()
	space_changed.emit(board_space)
	# Also emit movement_finished so any landing logic can trigger again if needed
	# In this case of "Go to Jail", we might want it to NOT trigger again immediately, 
	# or handle it carefully in board.gd.
	movement_finished.emit(board_space)


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
# Now animates one space at a time
func move_forward(spaces: int) -> void:
	if _is_moving:
		return  # Prevent overlapping movements
	
	_is_moving = true
	_remaining_steps = spaces
	_move_one_step()


# Internal function to move one step at a time
func _move_one_step() -> void:
	if _remaining_steps <= 0:
		_is_moving = false
		movement_finished.emit(board_space)
		return
	
	# Move one space forward
	board_space = (board_space + 1) % 40
	var new_coords := get_coords_from_space(board_space)
	board_x = new_coords.x
	board_y = new_coords.y
	update_position()
	space_changed.emit(board_space)
	
	_remaining_steps -= 1
	
	# Schedule the next step
	if _remaining_steps > 0:
		get_tree().create_timer(_step_delay).timeout.connect(_move_one_step)
	else:
		_is_moving = false
		movement_finished.emit(board_space)
		print("Moved to space ", board_space, " at (", board_x, ", ", board_y, ")")


# Convert grid position to world position and update
func update_position() -> void:
	if tile_map:
		var world_pos = tile_map.map_to_local(Vector2i(board_x, board_y))
		
		# Calculate offset based on player index and player count
		var offset_x: float = 0.0
		var offset_y: float = 0.0
		
		# Use different layouts based on player count
		match player_count:
			2:
				# 2 players: side by side horizontally
				match player_index:
					0: offset_x = -MAX_PIECE_OFFSET_X
					1: offset_x = MAX_PIECE_OFFSET_X
			3:
				# 3 players: triangle pattern
				match player_index:
					0:  # Top center
						offset_y = -MAX_PIECE_OFFSET_Y
					1:  # Bottom left
						offset_x = -MAX_PIECE_OFFSET_X
						offset_y = MAX_PIECE_OFFSET_Y
					2:  # Bottom right
						offset_x = MAX_PIECE_OFFSET_X
						offset_y = MAX_PIECE_OFFSET_Y
			4:
				# 4 players: 2x2 grid
				match player_index:
					0:  # Top-left
						offset_x = -MAX_PIECE_OFFSET_X
						offset_y = -MAX_PIECE_OFFSET_Y
					1:  # Top-right
						offset_x = MAX_PIECE_OFFSET_X
						offset_y = -MAX_PIECE_OFFSET_Y
					2:  # Bottom-left
						offset_x = -MAX_PIECE_OFFSET_X
						offset_y = MAX_PIECE_OFFSET_Y
					3:  # Bottom-right
						offset_x = MAX_PIECE_OFFSET_X
						offset_y = MAX_PIECE_OFFSET_Y
			5, 6:
				# 5-6 players: 2x3 grid
				match player_index:
					0:  # Top-left
						offset_x = -MAX_PIECE_OFFSET_X
						offset_y = -MAX_PIECE_OFFSET_Y
					1:  # Top-right
						offset_x = MAX_PIECE_OFFSET_X
						offset_y = -MAX_PIECE_OFFSET_Y
					2:  # Middle-left
						offset_x = -MAX_PIECE_OFFSET_X
						offset_y = 0.0
					3:  # Middle-right
						offset_x = MAX_PIECE_OFFSET_X
						offset_y = 0.0
					4:  # Bottom-left
						offset_x = -MAX_PIECE_OFFSET_X
						offset_y = MAX_PIECE_OFFSET_Y
					5:  # Bottom-right
						offset_x = MAX_PIECE_OFFSET_X
						offset_y = MAX_PIECE_OFFSET_Y
		
		position = world_pos + Vector2(offset_x, offset_y)


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

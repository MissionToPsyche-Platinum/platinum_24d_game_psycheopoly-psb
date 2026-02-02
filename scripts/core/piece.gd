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

# Dynamic tile layout positioning
var at_tile_index: int = 0   # Index among pieces on the same tile
var at_tile_count: int = 1   # Total pieces on the current tile

# Player index (0-5 for positioning offsets)
var player_index: int = 0

# Total number of players (used for offset scaling)
var player_count: int = 6

# Reference to the TileMapLayer
@export var tile_map: TileMapLayer

@onready var sprite: Sprite2D = $Sprite

# Initial sprite position to preserve vertical centering
var _base_sprite_y: float = 0.0

# Movement animation settings
var _is_moving: bool = false
var _remaining_steps: int = 0
@export var step_duration: float = 0.2  # Duration of movement between spaces
@export var jump_height: float = 12.0     # How high the piece jumps during movement


func _ready() -> void:
	if sprite:
		_base_sprite_y = sprite.position.y
		
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
	if not (sprite and sprite.material):
		return

	# Pull the real chosen color from GameState's PlayerState
	var chosen_color: Color = Color.WHITE
	if GameState.players.size() > player_index and GameState.players[player_index]:
		chosen_color = GameState.players[player_index].player_color
	else:
		# Fallback only (should rarely happen)
		var color_idx := player_index % GameState.PLAYER_COLORS.size()
		chosen_color = GameState.PLAYER_COLORS[color_idx]

	# Create a unique material instance so each piece can have a different color
	var unique_material = sprite.material.duplicate()
	unique_material.set_shader_parameter("target_color", chosen_color)
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
	
	# Reset to default centered layout until board.gd updates us
	at_tile_count = 1
	at_tile_index = 0
	
	update_position()
	space_changed.emit(board_space)
	# Also emit movement_finished so any landing logic can trigger again if needed
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
	
	# Reset tile layout to centered while in transit
	at_tile_count = 1
	at_tile_index = 0
	
	_move_one_step()


# Internal function to move one step at a time
func _move_one_step() -> void:
	if _remaining_steps <= 0:
		_is_moving = false
		movement_finished.emit(board_space)
		return
	
	# Move logic (advance one space)
	board_space = (board_space + 1) % 40
	var new_coords := get_coords_from_space(board_space)
	board_x = new_coords.x
	board_y = new_coords.y
	
	# Ensure centered layout during transit
	at_tile_count = 1
	at_tile_index = 0
	
	var target_pos = get_target_world_position()
	
	# Create movement tween
	var tween = create_tween()
	# Smoothly move to target position
	tween.tween_property(self, "position", target_pos, step_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# Parallel jump animation on the sprite (relative to its base Y)
	var jump_tween = create_tween()
	jump_tween.tween_property(sprite, "position:y", _base_sprite_y - jump_height, step_duration / 2.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(sprite, "position:y", _base_sprite_y, step_duration / 2.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	# When movement finishes, prepare for next step
	tween.finished.connect(func():
		space_changed.emit(board_space)
		_remaining_steps -= 1
		
		# Small pause between steps looks better
		if _remaining_steps > 0:
			get_tree().create_timer(0.05).timeout.connect(_move_one_step)
		else:
			_is_moving = false
			movement_finished.emit(board_space)
			print("Moved to space ", board_space, " at (", board_x, ", ", board_y, ")")
	)


# Convert grid position to world position mapping
func get_target_world_position() -> Vector2:
	if not tile_map:
		return position
		
	var world_pos = tile_map.map_to_local(Vector2i(board_x, board_y))
	
	# Calculate offset based on dynamic tile layout
	var offset := Vector2.ZERO
	
	# Use different layouts based on how many pieces are on THIS tile
	var count = at_tile_count
	var idx = at_tile_index
	
	if count <= 1:
		# 1 piece: centered (offset 0,0)
		return world_pos
	
	match count:
		2:
			# 2 pieces: side by side
			match idx:
				0: offset.x = -MAX_PIECE_OFFSET_X
				1: offset.x = MAX_PIECE_OFFSET_X
		3:
			# 3 pieces: triangle
			match idx:
				0: offset.y = -MAX_PIECE_OFFSET_Y
				1: offset.x = -MAX_PIECE_OFFSET_X; offset.y = MAX_PIECE_OFFSET_Y
				2: offset.x = MAX_PIECE_OFFSET_X; offset.y = MAX_PIECE_OFFSET_Y
		4:
			# 4 pieces: 2x2 grid
			match idx:
				0: offset.x = -MAX_PIECE_OFFSET_X; offset.y = -MAX_PIECE_OFFSET_Y
				1: offset.x = MAX_PIECE_OFFSET_X; offset.y = -MAX_PIECE_OFFSET_Y
				2: offset.x = -MAX_PIECE_OFFSET_X; offset.y = MAX_PIECE_OFFSET_Y
				3: offset.x = MAX_PIECE_OFFSET_X; offset.y = MAX_PIECE_OFFSET_Y
		5, 6:
			# 5-6 pieces: 2x3 grid
			match idx:
				0: offset.x = -MAX_PIECE_OFFSET_X; offset.y = -MAX_PIECE_OFFSET_Y
				1: offset.x = MAX_PIECE_OFFSET_X; offset.y = -MAX_PIECE_OFFSET_Y
				2: offset.x = -MAX_PIECE_OFFSET_X; offset.y = 0.0
				3: offset.x = MAX_PIECE_OFFSET_X; offset.y = 0.0
				4: offset.x = -MAX_PIECE_OFFSET_X; offset.y = MAX_PIECE_OFFSET_Y
				5: offset.x = MAX_PIECE_OFFSET_X; offset.y = MAX_PIECE_OFFSET_Y
	
	return world_pos + offset


# Update the piece's layout info (how many other pieces are on the same tile)
func set_tile_layout(index: int, count: int, animate: bool = true) -> void:
	at_tile_index = index
	at_tile_count = count
	
	if not animate:
		update_position()
		return
		
	var target_pos = get_target_world_position()
	if position.distance_to(target_pos) > 0.1:
		var tween = create_tween()
		tween.tween_property(self, "position", target_pos, 0.2)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)


# Convert grid position to world position and update
func update_position() -> void:
	position = get_target_world_position()


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

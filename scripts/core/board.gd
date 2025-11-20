extends Node2D

# Reference to the piece
var piece: Node2D = null

# Tile map references
var tile_map_layer: TileMapLayer = null
var highlight_layer: TileMapLayer = null

# Space info panel reference
var space_info_panel: Control = null

# Mouse interaction state
var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_tile: Vector2i = Vector2i(-1, -1)
var is_tile_selected: bool = false

# Highlight tile atlas coordinates
const HOVER_TILE := Vector2i(0, 2)  # Hover texture
const SELECTED_TILE := Vector2i(5, 1)  # Highlighted texture


func _ready() -> void:
	# Load and spawn the piece
	var piece_scene = preload("res://scenes/Piece.tscn")
	piece = piece_scene.instantiate()
	add_child(piece)
	
	# Get reference to the TileMapLayer
	tile_map_layer = $TileMap/TileMapLayer
	piece.tile_map = tile_map_layer
	
	# Get reference to highlight layer
	highlight_layer = $TileMap/HighlightLayer
	
	# Get reference to the space info panel (now in the scene tree)
	space_info_panel = $SpaceInfoPanel
	
	# Connect piece's space_changed signal to update the panel (only when no tile selected)
	if space_info_panel:
		piece.space_changed.connect(_on_piece_space_changed)

	# Start the piece at position (10, 0) on the board (space 0 - GO)
	piece.move_to(10, 0)


func _on_piece_space_changed(space_num: int) -> void:
	# Only update panel if no tile is selected
	if not is_tile_selected and space_info_panel:
		space_info_panel.update_space_display(space_num)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event)


func _handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if not tile_map_layer:
		return
	
	# Get the tile coordinates under the mouse
	var mouse_pos = get_global_mouse_position()
	var tile_coords = tile_map_layer.local_to_map(mouse_pos)
	
	# Check if this tile is a valid board space
	if _is_valid_board_tile(tile_coords) and tile_coords != hovered_tile:
		# Clear previous hover highlight (only if it's not the selected tile)
		if hovered_tile != Vector2i(-1, -1) and hovered_tile != selected_tile:
			highlight_layer.erase_cell(hovered_tile)
		
		# Set new hovered tile
		hovered_tile = tile_coords
		
		# Show hover highlight (only if it's not the selected tile)
		if hovered_tile != selected_tile:
			highlight_layer.set_cell(hovered_tile, 1, HOVER_TILE)
	elif not _is_valid_board_tile(tile_coords) and hovered_tile != Vector2i(-1, -1):
		# Mouse left the board, clear hover highlight (only if it's not the selected tile)
		if hovered_tile != selected_tile:
			highlight_layer.erase_cell(hovered_tile)
		hovered_tile = Vector2i(-1, -1)


func _handle_mouse_click(_event: InputEventMouseButton) -> void:
	if not tile_map_layer or not space_info_panel:
		return
	
	# Get the tile coordinates under the mouse
	var mouse_pos = get_global_mouse_position()
	var tile_coords = tile_map_layer.local_to_map(mouse_pos)
	
	# Check if this is a valid board tile
	if not _is_valid_board_tile(tile_coords):
		return
	
	# If clicking the same tile, deselect it
	if is_tile_selected and tile_coords == selected_tile:
		# Deselect
		is_tile_selected = false
		highlight_layer.erase_cell(selected_tile)
		selected_tile = Vector2i(-1, -1)
		
		# Restore hover highlight if mouse is still over a tile
		if hovered_tile != Vector2i(-1, -1):
			highlight_layer.set_cell(hovered_tile, 1, HOVER_TILE)
		
		# Show player's current position info
		space_info_panel.update_space_display(piece.board_space)
	else:
		# Clear previous selection
		if is_tile_selected and selected_tile != Vector2i(-1, -1):
			highlight_layer.erase_cell(selected_tile)
		
		# Select new tile
		selected_tile = tile_coords
		is_tile_selected = true
		
		# Show selected highlight
		highlight_layer.set_cell(selected_tile, 1, SELECTED_TILE)
		
		# Update space info panel with selected tile's info
		var space_num = _get_space_from_tile_coords(tile_coords)
		if space_num >= 0:
			space_info_panel.update_space_display(space_num)


func _is_valid_board_tile(coords: Vector2i) -> bool:
	# Check if coordinates are on the board perimeter (Monopoly-style)
	var x = coords.x
	var y = coords.y
	
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


func _get_space_from_tile_coords(coords: Vector2i) -> int:
	# Use the same logic as piece.gd's get_space_from_coords
	var x = coords.x
	var y = coords.y
	
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
	
	return -1

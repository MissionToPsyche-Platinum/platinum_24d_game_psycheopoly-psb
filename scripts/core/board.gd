extends Node2D

# Reference to the piece
var piece: Node2D = null

# Tile map references
var tile_map_layer: TileMapLayer = null
var highlight_layer: TileMapLayer = null

# Space info panel reference and scene
const SpaceInfoPanelScene = preload("res://scenes/SpaceInfoPanel.tscn")
var space_info_panel: CanvasLayer = null

# Dice roll UI reference and scene
const DiceRollPanelScene = preload("res://scenes/DiceRollPanel.tscn")
var dice_roll_ui: Control = null

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
	
	# Instantiate the space info panel
	space_info_panel = SpaceInfoPanelScene.instantiate()
	# CanvasLayers must be added to the SceneTree directly
	get_tree().root.call_deferred("add_child", space_info_panel)
	
	# Instantiate the dice roll UI
	_setup_dice_roll_ui()
	
	# Connect piece's space_changed signal to update the panel (only when no tile selected)
	if space_info_panel:
		piece.space_changed.connect(_on_piece_space_changed)

	# Start the piece at position (10, 0) on the board (space 0 - GO)
	piece.move_to(10, 0)
	
	# Update panel after everything is ready
	call_deferred("_initial_panel_update")


func _setup_dice_roll_ui() -> void:
	# Create a CanvasLayer to hold the dice UI (ensures it's always on top)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DiceRollLayer"
	canvas_layer.layer = 10  # Above other UI elements
	
	# Instantiate the dice roll panel
	dice_roll_ui = DiceRollPanelScene.instantiate()
	canvas_layer.add_child(dice_roll_ui)
	
	# Add to scene tree
	get_tree().root.call_deferred("add_child", canvas_layer)
	
	# Connect the dice_rolled signal to move the piece
	dice_roll_ui.dice_rolled.connect(_on_dice_rolled)


func _initial_panel_update() -> void:
	if space_info_panel and piece:
		space_info_panel.update_space_display(piece.board_space)


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


func _on_dice_rolled(d1: int, d2: int, total: int, is_doubles: bool) -> void:
	# Move the piece forward by the total dice value
	if piece:
		piece.move_forward(total)
		print("Dice rolled: %d + %d = %d%s" % [d1, d2, total, " (Doubles!)" if is_doubles else ""])

extends Control
## player_properties_preview.gd
## Displays a compact preview of properties owned by the current player
## Shows small colored blocks representing each property
## Colorblind mode:
## - Normal mode: small colored blocks
## - Colorblind mode: small symbol icons with black outline

signal trade_pressed

@onready var properties_grid: GridContainer = $Panel/MarginContainer/VBox/PropertiesGrid
@onready var count_label: Label = $Panel/MarginContainer/VBox/HeaderHBox/CountLabel
@onready var view_details_button: Button = $Panel/MarginContainer/VBox/ViewDetailsButton
@onready var trade_button: Button = $Panel/MarginContainer/VBox/TradeButton

# Preload the detailed popup scene
const PropertiesDetailPopupScene = preload("res://scenes/PropertiesDetailPopup.tscn")
var properties_detail_popup: CanvasLayer = null

# Size of each property indicator block
const PROPERTY_BLOCK_SIZE = 16

func _ready() -> void:
	# Hide initially if no player
	visible = false
	
	if Engine.is_editor_hint():
		return

	# Connect to GameController for turn changes
	if GameController:
		if not GameController.current_player_changed.is_connected(_on_current_player_changed):
			GameController.current_player_changed.connect(_on_current_player_changed)
		if not GameController.property_ownership_changed.is_connected(_on_property_ownership_changed):
			GameController.property_ownership_changed.connect(_on_property_ownership_changed)
		if not GameController.property_upgraded.is_connected(_on_property_ownership_changed):
			GameController.property_upgraded.connect(_on_property_ownership_changed)

		# Initial update if game already started
		var current = GameController.get_current_player()
		if current:
			_on_current_player_changed(current)

	# Connect button
	if view_details_button:
		view_details_button.pressed.connect(_on_view_details_pressed)
	if trade_button:
		trade_button.pressed.connect(_on_trade_pressed)

	# OPTIONAL but recommended:
	# If your SettingsManager emits a signal when colorblind mode changes,
	# this makes the preview update instantly when toggled.
	if SettingsManager:
		if SettingsManager.has_signal("colorblind_mode_changed"):
			if not SettingsManager.colorblind_mode_changed.is_connected(_on_colorblind_mode_changed):
				SettingsManager.colorblind_mode_changed.connect(_on_colorblind_mode_changed)


func _on_current_player_changed(player) -> void:
	if player == null || player.player_is_ai:
		visible = false
		return

	visible = true
	_update_properties_display(player)


func _on_property_ownership_changed() -> void:
	# Refresh display when any property ownership changes
	var current = GameController.get_current_player()
	if current:
		_update_properties_display(current)


func _on_colorblind_mode_changed(_enabled: bool) -> void:
	# Refresh immediately when colorblind mode is toggled
	refresh_preview()


func refresh_preview() -> void:
	var current = GameController.get_current_player()
	if current:
		visible = true
		_update_properties_display(current)
	else:
		visible = false


func _update_properties_display(player) -> void:
	# Clear existing property blocks
	for child in properties_grid.get_children():
		child.queue_free()

	# Get all properties owned by this player
	var owned_properties: Array[Dictionary] = []

	if GameState and GameState.board.size() > 0:
		for i in range(GameState.board.size()):
			var space = GameState.board[i]

			# Check if this space is ownable and owned by the current player
			if space is Ownable:
				var ownable := space as Ownable
				if ownable.is_owned() and ownable.get_property_owner() == player.player_id:
					# Get the space info to show color / symbol
					var space_info = SpaceData.SPACE_INFO[i]
					owned_properties.append({
						"space_index": i,
						"name": space_info.get("name", "Unknown"),
						"color": space_info.get("color", Color.WHITE),
						"type": space_info.get("type", "property")
					})

	# Update count label
	count_label.text = "(%d)" % owned_properties.size()

	# Create visual blocks for each property
	for prop in owned_properties:
		var border_container := PanelContainer.new()
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = Color(0, 0, 0, 0)  # Transparent background
		stylebox.border_width_left = 1
		stylebox.border_width_top = 1
		stylebox.border_width_right = 1
		stylebox.border_width_bottom = 1
		stylebox.border_color = Color(0.3, 0.3, 0.3, 1)
		border_container.add_theme_stylebox_override("panel", stylebox)
		border_container.custom_minimum_size = Vector2(PROPERTY_BLOCK_SIZE, PROPERTY_BLOCK_SIZE)
		border_container.tooltip_text = prop.name

		var space_index := int(prop.space_index)
		var symbol_texture: Texture2D = ColorblindHelpers.get_symbol_texture_for_space(space_index)

		if SettingsManager.is_colorblind_enabled() and symbol_texture != null:
			# Small symbol icon with black outline for compact preview
			# Slightly larger than before for better readability
			var icon_holder := Control.new()
			icon_holder.custom_minimum_size = Vector2(PROPERTY_BLOCK_SIZE, PROPERTY_BLOCK_SIZE)

			# Shadow / outline
			var symbol_shadow := TextureRect.new()
			symbol_shadow.texture = symbol_texture
			symbol_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			symbol_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			symbol_shadow.custom_minimum_size = Vector2(10, 10)
			symbol_shadow.position = Vector2(3, 3)
			symbol_shadow.modulate = Color.BLACK
			icon_holder.add_child(symbol_shadow)

			# Main symbol
			var symbol := TextureRect.new()
			symbol.texture = symbol_texture
			symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			symbol.custom_minimum_size = Vector2(10, 10)
			symbol.position = Vector2(2, 2)
			icon_holder.add_child(symbol)

			border_container.add_child(icon_holder)
		else:
			# Normal color block
			var property_block := ColorRect.new()
			property_block.custom_minimum_size = Vector2(PROPERTY_BLOCK_SIZE, PROPERTY_BLOCK_SIZE)
			property_block.color = prop.color
			border_container.add_child(property_block)

		properties_grid.add_child(border_container)

	# Show message if no properties
	if owned_properties.is_empty():
		var no_props_label := Label.new()
		no_props_label.text = "No properties yet"
		no_props_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8.ttf"))
		no_props_label.add_theme_font_size_override("font_size", 10)
		no_props_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		properties_grid.add_child(no_props_label)


func _on_view_details_pressed() -> void:
	# Show detailed properties popup
	if not properties_detail_popup:
		properties_detail_popup = PropertiesDetailPopupScene.instantiate()
		# Ensure the details popup renders above BankruptcyPopup overlay
		properties_detail_popup.layer = 200
		get_tree().root.add_child(properties_detail_popup)

	# Update the popup with current player
	var current = GameController.get_current_player()
	if current and properties_detail_popup.has_method("show_properties"):
		properties_detail_popup.show_properties(current)

	if properties_detail_popup.has_method("show_popup"):
		properties_detail_popup.show_popup()


# using this for the Bankruptcy open asset button
func open_details_for_player(player) -> void:
	if not properties_detail_popup:
		properties_detail_popup = PropertiesDetailPopupScene.instantiate()
		# Ensure the details popup renders above BankruptcyPopup overlay
		properties_detail_popup.layer = 200
		get_tree().root.add_child(properties_detail_popup)

	if properties_detail_popup.has_method("show_properties"):
		properties_detail_popup.show_properties(player)

	if properties_detail_popup.has_method("show_popup"):
		properties_detail_popup.show_popup()

	print("OPEN DETAILS FOR:", player.player_name)


func _on_trade_pressed() -> void:
	trade_pressed.emit()

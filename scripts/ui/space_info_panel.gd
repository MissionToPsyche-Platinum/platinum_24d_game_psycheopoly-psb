extends CanvasLayer

const PropertyDetailsPopup = preload("res://scenes/PropertyDetailsPopup.tscn")

# References to UI elements
@onready var panel_container: Panel = $Control/PanelContainer
@onready var space_name_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar/SpaceName
@onready var space_type_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/SpaceType
@onready var description_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/Description
@onready var price_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/PriceLabel
@onready var color_bar: ColorRect = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar
@onready var details_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DetailsButton
@onready var upgrade_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/UpgradeButton
@onready var downgrade_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DowngradeButton
@onready var color_symbol: TextureRect = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar/ColorSymbol
@onready var color_symbol_shadow: TextureRect = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar/ColorSymbolShadow

# Current space being displayed
var current_space: int = 0

# Popup instance
var _details_popup: CanvasLayer = null


func _ready() -> void:
	# Connect button signals
	details_button.pressed.connect(_on_details_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	downgrade_button.pressed.connect(_on_downgrade_pressed)
	
	# Connect space display update to property purchase signal
	GameController.property_ownership_changed.connect(trigger_display_update)

	# NEW: Refresh immediately when colorblind mode is toggled
	if SettingsManager:
		if SettingsManager.has_signal("colorblind_mode_changed"):
			if not SettingsManager.colorblind_mode_changed.is_connected(_on_colorblind_mode_changed):
				SettingsManager.colorblind_mode_changed.connect(_on_colorblind_mode_changed)
	
	# Update display with initial space
	update_space_display(0)


# Function to trigger an update from the purchase property signal
func trigger_display_update() -> void:
	update_space_display(current_space)


# NEW: Refresh current space immediately when colorblind mode changes
func _on_colorblind_mode_changed(_enabled: bool) -> void:
	update_space_display(current_space)


# Update the display with information about a space
func update_space_display(space_num: int) -> void:
	# Check if nodes are ready
	if not is_node_ready():
		return
	
	current_space = space_num
	var space_info = SpaceData.get_space_info(space_num)
	
	if space_info.is_empty():
		space_name_label.text = "Unknown Space"
		space_type_label.text = ""
		description_label.text = ""
		price_label.text = ""
		color_bar.visible = false
		return
	
	# Set space name
	space_name_label.text = space_info.name
	
	# Set space type
	match space_info.type:
		"property":
			space_type_label.text = "Property"
		"corner":
			space_type_label.text = "Special Space"
		"instrument":
			space_type_label.text = "Scientific Instrument"
		"planet":
			space_type_label.text = "Planet"
		"cost":
			space_type_label.text = "Cost"
		"card":
			space_type_label.text = "Draw Card"
		_:
			space_type_label.text = ""
	
	# Set description
	description_label.text = space_info.description if space_info.has("description") else ""
	
	# Set price display
	if space_info.has("price"):
		# Show price but no purchase button here
		price_label.text = "Price: $" + str(space_info.price)
		price_label.visible = true
	elif space_info.has("amount"):  # For cost spaces
		price_label.text = "Amount: $" + str(space_info.amount)
		price_label.visible = true
	else:
		price_label.text = ""
		price_label.visible = false
	
	# Show details button only for properties (property, instrument, planet)
	var has_details: bool = space_info.type in ["property", "instrument", "planet"]
	details_button.visible = has_details
	
	# Show upgrade/downgrade buttons only for properties that are owned by the current player
	var show_upgrade: bool = space_info.type in ["property"]
	var can_upgrade = show_upgrade
	var can_downgrade = show_upgrade
	if show_upgrade:
		show_upgrade = (GameState.board[current_space]._is_owned && GameState.board[current_space]._player_owner == GameState.current_player_index)
		can_upgrade = GameController._check_if_upgrade_is_valid(GameState.board[current_space], GameState.current_player_index)
		can_downgrade = GameController._check_if_downgrade_is_valid(GameState.board[current_space], GameState.current_player_index)
	upgrade_button.visible = show_upgrade
	downgrade_button.visible = show_upgrade

	# Only enable the buttons if the player can currently upgrade/downgrade the property
	upgrade_button.disabled = !can_upgrade
	downgrade_button.disabled = !can_downgrade

	# Set color bar
	if space_info.has("color"):
		color_bar.color = space_info.color
		color_bar.visible = true
	else:
		color_bar.visible = false

	_update_colorblind_symbol(space_num)


func _update_colorblind_symbol(space_num: int) -> void:
	if not color_symbol or not color_symbol_shadow:
		return

	# Hide both by default
	color_symbol.visible = false
	color_symbol.texture = null

	color_symbol_shadow.visible = false
	color_symbol_shadow.texture = null

	# Only show symbol overlays when colorblind mode is actually enabled
	if not SettingsManager.is_colorblind_enabled():
		return

	var tex := ColorblindHelpers.get_symbol_texture_for_space(space_num)

	if tex:
		# Main white symbol
		color_symbol.texture = tex
		color_symbol.visible = true

		# Black shadow / faux outline
		color_symbol_shadow.texture = tex
		color_symbol_shadow.visible = true
		

# Called when the Details button is pressed
func _on_details_pressed() -> void:
	# Create popup if it doesn't exist
	if _details_popup == null:
		_details_popup = PropertyDetailsPopup.instantiate()
		# CanvasLayers must be added to the SceneTree directly
		get_tree().root.add_child(_details_popup)
		print("Popup created and will be added to scene tree")
	
	# Show the popup with current space details
	var property = GameState.board[current_space]
	var owner_str = "Unowned"
	var owner_color: Color = Color(0.7, 0.7, 0.7, 1)
	print("Showing details for space: ", current_space)
	if property is Ownable and property._is_owned:
		var owner_index := int(property._player_owner)
		if owner_index >= 0 and owner_index < GameState.players.size():
			owner_str = GameState.get_player_display_name(owner_index)
			owner_color = GameState.players[owner_index].player_color
		else:
			owner_str = GameState.get_player_display_name(owner_index)
	_details_popup.show_space_details(current_space, owner_str, owner_color)  


func _on_upgrade_pressed() -> void:
	GameController.upgrade_property.emit(GameState.board[current_space], GameState.current_player_index)
	print("upgrade pressed")
	update_space_display(current_space)


func _on_downgrade_pressed() -> void:
	GameController.downgrade_property.emit(GameState.board[current_space], GameState.current_player_index)
	print("downgrade pressed")
	update_space_display(current_space)
	

extends CanvasLayer
signal close_pressed

# References to UI elements
@onready var color_bar: ColorRect = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar
@onready var color_symbol_shadow: TextureRect = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar/ColorSymbolShadow
@onready var color_symbol: TextureRect = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar/ColorSymbol
@onready var property_name: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar/PropertyName
@onready var property_type: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/PropertyType
@onready var details_container: VBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer
@onready var owner_label: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/OwnerContainer/OwnerLabel
@onready var close_button: Button = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ButtonContainer/CloseButton
@onready var sfx_click: AudioStreamPlayer = $SfxClick


# Detail row references
@onready var rent_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/RentContainer/Value
@onready var rent1_container: HBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent1Container
@onready var rent1_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent1Container/Value
@onready var rent2_container: HBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent2Container
@onready var rent2_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent2Container/Value
@onready var rent3_container: HBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent3Container
@onready var rent3_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent3Container/Value
@onready var rent4_container: HBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent4Container
@onready var rent4_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/Rent4Container/Value
@onready var rent_full_container: HBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/RentFullContainer
@onready var rent_full_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/RentFullContainer/Value

# Additional info references
@onready var additional_info_container: VBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/AdditionalInfoContainer
@onready var collaboration_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/AdditionalInfoContainer/CollaborationContainer/Value
@onready var data_point_cost: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/AdditionalInfoContainer/DataPointCostContainer/Value
@onready var discovery_cost: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/AdditionalInfoContainer/DiscoveryCostContainer/Value



# Current space being displayed
var current_space: int = 0


func _ready() -> void:
	# Ensure the popup stays fixed on screen (HUD mode)
	follow_viewport_enabled = false
	
	# Connect button signals
	close_button.pressed.connect(_on_close_pressed)
	
	# Start hidden
	visible = false
# Show the popup with information about a space
func show_space_details(space_num: int, owner_name: String = "Unowned", owner_color: Color = Color(0.7, 0.7, 0.7, 1)) -> void:
	current_space = space_num
	var space_info = SpaceData.get_space_info(space_num)
	
	if space_info.is_empty():
		push_warning("Invalid space number: ", space_num)
		return
	
	# Set property name and color bar
	property_name.text = space_info.name
	if space_info.has("color"):
		color_bar.color = space_info.color
	else:
		color_bar.color = Color.GRAY
		
	_update_colorblind_symbol(space_num)
	
	# Set property type
	match space_info.type:
		"property":
			property_type.text = "SCIENTIFIC DATA"
		"instrument":
			property_type.text = "RESEARCH INSTRUMENT"
		"planet":
			property_type.text = "PLANETARY STUDY"
		"corner":
			property_type.text = "SPECIAL SPACE"
		"expense":
			property_type.text = "EXPENSE"
		"card":
			property_type.text = "DRAW CARD"
		_:
			property_type.text = "SPACE"
	
	# Configure details based on space type
	if space_info.type == "property":
		_show_property_details(space_info)
	elif space_info.type == "instrument":
		_show_instrument_details(space_info)
	elif space_info.type == "planet":
		_show_planet_details(space_info)
	else:
		_hide_all_details()
	
	# Set owner
	owner_label.text = owner_name
	owner_label.add_theme_color_override("font_color", owner_color)
	
	# Show the popup and bring to front
	visible = true
	print("Popup shown for space: ", space_info.name)


# Display property rental details
func _show_property_details(space_info: Dictionary) -> void:
	details_container.visible = true
	
	var is_mortgaged := current_space >= 0 \
		and current_space < GameState.board.size() \
		and GameState.board[current_space] is Ownable \
		and (GameState.board[current_space] as Ownable)._is_mortgaged

	# Calculate rent values (typical Monopoly progression)
	if is_mortgaged:
		rent_value.text = "$0"
		rent_value.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
	else:
		rent_value.text = "$" + str(space_info.rent)
		rent_value.remove_theme_color_override("font_color")
	rent1_value.text = "$" + str(space_info.rent1data)
	rent2_value.text = "$" + str(space_info.rent2data)
	rent3_value.text = "$" + str(space_info.rent3data)
	rent4_value.text = "$" + str(space_info.rent4data)
	rent_full_value.text = "$" + str(space_info.rentDiscovery)
	
	# Show all rent containers
	rent1_container.visible = true
	rent2_container.visible = true
	rent3_container.visible = true
	rent4_container.visible = true
	rent_full_container.visible = true
	
	# Show additional property info
	additional_info_container.visible = true
	if space_info.has("price"):
		# Collaboration value is half the property price (mortgage value in Monopoly)
		var collab_value: int = space_info.mortgage
		collaboration_value.text = " $" + str(collab_value)
		
		# Data point cost is half the property price
		var dp_cost: int = space_info.dataCost
		data_point_cost.text = " $" + str(dp_cost) + " each"
		
		# Discovery cost is the data point cost plus 4 data points
		discovery_cost.text = " $" + str(dp_cost) + " plus 4 Data Pts"

	# Bold the row matching the current upgrade level; regular for all others
	var upgrades := 0
	if current_space >= 0 and current_space < GameState.board.size():
		var space = GameState.board[current_space]
		if space is PropertySpace:
			upgrades = (space as PropertySpace)._current_upgrades
	_set_rent_row_bold(rent_value.get_parent(), upgrades == 0)
	_set_rent_row_bold(rent1_container, upgrades == 1)
	_set_rent_row_bold(rent2_container, upgrades == 2)
	_set_rent_row_bold(rent3_container, upgrades == 3)
	_set_rent_row_bold(rent4_container, upgrades == 4)
	_set_rent_row_bold(rent_full_container, upgrades == 5)


func _set_rent_row_bold(container: Control, bold: bool) -> void:
	var font: Font = load("res://assets/fonts/PixelOperator8-Bold.ttf" if bold else "res://assets/fonts/PixelOperator8.ttf")
	for child in container.get_children():
		if child is Label:
			child.add_theme_font_override("font", font)


# Display instrument (railroad equivalent) details
func _show_instrument_details(_space_info: Dictionary) -> void:
	details_container.visible = true
	
	# Instruments have fixed rent based on how many you own
	rent_value.text = "$25 (1 owned)"
	rent1_value.text = "$50 (2 owned)"
	rent2_value.text = "$100 (3 owned)"
	rent3_value.text = "$200 (4 owned)"
	
	# Rename labels for instruments
	rent1_container.get_node("Label").text = "With 2 Instruments:"
	rent2_container.get_node("Label").text = "With 3 Instruments:"
	rent3_container.get_node("Label").text = "With 4 Instruments:"
	
	# Show only relevant containers
	rent1_container.visible = true
	rent2_container.visible = true
	rent3_container.visible = true
	rent4_container.visible = false
	rent_full_container.visible = false
	
	# Hide additional info for instruments
	additional_info_container.visible = false


# Display planet (utility equivalent) details
func _show_planet_details(_space_info: Dictionary) -> void:
	details_container.visible = true
	
	# Planets use dice multiplier
	rent_value.text = "4× dice roll (1 planet)"
	rent1_value.text = "10× dice roll (2 planets)"
	
	# Rename labels for planets
	rent1_container.get_node("Label").text = "With 2 Planets:"
	
	# Show only relevant containers
	rent1_container.visible = true
	rent2_container.visible = false
	rent3_container.visible = false
	rent4_container.visible = false
	rent_full_container.visible = false
	
	# Hide additional info for planets
	additional_info_container.visible = false


# Hide all detail rows
func _hide_all_details() -> void:
	details_container.visible = false
	additional_info_container.visible = false


# Called when close button is pressed
func _on_close_pressed() -> void:
	if sfx_click:
		sfx_click.pitch_scale = randf_range(0.95, 1.05) # optional polish
		sfx_click.play()

	visible = false
	emit_signal("close_pressed")
	print("Popup closed")

func _update_colorblind_symbol(space_num: int) -> void:
	# Hide by default
	color_symbol.visible = false
	color_symbol_shadow.visible = false
	color_symbol.texture = null
	color_symbol_shadow.texture = null

	var symbol_texture: Texture2D = ColorblindHelpers.get_symbol_texture_for_space(space_num)
	if symbol_texture == null:
		return

	# Apply same texture to both
	color_symbol.texture = symbol_texture
	color_symbol_shadow.texture = symbol_texture

	# Show both layers
	color_symbol.visible = true
	color_symbol_shadow.visible = true

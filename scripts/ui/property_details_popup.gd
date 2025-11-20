extends CanvasLayer

# Load space data
const SpaceData = preload("res://scripts/core/space_data.gd")

# References to UI elements
@onready var color_bar: ColorRect = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar
@onready var property_name: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar/PropertyName
@onready var property_type: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/PropertyType
@onready var description: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/Description
@onready var details_container: VBoxContainer = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer
@onready var owner_label: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/OwnerContainer/OwnerLabel
@onready var close_button: Button = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ButtonContainer/CloseButton

# Detail row references
@onready var price_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/DetailsContainer/PriceContainer/Value
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
func show_space_details(space_num: int, owner_name: String = "Unowned") -> void:
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
	
	# Set description
	description.text = space_info.description if space_info.has("description") else "No description available."
	
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
	if owner_name == "Unowned":
		owner_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	else:
		owner_label.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	
	# Show the popup and bring to front
	visible = true
	print("Popup shown for space: ", space_info.name)


# Display property rental details
func _show_property_details(space_info: Dictionary) -> void:
	details_container.visible = true
	
	# Show price
	if space_info.has("price"):
		price_value.text = "$" + str(space_info.price)
	
	# Parse rent from description (e.g., "Research Funding $2")
	var base_rent := 2
	if space_info.has("description"):
		var desc: String = space_info.description
		var rent_start := desc.find("$")
		if rent_start >= 0:
			var rent_str := desc.substr(rent_start + 1)
			base_rent = rent_str.to_int()
	
	# Calculate rent values (typical Monopoly progression)
	rent_value.text = "$" + str(base_rent)
	rent1_value.text = "$" + str(base_rent * 5)
	rent2_value.text = "$" + str(base_rent * 15)
	rent3_value.text = "$" + str(base_rent * 45)
	rent4_value.text = "$" + str(base_rent * 80)
	rent_full_value.text = "$" + str(base_rent * 125)
	
	# Show all rent containers
	rent1_container.visible = true
	rent2_container.visible = true
	rent3_container.visible = true
	rent4_container.visible = true
	rent_full_container.visible = true


# Display instrument (railroad equivalent) details
func _show_instrument_details(space_info: Dictionary) -> void:
	details_container.visible = true
	
	# Show price
	if space_info.has("price"):
		price_value.text = "$" + str(space_info.price)
	
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


# Display planet (utility equivalent) details
func _show_planet_details(space_info: Dictionary) -> void:
	details_container.visible = true
	
	# Show price
	if space_info.has("price"):
		price_value.text = "$" + str(space_info.price)
	
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


# Hide all detail rows
func _hide_all_details() -> void:
	details_container.visible = false


# Called when close button is pressed
func _on_close_pressed() -> void:
	visible = false
	print("Popup closed")

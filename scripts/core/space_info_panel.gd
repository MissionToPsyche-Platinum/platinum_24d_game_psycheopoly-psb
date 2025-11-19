extends Control

# Load space data
const SpaceData = preload("res://scripts/core/space_data.gd")
const PropertyDetailsPopup = preload("res://scenes/PropertyDetailsPopup.tscn")

# References to UI elements
@onready var panel_container: PanelContainer = $PanelContainer
@onready var space_name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpaceName
@onready var space_type_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpaceType
@onready var description_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Description
@onready var price_label: Label = $PanelContainer/MarginContainer/VBoxContainer/PriceLabel
@onready var color_bar: ColorRect = $PanelContainer/MarginContainer/VBoxContainer/ColorBar
@onready var details_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DetailsButton
@onready var purchase_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/PurchaseButton

# Current space being displayed
var current_space: int = 0

# Popup instance
var _details_popup: Control = null


func _ready() -> void:
	# Initially hide purchase button
	purchase_button.visible = false
	
	# Connect button signals
	details_button.pressed.connect(_on_details_pressed)
	purchase_button.pressed.connect(_on_purchase_pressed)
	
	# Update display with initial space
	update_space_display(0)


# Update the display with information about a space
func update_space_display(space_num: int) -> void:
	current_space = space_num
	var space_info = SpaceData.get_space_info(space_num)
	
	if space_info.is_empty():
		space_name_label.text = "Unknown Space"
		space_type_label.text = ""
		description_label.text = ""
		price_label.text = ""
		color_bar.visible = false
		purchase_button.visible = false
		return
	
	# Set space name
	space_name_label.text = space_info.name
	
	# Set space type
	match space_info.type:
		"property":
			space_type_label.text = "Property"
		"corner":
			space_type_label.text = "Special Space"
		"railroad":
			space_type_label.text = "Infrastructure"
		"utility":
			space_type_label.text = "Utility"
		"tax":
			space_type_label.text = "Tax"
		"card":
			space_type_label.text = "Draw Card"
		_:
			space_type_label.text = ""
	
	# Set description
	description_label.text = space_info.description if space_info.has("description") else ""
	
	# Set price and purchase button visibility
	if space_info.has("price"):
		price_label.text = "Price: $" + str(space_info.price)
		price_label.visible = true
		purchase_button.visible = true
		purchase_button.disabled = false  # TODO: Check if player can afford and doesn't own it
	elif space_info.has("amount"):  # For tax spaces
		price_label.text = "Amount: $" + str(space_info.amount)
		price_label.visible = true
		purchase_button.visible = false
	else:
		price_label.text = ""
		price_label.visible = false
		purchase_button.visible = false
	
	# Set color bar
	if space_info.has("color"):
		color_bar.color = space_info.color
		color_bar.visible = true
	else:
		color_bar.visible = false


# Called when the Details button is pressed
func _on_details_pressed() -> void:
	# Create popup if it doesn't exist
	if _details_popup == null:
		_details_popup = PropertyDetailsPopup.instantiate()
		# Add to GameBoard scene (go up to find the root scene)
		var game_board = get_tree().root.get_node("GameBoard")
		if game_board:
			game_board.add_child(_details_popup)
			print("Popup added to GameBoard")
		else:
			get_tree().root.add_child(_details_popup)
			print("Popup added to root")
		print("Popup node path: ", _details_popup.get_path())
	
	# Show the popup with current space details
	print("Showing details for space: ", current_space)
	print("Popup visible before show: ", _details_popup.visible)
	_details_popup.show_space_details(current_space, "Unowned")  # TODO: Get actual owner
	print("Popup visible after show: ", _details_popup.visible)


# Called when the Purchase button is pressed
func _on_purchase_pressed() -> void:
	print("Purchase button pressed for space ", current_space)
	var space_info = SpaceData.get_space_info(current_space)
	if space_info.has("price"):
		print("Attempting to purchase ", space_info.name, " for $", space_info.price)
		# TODO: Implement purchase logic
		# - Check if player has enough money
		# - Check if property is already owned
		# - Deduct money from player
		# - Add property to player's owned properties
		# - Update UI to show property is owned

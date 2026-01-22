extends CanvasLayer
#TODO:
# WHen user clicks pass, they pass correctly
#add sounds to the button press as feedback
# add a green floating dollar amount as visual confirmation that the user bid on selected amount
# add funnctionality that it deducts from user balance

# ============================
# Signals (emitted to GameBoard / Auction Manager)
# ============================
const SpaceDataRef = preload("res://scripts/core/space_data.gd")

signal details_requested
signal pass_requested
signal bid_increment_requested(amount: int)


var current_space_num: int = -1

# ============================
# Node References
# ============================

# Root UI container
@onready var ui_root: Control = $Control

# Main button row
@onready var buttons_row: HBoxContainer = ui_root.get_node(
	"CenterContainer/Panel/PanelContainer/VBoxContainer/ButtonsRow"
)

@onready var details_btn: Button = buttons_row.get_node("DetailsButton")
@onready var bid_btn: Button     = buttons_row.get_node("BidButton")
@onready var pass_btn: Button    = buttons_row.get_node("PassButton")

# Bid increment controls (hidden by default)
@onready var bid_controls: HBoxContainer = ui_root.get_node(
	"CenterContainer/Panel/PanelContainer/VBoxContainer/BidControlRow"
)

@onready var bid_10: Button  = bid_controls.get_node("BidPlus10")
@onready var bid_50: Button  = bid_controls.get_node("BidPlus50")
@onready var bid_100: Button = bid_controls.get_node("BidPlus100")


@onready var property_name_label: Label = ui_root.get_node(
	"CenterContainer/Panel/PanelContainer/VBoxContainer/ColorBar/PropertyName"
)
@onready var property_type_label: Label = ui_root.get_node(
	"CenterContainer/Panel/PanelContainer/VBoxContainer/PropertyType"
)


# ============================
# Ready
# ============================

func _ready() -> void:
	# Start hidden
	bid_controls.visible = false

	# Main action buttons
	details_btn.pressed.connect(_on_details_pressed)
	pass_btn.pressed.connect(_on_pass_pressed)
	bid_btn.pressed.connect(_on_bid_pressed)

	# Bid increment buttons
	bid_10.pressed.connect(func(): _emit_bid_increment(10))
	bid_50.pressed.connect(func(): _emit_bid_increment(50))
	bid_100.pressed.connect(func(): _emit_bid_increment(100))



# ============================
# Button Handlers
# ============================

func _on_details_pressed() -> void:
	emit_signal("details_requested")

func _on_pass_pressed() -> void:
	emit_signal("pass_requested")

func _on_bid_pressed() -> void:
	# Toggle bid increment row
	bid_controls.visible = !bid_controls.visible

func _emit_bid_increment(amount: int) -> void:
	emit_signal("bid_increment_requested", amount)

# ============================
# Public Helpers
# ============================

func show_popup(space_num: int) -> void:
	visible = true
	bid_controls.visible = false

	current_space_num = space_num

	var space_info: Dictionary = SpaceDataRef.get_space_info(space_num)
	if space_info.is_empty():
		property_name_label.text = "Unknown Space"
		property_type_label.text = ""
		push_warning("AuctionPopup: invalid space num: %s" % str(space_num))
		return

	# Title
	property_name_label.text = space_info.get("name", "Unknown Space")

	# Type text 
	match space_info.get("type", ""):
		"property":
			property_type_label.text = "SCIENTIFIC DATA"
		"instrument":
			property_type_label.text = "RESEARCH INSTRUMENT"
		"planet":
			property_type_label.text = "PLANETARY STUDY"
		"corner":
			property_type_label.text = "SPECIAL SPACE"
		"expense":
			property_type_label.text = "EXPENSE"
		"card":
			property_type_label.text = "DRAW CARD"
		_:
			property_type_label.text = "SPACE"

	print("AuctionPopup opened for space:", space_num, "->", property_name_label.text)



func hide_popup() -> void:
	visible = false
	bid_controls.visible = false
	current_space_num = -1

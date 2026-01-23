extends CanvasLayer
#TODO:
# add funnctionality that it deducts from user balance (handled by auction manager)

# ============================
# Signals (emitted to GameBoard / Auction Manager)
# ============================

const SpaceDataRef = preload("res://scripts/core/space_data.gd")
const FloatingNumberScene := preload("res://scenes/FloatingNumber.tscn")

signal details_requested
signal pass_requested
signal bid_increment_requested(amount: int)

var current_space_num: int = -1

# ============================
# Node References
# ============================

@onready var ui_root: Control = $Control

@onready var buttons_row: HBoxContainer = ui_root.get_node(
	"CenterContainer/Panel/PanelContainer/VBoxContainer/ButtonsRow"
)

@onready var details_btn: Button = buttons_row.get_node("DetailsButton")
@onready var bid_btn: Button     = buttons_row.get_node("BidButton")
@onready var pass_btn: Button    = buttons_row.get_node("PassButton")

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

@onready var sfx_click: AudioStreamPlayer = $SfxClick

# ============================
# Ready
# ============================

func _ready() -> void:
	bid_controls.visible = false

	details_btn.pressed.connect(_on_details_pressed)
	pass_btn.pressed.connect(_on_pass_pressed)
	bid_btn.pressed.connect(_on_bid_pressed)

	# Bid increment buttons
	bid_10.pressed.connect(func(): _emit_bid_increment(10, bid_10))
	bid_50.pressed.connect(func(): _emit_bid_increment(50, bid_50))
	bid_100.pressed.connect(func(): _emit_bid_increment(100, bid_100))

# ============================
# Button Handlers
# ============================

func _on_details_pressed() -> void:
	_play_click()
	emit_signal("details_requested")

func _on_pass_pressed() -> void:
	_play_click()
	emit_signal("pass_requested")

func _on_bid_pressed() -> void:
	_play_click()
	bid_controls.visible = !bid_controls.visible

func _emit_bid_increment(amount: int, from_button: Control) -> void:
	# Visual confirmation (polish)
	_spawn_floating_number(amount, from_button)

	# Let AuctionManager validate + apply the bid
	emit_signal("bid_increment_requested", amount)

func _play_click() -> void:
	if sfx_click:
		sfx_click.pitch_scale = randf_range(0.95, 1.05)
		sfx_click.play()

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

	property_name_label.text = space_info.get("name", "Unknown Space")

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

# ============================
# Floating Number Polish
# ============================

func _spawn_floating_number(amount: int, from_button: Control) -> void:
	var n := FloatingNumberScene.instantiate() as Control

	# Add to popup root overlay (NOT into an HBox/VBox container)
	ui_root.add_child(n)

	# Button center in GLOBAL space
	var button_center_global: Vector2 = from_button.global_position + (from_button.size * 0.5)

	# Convert GLOBAL -> ui_root LOCAL space (works even when Control has no to_local)
	var local_pos: Vector2 = ui_root.get_global_transform().affine_inverse() * button_center_global

	# Place slightly above button center
	n.position = local_pos + Vector2(0, -8)

	# Run its tween
	if n.has_method("play"):
		n.call("play", amount)

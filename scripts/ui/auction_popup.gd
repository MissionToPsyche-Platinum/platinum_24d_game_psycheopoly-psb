extends CanvasLayer
#TODO:
# maybe add a buffer or cushion so the bid buttons aren't so close to "details, bid, pass"
# maybe have the feedback of the green floating number stay on screen just a tick or two longer
# when user selects money to bid, it makes sure the user has available funds to bid once bid closes...
# final total gets deducted from player balance
# ======================================
# Signals (communicates with Game Board)
# ======================================

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
@onready var sfx_bid_ok: AudioStreamPlayer = $SfxBidOk


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
	# SFX: bid accepted 
	if sfx_bid_ok:
		_play_ui(sfx_bid_ok, 0.98, 1.05)
	else:
		_play_ui(sfx_click, 0.98, 1.05)

	# Visual confirmation / floating number when button pressed
	_spawn_floating_number(amount, from_button)

	emit_signal("bid_increment_requested", amount)

func _play_click() -> void:
	_play_ui(sfx_click, 0.95, 1.05)

func _play_ui(player: AudioStreamPlayer, pitch_min := 0.97, pitch_max := 1.03) -> void:
	if player and player.stream:
		player.pitch_scale = randf_range(pitch_min, pitch_max)

		#  prevent sound stacking when spamming buttons
		if player.playing:
			player.stop()

		player.play()


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


# ========================================
# Floating Number Animation for bid button
# ========================================

func _spawn_floating_number(amount: int, from_button: Control) -> void:
	var n := FloatingNumberScene.instantiate() as Control

	# Add to popup root overlay 
	ui_root.add_child(n)

	# Button center in the global space
	var button_center_global: Vector2 = from_button.global_position + (from_button.size * 0.5)

	# Convert global to ui_root local space
	var local_pos: Vector2 = ui_root.get_global_transform().affine_inverse() * button_center_global

	# Place a little above button center
	n.position = local_pos + Vector2(0, -17)

	# Run its tween
	if n.has_method("play"):
		n.call("play", amount)

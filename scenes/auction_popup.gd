extends CanvasLayer

# ============================
# Signals (emitted to GameBoard / Auction Manager)
# ============================
signal details_requested
signal pass_requested
signal bid_increment_requested(amount: int)

# ============================
# Node References
# ============================

# Root UI container (child of CanvasLayer)
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
@onready var bid_max: Button = bid_controls.get_node("BidMax")

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
	bid_max.pressed.connect(func(): _emit_bid_increment(-1)) # -1 = Max bid

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
# Public Helpers (optional but useful)
# ============================

func show_popup() -> void:
	visible = true
	bid_controls.visible = false

func hide_popup() -> void:
	visible = false
	bid_controls.visible = false

extends CanvasLayer
class_name BankruptcyPopup

signal open_assets_requested(debtor_id: int)
signal attempt_pay_requested
signal bankruptcy_declared

@onready var overlay: ColorRect = %Overlay

@onready var owed_to_label: Label = %OwedToLabel
@onready var reason_label: Label = %ReasonLabel
@onready var amount_label: Label = %AmountOwedLabel
@onready var cash_label: Label = %CashLabel
@onready var shortfall_label: Label = %ShortfallLabel

@onready var btn_open_assets: Button = %OpenAssetsButton
@onready var btn_attempt_pay: Button = %AttemptToPayButton
@onready var btn_trade_sell: Button = %TradeSellButton
@onready var btn_bankrupt: Button = %DeclareBankruptcyButton

var _debtor_id: int = -1
var _amount_owed: int = 0

func _ready() -> void:
	push_warning("BankruptcyPopup READY ok (nodes found)")

	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	btn_open_assets.pressed.connect(_on_open_assets_pressed)
	btn_attempt_pay.pressed.connect(_on_attempt_pay_pressed)
	btn_bankrupt.pressed.connect(_on_bankrupt_pressed)

	btn_trade_sell.disabled = true
	btn_trade_sell.tooltip_text = "Trading not available yet."

func show_popup(debtor_id: int, creditor_name: String, reason: String, amount_owed: int, current_cash: int) -> void:
	_debtor_id = debtor_id
	_amount_owed = amount_owed

	owed_to_label.text = "Owed to: %s" % creditor_name
	reason_label.text = "Reason: %s" % reason
	amount_label.text = "Amount Owed: $%d" % amount_owed
	cash_label.text = "Your Cash: $%d" % current_cash

	var shortfall: int = maxi(0, amount_owed - current_cash)
	shortfall_label.text = "Shortfall: $%d" % shortfall

	show()
	overlay.show()

func update_cash(current_cash: int) -> void:
	cash_label.text = "Your Cash: $%d" % current_cash
	var shortfall: int = maxi(0, _amount_owed - current_cash)
	shortfall_label.text = "Shortfall: $%d" % shortfall

func hide_popup() -> void:
	hide()
	overlay.hide()

func _on_open_assets_pressed() -> void:
	print("POPUP: open assets clicked") # Output tab
	emit_signal("open_assets_requested", _debtor_id)


func _on_attempt_pay_pressed() -> void:
	push_warning("POPUP: attempt pay clicked")
	emit_signal("attempt_pay_requested")

func _on_bankrupt_pressed() -> void:
	push_warning("POPUP: declare bankruptcy clicked")
	emit_signal("bankruptcy_declared")

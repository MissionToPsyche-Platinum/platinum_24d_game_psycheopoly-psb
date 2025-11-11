extends Control

@onready var roll_button: Button = $RollPanel/VBox/RollButton
@onready var die1_label: Label = $RollPanel/VBox/DiceRow/Die1Label
@onready var die2_label: Label = $RollPanel/VBox/DiceRow/Die2Label
@onready var result_label: Label = $RollPanel/VBox/ResultLabel

var rng := RandomNumberGenerator.new()

signal dice_rolled(d1: int, d2: int, total: int, is_doubles: bool)

func _ready() -> void:
	rng.randomize()
	roll_button.pressed.connect(_on_roll_pressed)
	_reset_ui()

func _reset_ui() -> void:
	die1_label.text = "1"
	die2_label.text = "1"
	result_label.text = "Total: —"

func _on_roll_pressed() -> void:
	var d1 := rng.randi_range(1, 6)
	var d2 := rng.randi_range(1, 6)
	var total := d1 + d2
	var doubles := (d1 == d2)

	die1_label.text = str(d1)
	die2_label.text = str(d2)
	result_label.text = "Total: %d%s" % [total, ("  (Doubles!)" if doubles else "")]


	emit_signal("dice_rolled", d1, d2, total, doubles)

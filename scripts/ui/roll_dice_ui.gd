extends Control

@onready var roll_button: Button = $RollPanel/VBox/RollButton
@onready var die1_label: Label = $RollPanel/VBox/DiceRow/Die1Label
@onready var die2_label: Label = $RollPanel/VBox/DiceRow/Die2Label
@onready var result_label: Label = $RollPanel/VBox/ResultLabel

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

signal dice_rolled(d1: int, d2: int, total: int, is_doubles: bool)


func _ready() -> void:
	rng.randomize()
	roll_button.pressed.connect(_on_roll_pressed)
	_reset_ui()


func _reset_ui() -> void:
	die1_label.text = "1"
	die2_label.text = "1"
	result_label.text = "Total: —"


# ---- helper used by tests and the UI ----
func roll_dice() -> Dictionary:
	var d1: int = rng.randi_range(1, 6)
	var d2: int = rng.randi_range(1, 6)
	var total: int = d1 + d2
	var doubles: bool = (d1 == d2)

	return {
		"d1": d1,
		"d2": d2,
		"total": total,
		"doubles": doubles
	}


func _on_roll_pressed() -> void:
	var r: Dictionary = roll_dice()
	var d1: int = r["d1"]
	var d2: int = r["d2"]
	var total: int = r["total"]
	var doubles: bool = r["doubles"]

	die1_label.text = str(d1)
	die2_label.text = str(d2)
	result_label.text = "Total: %d%s" % [total, ("  (Doubles!)" if doubles else "")]

	dice_rolled.emit(d1, d2, total, doubles)

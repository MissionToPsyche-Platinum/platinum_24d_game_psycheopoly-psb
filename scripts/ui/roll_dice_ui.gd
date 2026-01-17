extends Control

@onready var roll_button: Button = $RollPanel/MarginContainer/VBox/RollButton
@onready var die1_label: Label = $RollPanel/MarginContainer/VBox/DiceRow/Die1Label
@onready var die2_label: Label = $RollPanel/MarginContainer/VBox/DiceRow/Die2Label
@onready var result_label: Label = $RollPanel/MarginContainer/VBox/ResultLabel

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


func _unhandled_input(event: InputEvent) -> void:
	# Strictly debug option: press numpad 1-9 to force a roll
	if not OS.is_debug_build():
		return
		
	if event is InputEventKey and event.pressed:
		var forced_value: int = -1
		match event.keycode:
			KEY_KP_1: forced_value = 1
			KEY_KP_2: forced_value = 2
			KEY_KP_3: forced_value = 3
			KEY_KP_4: forced_value = 4
			KEY_KP_5: forced_value = 5
			KEY_KP_6: forced_value = 6
			KEY_KP_7: forced_value = 7
			KEY_KP_8: forced_value = 8
			KEY_KP_9: forced_value = 9
			
		if forced_value != -1:
			_perform_forced_roll(forced_value)


func _perform_forced_roll(total: int) -> void:
	# Split the total into two dice (debug only, so d1=1, d2=total-1 is fine)
	# Even if total=1, we'll just allow it for debug convenience
	var d1: int = 0
	var d2: int = 0
	
	if total == 1:
		d1 = 1
		d2 = 0
	else:
		d1 = floor(total / 2.0)
		d2 = total - d1
		
	var doubles: bool = (d1 == d2) and d1 > 0

	die1_label.text = str(d1)
	die2_label.text = str(d2)
	result_label.text = "DEBUG: %d%s" % [total, ("  (Doubles!)" if doubles else "")]

	dice_rolled.emit(d1, d2, total, doubles)

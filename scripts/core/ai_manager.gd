extends Node

signal ai_dice_roll()

func _ready() -> void:
	print("READY CALLED")
	GameController.turn_started.connect(check_if_ai_turn)

func check_if_ai_turn(player_index) -> void:
	print("AI TURN CHECK")
	if GameState.players[player_index].player_is_ai == true:
		ai_turn_start()


func ai_turn_start() -> void:
	print("AI TURN START")
	ai_dice_roll.emit()
	

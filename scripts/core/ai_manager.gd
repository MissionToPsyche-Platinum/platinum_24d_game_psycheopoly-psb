extends Node

signal ai_dice_roll()

func _ready() -> void:
	GameController.turn_started.connect(check_if_ai_turn)

# Emits the ai turn start signal if the next player is AI 
func check_if_ai_turn(player_index) -> void:
	if GameState.players[player_index].player_is_ai == true:
		ai_turn_start()

# Actions that should occur at the start of the AI player's turn
func ai_turn_start() -> void:
	ai_dice_roll.emit()
	

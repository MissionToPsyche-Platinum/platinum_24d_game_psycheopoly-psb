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

# Controls logic for AI players landing on spaces
func ai_lands_on_space(space_num: int) -> void:
	var property = GameState.board[space_num]
	# Explicitly type script reference (prevents Variant inference warning)
	var scr: Script = property.get_script() as Script
	var gname: String = ""
	if scr != null:
		gname = scr.get_global_name()

	match gname:
		"PropertySpace", "InstrumentSpace", "PlanetSpace", "SpecialSpace", "CardSpace", "ExpenseSpace":
			ai_turn_mid()
	
# AI should choose between purchasing and auctioning here
func ai_lands_on_unowned_property() -> void:
	pass

# Pay rent here
func ai_lands_on_owned_property() -> void:
	pass

# AI should decide between property upgrading, trading, or ending the current turn
func ai_turn_mid() -> void:
	ai_turn_end()
	
func ai_turn_end() -> void:
	GameController.end_turn()

extends Node

signal ai_dice_roll()
signal ai_auction_start(space_num: int)
signal ai_draw_card(space_num: int)


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
		"PropertySpace", "InstrumentSpace", "PlanetSpace":
			if (property._is_owned == true):
				GameController.pay_rent.emit(property, GameState.current_player_index)
			else:
				ai_lands_on_unowned_property(space_num)
		"CardSpace":
			ai_draw_card.emit(space_num)
		"SpecialSpace", "ExpenseSpace":
			pass
	#ai_turn_mid() #temporarily commented out to test AI behaviour
	
# AI should choose between purchasing and auctioning here
func ai_lands_on_unowned_property(space_num: int) -> void:
	ai_auction_start.emit(space_num)


# AI should decide between property upgrading, trading, or ending the current turn
func ai_turn_mid() -> void:
	ai_turn_end()
	
func ai_turn_end() -> void:
	GameController.end_turn()

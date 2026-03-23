extends Node

# Signals called in this class 
signal ai_dice_roll()
signal ai_auction_start(space_num: int)
signal ai_draw_card(space_num: int)
signal ai_pay(space_num: int)
signal ai_move(space_num: int)

signal ai_auction_pass()
signal ai_auction_bid()

signal ai_trade_reject()

#Signals called by other classes
signal ai_auction_turn()
signal ai_trade_turn()

func _ready() -> void:
	GameController.turn_started.connect(check_if_ai_turn)
	ai_auction_turn.connect(ai_auction_decision)
	ai_trade_turn.connect(ai_trade_decision)
	
	ChanceCardMgr.card_resolved.connect(ai_card_resolve)

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

	print(gname)
	match gname:
		"PropertySpace", "InstrumentSpace", "PlanetSpace":
			if (property._is_owned == true):
				ai_pay.emit(space_num)
			else:
				await ai_lands_on_unowned_property(space_num)
		"CardSpace": # TODO: Make AI await the resolution of the chance card
			ai_draw_card.emit(space_num)
			return
		"ExpenseSpace":
			ai_pay.emit(space_num)
		"SpecialSpace":
			if (space_num == 30): # Solar Storm
				ai_move.emit(space_num)
		"GameSpace": # currently handles only the free parking sapce
			if (space_num == 20): # "Free parking" space
				var space_info = SpaceData.get_space_info(space_num)
				GameController.credit(GameState.current_player_index, space_info.get("amount", 0))
	ai_turn_mid() 
	

func ai_card_resolve (card_num: int) -> void:
	if (GameController.get_current_player().player_is_ai == false):
		return
	elif (card_num not in range(18, 33)): # Don't move to ai turn mid if the card is a movement based one. This range will need to be changed if chance card data is updated
		ai_turn_mid() 


# AI should choose between purchasing and auctioning here
func ai_lands_on_unowned_property(space_num: int) -> void:
	ai_auction_start.emit(space_num)
	await AuctionMgr.auction_ended
	await GameController.action_completed



# AI should decide between property upgrading, trading, or ending the current turn
func ai_turn_mid() -> void:
	ai_turn_end()

	
func ai_turn_end() -> void:
	if (GameState.players[GameState.current_player_index].has_rolled == true):
		GameController.end_turn()
	else:
		ai_turn_start()

# AI should decide how much to bid on an auction here
func ai_auction_decision() -> void:
	ai_auction_pass.emit()

# AI should decide whether to accept or decline a trade here
func ai_trade_decision() -> void:
	ai_trade_reject.emit()

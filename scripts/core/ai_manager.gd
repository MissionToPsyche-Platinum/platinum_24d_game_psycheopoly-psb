extends Node

# Signals called in this class 
signal ai_dice_roll()
signal ai_auction_start(space_num: int)
signal ai_draw_card(space_num: int)
signal ai_pay(space_num: int)
signal ai_move(space_num: int)
signal ai_purchase(space_num: int)

signal ai_auction_pass()
signal ai_auction_bid(amount: int, highest_bid: int)

signal ai_trade_reject()
signal ai_trade_accept()

signal ai_trade_create(offering_player: int, receiving_player: int, offering_cash: int, receiving_cash: int, offering_properties: Array[int], receiving_properties: Array[int])

signal ai_jail_pay(current_player: int)
signal ai_jail_card(current_player: int)
signal ai_jail_roll(current_player: int)


signal ai_declare_bankruptcy()
signal ai_pay_bankruptcy()

#Signals called by other classes
signal ai_auction_turn(player_index: int, highest_bid: int, space_num: int)
signal ai_trade_turn(trade_offer: Dictionary)
signal ai_doubles_jail()
signal ai_bankruptcy(amount: int)
signal ai_leaves_jail()

var ai_is_mid_turn = false
var rng

var validUpgrades: Array[int] = [] # holds the space numbers of upgradable properties
var validDowngrades: Array[int] = [] # holds the space numbers of downgradable properties
var validMortgages: Array[int] = [] # holds the space numbers of mortgagable properties
var validUnmortgages: Array[int] = [] # holds the space numbers of mortgagable properties

func _initialize_property_multipliers(player: AiPlayerState) -> void:
	for i in range(GameState.board.size()):
		if GameState.board[i] is Ownable:
			player.base_property_value_multipliers.append(1.1 + 0.4 * randf()) # TODO: set this based on difficulty, with a bit of variance between different properties/sets
		else:
			player.base_property_value_multipliers.append(0)
		player.current_property_value_multipliers.append(player.base_property_value_multipliers[i])
		player.master_property_value_multiplier = 1.2


func _update_property_multipliers(player: AiPlayerState) -> void:
	var totalOwnedSpaces = 0 # total number of spaces owned by players across the board
	var AIOwnedSpaces = 0 # total number of spaces owned by the AI
	var upgradableSpaces = 0 # total number of spaces able to be upgraded by the AI

	for i in range(GameState.board.size()):
		var multiplier = 0
		var space = GameState.board[i]
		if space is Ownable:
			multiplier = player.base_property_value_multipliers[i] 
			if (space._is_owned):
				totalOwnedSpaces += 1
				if (space._player_owner == player.player_id):
					AIOwnedSpaces += 1
					multiplier *= 1.2 # Ai values holding on to spaces it already has

			if space is PropertySpace:
				if (GameController._check_if_upgrade_is_valid(space, player.player_id)):
					upgradableSpaces += 1
				var propertySet = GameController._get_property_set(space)
				var ownedPropertiesInSet = 0; # amount of properties owned by the AI
				var otherPlayerOwnedProperties = 0 # properties in set owned by players other than the AI
				for j in range(propertySet.size()):
					if (propertySet[j].is_owned):
						if(propertySet[j]._player_owner == player.player_id):
							ownedPropertiesInSet += 1
						else:
							if (propertySet[j] != space): # Don't count the current space being owned against it
								otherPlayerOwnedProperties += 1 
				if (propertySet.size() == ownedPropertiesInSet):
					multiplier *= 4
				elif (propertySet.size() - ownedPropertiesInSet == 1):
					multiplier *= 1.7
				elif (propertySet.size() - ownedPropertiesInSet == 2 && propertySet.size() == 3):
					multiplier *= 1.3
				if (otherPlayerOwnedProperties == 1):
					multiplier *= 0.8
				elif (otherPlayerOwnedProperties == 2):
					multiplier *= 0.6
		player.current_property_value_multipliers[i] = multiplier
	
	var master_multiplier = 0.8
	# update master multiplier
	if (player.balance >= 500): # Ai is more likely to buy properties when it has a lot of money
		master_multiplier += (player.balance - 500) / 2500.0

	if (AIOwnedSpaces < totalOwnedSpaces / float(GameState.players.size())):
		var difference = totalOwnedSpaces / float(GameState.players.size()) - AIOwnedSpaces
		master_multiplier += difference / 10
	
	# If AI has any spaces that can be upgraded, then AI should propritize upgrading them
	if (upgradableSpaces > 0):
		master_multiplier *= 0.5
	
	player.master_property_value_multiplier = master_multiplier
	
	#for i in range(GameState.board.size()):
	#	print(GameState.board[i]._space_name, ": ", _calculate_AI_property_value(player, i))
	

func _calculate_AI_property_value(player: AiPlayerState, space_num: int) -> float:
	if (GameState.board[space_num] is Ownable):
		return player.current_property_value_multipliers[space_num] * player.master_property_value_multiplier * GameState.board[space_num]._initial_price
	else:
		return 0
	
	
var active_ai_player_index: int = -1

#Right now visibly the AI is just going light speed on board
#and hard to know what is happening without looking at turn log
#This should help a little - some delays between actions.
const AI_PACING := {
	"pre_roll": 0.35,
	"post_roll": 0.75,
	"after_landing": 0.60,
	"card_draw": 0.90,
	"before_purchase": 0.65,
	"before_trade": 0.85,
	"after_trade": 0.75,
	"end_turn": 0.35
}

var ai_pacing_enabled: bool = true
var ai_pacing_scale: float = 1.0

func _ai_pause(key: String) -> void:
	if not ai_pacing_enabled:
		return
	
	var duration := float(AI_PACING.get(key, 0.0)) * ai_pacing_scale
	if duration <= 0.0:
		return
	
	await get_tree().create_timer(duration, true).timeout

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	GameController.turn_setup_complete.connect(check_if_ai_turn)
	ai_auction_turn.connect(ai_auction_decision)
	ai_trade_turn.connect(ai_trade_decision)
	
	ChanceCardMgr.card_resolved.connect(ai_card_resolve)
	ai_doubles_jail.connect(handle_doubles_jail)
	ai_bankruptcy.connect(ai_bankruptcy_resolve)
	
	GameController.trade_finished.connect(check_trade_completion)
	ai_leaves_jail.connect(ai_turn_start)

# Emits the ai turn start signal if the next player is AI 
func check_if_ai_turn(player_index) -> void:
	if GameState.players[player_index].player_is_ai == true:
		ai_turn_start()

# Actions that should occur at the start of the AI player's turn
func ai_turn_start() -> void:
	print("AI Manager: AI turn start")

	var acting_ai := _begin_ai_turn_context()

	if not _is_same_ai_turn(acting_ai):
		return

	if (GameController.get_current_player().base_property_value_multipliers.is_empty()):
		_initialize_property_multipliers(GameController.get_current_player())
	else:
		_update_property_multipliers(GameController.get_current_player())
		
	if GameController.get_current_player().is_in_jail:
		ai_jail_decision()
		return

	if not GameController.get_current_player().has_rolled:
		await _ai_pause("pre_roll")
		if not _is_same_ai_turn(acting_ai):
			return
		ai_dice_roll.emit()
	else:
		ai_turn_mid()

# Specifically handles the case where the AI rolls doubles 3 times in a row, since this path leads to ai never landing on a space
func handle_doubles_jail():
	GameController.get_current_player().last_roll_was_doubles = false
	GameController.get_current_player().has_rolled = true
	ai_turn_mid()


# AI should choose between rolling, paying, and using a card here
func ai_jail_decision():
	print("AI Manager: AI makes jail decision")
	var current_player = GameController.get_current_player()

	# Attempt to roll for doubles if still early in jail (< 2 turns)
	if current_player.turns_in_jail < 2:
		ai_jail_roll.emit(GameState.current_player_index)
		await get_tree().process_frame  # Let jail popup process before rolling
		await _ai_pause("pre_roll")
		ai_dice_roll.emit()  # Actually trigger the dice roll
		await GameController.player_rolled
		if current_player.is_in_jail: # move on to middle of turn if still in jail, otherwise landing on a property will trigger first
			ai_turn_mid()
	elif GameController.get_current_player().go_for_launch_cards > 0:
		ai_jail_card.emit(GameState.current_player_index)
	else:
		ai_jail_pay.emit(GameState.current_player_index)



# Controls logic for AI players landing on spaces, then moves the AI to the middle of its turn
func ai_lands_on_space(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	var current_player = GameController.get_current_player()
	if current_player == null:
		return

	# A real landing should only be resolved after has_rolled is true.
	if not current_player.has_rolled and not current_player.is_in_jail:
		return

	print("AI Manager: AI lands on space")

	await _ai_pause("after_landing")
	if not _is_same_ai_turn(acting_ai):
		return

	var property = GameState.board[space_num]
	var scr: Script = property.get_script() as Script
	var gname: String = ""
	if scr != null:
		gname = scr.get_global_name()

	match gname:
		"PropertySpace", "InstrumentSpace", "PlanetSpace":
			if property._is_owned == true:
				if current_player.balance > GameController.calculate_rent(GameState.board[space_num]):
					ai_pay.emit(space_num)
				else:
					ai_pay.emit(space_num)
					await GameController.action_completed
			else:
				await ai_lands_on_unowned_property(space_num)

		"CardSpace":
			await _ai_pause("card_draw")
			if not _is_same_ai_turn(acting_ai):
				return
			ai_draw_card.emit(space_num)
			return

		"ExpenseSpace":
			ai_pay.emit(space_num)

		"SpecialSpace":
			if space_num == 30:
				ai_move.emit(space_num)

		"GameSpace":
			if space_num == 20:
				var space_info = SpaceData.get_space_info(space_num)
				GameController.credit(acting_ai, space_info.get("amount", 0))

	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_mid()
	

func ai_card_resolve(card_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	var current_player = GameController.get_current_player()
	if current_player == null:
		return

	# Ignore stale card callbacks before this AI has actually rolled/resolved movement
	if not current_player.has_rolled and not current_player.is_in_jail:
		return

	if card_num not in range(18, 33):
		ai_turn_mid()
	elif card_num in range(32, 33):
		ai_turn_mid()

# AI should choose between purchasing and auctioning here
func ai_lands_on_unowned_property(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("before_purchase")
	if not _is_same_ai_turn(acting_ai):
		return

	var player = GameController.get_current_player()
	if (player.balance >= GameState.board[space_num]._initial_price && _calculate_AI_property_value(player, space_num) >= GameState.board[space_num]._initial_price):
		ai_purchase.emit(space_num)
	else:
		await _ai_pause("before_trade")
		if not _is_same_ai_turn(acting_ai):
			return

		ai_auction_start.emit(space_num)
		await AuctionMgr.auction_ended
		await GameController.action_completed

	if not _is_same_ai_turn(acting_ai):
		return

# AI should attempt to not go bankrupt through mortgaging properties and selling upgrades, make it do that here. 
func ai_bankruptcy_resolve(amount: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	update_valid_mid_turn_targets()

	while GameController.get_current_player().balance < amount and (validDowngrades.size() > 0 or validMortgages.size() > 0):
		if not _is_same_ai_turn(acting_ai):
			return

		var decision = randf()
		if validDowngrades.size() == 0:
			decision = 1
		elif validMortgages.size() == 0:
			decision = 0

		if decision <= 0.5:
			ai_sells_upgrade(validDowngrades.pick_random())
		else:
			ai_property_mortgage(validMortgages.pick_random())

		update_valid_mid_turn_targets()

	if not _is_same_ai_turn(acting_ai):
		return

	if GameController.get_current_player().balance >= amount:
		ai_pay_bankruptcy.emit()
	else:
		ai_declare_bankruptcy.emit()
	
# Updates valid upgrades, downgrades, mortgages, and unmortgages
func update_valid_mid_turn_targets() -> void:
	validUpgrades = [] # holds the space numbers of upgradable properties
	validDowngrades = [] # holds the space numbers of downgradable properties
	validMortgages = []
	validUnmortgages = []
	for i in range(GameState.board.size()):
		if (GameState.board[i] is PropertySpace):
			if GameController._check_if_upgrade_is_valid(GameState.board[i], GameState.current_player_index):
				validUpgrades.append(i)
			if GameController._check_if_downgrade_is_valid(GameState.board[i], GameState.current_player_index):
				validDowngrades.append(i)
		if (GameState.board[i] is Ownable):
			if GameController._check_if_mortgage_is_valid(GameState.board[i], GameState.current_player_index):
				validMortgages.append(i)
			if GameController._check_if_unmortgage_is_valid(GameState.board[i], GameState.current_player_index):
				validUnmortgages.append(i)

# AI should whether to trade or not here
func ai_turn_mid() -> void:
	print("AI manager: AI moves to middle of turn")

	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("before_trade")
	if not _is_same_ai_turn(acting_ai):
		return

	var player = GameController.get_current_player()
	if (player.master_property_value_multiplier > 1 && player.master_property_value_multiplier - randf() * 0.5 > 1):
		ai_create_trade_offer(true)
	elif(player.master_property_value_multiplier < 1 && player.master_property_value_multiplier - randf() * 1.5 < 0):
		ai_create_trade_offer(false)
	else:
		ai_turn_post_trade()


# Forces the AI to wait until its trade offer is complete before resuming
func check_trade_completion() -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("after_trade")
	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_post_trade()

# AI should decide between property upgrading and mortgaging before ending the current turn
func ai_turn_post_trade() -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	var decisionAttempts = 4
	var randFloat = randf()

	while randFloat < decisionAttempts / 4.0:
		if not _is_same_ai_turn(acting_ai):
			return

		update_valid_mid_turn_targets()
		randFloat = randf()

		if randFloat > 0.5:
			if validUpgrades.size() > 0:
				var randInt = randi_range(0, validUpgrades.size() - 1)
				ai_property_upgrade(validUpgrades[randInt])
		#elif (randFloat > 0.3):
		#	if (validDowngrades.size() > 0):
		#		var randInt = randi_range(0, validDowngrades.size() - 1)
		#		ai_sells_upgrade(validDowngrades[randInt])
		#elif (randFloat > 0.4):
		#	if (validMortgages.size() > 0):
		#		var randInt = randi_range(0, validMortgages.size() - 1)
		#		ai_property_mortgage(validMortgages[randInt])
		else:
			if validUnmortgages.size() > 0:
				var randInt = randi_range(0, validUnmortgages.size() - 1)
				ai_property_unmortgage(validUnmortgages[randInt])

		randFloat = randf()
		decisionAttempts -= 1

	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_end()

# sorts the properties from highest multiplier -> lowest
func _sort_by_multiplier(a: int, b: int) -> bool:
	var current_player = GameController.get_current_player()
	if (current_player.current_property_value_multipliers[a] > current_player.current_property_value_multipliers[b]):
		return true
	return false
	


# AI should decide what to trade here
func ai_create_trade_offer(buying: bool) -> void:
	var current_player := active_ai_player_index
	if not _is_same_ai_turn(current_player):
		return
	
	var offeringProperties: Array[int] = []
	var receivingProperties: Array[int] = []
	var offeringCash = 0
	var receivingCash = 0

	# Generate a random target player to trade with
	var target_player = randi_range(0, GameState.players.size() - 2)
	if target_player >= current_player:
		target_player += 1
		
	var receivablePropeties: Array[int] = []
	if buying:
		for i in range(GameState.players.size()):
			if i != current_player:
				receivablePropeties.append_array(GameController.get_tradeable_space_indexes(i))
		receivablePropeties.sort_custom(_sort_by_multiplier)

		if receivablePropeties.size() > 0:
			receivingProperties.append(receivablePropeties[0])
			target_player = GameState.board[receivingProperties[0]]._player_owner

			var maxOffer = min(
				GameController.get_current_player().balance,
				_calculate_AI_property_value(GameState.players[current_player], receivingProperties[0])
			)
			offeringCash = randi_range(maxOffer / 2, maxOffer)
	else:
		var offerablePropeties: Array[int] = GameController.get_tradeable_space_indexes(current_player)
		offerablePropeties.sort_custom(_sort_by_multiplier)

		if offerablePropeties.size() > 0:
			offeringProperties.append(offerablePropeties[offerablePropeties.size() - 1])

			var propertyValue = _calculate_AI_property_value(GameState.players[current_player], offeringProperties[0])
			if propertyValue < GameState.players[target_player].balance:
				receivingCash = randi_range(propertyValue, GameState.players[target_player].balance)
			else:
				receivingCash = GameState.players[target_player].balance
			
	if offeringProperties.size() > 0 or receivingProperties.size() > 0:
		if not _is_same_ai_turn(current_player):
			return

		# Give the AI action toast time to finish before the trade popup is requested
		await get_tree().create_timer(2.9, true).timeout

		if not _is_same_ai_turn(current_player):
			return

		ai_trade_create.emit(
			current_player,
			target_player,
			offeringCash,
			receivingCash,
			offeringProperties,
			receivingProperties
		) # only create offer if AI is trading a property
	else:
		ai_turn_post_trade()


func ai_property_upgrade(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.upgrade_property.emit(GameState.board[space_num], acting_ai)
	
func ai_sells_upgrade(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.downgrade_property.emit(GameState.board[space_num], acting_ai)

	
func ai_property_mortgage(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.mortgage_property.emit(GameState.board[space_num], acting_ai)

	
func ai_property_unmortgage(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.unmortgage_property.emit(GameState.board[space_num], acting_ai)



func ai_turn_end() -> void:
	print("AI manager: AI moves to end of turn")

	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("end_turn")
	if not _is_same_ai_turn(acting_ai):
		return

	if GameController.get_current_player().last_roll_was_doubles:
		GameController.get_current_player().has_rolled = false
		GameController.get_current_player().last_roll_was_doubles = false

	if GameController.get_current_player().has_rolled == true or GameController.get_current_player().is_in_jail:
		active_ai_player_index = -1
		GameController.end_turn()
	else:
		ai_turn_start()

# AI should decide how much to bid on an auction here
func ai_auction_decision(player_index: int, highest_bid: int, space_num: int) -> void:
	await _ai_pause("before_trade")
	if player_index < 0 or player_index >= GameState.players.size():
		return
	if GameState.current_player_index < 0 or GameState.current_player_index >= GameState.players.size():
		return
	if not GameState.players[player_index].player_is_ai:
		return

	var player = GameState.players[player_index]
	var value = _calculate_AI_property_value(player, space_num)
	if (player.balance > highest_bid + 50 && value > highest_bid + 50):
		ai_auction_bid.emit(50)
	elif (player.balance > highest_bid + 10 && value > highest_bid + 10):
		ai_auction_bid.emit(10)
	elif (player.balance > highest_bid + 1 && value > highest_bid + 1):
		ai_auction_bid.emit(1)
	else:
		ai_auction_pass.emit()
# AI should decide whether to accept or decline a trade here
func ai_trade_decision(trade_offer: Dictionary) -> void:
	var player = trade_offer.get("target_player", -1)


	var value_offered = trade_offer.get("offer_cash", 0)
	var offered_spaces = trade_offer.get("offered_spaces", [])
	for i in range(offered_spaces.size()):
		value_offered += _calculate_AI_property_value(GameState.players[player], offered_spaces[i])
		
	var value_requested = trade_offer.get("request_cash", 0)
	var requested_spaces = trade_offer.get("requested_spaces", [])
	for i in range(requested_spaces.size()):
		value_requested += _calculate_AI_property_value(GameState.players[player], requested_spaces[i])
		
	if (value_offered > value_requested):
		ai_trade_accept.emit()
	else:
		ai_trade_reject.emit()
	

func _begin_ai_turn_context() -> int:
	active_ai_player_index = GameState.current_player_index
	return active_ai_player_index


func _is_same_ai_turn(expected_player_index: int) -> bool:
	if expected_player_index < 0:
		return false
	if GameState.current_player_index != expected_player_index:
		return false
	if expected_player_index >= GameState.players.size():
		return false
	return GameState.players[expected_player_index].player_is_ai

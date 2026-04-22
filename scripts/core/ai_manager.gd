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
			if (player.difficulty == "Hard"):
				player.base_property_value_multipliers.append(1 + 0.2 * randf()) # Hard AI has lower variance, and more heavily values the properties around and after jail
				if (i > 10 && i < 30):
					player.base_property_value_multipliers[i] *= 1.2
				if (i > 15 && i < 25):
					player.base_property_value_multipliers[i] *= 1.2 # Further value is given to the properties 1-2 turns out from jail
			elif (player.difficulty == "Easy"):
				player.base_property_value_multipliers.append(0.4 + 0.6 * randf() + 0.6 * randf()) # Easy AI values properties less generally but has a much higher range
			else:
				player.base_property_value_multipliers.append(1.1 + 0.4 * randf())
			
			if (GameState.board[i] is InstrumentSpace): # Harder AI values instruments more heavily, and dislikes planets. Easy AI is the opposite
				if (player.difficulty == "Easy"):
					player.base_property_value_multipliers[i] *= 0.6
				elif (player.difficulty == "Normal"):
					player.base_property_value_multipliers[i] *= 1
				elif (player.difficulty == "Hard"):
					player.base_property_value_multipliers[i] *= 1.25
				
			if (GameState.board[i] is PlanetSpace):
				if (player.difficulty == "Easy"):
					player.base_property_value_multipliers[i] *= 1.3
				elif (player.difficulty == "Normal"):
					player.base_property_value_multipliers[i] *= 1
				elif (player.difficulty == "Hard"):
					player.base_property_value_multipliers[i] *= 0.7
				
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
					if (player.difficulty != "Easy"):
						multiplier *= 1.2 # Good AI values holding on to spaces it already has
						
			if (space.is_mortgaged()):
				multiplier *= 0.6 # AI dislikes mortgages properties

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
				
				var easyUpgradeMultipliers: Array[float] = [1, 0.9, 0.85, 0.8, 0.75, 0.7] # This multiplier is also used for property upgrading, easy AI prefers upgrading unupgraded properties
				var normalUpgradeMultipliers: Array[float] = [1, 1.1, 1.2, 1.3, 1.4, 1.5] # Normal AI prefers fully upgrading a set
				var hardUpgradeMultipliers: Array[float] = [1, 1.3, 1.3, 1.3, 1.1, 1.1] # Hard AI prefers upgrading to the 3rd upgrade level

				if (player.difficulty == "Easy"):
					multiplier *= easyUpgradeMultipliers[space._current_upgrades]
				elif (player.difficulty == "Normal"):
					multiplier *= normalUpgradeMultipliers[space._current_upgrades]
				elif (player.difficulty == "Hard"):
					multiplier *= hardUpgradeMultipliers[space._current_upgrades]				
				
		player.current_property_value_multipliers[i] = multiplier
	
	var master_multiplier = 0.8
	# update master multiplier
	if (player.balance >= 500): # Ai is more likely to buy properties when it has a lot of money
		master_multiplier += (player.balance - 500) / 2500.0

	if (AIOwnedSpaces < totalOwnedSpaces / float(GameState.players.size())): # AI is more likely to buy properties when it has few properties
		var difference = totalOwnedSpaces / float(GameState.players.size()) - AIOwnedSpaces
		master_multiplier += difference / 5.0
	
	# If AI has any spaces that can be upgraded, then good AI should propritize upgrading them
	if (upgradableSpaces > 0 && player.difficulty != "Easy"):
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
func handle_doubles_jail() -> void:
	var current_player = GameController.get_current_player()
	if current_player == null:
		return

	current_player.last_roll_was_doubles = false
	current_player.doubles_count = 0
	current_player.has_rolled = true

	active_ai_player_index = -1
	GameController.end_turn()


# AI should choose between rolling, paying, and using a card here
func ai_jail_decision() -> void:
	print("AI Manager: AI makes jail decision")
	var current_player = GameController.get_current_player()
	if current_player == null:
		return

	# Third jail turn:
	# AI must pay $50 to leave immediately, then roll normally for the turn.
	if current_player.turns_in_jail >= 2:
		var paid := GameController.request_payment(GameState.current_player_index, 50, "Launch Permit")
		if not paid:
			return

		GameController.release_player_from_jail(GameState.current_player_index)
		current_player.has_rolled = false

		await _ai_pause("pre_roll")
		if not _is_same_ai_turn(active_ai_player_index):
			return

		ai_dice_roll.emit()
		return

	# Turns 1 and 2: try to roll doubles to get out
	ai_jail_roll.emit(GameState.current_player_index)
	await get_tree().process_frame
	await _ai_pause("pre_roll")

	if not _is_same_ai_turn(active_ai_player_index):
		return

	ai_dice_roll.emit()
	await GameController.player_rolled

	if current_player.is_in_jail:
		ai_turn_mid()



# Controls logic for AI players landing on spaces, then moves the AI to the middle of its turn
func ai_lands_on_space(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	print("AI DEBUG: ai_lands_on_space called for space %d" % space_num)
	print("AI DEBUG: active_ai_player_index=%s current_player_index=%s" % [
		str(acting_ai),
		str(GameState.current_player_index)
	])

	if not _is_same_ai_turn(acting_ai):
		print("AI DEBUG: ai_lands_on_space RETURNED - not same AI turn")
		return

	var current_player = GameController.get_current_player()
	if current_player == null:
		print("AI DEBUG: ai_lands_on_space RETURNED - current_player is null")
		return

	print("AI DEBUG: ai_lands_on_space state | has_rolled=%s is_in_jail=%s balance=%s" % [
		str(current_player.has_rolled),
		str(current_player.is_in_jail),
		str(current_player.balance)
	])

	# A real landing should only be resolved after has_rolled is true. ## This is not true, rolling doubles should still resolve the space landing
	#if not current_player.has_rolled and not current_player.is_in_jail:
	#	print("AI DEBUG: ai_lands_on_space RETURNED - has_rolled is false and player not in jail")
	#	return

	print("AI Manager: AI lands on space")

	await _ai_pause("after_landing")
	if not _is_same_ai_turn(acting_ai):
		print("AI DEBUG: ai_lands_on_space RETURNED after pause - not same AI turn")
		return

	var property = GameState.board[space_num]
	var scr: Script = property.get_script() as Script
	var gname: String = ""
	if scr != null:
		gname = scr.get_global_name()

	print("AI DEBUG: landing space type = %s | space_num = %d" % [gname, space_num])

	match gname:
		"PropertySpace", "InstrumentSpace", "PlanetSpace":
			if property._is_owned == true:
				if property._player_owner != active_ai_player_index:
					var rent_owed := GameController.calculate_rent(GameState.board[space_num])
					var needs_bankruptcy_flow: bool = current_player.balance < rent_owed

					print("AI DEBUG: owned space landed on, emitting ai_pay for space %d" % space_num)
					ai_pay.emit(space_num)

				# Only wait if this payment was going to trigger bankruptcy handling.
					if needs_bankruptcy_flow:
						print("AI DEBUG: waiting for action_completed after bankruptcy-risk rent payment")
						await GameController.action_completed
						print("AI DEBUG: action_completed received after bankruptcy-risk rent payment")
			else:
				print("AI DEBUG: unowned property/instrument/planet at space %d" % space_num)
				await ai_lands_on_unowned_property(space_num)

		"CardSpace":
			print("AI DEBUG: landed on CardSpace %d" % space_num)
			await _ai_pause("card_draw")
			if not _is_same_ai_turn(acting_ai):
				print("AI DEBUG: ai_lands_on_space RETURNED before card draw - not same AI turn")
				return
			ai_draw_card.emit(space_num)
			return

		"ExpenseSpace":
			var space_info = SpaceData.get_space_info(space_num)
			var amount_owed := int(space_info.get("amount", 0))
			var needs_bankruptcy_flow: bool = current_player.balance < amount_owed

			print("AI DEBUG: expense space landed on, emitting ai_pay for space %d" % space_num)
			ai_pay.emit(space_num)

			# Only wait if this expense was going to trigger bankruptcy handling.
			if needs_bankruptcy_flow:
				print("AI DEBUG: waiting for action_completed after bankruptcy-risk expense payment")
				await GameController.action_completed
				print("AI DEBUG: action_completed received after bankruptcy-risk expense payment")

		"SpecialSpace":
			if space_num == 30:
				print("AI DEBUG: landed on Solar Storm, moving to Launch Pad")
				ai_move.emit(space_num)

				# Let the board finish the transport / jail state update first.
				await get_tree().process_frame

				if not _is_same_ai_turn(acting_ai):
					print("AI DEBUG: ai_lands_on_space RETURNED after Solar Storm move - not same AI turn")
					return

				var updated_player = GameController.get_current_player()
				if updated_player != null and updated_player.is_in_jail:
					print("AI DEBUG: AI was sent to Launch Pad, ending turn immediately")
					ai_turn_end()
					return

				return
			# Space 10 ("just visiting"/Launch Pad tile) should fall through normally.

		"GameSpace":
			if space_num == 20:
				var space_info = SpaceData.get_space_info(space_num)
				GameController.credit(acting_ai, space_info.get("amount", 0))

	if not _is_same_ai_turn(acting_ai):
		print("AI DEBUG: ai_lands_on_space RETURNED before ai_turn_mid - not same AI turn")
		return
		
	GameController.action_completed.emit()
	print("AI DEBUG: entering ai_turn_mid from ai_lands_on_space")
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

	print("AI DEBUG: ai_card_resolve called for card ", card_num)

	# Jail cards: turn should end through the jail flow, not mid-turn logic
	if current_player.is_in_jail:
		print("AI DEBUG: card resolution left AI in Launch Pad, ending turn")
		ai_turn_end()
		return

	# Movement cards shouldnt  resume the turn here.
	# Let the follow-up movement finish and let the destination landing handle continuation.
	if card_num in range(18, 34):
		print("AI DEBUG: movement card resolved, waiting for destination landing")
		return

	# Non-movement cards can continue the turn immediately
	print("AI DEBUG: non-movement card resolved, continuing AI turn")
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
		await get_tree().process_frame
		ai_turn_mid()
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
	if (player.master_property_value_multiplier > 1 && player.master_property_value_multiplier - randf() * 1 > 1):
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

	var player = GameState.players[active_ai_player_index]

	update_valid_mid_turn_targets()

	if validUnmortgages.size() > 0:
		validUnmortgages.sort_custom(_sort_by_multiplier)
		if (_calculate_AI_property_value(player, validUnmortgages[0]) / 0.6 > GameState.board[validUnmortgages[0]]._mortgage_value * 1.3):
			ai_property_unmortgage(validUnmortgages[0])

	var upgradeAttempts = 0
	
	if (player.difficulty == "Easy"):
		upgradeAttempts = randi_range(0, 2)
	
	if (player.difficulty == "Normal"):
		upgradeAttempts = randi_range(2, 5)
		
	if (player.difficulty == "Hard"):
		upgradeAttempts = randi_range(7, 11)

	while upgradeAttempts > 0:
		if not _is_same_ai_turn(acting_ai):
			return

		update_valid_mid_turn_targets()

		if validUpgrades.size() > 0:
			validUpgrades.sort_custom(_sort_by_multiplier)
			ai_property_upgrade(validUpgrades[0])
		upgradeAttempts -= 1
		
		if (player.balance <= randi_range(0, 600)):
			upgradeAttempts -= 4

	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_end()

# sorts the properties from highest multiplier -> lowest
func _sort_by_multiplier(a: int, b: int) -> bool:
	var current_player = GameController.get_current_player()
	if current_player == null:
		return false

	var multipliers: Array = current_player.current_property_value_multipliers
	if multipliers == null:
		return false

	var max_index: int = multipliers.size() - 1
	var a_valid: bool = a >= 0 and a <= max_index
	var b_valid: bool = b >= 0 and b <= max_index

	if a_valid and not b_valid:
		return true
	if not a_valid and b_valid:
		return false
	if not a_valid and not b_valid:
		return a < b

	if multipliers[a] > multipliers[b]:
		return true
	return false


func _filter_valid_board_property_ids(property_ids: Array[int]) -> Array[int]:
	var results: Array[int] = []

	for property_id in property_ids:
		if property_id >= 0 and property_id < GameState.board.size():
			results.append(property_id)

	return results
	
func _filter_out_properties_with_upgrades(property_ids: Array[int]) -> Array[int]:
	var results: Array[int] = []
	for property_id in property_ids:
		if GameState.board[property_id] is not PropertySpace:
			results.append(property_id)
		else:
			var upgrades = false
			for property in GameController._get_property_set(GameState.board[property_id]):
				if (property._current_upgrades > 0):
					upgrades = true
			if (!upgrades):
				results.append(property_id)
	return results


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

		receivablePropeties = _filter_valid_board_property_ids(receivablePropeties)
		receivablePropeties = _filter_out_properties_with_upgrades(receivablePropeties)
		receivablePropeties.sort_custom(_sort_by_multiplier)

		if receivablePropeties.size() > 0:
			receivingProperties.append(receivablePropeties[0])
			target_player = GameState.board[receivingProperties[0]]._player_owner

			var maxOffer = min(
				GameController.get_current_player().balance,
				_calculate_AI_property_value(GameState.players[current_player], receivingProperties[0])
			)
			offeringCash = randi_range(maxOffer / 2, maxOffer)
			if (GameState.players[current_player].difficulty == "Easy"): # Easy AI offers more money in trade offers
				offeringCash *= 1.6
			if (GameState.players[current_player].difficulty == "Normal"): 
				offeringCash *= 1.2
			offeringCash = min(offeringCash, GameController.get_current_player().balance)
	else:
		var offerablePropeties: Array[int] = GameController.get_tradeable_space_indexes(current_player)

		offerablePropeties = _filter_valid_board_property_ids(offerablePropeties)
		offerablePropeties = _filter_out_properties_with_upgrades(offerablePropeties)
		offerablePropeties.sort_custom(_sort_by_multiplier)

		if offerablePropeties.size() > 0:
			offeringProperties.append(offerablePropeties[offerablePropeties.size() - 1])

			var propertyValue = _calculate_AI_property_value(GameState.players[current_player], offeringProperties[0])
			receivingCash = randi_range(propertyValue, GameState.players[target_player].balance)

			if (GameState.players[current_player].difficulty == "Easy"):
				receivingCash *= 0.6 # Easy AI asks for less money in trades
			if (GameState.players[current_player].difficulty == "Normal"):
				receivingCash *= 0.9 
				
			if receivingCash > GameState.players[target_player].balance:
				offeringProperties.clear() # cancel trade if other player doesn't have the money to pay
				receivingCash = 0
			
	if ((offeringProperties.size() > 0 or receivingProperties.size() > 0) && GameState.player_active[target_player]):
		if not _is_same_ai_turn(current_player):
			return

		# Give the AI action toast time to finish before the trade popup is requested
		await get_tree().create_timer(2.9, true).timeout

		if not _is_same_ai_turn(current_player):
			return

		print("AI TRADE ATTEMPT, Current player: ", current_player, "Target: ",target_player, "Offering Cash: ", offeringCash, "Receiving Cash: ", receivingCash, "Offering Properties: ", offeringProperties, "Receiving Properties: ", receivingProperties)
		
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
		if offered_spaces[i] >= 0 and offered_spaces[i] < GameState.board.size():
			value_offered += _calculate_AI_property_value(GameState.players[player], offered_spaces[i])
		
	var value_requested = trade_offer.get("request_cash", 0)
	var requested_spaces = trade_offer.get("requested_spaces", [])
	for i in range(requested_spaces.size()):
		if requested_spaces[i] >= 0 and requested_spaces[i] < GameState.board.size():
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

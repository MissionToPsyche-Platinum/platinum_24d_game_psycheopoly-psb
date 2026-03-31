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
signal ai_auction_turn(player_index: int)
signal ai_trade_turn()
signal ai_doubles_jail()
signal ai_bankruptcy(amount: int)
signal ai_leaves_jail()

var ai_is_mid_turn = false
var rng

var validUpgrades: Array[int] = [] # holds the space numbers of upgradable properties
var validDowngrades: Array[int] = [] # holds the space numbers of downgradable properties
var validMortgages: Array[int] = [] # holds the space numbers of mortgagable properties
var validUnmortgages: Array[int] = [] # holds the space numbers of mortgagable properties

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
	if GameController.get_current_player().is_in_jail:
		ai_jail_decision()
	if not (GameController.get_current_player().has_rolled):
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
	
	if (false):
		ai_jail_roll.emit(GameState.current_player_index)
		await GameController.player_rolled
		if current_player.is_in_jail: # move on to middle of turn if still in jail, otherwise landing on a property will trigger first
			ai_turn_mid()
	elif (GameController.get_current_player().go_for_launch_cards > 0):
		ai_jail_card.emit(GameState.current_player_index)
	else:
		ai_jail_pay.emit(GameState.current_player_index)



# Controls logic for AI players landing on spaces, then moves the AI to the middle of its turn
func ai_lands_on_space(space_num: int) -> void:
	print("AI Manager: AI lands on space")
	var property = GameState.board[space_num]
	# Explicitly type script reference (prevents Variant inference warning)
	var scr: Script = property.get_script() as Script
	var gname: String = ""
	if scr != null:
		gname = scr.get_global_name()
		
	var current_player = GameState.current_player_index
	match gname:
		
		"PropertySpace", "InstrumentSpace", "PlanetSpace":
			if (property._is_owned == true):
				if (GameController.get_current_player().balance > GameController.calculate_rent(GameState.board[space_num])):
					ai_pay.emit(space_num)
				else:
					ai_pay.emit(space_num)
					await(GameController.action_completed)
			else:
				await ai_lands_on_unowned_property(space_num)
		"CardSpace":
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
	if (GameState.current_player_index == current_player): # Halt the AI turn if the AI goes bankrupt
		ai_turn_mid()
	

func ai_card_resolve(card_num: int) -> void:
	if (GameController.get_current_player().player_is_ai == false):
		return
	elif (card_num not in range(18, 33)): # Don't move to ai turn mid if the card is a movement based one, since it will land on a space and trigger it anyways. This range will need to be changed if chance card data is updated
		ai_turn_mid()
	elif (card_num in range(32, 33)): # The exception to this is the go to jail cards, which don't trigger space landing
		ai_turn_mid()

# AI should choose between purchasing and auctioning here
func ai_lands_on_unowned_property(space_num: int) -> void:
	if (GameController.get_current_player().balance >= GameState.board[space_num]._initial_price):
		ai_purchase.emit(space_num)
	else:
		ai_auction_start.emit(space_num)
		await AuctionMgr.auction_ended
		await GameController.action_completed

# AI should attempt to not go bankrupt through mortgaging properties and selling upgrades, make it do that here. 
func ai_bankruptcy_resolve(amount: int) -> void:
	update_valid_mid_turn_targets()
	while (GameController.get_current_player().balance < amount && (validDowngrades.size() > 0 || validMortgages.size() > 0)):
		var decision = randf()
		if (validDowngrades.size() == 0):
			decision = 1
		elif(validMortgages.size() == 0):
			decision = 0
			
		if (decision <= 0.5):
			ai_sells_upgrade(validDowngrades.pick_random())
		else:
			ai_property_mortgage(validMortgages.pick_random())
		update_valid_mid_turn_targets()
	if (GameController.get_current_player().balance >= amount):
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
	ai_create_trade_offer()

# Forces the AI to wait until its trade offer is complete before resuming
func check_trade_completion() -> void:
	if (GameController.get_current_player().player_is_ai):
		ai_turn_post_trade()

# AI should decide between property upgrading and mortgaging before ending the current turn
func ai_turn_post_trade() -> void:
	var decisionAttempts = 4
	var randFloat = randf()
	
	while(randFloat < decisionAttempts / 4.0):
		update_valid_mid_turn_targets()
		randFloat = randf()
		if (randFloat > 0.5):
			if (validUpgrades.size() > 0):
				var randInt = randi_range(0, validUpgrades.size() - 1)
				ai_property_upgrade(validUpgrades[randInt])
		elif (randFloat > 0.3):
			if (validDowngrades.size() > 0):
				var randInt = randi_range(0, validDowngrades.size() - 1)
				ai_sells_upgrade(validDowngrades[randInt])
		elif (randFloat > 0.15):
			if (validMortgages.size() > 0):
				var randInt = randi_range(0, validMortgages.size() - 1)
				ai_property_mortgage(validMortgages[randInt])
		else:
			if (validUnmortgages.size() > 0):
				var randInt = randi_range(0, validUnmortgages.size() - 1)
				ai_property_unmortgage(validUnmortgages[randInt])
		randFloat = randf()
		decisionAttempts -= 1

	ai_turn_end()

# AI should decide what to trade here
func ai_create_trade_offer() -> void:
	
	var current_player = GameState.current_player_index;
	# Generate a (currently) random target player to trade with
	var target_player = randi_range(0, GameState.players.size() - 2)
	if (target_player >= current_player):
		target_player += 1
	
	
	var offerablePropeties: Array[int] = GameController.get_tradeable_space_indexes(current_player)
	var receivablePropeties: Array[int] = GameController.get_tradeable_space_indexes(target_player)

	var offeringProperties: Array[int] = []
	var receivingProperties: Array[int] = []
	
	offerablePropeties.shuffle()
	for i in range(randi_range(0, offerablePropeties.size() - 1)):
		offeringProperties.append(offerablePropeties[i])
	
	receivablePropeties.shuffle()
	for i in range(randi_range(0, receivablePropeties.size() - 1)):
		receivingProperties.append(receivablePropeties[i])	
	
	var offeringCash = randi_range(0, GameController.get_current_player().balance)
	var receivingCash = randi_range(0, GameState.players[target_player].balance)

	
	ai_trade_create.emit(current_player, target_player, offeringCash, receivingCash, offeringProperties, receivingProperties)


func ai_property_upgrade(space_num: int) -> void:
	GameController.upgrade_property.emit(GameState.board[space_num], GameState.current_player_index)
	
func ai_sells_upgrade(space_num: int) -> void:
	GameController.downgrade_property.emit(GameState.board[space_num], GameState.current_player_index)

	
func ai_property_mortgage(space_num: int) -> void:
	GameController.mortgage_property.emit(GameState.board[space_num], GameState.current_player_index)

	
func ai_property_unmortgage(space_num: int) -> void:
	GameController.unmortgage_property.emit(GameState.board[space_num], GameState.current_player_index)



func ai_turn_end() -> void:
	print("AI manager: AI moves to end of turn")
	if GameController.get_current_player().last_roll_was_doubles: # These are normaly called from board.gd, but they wait for action completed, and may not trigger before the AI ends its turn
		GameController.get_current_player().has_rolled = false
		GameController.get_current_player().last_roll_was_doubles = false

	if (GameController.get_current_player().has_rolled == true || GameController.get_current_player().is_in_jail):
		GameController.end_turn()
	else:
		ai_turn_start()

# AI should decide how much to bid on an auction here
func ai_auction_decision(player_index: int, highest_bid: int) -> void:
	var decision
	if (GameState.players[player_index].balance - highest_bid >= 50):
		decision = randf()
	elif (GameState.players[player_index].balance - highest_bid >= 10):
		decision = randf() / 1.34
	elif (GameState.players[player_index].balance - highest_bid >= 1):
		decision = randf() / 2
	else:
		decision = 0
		
	if (decision > 0.75):
		ai_auction_bid.emit(50)
	elif (decision > 0.5):
		ai_auction_bid.emit(10)
	elif (decision > 0.25):
		ai_auction_bid.emit(1)
	else:
		ai_auction_pass.emit()

# AI should decide whether to accept or decline a trade here
func ai_trade_decision() -> void:
	#ai_trade_reject.emit()
	ai_trade_accept.emit()

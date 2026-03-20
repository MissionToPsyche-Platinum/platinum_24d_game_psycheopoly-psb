extends Node
##
## game_controller.gd  (An autoload singleton)
## ============================================================================
##  PURPOSE:
##    - Manage global signals and control interactions between views, models, itself (controller)
##    - Handle game logic
## ============================================================================


# ------------------------------------------------------------------------------
# Global Signals
# ------------------------------------------------------------------------------
## Emitted when the active player changes.
signal current_player_changed(player)

## Emitted when a player's money changes
signal player_money_updated(player)

## Emitted when a player's turn starts
signal turn_started(player_index: int)

## Emitted when a player's turn ends
signal turn_ended(player_index: int)

## Emitted when a player rolls the dice
signal player_rolled(player: PlayerState)

## Emitted when a player goes to or leaves jail
signal player_sent_to_jail(player_index: int)
signal player_released_from_jail(player_index: int)

## Emitted when a player completes an action (purchase, pay, etc.)
signal action_completed()

## Emitted when property ownership changes
signal property_ownership_changed()

## Emitted when a property is upgraded or downgraded
signal property_upgraded()

## Emitted when a player cannot afford a required payment (rent/cost/etc.)
signal bankruptcy_needed(debtor_index: int, creditor_index: int, amount: int, reason: String)

## Emitted when a trade is executed successfully
signal trade_completed(trade_offer: Dictionary)

## Emitted when a trade execution attempt fails validation
signal trade_failed(reason: String)


# ------------------------------------------------------------------------------
# Signals to be called from space action popup
# ------------------------------------------------------------------------------
signal pay_rent(property, player)
signal purchase_property(property, player)
signal upgrade_property(property, player)
signal downgrade_property(property, player)
signal mortgage_property(property, player)
signal unmortgage_property(property, player)

# Other signals
signal difficulty_changed(new_value: String)
signal colorblind_mode_changed(enabled: bool)
signal setup_changed()


func _ready() -> void:
	pay_rent.connect(_pay_rent)
	purchase_property.connect(_purchase_property)
	upgrade_property.connect(_upgrade_property)
	downgrade_property.connect(_downgrade_property)
	mortgage_property.connect(_mortgage_property)
	unmortgage_property.connect(_unmortgage_property)


func debit(player_index: int, amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	if player_index < 0 or player_index >= GameState.players.size():
		return
	GameState.players[player_index].balance -= amount
	print("DEBIT ", GameState.players[player_index].player_name, " -$", amount, " ", reason, " => $", GameState.players[player_index].balance)
	player_money_updated.emit(GameState.players[player_index])


func credit(player_index: int, amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	if player_index < 0 or player_index >= GameState.players.size():
		return
	GameState.players[player_index].balance += amount
	print("CREDIT ", GameState.players[player_index].player_name, " +$", amount, " ", reason, " => $", GameState.players[player_index].balance)
	player_money_updated.emit(GameState.players[player_index])


func transfer(from_index: int, to_index: int, amount: int, reason: String = "") -> void:
	debit(from_index, amount, reason)
	credit(to_index, amount, reason)


func _is_valid_player_index(player_index: int) -> bool:
	return player_index >= 0 and player_index < GameState.players.size()


func _array_has_duplicates(values: Array) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false


func _get_property_space(space_index: int) -> PropertySpace:
	if space_index < 0 or space_index >= GameState.board.size():
		return null
	if GameState.board[space_index] is PropertySpace:
		return GameState.board[space_index] as PropertySpace
	return null


func _is_property_group_developed(property: PropertySpace) -> bool:
	if property == null:
		return false
	var property_set: Array[PropertySpace] = _get_property_set(property)
	for set_property in property_set:
		if set_property._current_upgrades > 0:
			return true
	return false


func _is_space_tradeable_by_owner(space_index: int, owner_index: int) -> bool:
	if space_index < 0 or space_index >= GameState.board.size():
		return false
	var space := GameState.board[space_index]
	if not (space is Ownable):
		return false
	var ownable := space as Ownable
	if not ownable._is_owned or ownable._player_owner != owner_index:
		return false
	return true


func get_tradeable_space_indexes(player_index: int) -> Array[int]:
	var tradeable: Array[int] = []
	if not _is_valid_player_index(player_index):
		return tradeable
	for i in range(GameState.board.size()):
		if _is_space_tradeable_by_owner(i, player_index):
			tradeable.append(i)
	return tradeable


func validate_trade_offer(trade_offer: Dictionary) -> Dictionary:
	var result := {"ok": false, "reason": "Invalid trade offer."}

	var offering_player: int = int(trade_offer.get("offering_player", -1))
	var target_player: int = int(trade_offer.get("target_player", -1))

	if not _is_valid_player_index(offering_player) or not _is_valid_player_index(target_player):
		result.reason = "Trade players are invalid."
		return result

	result.ok = true
	result.reason = "OK"
	return result


func execute_trade_offer(trade_offer: Dictionary) -> bool:
	var validation := validate_trade_offer(trade_offer)
	if not bool(validation.get("ok", false)):
		var reason := str(validation.get("reason", "Invalid trade offer."))
		trade_failed.emit(reason)
		print("Trade failed: ", reason)
		return false

	var offering_player: int = int(trade_offer.get("offering_player", -1))
	var target_player: int = int(trade_offer.get("target_player", -1))
	var offer_cash: int = int(trade_offer.get("offer_cash", 0))
	var request_cash: int = int(trade_offer.get("request_cash", 0))
	var offered_spaces: Array = trade_offer.get("offered_spaces", [])
	var requested_spaces: Array = trade_offer.get("requested_spaces", [])

	if offer_cash > 0:
		transfer(offering_player, target_player, offer_cash, "trade cash")
	if request_cash > 0:
		transfer(target_player, offering_player, request_cash, "trade cash")

	for offered_space in offered_spaces:
		_transfer_property(GameState.board[int(offered_space)] as Ownable, target_player)

	for requested_space in requested_spaces:
		_transfer_property(GameState.board[int(requested_space)] as Ownable, offering_player)

	trade_completed.emit(trade_offer)
	print("Trade completed between ", GameState.get_player_display_name(offering_player), " and ", GameState.get_player_display_name(target_player))
	return true


func _adjust_upgrade_level(property: PropertySpace, amount: int) -> void:
	property._current_upgrades += amount
	if property._current_upgrades > 5:
		print("Error, property upgrades exceeded 5")
		property._current_upgrades = 5
	if property._current_upgrades < 0:
		print("Error, property upgrades is negative")
		property._current_upgrades = 0


func _get_property_set(property: PropertySpace) -> Array[PropertySpace]:
	var property_set: Array[PropertySpace] = []
	for i in range(GameState.board.size()):
		if (GameState.board[i].get_script().get_global_name() == "PropertySpace"):
			if (GameState.board[i]._property_set == property._property_set):
				property_set.append(GameState.board[i])
	return property_set


func _check_if_upgrade_is_valid(property: PropertySpace, player: int) -> bool:
	# There are 5 conditions for this
	# 1: The player must own the property
	# 2: The player cannot upgrade past upgrade level 5 (discovery)
	# 3: The player must be able to afford the upgrade
	# 4: The player must own all properties of the set they are trying to upgrade
	# 5: The property that the player is upgrading must have less or equal upgrades to each other property of the set
	var upgrade_valid = true
	var property_set: Array[PropertySpace] = _get_property_set(property)
	for i in range(property_set.size()):
		if (!property_set[i].is_owned() || property_set[i]._player_owner != player):
			upgrade_valid = false
		elif (property._current_upgrades > property_set[i]._current_upgrades):
			upgrade_valid = false
		elif property_set[i]._is_mortgaged:
			upgrade_valid = false
	if (property._current_upgrades > 4):
		upgrade_valid = false
	if (property._upgrade_cost > GameState.players[player].balance):
		upgrade_valid = false
	return upgrade_valid


func _check_if_downgrade_is_valid(property: PropertySpace, player: int) -> bool:
	# There are 3 conditions for this
	# 1: The player must own the property
	# 2: The player cannot downgrade if there are no upgrades on the property
	# 3: The property that the player is downgrading must have equal or more upgrades to each other property of the set
	var downgrade_valid = true
	var property_set: Array[PropertySpace] = _get_property_set(property)
	if (property._player_owner != player):
		downgrade_valid = false
	for i in range(property_set.size()):
		if (property._current_upgrades < property_set[i]._current_upgrades):
			downgrade_valid = false
	if (property._current_upgrades < 1):
		downgrade_valid = false
	return downgrade_valid


func _upgrade_property(property: PropertySpace, player: int) -> void:
	var total_data_points = GameState.players[player].total_data_points
	var total_discoveries = GameState.players[player].total_discoveries

	if (player == property._player_owner && property.is_owned()):
		debit(property._player_owner, property._upgrade_cost, "property upgrade")
		if property._current_upgrades == 4:
			GameState.players[player].total_data_points = total_data_points - 4
			GameState.players[player].total_discoveries = total_discoveries + 1
		else:
			GameState.players[player].total_data_points = total_data_points + 1
		_adjust_upgrade_level(property, 1)
		property_upgraded.emit()
		print("your data points/discoveries are: ", GameState.players[player].total_data_points, " ", GameState.players[player].total_discoveries)
	else:
		print("Error, incorrect player attempted to downgrade property or property is unowned")


func _downgrade_property(property: PropertySpace, player: int) -> void:
	var total_data_points = GameState.players[player].total_data_points
	var total_discoveries = GameState.players[player].total_discoveries
	if (player == property._player_owner && property.is_owned()):
		var downgradeRefund = property._upgrade_cost / 2 # upgrades are refunded for 1/2 the original price paid
		credit(property._player_owner, downgradeRefund, "property downgrade")
		if property._current_upgrades == 5:
			GameState.players[player].total_data_points = total_data_points + 4
			GameState.players[player].total_discoveries = total_discoveries - 1
		else:
			GameState.players[player].total_data_points = total_data_points - 1
		print("your data points/discoveries are: ", GameState.players[player].total_data_points, " ", GameState.players[player].total_discoveries)
		_adjust_upgrade_level(property, -1)
		property_upgraded.emit()
	else:
		print("Error, incorrect player attempted to downgrade property or property is unowned")


## Returns the mortgage value for any Ownable subtype
func _get_mortgage_value(property: Ownable) -> int:
	if property is PropertySpace:
		return (property as PropertySpace)._mortgage_value
	elif property is InstrumentSpace:
		return (property as InstrumentSpace)._mortgage_value
	elif property is PlanetSpace:
		return (property as PlanetSpace)._mortgage_value
	return 0


## Returns the cost to unmortgage a property (mortgage value + 10% interest, rounded up)
func _get_unmortgage_cost(property: Ownable) -> int:
	return int(ceil(_get_mortgage_value(property) * 1.1))


func _check_if_mortgage_is_valid(property: Ownable, player: int) -> bool:
	if not property._is_owned or property._player_owner != player:
		return false
	if property._is_mortgaged:
		return false
	# PropertySpace: no upgrades allowed on any set member
	if property is PropertySpace:
		for set_property in _get_property_set(property as PropertySpace):
			if set_property._current_upgrades > 0:
				return false
	return true


func _check_if_unmortgage_is_valid(property: Ownable, player: int) -> bool:
	if not property._is_owned or property._player_owner != player:
		return false
	if not property._is_mortgaged:
		return false
	return get_player_balance(player) >= _get_unmortgage_cost(property)


## Public accessors for UI validation
func check_mortgage_valid(property: Ownable, player: int) -> bool:
	return _check_if_mortgage_is_valid(property, player)

func check_unmortgage_valid(property: Ownable, player: int) -> bool:
	return _check_if_unmortgage_is_valid(property, player)

func get_mortgage_value(property: Ownable) -> int:
	return _get_mortgage_value(property)

func get_unmortgage_cost(property: Ownable) -> int:
	return _get_unmortgage_cost(property)


func _mortgage_property(property: Ownable, player: int) -> void:
	if not _check_if_mortgage_is_valid(property, player):
		print("Mortgage invalid")
		return
	var value := _get_mortgage_value(property)
	credit(player, value, "mortgage")
	property._is_mortgaged = true
	property_ownership_changed.emit()
	print("Player ", GameState.players[player].player_name, " mortgaged a property for $", value)


func _unmortgage_property(property: Ownable, player: int) -> void:
	if not _check_if_unmortgage_is_valid(property, player):
		print("Unmortgage invalid")
		return
	var cost := _get_unmortgage_cost(property)
	debit(player, cost, "unmortgage")
	property._is_mortgaged = false
	property_ownership_changed.emit()
	print("Player ", GameState.players[player].player_name, " unmortgaged a property for $", cost)


## Changes the ownership of an ownable property
func _transfer_property(property: Ownable, player: int) -> void:
	property.set_property_owner(player)
	property_ownership_changed.emit()


## Purchases a property - called by the purchase property signal
func _purchase_property(property: Ownable, player: int) -> void:
	# If already owned, you cannot purchase it again.
	if property._is_owned:
		# If it's yours, nothing to do (later: manage upgrades/mortgage)
		if property._player_owner == player:
			print("Purchase blocked: player already owns this property.")
			return

		# If someone else owns it, this should be rent — not purchase.
		print("Purchase blocked: property already owned by player ", property._player_owner, ". Pay rent instead.")
		return

	# Unowned -> normal purchase
	_purchase_unowned_property(property, player, property._initial_price)


## Purchases an unowned property - deducts balance and transfers ownership
func _purchase_unowned_property(property: Ownable, player: int, purchase_price: int) -> void:
	debit(player, purchase_price, "purchase unowned")
	_transfer_property(property, player)


## Purchases an owned property - handles money transfer between players
## (kept for future trading / special rules, NOT used by normal "Purchase" now)
func _purchase_owned_property(property: Ownable, buyer: int, seller: int, purchase_price: int) -> void:
	transfer(buyer, seller, purchase_price, "purchase owned")
	_transfer_property(property, buyer)


func _pay_rent(property: Ownable, player: int) -> void:
	if !property._is_owned or property._player_owner == player:
		return
	# Mortgaged properties collect no rent
	if property._is_mortgaged:
		return

	var owner: int = int(property._player_owner)
	var rent: int = 0

	# Explicitly type script reference (prevents Variant inference warning)
	var scr: Script = property.get_script() as Script
	var gname: String = ""
	if scr != null:
		gname = scr.get_global_name()

	match gname:

		"PropertySpace":
			match property._current_upgrades:
				0: rent = property._default_rent
				1: rent = property._one_data_rent
				2: rent = property._two_data_rent
				3: rent = property._three_data_rent
				4: rent = property._four_data_rent
				5: rent = property._discovery_rent
				_: rent = 0

		"InstrumentSpace":
			var count: int = 0
			for s in GameState.board:
				if s is Ownable:
					var s_scr: Script = s.get_script() as Script
					if s_scr != null and s_scr.get_global_name() == "InstrumentSpace":
						var ownable := s as Ownable
						if ownable._is_owned and int(ownable._player_owner) == owner:
							count += 1

			match count:
				1: rent = 25
				2: rent = 50
				3: rent = 100
				4: rent = 200
				_: rent = 0

		"PlanetSpace":
			var count: int = 0
			for s in GameState.board:
				if s is Ownable:
					var s_scr: Script = s.get_script() as Script
					if s_scr != null and s_scr.get_global_name() == "PlanetSpace":
						var ownable := s as Ownable
						if ownable._is_owned and int(ownable._player_owner) == owner:
							count += 1

			var multiplier: int = 4
			if count >= 2:
				multiplier = 10

			rent = int(GameState.last_roll) * multiplier

		_:
			rent = 0

	# Trigger bankruptcy if needed
	if get_player_balance(player) < rent:
		emit_signal("bankruptcy_needed", player, owner, rent, "Rent")
		return

	transfer(player, owner, rent, "rent")




func set_difficulty(new_difficulty: String) -> void:
	GameState.difficulty = new_difficulty
	emit_signal("difficulty_changed", GameState.difficulty)
	print("GameState difficulty set to: ", GameState.difficulty)


func set_colorblind_mode(enabled: bool) -> void:
	if enabled == GameState.colorblind_mode:
		return
	GameState.colorblind_mode = enabled
	emit_signal("colorblind_mode_changed", GameState.colorblind_mode)

	# Keep player_count consistent with the actual player objects created
	GameState.player_count = GameState.players.size()

	emit_signal("setup_changed")


# ------------------------------------------------------------------------------
# Placeholder for the MoneyHud
# ------------------------------------------------------------------------------
## These functions exist only so other code (like MoneyHUD) can compile and call
## them. We can change implementations later, no big deal.


func get_current_player() -> PlayerState:
	## Returns the current active player
	if GameState.players.size() > 0 and GameState.current_player_index < GameState.players.size():
		return GameState.players[GameState.current_player_index]
	return null

func _is_player_active(index: int) -> bool:
	# If player_active isn't initialized yet, assume everyone is active
	if GameState.player_active.is_empty():
		return true
	if index < 0 or index >= GameState.player_active.size():
		return true
	return bool(GameState.player_active[index])

func send_player_to_jail(player_index: int) -> void:
	if not _is_valid_player_index(player_index):
		return
	
	var player = GameState.players[player_index]
	player.is_in_jail = true
	player.turns_in_jail = 0
	player.doubles_count = 0
	player.has_rolled = true
	
	emit_signal("player_sent_to_jail", player_index)

func release_player_from_jail(player_index: int) -> void:
	if not _is_valid_player_index(player_index):
		return
		
	var player = GameState.players[player_index]
	player.is_in_jail = false
	player.turns_in_jail = 0
	
	emit_signal("player_released_from_jail", player_index)

func end_turn() -> void:
	var current_player = get_current_player()
	if current_player:
		# Clean up turn flags so UI and next turn start clean.
		current_player.has_rolled = false
		current_player.doubles_count = 0
		current_player.last_roll_was_doubles = false

	next_player()


func start_game() -> void:
	GameState.game_active = true

	var start_idx := -1
	for i in range(GameState.players.size()):
		if _is_player_active(i):
			start_idx = i
			break

	if start_idx == -1:
		push_warning("GameController.start_game(): No active players.")
		return

	GameState.current_player_index = start_idx
	var current_player = get_current_player()
	if current_player:
		print("Game started! ", current_player.player_name, "'s turn")
		emit_signal("current_player_changed", current_player)
		emit_signal("turn_started", GameState.current_player_index)


func next_player() -> void:
	## Advance to the next ACTIVE player's turn
	if not GameState.game_active:
		return

	# Emit turn ended for current player
	emit_signal("turn_ended", GameState.current_player_index)

	var next_idx := _find_next_active_player_index(GameState.current_player_index)
	if next_idx == -1:
		push_warning("GameController.next_player(): No active players found.")
		return

	GameState.current_player_index = next_idx

	# Emit signals for new player
	var current_player = get_current_player()
	if current_player:
		print(current_player.player_name, "'s turn")
		emit_signal("current_player_changed", current_player)
		emit_signal("turn_started", GameState.current_player_index)



func _find_next_active_player_index(from_index: int) -> int:
	var total := GameState.players.size()
	if total <= 0:
		return -1

	# Try each player once
	for step in range(1, total + 1):
		var idx := (from_index + step) % total
		if _is_player_active(idx):
			return idx

	return -1


func change_player_cash(player: PlayerState, delta: int) -> void:
	## Adjust a player's cash and emit update signal
	if player:
		player.balance += delta
		print(player.player_name, " cash changed by ", delta, " (new balance: $", player.balance, ")")
		emit_signal("player_money_updated", player)


# Public helper: return a player's balance safely
func get_player_balance(player_index: int) -> int:
	if player_index < 0 or player_index >= GameState.players.size():
		return 0
	return GameState.players[player_index].balance


## Returns the current rent owed for a property, mirroring _pay_rent logic.
## Returns 0 if mortgaged or unowned.
func calculate_rent(property: Ownable) -> int:
	if not property._is_owned or property._is_mortgaged:
		return 0

	var owner: int = int(property._player_owner)
	var scr: Script = property.get_script() as Script
	var gname: String = scr.get_global_name() if scr != null else ""

	match gname:
		"PropertySpace":
			match property._current_upgrades:
				0: return property._default_rent
				1: return property._one_data_rent
				2: return property._two_data_rent
				3: return property._three_data_rent
				4: return property._four_data_rent
				5: return property._discovery_rent

		"InstrumentSpace":
			var count := 0
			for s in GameState.board:
				if s is Ownable:
					var s_scr: Script = s.get_script() as Script
					if s_scr != null and s_scr.get_global_name() == "InstrumentSpace":
						var ownable := s as Ownable
						if ownable._is_owned and int(ownable._player_owner) == owner:
							count += 1
			match count:
				1: return 25
				2: return 50
				3: return 100
				4: return 200

		"PlanetSpace":
			var count := 0
			for s in GameState.board:
				if s is Ownable:
					var s_scr: Script = s.get_script() as Script
					if s_scr != null and s_scr.get_global_name() == "PlanetSpace":
						var ownable := s as Ownable
						if ownable._is_owned and int(ownable._player_owner) == owner:
							count += 1
			return int(GameState.last_roll) * (10 if count >= 2 else 4)

	return 0

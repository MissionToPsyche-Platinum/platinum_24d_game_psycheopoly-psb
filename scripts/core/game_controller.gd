extends Node
##
## game_contropller.gd  (An autoload singleton)
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

## Emitted when a player completes an action (purchase, pay, etc.)
signal action_completed()

## Emitted when property ownership changes
signal property_ownership_changed()

signal bankruptcy_needed(debtor_index: int, creditor_index: int, amount: int, reason: String)


# ------------------------------------------------------------------------------
# Signals to be called from space action popup
# ------------------------------------------------------------------------------
signal pay_rent(property, player)

signal purchase_property(property, player)

#other signals

signal difficulty_changed(new_value: String)
signal colorblind_mode_changed(enabled: bool)
signal setup_changed()

func _ready() -> void:
	pay_rent.connect(_pay_rent)
	purchase_property.connect(_purchase_property)


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

	var rent := 0
	match property.get_script().get_global_name():
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
			rent = 0
		"PlanetSpace":
			rent = 0

	# If they can’t afford, trigger bankruptcy instead of transferring
	if get_player_balance(player) < rent:
		emit_signal("bankruptcy_needed", player, property._player_owner, rent, "Rent")
		return

	transfer(player, property._player_owner, rent, "rent")




func set_difficulty(new_difficulty: String) -> void:
	GameState.difficulty = new_difficulty
	emit_signal("difficulty_changed", GameState.difficulty)
	print("GameState difficulty set to: ", GameState.difficulty)


func set_colorblind_mode(enabled: bool) -> void:
	if enabled == GameState.colorblind_mode:
		return
	GameState.colorblind_mode = enabled
	emit_signal("colorblind_mode_changed", GameState.colorblind_mode)
	emit_signal("setup_changed")

	
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


func start_game() -> void:
	## Initialize the game and start the first player's turn
	GameState.game_active = true
	GameState.current_player_index = 0
	var current_player = get_current_player()
	if current_player:
		print("Game started! ", current_player.player_name, "'s turn")
		emit_signal("current_player_changed", current_player)
		emit_signal("turn_started", GameState.current_player_index)


func next_player() -> void:
	## Advance to the next player's turn
	if not GameState.game_active:
		return

	# Emit turn ended for current player
	emit_signal("turn_ended", GameState.current_player_index)

	# Advance to next player (use actual players array size)
	var total := GameState.players.size()
	if total <= 0:
		return
	GameState.current_player_index = (GameState.current_player_index + 1) % total

	# Emit signals for new player
	var current_player = get_current_player()
	if current_player:
		print(current_player.player_name, "'s turn")
		emit_signal("current_player_changed", current_player)
		emit_signal("turn_started", GameState.current_player_index)


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


# Public helper: set ownership without using private methods from other scripts
func transfer_property_to_player(property: Ownable, player_index: int) -> void:
	_transfer_property(property, player_index)


func charge_player(player_index: int, amount: int) -> void:
	# Keep as a wrapper so existing code continues to work
	debit(player_index, amount, "charge_player")
	print("DEBIT ", GameState.players[player_index].player_name, " -$", amount, " charge_player => $", GameState.players[player_index].balance)

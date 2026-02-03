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
## Emitted when the active player changes (MoneyHUD should listen to this).
signal current_player_changed(player)

## Emitted when a player's money changes (MoneyHUD should listen to this).
signal player_money_updated(player)

## Emitted when a player's turn starts
signal turn_started(player_index: int)

## Emitted when a player's turn ends
signal turn_ended(player_index: int)

## Emitted when a player rolls the dice
signal player_rolled(player: PlayerState)

## Emitted when a player completes an action (purchase, pay, etc.)
signal action_completed()

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

## Changes the ownership of an ownable property
func _transfer_property(property: Ownable, player: int) -> void:
	if not property._is_owned:
		property._is_owned = true
	property._player_owner = player


## Purchases a property - called by the purchase property signal
func _purchase_property(property: Ownable, player: int) -> void:
	if (property._is_owned):
		_purchase_owned_property(property, player, property._player_owner, property._initial_price) # currently we assume that the purchase price is the same as the default, though this will not always be the case
	else:
		_purchase_unowned_property(property, player, property._initial_price)


## Purchases an unowned property - deducts balance and transfers ownership
func _purchase_unowned_property(property: Ownable, player: int, purchase_price: int) -> void:
	GameState.players[player].balance -= purchase_price
	player_money_updated.emit(GameState.players[player])
	_transfer_property(property, player)


## Purchases an owned property - handles money transfer between players
func _purchase_owned_property(property: Ownable, buyer: int, seller: int, purchase_price: int) -> void:
	GameState.players[buyer].balance -= purchase_price
	player_money_updated.emit(GameState.players[buyer])
	GameState.players[seller].balance += purchase_price
	player_money_updated.emit(GameState.players[seller])
	_transfer_property(property, buyer)

func _pay_rent(property: Ownable, player: int) -> void:
	if !property._is_owned or property._player_owner == player:
		return
		
	var rent = 0
	match property.get_script().get_global_name():
		"PropertySpace":
			match property._current_upgrades:
				0:  
					rent = property._default_rent
				1:  
					rent = property._one_data_rent
				2:  
					rent = property._two_data_rent
				3:  
					rent = property._three_data_rent
				4:  
					rent = property._four_data_rent
				5:  
					rent = property._discovery_rent
				_:  
					rent = 0
		"InstrumentSpace": # TODO: Implement checking for number of instrument spaces
			rent = 0
		"PlanetSpace": # TODO: Implement checking dice roll for determining rent
			rent = 0
	GameState.players[player].balance -= rent
	GameState.players[property._player_owner].balance += rent
	player_money_updated.emit(GameState.players[player])
	player_money_updated.emit(GameState.players[property._player_owner])

func set_difficulty(new_difficulty: String) -> void:
	## Simple setter used by StartMenu.gd
	## You can add validation or mapping here later if needed.
	GameState.difficulty = new_difficulty
	print("GameState difficulty set to: ", GameState.difficulty)

func set_colorblind_mode(enabled: bool) -> void:
	if enabled == GameState.colorblind_mode:
		return
	GameState.colorblind_mode = enabled
	emit_signal("colorblind_mode_changed", GameState.colorblind_mode)
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
	
	# Advance to next player
	GameState.current_player_index = (GameState.current_player_index + 1) % GameState.player_count
	
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

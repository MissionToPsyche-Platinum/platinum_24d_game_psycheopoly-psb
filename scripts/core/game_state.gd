extends Node
##
## game_state.gd  (An autoload singleton)
## ============================================================================
##  PURPOSE (for now):
##    - Provide the signals and the functions that MoneyHUD expects.
##    - Provide a simple global difficulty setting for the Start Menu.
##    - Allow the HUD and UI to run without errors.
##
##  NOTE:
##    This is still a placeholder / bridge. We can refactor later as the
##    real GameState design is implemented.
## ============================================================================


# ------------------------------------------------------------------------------
# Signals expected by MoneyHUD.gd
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


# ------------------------------------------------------------------------------
# Global difficulty (used by StartMenu.gd)
# ------------------------------------------------------------------------------
## Valid values (for now): "Easy", "Normal", "Hard"
## Default to "Normal" so Start Menu can initialize its OptionButton.
var difficulty: String = "Normal"

# Contains the board data model
var board: Array[GameSpace] = []

# Holds the list of board spaces
var _spaces_list := BoardSpaceList.new()

# TODO: Eventually we want to be able to set this before a game starts
var player_count: int = 6

# Holds the player state data models
var players: Array[PlayerState] = []

# Player colors for pieces and UI
const PLAYER_COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2),   # Red
	Color(0.2, 0.5, 0.9),   # Blue
	Color(0.2, 0.8, 0.2),   # Green
	Color(0.9, 0.8, 0.1),   # Yellow
	Color(0.9, 0.5, 0.1),   # Orange
	Color(0.8, 0.3, 0.8),   # Purple
]

# Current player's index (0-based)
var current_player_index: int = 0

# Whether a game is currently active
var game_active: bool = false


func _ready() -> void:
	# connect signals 
	pay_rent.connect(_pay_rent)
	purchase_property.connect(_purchase_property)
	
	_setup_board()
	_setup_players()


func _setup_board() -> void:
	board = _spaces_list.board


func _setup_players() -> void:
	for i in range(player_count):
		var player = PlayerState.new()
		player.player_id = i
		player.player_name = "Player " + str(i + 1)
		player.balance = 1500  # TODO: Change to constant
		players.append(player)
		add_child(player)


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
	players[player].balance -= purchase_price
	player_money_updated.emit(players[player])
	_transfer_property(property, player)


## Purchases an owned property - handles money transfer between players
func _purchase_owned_property(property: Ownable, buyer: int, seller: int, purchase_price: int) -> void:
	players[buyer].balance -= purchase_price
	player_money_updated.emit(players[buyer])
	players[seller].balance += purchase_price
	player_money_updated.emit(players[seller])
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
	players[player].balance -= rent
	players[property._player_owner].balance += rent
	player_money_updated.emit(players[player])
	player_money_updated.emit(players[property._player_owner])


func set_difficulty(new_difficulty: String) -> void:
	## Simple setter used by StartMenu.gd
	## You can add validation or mapping here later if needed.
	difficulty = new_difficulty
	print("GameState difficulty set to: ", difficulty)


# ------------------------------------------------------------------------------
# Placeholder for the MoneyHud
# ------------------------------------------------------------------------------
## These functions exist only so other code (like MoneyHUD) can compile and call
## them. We can change implementations later, no big deal.


func get_current_player() -> PlayerState:
	## Returns the current active player
	if players.size() > 0 and current_player_index < players.size():
		return players[current_player_index]
	return null


func start_game() -> void:
	## Initialize the game and start the first player's turn
	game_active = true
	current_player_index = 0
	var current_player = get_current_player()
	if current_player:
		print("Game started! ", current_player.player_name, "'s turn")
		emit_signal("current_player_changed", current_player)
		emit_signal("turn_started", current_player_index)


func next_player() -> void:
	## Advance to the next player's turn
	if not game_active:
		return
	
	# Emit turn ended for current player
	emit_signal("turn_ended", current_player_index)
	
	# Advance to next player
	current_player_index = (current_player_index + 1) % player_count
	
	# Emit signals for new player
	var current_player = get_current_player()
	if current_player:
		print(current_player.player_name, "'s turn")
		emit_signal("current_player_changed", current_player)
		emit_signal("turn_started", current_player_index)


func change_player_cash(player: PlayerState, delta: int) -> void:
	## Adjust a player's cash and emit update signal
	if player:
		player.balance += delta
		print(player.player_name, " cash changed by ", delta, " (new balance: $", player.balance, ")")
		emit_signal("player_money_updated", player)

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
var player_count: int = 4

# Holds the player state data models
var players: Array[PlayerState] = []


func _ready() -> void:
	_setup_board()
	_setup_players()


func _setup_board() -> void:
	board = _spaces_list.board


func _setup_players() -> void:
	for i in range(player_count):
		players.append(PlayerState.new())
		add_child(players[i])
		players[i].balance = 1500  # TODO: Change to constant


## Changes the ownership of an ownable property
func _transfer_property(property: Ownable, player: int) -> void:
	if not property._is_owned:
		property._is_owned = true
	property._player_owner = player


## Purchases an unowned property - deducts balance and transfers ownership
func _purchase_unowned_property(property: Ownable, player: int, purchase_price: int) -> void:
	players[player].balance -= purchase_price
	_transfer_property(property, player)


## Purchases an owned property - handles money transfer between players
func _purchase_owned_property(property: Ownable, buyer: int, seller: int, purchase_price: int) -> void:
	players[buyer].balance -= purchase_price
	players[seller].balance += purchase_price
	_transfer_property(property, buyer)

func _payRent(property: Ownable, player:int) ->void:
	var rent = 0
	match property.get_script().get_global_name():
		"property_space":
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
		"instrument_space": # TODO: Implement checking for number of instrument spaces
			rent = 0
		"planet_space": # TODO: Implement checking dice roll for determining rent
			rent = 0
	players[player].balance -= rent
	players[property.owner] += rent
	player_money_updated.emit(players[player])
	player_money_updated.emit(players[property.owner])


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


func get_current_player():
	## PLACEHOLDER:
	##   - Currently returns null, because we don't have a real player model yet.
	##   - When the real Player system is implemented, this should return the
	##     current player object / dictionary/array.
	return null


func start_game() -> void:
	## PLACEHOLDER:
	##   - Call this from the main scene if we want a single place to
	##     initialize GameState.
	##   - Emits current_player_changed with whatever get_current_player()
	##     returns (currently null).
	emit_signal("current_player_changed", get_current_player())


func next_player() -> void:
	## PLACEHOLDER:
	##   - for "end turn / advance player" logic.
	##   - Right now it just re-emits current_player_changed with whatever
	##     get_current_player() returns (null).
	emit_signal("current_player_changed", get_current_player())


func change_player_cash(player, _delta: int) -> void:
	## PLACEHOLDER:
	##   - Intended to adjust a player's cash 
	##   - Currently does nothing to player and only emits a signal.
	##   - When the real Player model is ready, this function is a good place
	##     to:
	##         • modify player.cash (or whatever field we use)
	##         • then emit player_money_updated(player)
	emit_signal("player_money_updated", player)

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

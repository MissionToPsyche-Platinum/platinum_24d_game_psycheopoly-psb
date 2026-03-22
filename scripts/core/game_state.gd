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
## Think I provided a solution
var player_count: int = 6

# Holds the player state data models
var players: Array[PlayerState] = []

var last_roll = 0

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

# Accessibility
var colorblind_mode: bool = false

# Setup selections (filled by GameSetupScreen before starting board)
# Each: { "name": String, "color_index": int }
var setup_humans: Array[Dictionary] = []
var setup_human_count: int = 1

# Tracks whether each player is still in the game
var player_active: Array[bool] = []


func _ready() -> void:
	_setup_board()


func _setup_board() -> void:
	board = _spaces_list.board


func _setup_players() -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()

	player_active.clear()

	for i in range(player_count):
		var player = PlayerState.new()
		player.player_id = i
		player.balance = 1500

		# Apply human config if provided
		if i < setup_humans.size():
			var cfg: Dictionary = setup_humans[i]

			player.player_name = str(cfg.get("name", "Player " + str(i + 1)))

			var color_index: int = int(cfg.get("color_index", i))
			color_index = clampi(color_index, 0, PLAYER_COLORS.size() - 1)
			player.player_color = PLAYER_COLORS[color_index]
			player.player_is_ai = false
		else:
			# AI player
			player.player_name = "AI " + str(i + 1)
			player.player_color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
			player.player_is_ai = true

		players.append(player)
		add_child(player)

		# Everyone starts active
		player_active.append(true)


func apply_setup(total_players: int, humans: Array[Dictionary]) -> void:
	player_count = total_players
	setup_humans = humans.duplicate(true)
	setup_human_count = setup_humans.size()

	current_player_index = 0
	game_active = false

	_setup_players()
	player_count = players.size()

	GameController.emit_signal("setup_changed")


# ------------------------------------------------------------------------------
# Money helpers (used by Board / UI flows)
# ------------------------------------------------------------------------------

func charge_player(player_idx: int, amount: int) -> void:
	if player_idx < 0 or player_idx >= players.size():
		return
	players[player_idx].balance -= amount


func credit_player(player_idx: int, amount: int) -> void:
	if player_idx < 0 or player_idx >= players.size():
		return
	players[player_idx].balance += amount


# ------------------------------------------------------------------------------
# UI helpers
# ------------------------------------------------------------------------------

func get_player_display_name(player_index: int) -> String:
	if player_index >= 0 and player_index < players.size():
		var player_name := str(players[player_index].player_name).strip_edges()
		if player_name != "":
			return player_name

	if player_index >= 0 and player_index < setup_humans.size():
		var setup_name := str(setup_humans[player_index].get("name", "")).strip_edges()
		if setup_name != "":
			return setup_name

	return "Player %d" % (player_index + 1)

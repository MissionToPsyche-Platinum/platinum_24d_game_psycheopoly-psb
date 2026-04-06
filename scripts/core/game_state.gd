extends Node
##
## game_state.gd  (An autoload singleton)

# Global difficulty (used by StartMenu.gd)

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

# Available board token names
const AVAILABLE_TOKENS: Array[String] = [
	"Asteroid",
	"Crescent Moon",
	"Rocket",
	"Satellite",
	"Sun",
	"UFO"
]

# Current player's index (0-based)
var current_player_index: int = 0

# Whether a game is currently active
var game_active: bool = false

# Accessibility
var colorblind_mode: bool = false

# Setup selections (filled by GameSetupScreen before starting board)
# Each: { "name": String, "color_index": int, "token": String }
var setup_humans: Array[Dictionary] = []
var setup_human_count: int = 1

# Tracks whether each player is still in the game
var player_active: Array[bool] = []

var match_start_unix: int = 0

var match_stats: Dictionary = {}


func _ready() -> void:
	_setup_board()


func _setup_board() -> void:
	board = _spaces_list.board
	

func _reset_board_ownership_state() -> void:
	for i in range(board.size()):
		var space = board[i]

		if space == null:
			continue

		# Reset all ownable spaces (properties, planets, instruments)
		if space is Ownable:
			var ownable := space as Ownable
			ownable._is_owned = false
			ownable._player_owner = -1
			ownable._is_mortgaged = false

		# Reset upgrades on standard properties
		if space is PropertySpace:
			var property := space as PropertySpace
			property._current_upgrades = 0


func _setup_players() -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()

	player_active.clear()

	# Track used tokens so AI can avoid duplicates when possible
	var used_tokens: Array[String] = []

	# First collect human-selected tokens from setup data
	for i in range(setup_humans.size()):
		var cfg: Dictionary = setup_humans[i]
		var token_name := str(cfg.get("token", "Rocket")).strip_edges()

		if token_name == "":
			token_name = "Rocket"

		if not AVAILABLE_TOKENS.has(token_name):
			token_name = "Rocket"

		if not used_tokens.has(token_name):
			used_tokens.append(token_name)

	for i in range(player_count):
		var player
		# Apply human config if provided
		if i < setup_humans.size():
			player = PlayerState.new()
			player.player_id = i
			player.balance = 1500
			var cfg: Dictionary = setup_humans[i]

			player.player_name = str(cfg.get("name", "Player " + str(i + 1)))

			var color_index: int = int(cfg.get("color_index", i))
			color_index = clampi(color_index, 0, PLAYER_COLORS.size() - 1)
			player.player_color = PLAYER_COLORS[color_index]

			# store selected token from setup
			var human_token := str(cfg.get("token", "Rocket")).strip_edges()
			if human_token == "":
				human_token = "Rocket"
			if not AVAILABLE_TOKENS.has(human_token):
				human_token = "Rocket"

			player.player_token_name = human_token
			player.player_is_ai = false
		else:
			# AI player
			player = AiPlayerState.new()
			player.player_id = i
			player.balance = 1500
			player.difficulty = GameState.difficulty # set the difficulty of the AI on AI creation
			player.player_name = "AI " + str(i + 1)
			player.player_color = PLAYER_COLORS[i % PLAYER_COLORS.size()]

			#  AI randomly chooses an unused token if possible
			var ai_token := _get_random_available_token(used_tokens)
			player.player_token_name = ai_token
			player.player_is_ai = true
			
			AiManager._initialize_property_multipliers(player)

			if not used_tokens.has(ai_token):
				used_tokens.append(ai_token)

		players.append(player)
		add_child(player)

		# Everyone starts active
		player_active.append(true)
		
	start_match_stats()


func apply_setup(total_players: int, humans: Array[Dictionary]) -> void:
	player_count = total_players
	setup_humans = humans.duplicate(true)
	setup_human_count = setup_humans.size()

	current_player_index = 0
	game_active = false

	_setup_players()
	player_count = players.size()

	GameController.emit_signal("setup_changed")


# Money helpers (used by Board / UI flows)

func charge_player(player_idx: int, amount: int) -> void:
	if player_idx < 0 or player_idx >= players.size():
		return
	players[player_idx].balance -= amount


func credit_player(player_idx: int, amount: int) -> void:
	if player_idx < 0 or player_idx >= players.size():
		return
	players[player_idx].balance += amount



# UI helpers


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


# Helper to get a player's selected token
func get_player_token_name(player_index: int) -> String:
	if player_index >= 0 and player_index < players.size():
		var p = players[player_index]
		if p != null:
			var token_name := str(p.player_token_name).strip_edges()
			if token_name != "" and AVAILABLE_TOKENS.has(token_name):
				return token_name

	if player_index >= 0 and player_index < setup_humans.size():
		var setup_token := str(setup_humans[player_index].get("token", "Rocket")).strip_edges()
		if setup_token != "" and AVAILABLE_TOKENS.has(setup_token):
			return setup_token

	return "Rocket"

# pick a random unused token if possible, otherwise random from all
func _get_random_available_token(used_tokens: Array[String]) -> String:
	var remaining: Array[String] = []

	for token_name in AVAILABLE_TOKENS:
		if not used_tokens.has(token_name):
			remaining.append(token_name)

	if remaining.size() > 0:
		return remaining[randi() % remaining.size()]

	# Fallback: all tokens already used, allow duplicates
	return AVAILABLE_TOKENS[randi() % AVAILABLE_TOKENS.size()]
	

func reset_for_replay() -> void:
	# Stop active match
	game_active = false

	# Reset basic turn/game state
	current_player_index = 0
	last_roll = 0

	# Keep board reference valid, then clear ownership/upgrades/mortgages
	_setup_board()
	_reset_board_ownership_state()

	# Rebuild players using the same saved humans/player count
	# This restores starting cash, clears jail flags, resets stats on PlayerState, etc.
	_setup_players()

	# Keep player_count synced to actual created players
	player_count = players.size()
	
func reset_for_new_game() -> void:
	# Stop active match
	game_active = false

	# Reset basic turn/game state
	current_player_index = 0
	last_roll = 0

	# Clear board ownership/upgrades/mortgages
	_setup_board()
	_reset_board_ownership_state()

	# Free existing player nodes and clear runtime arrays
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()

	player_active.clear()
	reset_match_stats()


# Match Stats Helpers

func reset_match_stats() -> void:
	match_start_unix = 0
	match_stats.clear()


func start_match_stats() -> void:
	match_start_unix = Time.get_unix_time_from_system()
	match_stats.clear()

	for i in range(players.size()):
		_ensure_player_match_stats(i)


func _ensure_player_match_stats(player_index: int) -> void:
	if not match_stats.has(player_index):
		match_stats[player_index] = {
			"earnings": 0,
			"properties_acquired": 0
		}


func add_player_earnings(player_index: int, amount: int) -> void:
	if player_index < 0:
		return

	_ensure_player_match_stats(player_index)
	match_stats[player_index]["earnings"] += amount


func increment_properties_acquired(player_index: int, amount: int = 1) -> void:
	if player_index < 0:
		return

	_ensure_player_match_stats(player_index)
	match_stats[player_index]["properties_acquired"] += amount


func get_player_earnings(player_index: int) -> int:
	if not match_stats.has(player_index):
		return 0
	return int(match_stats[player_index].get("earnings", 0))


func get_player_properties_acquired(player_index: int) -> int:
	if not match_stats.has(player_index):
		return 0
	return int(match_stats[player_index].get("properties_acquired", 0))


func get_match_duration_seconds() -> int:
	if match_start_unix <= 0:
		return 0

	var now_time := Time.get_unix_time_from_system()
	return max(0, now_time - match_start_unix)


func format_match_duration() -> String:
	var total_seconds := get_match_duration_seconds()
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func get_player_final_net_worth(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0

	var player = players[player_index]
	if player == null:
		return 0

	var total := int(player.balance)

	for space in board:
		if space == null:
			continue

		if not (space is Ownable):
			continue

		var ownable := space as Ownable
		var owner_index := ownable.get_property_owner()

		# Skip unowned or properties owned by other players
		if owner_index == Ownable.NO_OWNER or owner_index != player_index:
			continue

		total += int(ownable._initial_price)

		if space is PropertySpace:
			var property := space as PropertySpace
			total += int(property._current_upgrades * property._upgrade_cost)

	return total

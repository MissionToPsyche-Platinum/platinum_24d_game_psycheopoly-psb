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

extends Node
##
## game_state.gd  (An autoload singleton)
## ============================================================================
##  PURPOSE (at least, for now):
##    - Provide the signals and the functions that MoneyHUD expects.
##    - Allow the HUD to connect and run without errors.
##    - not define any real game logic yet.
##
##  General note for us
##    Everything here is safe to change or replace later.
##    Think of this file as a small bridge so the HUD can exist while the
##    real GameState design is still in progress.
## ============================================================================


# ------------------------------------------------------------------------------
# The Signlas expected by MoneyHUD.gd
# ------------------------------------------------------------------------------
## Emitted when the active player changes (MoneyHUD should listen to this).
signal current_player_changed(player)

## Emitted when a player's money changes (MoneyHUD should listen to this).
signal player_money_updated(player)



# ------------------------------------------------------------------------------
# Placeholder Section
# ------------------------------------------------------------------------------
## These functions exist ONLY so other code in money HUD can compile and call them.
## We can change their implementation or signatures to what we all agree on is best
## as long as MoneyHUD still gets usable data via the signals above, things should
## work as expected.


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


func change_player_cash(player, delta: int) -> void:
	## PLACEHOLDER:
	##   - Intended to adjust a player's cash by `delta`.
	##   - Currently does nothing to `player` and only emits a signal.
	##
	##   - When the real Player model is ready, this function is a good place
	##     to:
	##         • modify player.cash (or whatever field you use)
	##         • then emit player_money_updated(player)
	emit_signal("player_money_updated", player)

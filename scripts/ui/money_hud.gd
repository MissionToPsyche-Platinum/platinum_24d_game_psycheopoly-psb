extends Control
## MoneyHUD.gd
## -----------------------------------------------------------------------------
## 	 Money HUD is responsible for Displaying the labels, icons
## 	 and listening to the GameState signals to update values in real time
##  
##
## How it flows :
##   - I made GameState is an autoload singleton (Project Settings → Autoload).
##   - GameState should at least define:
##         signal current_player_changed(player)
##         signal player_money_updated(player)
##   - This HUD connects to those signals in the _ready() function.
##
##  Placeholder notes.
##   - update_from_player() assumes the player object has cash and
##     assets_value fields (or getters). If we decide to use different names,
##     we have to change them inside that function.
##   - The debug input handler (_unhandled_input) is just for quick testing 
##    on the HUD and can be removed later
## -----------------------------------------------------------------------------


@onready var money_label: Label = $Panel/ContentMargin/HBoxContainer/MoneyBox/MoneyLabel
@onready var asset_label: Label = $Panel/ContentMargin/HBoxContainer/AssetBox/AssetLabel

@onready var money_title_label: Label = $Panel/ContentMargin/HBoxContainer/MoneyBox/MoneyTitleLabel
@onready var asset_title_label: Label = $Panel/ContentMargin/HBoxContainer/AssetBox/AssetTitleLabel


func _ready() -> void:
	## Called when the HUD is added to the scene tree.
	## Here we:
	##    initialize default text
	##    connect to the global GameState autoload so the HUD updates
	##    automatically when the current player changes or their money or assets change.

	# Initial text for the HUD 
	money_title_label.text = "Cash"
	asset_title_label.text = "Assets"
	money_label.text = "$0"
	asset_label.text = "$0"

	# This prevents talking to GameState while editing someting in the scene view
	if Engine.is_editor_hint():
		return

	# ------------------------------------------------------------------------
	# Connecting to the GameState signals here
	# ------------------------------------------------------------------------
	
	# General note for us as a reminder
	#   - If these signal names change, update them here.
	#   - If GameController stops being an autoload, this section will need to be
	#     adjusted to use get_node() instead, I think. Just FYI
	#
	if GameController:
		if GameController.has_signal("current_player_changed"):
			GameController.current_player_changed.connect(_on_current_player_changed)
		else:
			push_warning("GameState has no 'current_player_changed' signal. " +
						 "HUD will not auto-update on turn changes.")

		if GameController.has_signal("player_money_updated"):
			GameController.player_money_updated.connect(_on_player_money_updated)
		else:
			push_warning("GameState has no 'player_money_updated' signal. " +
						 "HUD will not auto-update on money changes.")
	else:
		push_warning("GameState autoload not found. " +
					 "HUD will only update if set_cash/set_assets are called manually.")

	# Initialize HUD with the current player right away (safe, no fake signal emit)
	if GameState and GameState.players.size() > 0:
		update_from_player(GameState.get_current_player())


# ---------------------------------------------------------------------------
#  other scripts should be able  call these directly if we want
# ---------------------------------------------------------------------------

func set_cash(amount: int) -> void:
	## Updates the displayed cash to user
	## GameState calls this when the active player's cash changes.
	money_label.text = "$" + str(amount)


func set_assets(amount: int) -> void:
	## Updates the displayed assets (total wealth including properties).
	## GameState calls this when the active player's asset value changes.
	asset_label.text = "$" + str(amount)


func update_from_player(player: Object) -> void:
	## Method for convenience: update HUD from a "player" object or dictionary.
	##
	## PLACEHOLDER ASSUMPTIONS I AM HAVING ABOUT THE PLAYER
	##   - player.balance       : int value
	##   - player.assets_value  : int (cash + property values, etc.) value
	##
	## If our Player uses different names, change only the field access modifier here
	## (so for example `player.balance` instead of `player.cash`).
	##
	if player == null:
		return

	var cash := 0
	var assets := 0

	# Dictionary-style player data
	if typeof(player) == TYPE_DICTIONARY:
		if "balance" in player:
			cash = int(player["balance"])
		if "assets_value" in player:
			assets = int(player["assets_value"])
	else:
		# Node/Resource-style player data
		if "balance" in player:
			cash = int(player.balance)
		elif player.has_method("get_cash"):
			cash = int(player.get_cash())

		if "assets_value" in player:
			assets = int(player.assets_value)
		elif player.has_method("get_assets_value"):
			assets = int(player.get_assets_value())

	set_cash(cash)
	set_assets(assets)


# ---------------------------------------------------------------------------
# Signal Handling – called when GameState emits updates
# ---------------------------------------------------------------------------

func _on_current_player_changed(player: Object) -> void:
	## Called when GameState emits "current_player_changed".
	## We simply forward the player to update_from_player.
	##
	## Expected emit (in GameState.gd):
	##     emit_signal("current_player_changed", current_player)
	update_from_player(player)


func _on_player_money_updated(player: Object) -> void:
	## Called when GameState emits "player_money_updated".
	##
	## IMPORTANT:
	## Auctions / rent / other events can change a NON-current player's money
	## during someone else's turn. We should only update this HUD if the money
	## update belongs to the current player being displayed.
	if not GameState:
		return

	var current_player := GameState.get_current_player()
	if current_player == null:
		return

	# Only update HUD if this update belongs to the current player
	if player != current_player:
		return

	update_from_player(player)


# ---------------------------------------------------------------------------
# Quick keyboard test – can be removed once GameState integration is functional
# Just made this to visually see updates to the values in the HUD
# without the need to have the GameState, Player, etc created.
# ---------------------------------------------------------------------------

var _debug_cash := 0        # placeholder  value
var _debug_assets := 0      # placeholder  value

func _unhandled_input(event: InputEvent) -> void:
	## Lets us test the HUD in-game without involving GameState.
	##  - Press "C" to add +10 cash
	##  - Press "A" to add +50 assets
	##
	## We are good to delete this once
	##  - GameState is fully wired to the HUD, and
	##  - We no longer need quick testing.
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_C:
				_debug_cash += 10
				set_cash(_debug_cash)
			KEY_A:
				_debug_assets += 50
				set_assets(_debug_assets)

extends Node

const RollDiceUI := preload("res://scripts/ui/roll_dice_ui.gd")

var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("=== Acquiring Asteroids Automated Tests START ===")

	test_dice_range()
	test_turn_progression_and_doubles()
	test_multiple_doubles_extra_turns()
	test_trading_execution()

	print("=== Acquiring Asteroids Automated Tests END ===")
	print("Passed: %d | Failed: %d" % [tests_passed, tests_failed])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		# No print on success to avoid output overflow, was getting errors before
	else:
		tests_failed += 1
		push_error("FAIL: " + message)


func test_dice_range() -> void:
	print("--- Running test_dice_range ---")

	# Using the dice logic from roll_dice_ui.gd
	var dice_ui := RollDiceUI.new()
	dice_ui.rng.randomize() 

	var iterations: int = 500  # Can adjust number of tests here

	for i in range(iterations):
		var r: Dictionary = dice_ui.roll_dice()
		var d1: int = r["d1"]
		var d2: int = r["d2"]
		var total: int = r["total"]
	
	# 3 Checks of 500 each, 500 for dice 1, 500 for dice 2, and 500 for total.
		assert_true(d1 >= 1 and d1 <= 6,
			"Die 1 in range [1,6] (got %d)" % d1)
		assert_true(d2 >= 1 and d2 <= 6,
			"Die 2 in range [1,6] (got %d)" % d2)
		assert_true(total >= 2 and total <= 12,
			"Total in range [2,12] (got %d)" % total)

	print("Dice range test finished for %d rolls." % iterations)


# ---- Helper: set up a 2-player game for unit tests ----
func _setup_two_players() -> void:
	var humans: Array[Dictionary] = [
		{"name": "Player 1", "color_index": 0},
		{"name": "Player 2", "color_index": 1}
	]
	GameState.apply_setup(2, humans)
	GameState.game_active = true
	GameState.current_player_index = 0


# ---- TC-006: Turn Progression and Doubles ----
func test_turn_progression_and_doubles():
	print("--- Running test_turn_progression_and_doubles ---")
	_setup_two_players()

	var player1 = GameState.players[0]

	# Simulate a non-double roll (e.g., 3 and 4)
	player1.has_rolled = true
	player1.doubles_count = 0
	GameController.end_turn()

	assert_true(GameState.current_player_index == 1,
		"Normal turn: Expected next player index 1, got %d" % GameState.current_player_index)
	print("Test Normal Turn: Expected Next Player Index 1, Got ", GameState.current_player_index)

	# Simulate a double roll (e.g., 3 and 3)
	GameState.current_player_index = 0
	player1.doubles_count = 1
	GameController.end_turn()

	assert_true(GameState.current_player_index == 0,
		"Doubles turn: Expected player index 0 (roll again), got %d" % GameState.current_player_index)
	print("Test Doubles Turn: Expected Next Player Index 0 (Roll Again), Got ", GameState.current_player_index)


# ---- TC-007: Multiple Doubles Extra Turns ----
func test_multiple_doubles_extra_turns():
	print("--- Running test_multiple_doubles_extra_turns ---")
	_setup_two_players()

	GameState.current_player_index = 0
	var player1 = GameState.players[0]

	# Roll 1: Doubles (1st extra turn earned)
	player1.has_rolled = true
	player1.doubles_count = 1
	GameController.end_turn()

	assert_true(GameState.current_player_index == 0,
		"Roll 1 (Double): Expected player index 0, got %d" % GameState.current_player_index)
	print("Test Roll 1 (Double) - Expected Player Index: 0, Got: ", GameState.current_player_index)

	# Roll 2: Doubles (2nd extra turn earned)
	player1.has_rolled = true
	player1.doubles_count = 2
	GameController.end_turn()

	assert_true(GameState.current_player_index == 0,
		"Roll 2 (Double): Expected player index 0, got %d" % GameState.current_player_index)
	print("Test Roll 2 (Double) - Expected Player Index: 0, Got: ", GameState.current_player_index)

	# Roll 3: Normal Roll (Turn finally ends)
	player1.has_rolled = true
	player1.doubles_count = 0
	GameController.end_turn()

	assert_true(GameState.current_player_index == 1,
		"Roll 3 (Normal): Expected player index 1, got %d" % GameState.current_player_index)
	print("Test Roll 3 (Normal) - Expected Player Index: 1, Got: ", GameState.current_player_index)


# ---- TC-008: Trading Execution ----
func test_trading_execution():
	print("--- Running test_trading_execution ---")
	_setup_two_players()

	var player1 = GameState.players[0]
	var player2 = GameState.players[1]
	player1.balance = 1500
	player2.balance = 1500

	# Assign Property at space 1 (Hebe) to Player 1, space 3 (Elektra) to Player 2
	(GameState.board[1] as Ownable).set_property_owner(player1.player_id)
	(GameState.board[3] as Ownable).set_property_owner(player2.player_id)

	# Execute trade: Player 1 gives Property 1 + $100 for Player 2's Property 3
	var trade_offer := {
		"offering_player": player1.player_id,
		"target_player": player2.player_id,
		"offered_spaces": [1],
		"offer_cash": 100,
		"requested_spaces": [3],
		"request_cash": 0
	}
	GameController.execute_trade_offer(trade_offer)

	assert_true(player1.balance == 1400,
		"Trade balance P1: Expected 1400, got %d" % player1.balance)
	assert_true(player2.balance == 1600,
		"Trade balance P2: Expected 1600, got %d" % player2.balance)
	assert_true((GameState.board[1] as Ownable)._player_owner == player2.player_id,
		"Trade prop 1 owner: Expected player 2 ID (%d), got %d" % [player2.player_id, (GameState.board[1] as Ownable)._player_owner])
	assert_true((GameState.board[3] as Ownable)._player_owner == player1.player_id,
		"Trade prop 3 owner: Expected player 1 ID (%d), got %d" % [player1.player_id, (GameState.board[3] as Ownable)._player_owner])

	print("Test Trade Balance P1: Expected 1400, Got ", player1.balance)
	print("Test Trade Balance P2: Expected 1600, Got ", player2.balance)
	print("Test Trade Prop 1 Owner: Expected Player 2 ID, Got ", (GameState.board[1] as Ownable)._player_owner)
	print("Test Trade Prop 3 Owner: Expected Player 1 ID, Got ", (GameState.board[3] as Ownable)._player_owner)

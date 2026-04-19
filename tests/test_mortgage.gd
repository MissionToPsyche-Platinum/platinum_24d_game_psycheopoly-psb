extends Node

var tests_passed := 0
var tests_failed := 0


func _ready() -> void:
	await run_all_tests()
	print("=== Mortgage Tests Complete ===")
	print("Passed: %d | Failed: %d" % [tests_passed, tests_failed])
	get_tree().quit(1 if tests_failed > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		print("PASS: " + message)
	else:
		tests_failed += 1
		push_error("FAIL: " + message)


func setup_game() -> void:
	GameState.reset_for_new_game()
	await get_tree().process_frame
	GameState._setup_board()

	var humans: Array[Dictionary] = [
		{"name": "Player 1", "color_index": 0},
		{"name": "Player 2", "color_index": 1}
	]
	GameState.apply_setup(2, humans, [])
	GameState.current_player_index = 0
	GameState.game_active = true
	await get_tree().process_frame


func run_all_tests() -> void:
	print("=== Running Mortgage Test Suite ===")
	await test_mortgage_rejected_when_set_has_upgrades()
	await test_mortgage_credits_owner_and_disables_rent()
	await test_unmortgage_requires_cash_and_charges_interest()


func test_mortgage_rejected_when_set_has_upgrades() -> void:
	await setup_game()

	var hebe := GameState.board[1] as PropertySpace
	var elektra := GameState.board[3] as PropertySpace
	hebe.set_property_owner(0)
	elektra.set_property_owner(0)
	elektra._current_upgrades = 1

	var starting_balance := GameState.players[0].balance

	assert_true(
		not GameController.check_mortgage_valid(hebe, 0),
		"mortgage is invalid when any property in the set still has upgrades"
	)

	GameController.mortgage_property.emit(hebe, 0)

	assert_true(not hebe._is_mortgaged, "property stays unmortgaged when mortgage rules are not met")
	assert_true(
		GameState.players[0].balance == starting_balance,
		"invalid mortgage does not change the owner's balance"
	)


func test_mortgage_credits_owner_and_disables_rent() -> void:
	await setup_game()

	var instrument := GameState.board[5] as Ownable
	instrument.set_property_owner(0)

	var owner_balance := GameState.players[0].balance
	var visitor_balance := GameState.players[1].balance
	var mortgage_value := GameController.get_mortgage_value(instrument)

	assert_true(
		GameController.check_mortgage_valid(instrument, 0),
		"ownable space can be mortgaged by its owner when requirements are satisfied"
	)
	assert_true(
		not GameController.check_mortgage_valid(instrument, 1),
		"non-owner cannot mortgage another player's property"
	)

	GameController.mortgage_property.emit(instrument, 0)

	assert_true(instrument._is_mortgaged, "valid mortgage marks the space as mortgaged")
	assert_true(
		GameState.players[0].balance == owner_balance + mortgage_value,
		"valid mortgage credits the owner with the listed mortgage value"
	)

	GameController._pay_rent(instrument, 1)

	assert_true(
		GameState.players[0].balance == owner_balance + mortgage_value,
		"mortgaged property does not collect rent for the owner"
	)
	assert_true(
		GameState.players[1].balance == visitor_balance,
		"landing player pays no rent on a mortgaged property"
	)


func test_unmortgage_requires_cash_and_charges_interest() -> void:
	await setup_game()

	var instrument := GameState.board[5] as Ownable
	instrument.set_property_owner(0)
	GameController.mortgage_property.emit(instrument, 0)

	var unmortgage_cost := GameController.get_unmortgage_cost(instrument)
	assert_true(unmortgage_cost == 83, "unmortgage cost applies the 10 percent fee and rounds up")

	GameState.players[0].balance = 82
	assert_true(
		not GameController.check_unmortgage_valid(instrument, 0),
		"player cannot unmortgage without enough money to cover the fee"
	)

	GameController.unmortgage_property.emit(instrument, 0)

	assert_true(instrument._is_mortgaged, "property remains mortgaged after an invalid unmortgage attempt")
	assert_true(
		GameState.players[0].balance == 82,
		"invalid unmortgage attempt does not change the player's balance"
	)

	GameState.players[0].balance = 100
	assert_true(
		GameController.check_unmortgage_valid(instrument, 0),
		"player can unmortgage once enough funds are available"
	)

	GameController.unmortgage_property.emit(instrument, 0)

	assert_true(not instrument._is_mortgaged, "valid unmortgage clears the mortgaged state")
	assert_true(
		GameState.players[0].balance == 17,
		"valid unmortgage deducts the full mortgage cost including interest"
	)

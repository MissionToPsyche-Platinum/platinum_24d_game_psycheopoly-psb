extends Node

var bankruptcy_signal_emitted := false
var bankruptcy_debtor := -1
var bankruptcy_creditor := -1
var bankruptcy_amount := -1
var bankruptcy_reason := ""

var board

func _ready() -> void:
	await run_all_tests()
	get_tree().quit()


func setup_shared_state() -> void:
	bankruptcy_signal_emitted = false
	bankruptcy_debtor = -1
	bankruptcy_creditor = -1
	bankruptcy_amount = -1
	bankruptcy_reason = ""

	GameState.reset_for_new_game()
	GameState._setup_board()

	var humans: Array[Dictionary] = [
		{
			"name": "Player 1",
			"color_index": 0,
			"token": "Satellite"
		},
		{
			"name": "Player 2",
			"color_index": 1,
			"token": "Rocket"
		}
	]

	GameState.apply_setup(2, humans, [])
	GameState.game_active = true
	GameState.current_player_index = 0

	GameState.players[0].balance = 50
	GameState.players[1].balance = 1500
	GameState.player_active = [true, true]

	if not GameController.bankruptcy_needed.is_connected(_on_bankruptcy_needed):
		GameController.bankruptcy_needed.connect(_on_bankruptcy_needed)

	var BoardScript = preload("res://scripts/core/board.gd")
	board = BoardScript.new()

	board.notification_popup = null
	board.bankruptcy_popup = null
	board.end_game_popup = null
	board.assets_popup = null
	board.auction_popup = null
	board.trade_popup = null
	board.space_action_popup = null


func _on_bankruptcy_needed(debtor_index: int, creditor_index: int, amount: int, reason: String) -> void:
	bankruptcy_signal_emitted = true
	bankruptcy_debtor = debtor_index
	bankruptcy_creditor = creditor_index
	bankruptcy_amount = amount
	bankruptcy_reason = reason


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func cleanup_state() -> void:
	if board != null:
		board.queue_free()
		board = null
	await get_tree().process_frame


func run_all_tests() -> void:
	print("=== Running TC-015: Bankruptcy and Winner Detection ===")
	await test_bankruptcy_signal_emits()
	await test_bankruptcy_removes_player_and_detects_winner()
	print("=== Finished TC-015 ===")


func test_bankruptcy_signal_emits() -> void:
	setup_shared_state()

	var paid := GameController.request_payment(0, 200, "Test bankruptcy payment", 1)

	assert_true(not paid, "request_payment returns false when player cannot afford debt")
	assert_true(bankruptcy_signal_emitted, "bankruptcy_needed signal is emitted")
	assert_true(bankruptcy_debtor == 0, "bankruptcy debtor index is Player 1")
	assert_true(bankruptcy_creditor == 1, "bankruptcy creditor index is Player 2")
	assert_true(bankruptcy_amount == 200, "bankruptcy amount is recorded correctly")
	assert_true(bankruptcy_reason == "Test bankruptcy payment", "bankruptcy reason is recorded correctly")

	await cleanup_state()


func test_bankruptcy_removes_player_and_detects_winner() -> void:
	setup_shared_state()

	board.pending_debtor_index = 0
	board.pending_creditor_index = 1
	board.pending_amount_owed = 200
	board.pending_reason = "Test bankruptcy payment"

	await board._on_bankruptcy_declared()

	assert_true(GameState.player_active[0] == false, "bankrupt player is marked inactive")
	assert_true(GameState.player_active[1] == true, "remaining player stays active")

	var active_count := 0
	var last_active := -1
	for i in range(GameState.player_active.size()):
		if GameState.player_active[i]:
			active_count += 1
			last_active = i

	assert_true(active_count == 1, "only one active player remains after bankruptcy")
	assert_true(last_active == 1, "Player 2 is the last active player")
	assert_true(GameState.game_active == false, "game is ended after winner is determined")

	await cleanup_state()

extends Node

var board_scene_instance = null
var bankruptcy_signal_emitted := false
var bankruptcy_popup_shown := false

func _ready() -> void:
	await run_test()
	get_tree().quit()


func setup_game() -> void:
	# Reset state
	bankruptcy_signal_emitted = false
	bankruptcy_popup_shown = false

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
	GameState.current_player_index = 0

	# Instantiate the REAL game board scene
	var BoardScene = preload("res://scenes/GameBoard.tscn")
	board_scene_instance = BoardScene.instantiate()
	add_child(board_scene_instance)

	# Let Board._ready() finish creating popups/UI and start the game
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Force a bankruptcy setup
	GameState.players[0].balance = 50
	GameState.players[1].balance = 1500
	GameState.player_active = [true, true]

	# Watch bankruptcy signal
	if not GameController.bankruptcy_needed.is_connected(_on_bankruptcy_needed):
		GameController.bankruptcy_needed.connect(_on_bankruptcy_needed)


func _on_bankruptcy_needed(_debtor_index: int, _creditor_index: int, _amount: int, _reason: String) -> void:
	bankruptcy_signal_emitted = true


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func cleanup_game() -> void:
	if GameController.bankruptcy_needed.is_connected(_on_bankruptcy_needed):
		GameController.bankruptcy_needed.disconnect(_on_bankruptcy_needed)

	if board_scene_instance != null and is_instance_valid(board_scene_instance):
		board_scene_instance.queue_free()
		board_scene_instance = null

	GameState.reset_for_new_game()
	await get_tree().process_frame


func run_test() -> void:
	print("=== Running TC-016: End-to-End Bankruptcy to Win Screen Flow ===")
	await test_end_to_end_bankruptcy_to_win()
	print("=== Finished TC-016 ===")


func test_end_to_end_bankruptcy_to_win() -> void:
	await setup_game()

	# Trigger a payment the current player cannot afford
	var paid := GameController.request_payment(0, 200, "System test payment", 1)

	assert_true(not paid, "system flow rejects payment when player cannot afford debt")
	assert_true(bankruptcy_signal_emitted, "system emits bankruptcy_needed during end-to-end flow")

	#  Let the board receive the bankruptcy signal and show popup
	await get_tree().process_frame
	await get_tree().process_frame

	if board_scene_instance.bankruptcy_popup != null and is_instance_valid(board_scene_instance.bankruptcy_popup):
		bankruptcy_popup_shown = board_scene_instance.bankruptcy_popup.visible

	assert_true(bankruptcy_popup_shown, "bankruptcy popup is shown in end-to-end flow")

	#  Simulate the player declaring bankruptcy via the real board handler
	await board_scene_instance._on_bankruptcy_declared()

	#  Verify system-wide outcome
	assert_true(GameState.player_active[0] == false, "bankrupt player is removed from active play")
	assert_true(GameState.player_active[1] == true, "remaining player stays active")
	assert_true(GameState.game_active == false, "game stops after winner is determined")

	var active_count := 0
	var last_active := -1
	for i in range(GameState.player_active.size()):
		if GameState.player_active[i]:
			active_count += 1
			last_active = i

	assert_true(active_count == 1, "only one active player remains at system level")
	assert_true(last_active == 1, "Player 2 is the winning player")

	#  verify end game popup exists/is visible
	if board_scene_instance.end_game_popup != null and is_instance_valid(board_scene_instance.end_game_popup):
		assert_true(board_scene_instance.end_game_popup.visible, "end game popup is shown after win condition")

	await cleanup_game()

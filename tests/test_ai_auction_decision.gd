extends Node

var ai_manager
var bid_emitted := false
var pass_emitted := false
var bid_amount := -1

func _ready() -> void:
	await run_all_tests()
	get_tree().quit()


func setup_shared_state() -> void:
	# Reset flags
	bid_emitted = false
	pass_emitted = false
	bid_amount = -1

	# Reset GameState
	GameState.players.clear()
	GameState.board.clear()
	GameState.current_player_index = 0

	# Create AI player
	var AiPlayerStateScript = preload("res://scripts/core/ai_player_state.gd")
	var ai_player = AiPlayerStateScript.new()
	ai_player.player_id = 0
	ai_player.player_name = "Test AI"
	ai_player.player_is_ai = true
	ai_player.balance = 1000
	ai_player.difficulty = "Normal"

	GameState.players.append(ai_player)

	# Create test property on board
	var property_data = {
		"name": "Test Property",
		"price": 200,
		"rent": 10,
		"rent1data": 20,
		"rent2data": 30,
		"rent3data": 40,
		"rent4data": 50,
		"rentDiscovery": 60,
		"dataCost": 50,
		"mortgage": 100,
		"set": "Test Set"
	}

	var property = PropertySpace.new(property_data)
	GameState.board.append(property)

	# Load AI manager script
	
	ai_manager = preload("res://scripts/core/ai_manager.gd").new()
	add_child(ai_manager)

	# Connect auction signals so we can inspect emitted results
	ai_manager.ai_auction_bid.connect(_on_ai_auction_bid)
	ai_manager.ai_auction_pass.connect(_on_ai_auction_pass)

	# Initialize AI property values using the AI manager itself
	ai_manager._initialize_property_multipliers(ai_player)
	ai_manager._update_property_multipliers(ai_player)


func _on_ai_auction_bid(amount: int) -> void:
	bid_emitted = true
	bid_amount = amount


func _on_ai_auction_pass() -> void:
	pass_emitted = true


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func cleanup_manager() -> void:
	if ai_manager != null:
		ai_manager.queue_free()
		await get_tree().process_frame


func run_all_tests() -> void:
	print("=== Running TC-013: AI Auction Decision Logic ===")
	await test_ai_bids_50()
	await test_ai_bids_10()
	await test_ai_bids_1()
	await test_ai_passes()
	print("=== Finished TC-013 ===")


func test_ai_bids_50() -> void:
	setup_shared_state()

	var ai_player = GameState.players[0]
	ai_player.balance = 1000

	# Make property very valuable to AI
	ai_player.current_property_value_multipliers[0] = 10.0
	ai_player.master_property_value_multiplier = 1.0

	await ai_manager.ai_auction_decision(0, 100, 0)

	assert_true(bid_emitted, "AI emits a bid when value and balance support +50")
	assert_true(bid_amount == 50, "AI chooses +50 bid when it can afford it and value supports it")
	assert_true(not pass_emitted, "AI does not pass in +50 case")

	await cleanup_manager()


func test_ai_bids_10() -> void:
	setup_shared_state()

	var ai_player = GameState.players[0]
	ai_player.balance = 115

	# Value supports +10 but not +50
	ai_player.current_property_value_multipliers[0] = 1.0
	ai_player.master_property_value_multiplier = 1.0
	GameState.board[0]._initial_price = 200

	await ai_manager.ai_auction_decision(0, 100, 0)

	assert_true(bid_emitted, "AI emits a bid when it cannot do +50 but can do +10")
	assert_true(bid_amount == 10, "AI chooses +10 bid when +50 is not affordable")
	assert_true(not pass_emitted, "AI does not pass in +10 case")

	await cleanup_manager()


func test_ai_bids_1() -> void:
	setup_shared_state()

	var ai_player = GameState.players[0]
	ai_player.balance = 102

	# Value only barely supports +1
	ai_player.current_property_value_multipliers[0] = 1.0
	ai_player.master_property_value_multiplier = 1.0
	GameState.board[0]._initial_price = 200

	await ai_manager.ai_auction_decision(0, 100, 0)

	assert_true(bid_emitted, "AI emits a bid when it can only afford/value +1")
	assert_true(bid_amount == 1, "AI chooses +1 bid when +10 and +50 are not possible")
	assert_true(not pass_emitted, "AI does not pass in +1 case")

	await cleanup_manager()


func test_ai_passes() -> void:
	setup_shared_state()

	var ai_player = GameState.players[0]
	ai_player.balance = 100

	# Make property low value to AI
	ai_player.current_property_value_multipliers[0] = 0.1
	ai_player.master_property_value_multiplier = 1.0
	GameState.board[0]._initial_price = 100

	await ai_manager.ai_auction_decision(0, 100, 0)

	assert_true(pass_emitted, "AI passes when it cannot legally/profitably outbid")
	assert_true(not bid_emitted, "AI does not emit a bid when passing")

	await cleanup_manager()

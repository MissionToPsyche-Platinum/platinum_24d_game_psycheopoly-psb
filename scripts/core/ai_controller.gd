extends Node

const API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemma-3-27b-it:generateContent?key="
var API_KEY = ""

var http_request: HTTPRequest
var _request_in_flight: bool = false

var _last_request_time: int = 0
const MIN_REQUEST_INTERVAL_MSEC: int = 2100 # ~2.1 seconds to stay under 30 requests/minute

func _extract_reason(action_dict: Dictionary) -> String:
	var reason_text := str(action_dict.get("reason", "")).strip_edges()
	if reason_text == "":
		reason_text = str(action_dict.get("rationale", "")).strip_edges()
	if reason_text == "":
		reason_text = str(action_dict.get("thought", "")).strip_edges()

	reason_text = reason_text.replace("\n", " ").replace("\r", " ")
	if reason_text.length() > 240:
		reason_text = reason_text.substr(0, 240) + "..."
	return reason_text

func _ready():
	_load_env()
	# Create and configure the HTTPRequest node dynamically
	http_request = HTTPRequest.new()
	http_request.timeout = 25.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func _load_env():
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		for line in content.split("\n"):
			if line.begins_with("GEMINI_API_KEY="):
				API_KEY = line.split("=")[1].strip_edges()
	
	if API_KEY == "":
		push_error("AiController: GEMINI_API_KEY not found in .env file!")

# Example game_state structure:
# {
#     "player_name": "AI Bot 1",
#     "balance": 1500,
#     "current_space": "Boardwalk",
#     "can_buy_property": true,
#     "property_id_on_space": "prop_boardwalk",
#     "opponents": [{"name": "Player 2", "balance": 1200}]
# }
func take_turn(game_state_dictionary: Dictionary):
	if _request_in_flight:
		print("AiController: Request already in flight. Ignoring duplicate AI turn request.")
		return

	var current_time = Time.get_ticks_msec()
	var elapsed = current_time - _last_request_time
	
	if _last_request_time > 0 and elapsed < MIN_REQUEST_INTERVAL_MSEC:
		var wait_time = (MIN_REQUEST_INTERVAL_MSEC - elapsed) / 1000.0
		# Lock in the expected request time immediately for any parallel checks
		_last_request_time = current_time + int((MIN_REQUEST_INTERVAL_MSEC - elapsed))
		
		print("AiController: Pacing API requests (free tier limits). Waiting %.2f seconds..." % wait_time)
		await get_tree().create_timer(wait_time).timeout
	else:
		_last_request_time = current_time

	print("AiController: AI taking turn. Generating prompt...")
	
	# Extract difficulty from dictionary and remove it so it's not confusing in the JSON dump
	var diff = game_state_dictionary.get("difficulty", "Normal")
	var is_in_jail = game_state_dictionary.get("is_in_jail", false)
	var amount_owed = game_state_dictionary.get("amount_owed_in_bankruptcy", 0)
	
	# 1. Format the current game state into a text prompt
	var prompt_text = "You are an AI playing a Monopoly-like board game.\n"
	prompt_text += "You are playing as " + str(game_state_dictionary.get("player_name", "AI")) + " (Player ID: " + str(game_state_dictionary.get("player_index", -1)) + ").\n"
	prompt_text += "The current difficulty is set to: " + diff + ".\n"
	if game_state_dictionary.has("recent_previous_turn_events"):
		var previous_turn_events = game_state_dictionary.get("recent_previous_turn_events", [])
		if previous_turn_events is Array and previous_turn_events.size() > 0:
			prompt_text += "Use recent_previous_turn_events for short-term context from the last completed turn. Prioritize legal moves from the provided valid_* action lists.\n"
	
	if diff == "Hard":
		prompt_text += "Make very strategic, cutthroat decisions. Aggressively buy properties and try to bankrupt opponents.\n"
	elif diff == "Easy":
		prompt_text += "Play casually. Be less aggressive about buying properties.\n"

	prompt_text += "Here is the current game state:\n"
	prompt_text += JSON.stringify(game_state_dictionary, "\t")
	prompt_text += '\nBased on this game state, choose the best action to take.\n'
	
	if amount_owed > 0:
		prompt_text += 'RULES:\n'
		prompt_text += '- You are facing bankruptcy. You owe: $' + str(amount_owed) + '\n'
		prompt_text += '- Your current balance is $' + str(game_state_dictionary.get("balance", 0)) + '\n'
		prompt_text += '- You MUST choose ONE of the following actions to resolve this debt:\n'
		prompt_text += '  1. "mortgage_property" utilizing "valid_mortgages" list.\n'
		prompt_text += '  2. "sell_upgrade" utilizing "valid_upgrades_to_sell" list.\n'
		if game_state_dictionary.get("balance", 0) >= amount_owed:
			prompt_text += '  3. "pay_debt" because you now have enough cash to satisfy the debt.\n'
		prompt_text += '  4. "declare_bankruptcy" if you cannot mathematically raise enough cash or wish to surrender.\n'
		prompt_text += 'You MUST output ONLY raw JSON formatted exactly like this:\n'
		prompt_text += '{"action": "mortgage_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}\nOR\n{"action": "sell_upgrade", "args": {"space_index": <int>}, "reason": "<short rationale>"}\nOR\n{"action": "declare_bankruptcy", "reason": "<short rationale>"}'
		if game_state_dictionary.get("balance", 0) >= amount_owed:
			prompt_text += '\nOR\n{"action": "pay_debt", "reason": "<short rationale>"}'
		prompt_text += '\nThe "reason" field is required and must be one concise sentence (max 20 words).\n'
		prompt_text += '\nDo not include any explanation or markdown formatting.\n'
	elif is_in_jail and not game_state_dictionary.get("has_rolled_dice", false):
		prompt_text += 'RULES:\n'
		prompt_text += '- You are currently in the Launch Pad (jail).\n'
		prompt_text += '- You MUST choose ONE of the following actions to attempt escape:\n'
		prompt_text += '  1. "roll_dice" to try rolling doubles (free, but costs a turn if you fail).\n'
		prompt_text += '  2. "pay_jail" to pay $50 and escape immediately.\n'
		var has_cards = game_state_dictionary.get("jail_cards", 0) > 0
		if has_cards:
			prompt_text += '  3. "use_jail_card" to use your Get Out card.\n'
		prompt_text += 'You MUST output ONLY raw JSON formatted exactly like this:\n'
		prompt_text += '{"action": "roll_dice", "reason": "<short rationale>"}\nOR\n{"action": "pay_jail", "reason": "<short rationale>"}'
		if has_cards:
			prompt_text += '\nOR\n{"action": "use_jail_card", "reason": "<short rationale>"}'
		prompt_text += '\nThe "reason" field is required and must be one concise sentence (max 20 words).\n'
		prompt_text += '\nDo not include any explanation or markdown formatting.\n'
	else:
		prompt_text += 'RULES:\n'
		prompt_text += '- If "can_buy_property_here" is true, you should consider "buy_property".\n'
		prompt_text += '- You can also do ONE property management action per response if valid options exist in game state:\n'
		prompt_text += '  - "upgrade_property" using "valid_upgrades"\n'
		prompt_text += '  - "sell_upgrade" using "valid_upgrades_to_sell"\n'
		prompt_text += '  - "mortgage_property" using "valid_mortgages"\n'
		prompt_text += '  - "unmortgage_property" using "valid_unmortgages"\n'
		prompt_text += '- You can optionally propose a trade to another player using "propose_trade".\n'
		prompt_text += '- If you do not want to or cannot buy a property, trade, or do property management, you MUST choose "end_turn".\n\n'
		prompt_text += 'You MUST output ONLY raw JSON formatted exactly like this:\n'
		prompt_text += '{"action": "buy_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}'
		prompt_text += '\nOR\n{"action": "propose_trade", "args": {"target_player_index": <int>, "offer_cash": <int>, "request_cash": <int>, "offered_properties": [<int>], "requested_properties": [<int>]}, "reason": "<short rationale>"}'
		prompt_text += '\nOR\n{"action": "upgrade_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}'
		prompt_text += '\nOR\n{"action": "sell_upgrade", "args": {"space_index": <int>}, "reason": "<short rationale>"}'
		prompt_text += '\nOR\n{"action": "mortgage_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}'
		prompt_text += '\nOR\n{"action": "unmortgage_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}'
		prompt_text += '\nOR\n{"action": "end_turn", "reason": "<short rationale>"}'
		prompt_text += '\nThe "reason" field is required and must be one concise sentence (max 20 words).\n'
		prompt_text += '\nDo not include any explanation or markdown formatting.\n'
	# 2. Construct the core content for the API request
	var contents = [
		{
			"role": "user",
			"parts": [{"text": prompt_text}]
		}
	]
	
	# 3. Request body (No Tools dictionary since Gemma does not support them natively)
	var body = {
		"contents": contents
	}
	
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	
	# Send the HTTP request
	_request_in_flight = true
	var error = http_request.request(API_URL + API_KEY, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		_request_in_flight = false
		if error == ERR_BUSY:
			print("AiController: HTTP request is busy. Keeping current in-flight request and skipping duplicate.")
			return
		print("AiController: An error occurred in the HTTP request: ", error)
		AiManager.execute_fallback()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	_request_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		print("AiController: API Network Request failed entirely! Result code: ", result)
		AiManager.execute_fallback()
		return
		
	if response_code != 200:
		print("AiController: API Request failed! HTTP Code: ", response_code)
		print(body.get_string_from_utf8())
		AiManager.execute_fallback()
		return
		
	var response_string = body.get_string_from_utf8()
	print("AiController: Received raw response from Gemini:")
	print(response_string)
	
	var json = JSON.new()
	var error = json.parse(response_string)
	
	if error != OK:
		print("AiController: Failed to parse JSON response")
		if _is_evaluating_trade: _resolve_trade_fallback()
		elif _is_evaluating_auction: _resolve_auction_fallback()
		else: AiManager.execute_fallback()
		return
		
	var response_data = json.data
	
	# Extract the JSON payload from the Model's text response
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		if candidate.has("content") and candidate["content"].has("parts"):
			var parts = candidate["content"]["parts"]
			for part in parts:
				if part.has("text"):
					var raw_text = part["text"]
					# Clean markdown
					raw_text = raw_text.replace("```json", "").replace("```", "").strip_edges()
					
					var inner_json = JSON.new()
					var parse_err = inner_json.parse(raw_text)
					
					if parse_err == OK and typeof(inner_json.data) == TYPE_DICTIONARY:
						var action_dict = inner_json.data
						if action_dict.has("action"):
							var function_name = action_dict["action"]
							var args = action_dict.get("args", {})
							var decision_reason := _extract_reason(action_dict)
							
							print("AiController: Gemma decided to call function: ", function_name, " with args: ", args)
							if decision_reason != "":
								print("AiController: LLM reasoning: ", decision_reason)
							else:
								print("AiController: LLM reasoning: (none provided)")
							
							if _is_evaluating_trade:
								_is_evaluating_trade = false
								if function_name == "accept_trade":
									AiManager.ai_trade_accept.emit()
								else:
									AiManager.ai_trade_reject.emit()
							elif _is_evaluating_auction:
								_is_evaluating_auction = false
								if function_name == "auction_bid":
									var amount = int(args.get("amount", 0))
									AiManager.ai_auction_bid.emit(amount)
								else:
									AiManager.ai_auction_pass.emit()
							else:
								call_deferred("execute_action", function_name, args)
							return
					else:
						print("AiController: Failed to parse inner JSON from text block: ", raw_text)

	if _is_evaluating_trade: _resolve_trade_fallback()
	elif _is_evaluating_auction: _resolve_auction_fallback()
	else:
		print("AiController: No valid action found in the response. Ending turn by default.")
		AiManager.execute_fallback()

func _resolve_auction_fallback():
	_is_evaluating_auction = false
	print("AiController: Failed to evaluate auction with LLM, passing by default.")
	AiManager.ai_auction_pass.emit()

func _resolve_trade_fallback():
	_is_evaluating_trade = false
	print("AiController: Failed to evaluate trade with LLM, rejecting by default.")
	AiManager.ai_trade_reject.emit()

# 7. Route to your game logic
func execute_action(action_name: String, args: Dictionary):
	match action_name:
		"roll_dice":
			print("AiController: Executing action: rolling dice")
			if GameController.get_current_player().is_in_jail:
				AiManager.ai_jail_roll_sequence()
			else:
				AiManager.ai_dice_roll.emit()
				
		"pay_jail":
			print("AiController: Executing action: pay jail")
			AiManager.ai_jail_pay.emit(GameState.current_player_index)
			
		"use_jail_card":
			print("AiController: Executing action: use jail card")
			AiManager.ai_jail_card.emit(GameState.current_player_index)

		"mortgage_property":
			var space_index = int(args.get("space_index", -1))
			print("AiController: Executing action: mortgage property at space index ", space_index)
			AiManager.ai_property_mortgage(space_index)
			if AiManager._fallback_state == "bankruptcy":
				AiManager.continue_llm_bankruptcy()
			else:
				call_deferred("_resume_ai_turn")

		"sell_upgrade":
			var space_index = int(args.get("space_index", -1))
			print("AiController: Executing action: sell upgrade at space index ", space_index)
			AiManager.ai_sells_upgrade(space_index)
			if AiManager._fallback_state == "bankruptcy":
				AiManager.continue_llm_bankruptcy()
			else:
				call_deferred("_resume_ai_turn")

		"upgrade_property":
			var space_index = int(args.get("space_index", -1))
			print("AiController: Executing action: upgrade property at space index ", space_index)
			AiManager.ai_property_upgrade(space_index)
			call_deferred("_resume_ai_turn")

		"unmortgage_property":
			var space_index = int(args.get("space_index", -1))
			print("AiController: Executing action: unmortgage property at space index ", space_index)
			AiManager.ai_property_unmortgage(space_index)
			call_deferred("_resume_ai_turn")

		"pay_debt":
			print("AiController: Executing action: pay debt")
			AiManager.ai_pay_bankruptcy.emit()
			
		"declare_bankruptcy":
			print("AiController: Executing action: declare bankruptcy")
			AiManager.ai_declare_bankruptcy.emit()

		"buy_property":
			var space_index = int(args.get("space_index", -1))
			print("AiController: Executing action: buying property at space index ", space_index)

			var is_valid_index = (space_index >= 0 and space_index < GameState.board.size())
			var space = GameState.board[space_index] if is_valid_index else null
			var can_buy_here = space != null and space is Ownable

			if can_buy_here:
				# Connect before emitting because purchase is resolved synchronously
				if not GameController.action_completed.is_connected(_resume_ai_turn):
					GameController.action_completed.connect(_resume_ai_turn, CONNECT_ONE_SHOT)
				
				AiManager.ai_purchase.emit(space_index)
			else:
				print("AiController: Could not find valid purchasable property at space index: ", space_index)
				AiManager.execute_fallback() # Fallback ending turn gracefully

		"propose_trade":
			var target_idx = int(args.get("target_player_index", -1))
			var offer_cash = int(args.get("offer_cash", 0))
			var request_cash = int(args.get("request_cash", 0))
			var offer_props: Array[int] = []
			var req_props: Array[int] = []

			if args.has("offered_properties"):
				for p in args["offered_properties"]:
					offer_props.append(int(p))
			if args.has("requested_properties"):
				for p in args["requested_properties"]:
					req_props.append(int(p))

			print("AiController: Proposing trade to player ", target_idx, " offering $", offer_cash, " props:", offer_props, " for $", request_cash, " props:", req_props)

			# Connect before emitting because trade may resolve synchronously or async
			if not GameController.trade_finished.is_connected(_resume_ai_turn):
				GameController.trade_finished.connect(_resume_ai_turn, CONNECT_ONE_SHOT)

			AiManager.ai_trade_create.emit(GameState.current_player_index, target_idx, offer_cash, request_cash, offer_props, req_props)

		"end_turn":
			print("AiController: Executing action: ending turn")
			AiManager.ai_turn_end()
			
		_:
			print("AiController: Unknown action received: ", action_name)
			# Fallback
			AiManager.execute_fallback()

func _resume_ai_turn() -> void:
	print("AiController: Action completed, resuming LLM AI turn...")
	AiManager.ai_turn_mid()

var _is_evaluating_trade: bool = false
var _is_evaluating_auction: bool = false
var _pending_trade_offer: Dictionary = {}
var _pending_auction_data: Dictionary = {}

func evaluate_trade(trade_offer: Dictionary, state_dict: Dictionary):
	_is_evaluating_trade = true
	_pending_trade_offer = trade_offer
	print("AiController: Evaluating trade offer...")

	if _request_in_flight:
		print("AiController: Request already in flight during trade evaluation. Rejecting trade by fallback.")
		_resolve_trade_fallback()
		return

	# Rate limiter pacing
	var current_time = Time.get_ticks_msec()
	var elapsed = current_time - _last_request_time

	if _last_request_time > 0 and elapsed < MIN_REQUEST_INTERVAL_MSEC:
		var wait_time = (MIN_REQUEST_INTERVAL_MSEC - elapsed) / 1000.0
		print("AiController: Pacing API requests (free tier limits). Waiting ", "%.2f" % wait_time, " seconds...")
		await get_tree().create_timer(wait_time).timeout

	# Recalculate
	current_time = Time.get_ticks_msec()
	_last_request_time = current_time

	var prompt_text = "You are playing a Monopoly-style board game and received a trade offer.\n"
	prompt_text += "You are playing as " + str(state_dict.get("player_name", "AI")) + " (Player ID: " + str(state_dict.get("player_index", -1)) + ").\n"
	prompt_text += "Here is the current game state:\n"
	prompt_text += JSON.stringify(state_dict, "\t")
	prompt_text += "\nTrade details:\n"
	prompt_text += JSON.stringify(trade_offer, "\t")
	prompt_text += "\nDO you accept this trade? You MUST output ONLY raw JSON formatted exactly like this:\n"
	prompt_text += '{"action": "accept_trade", "reason": "<short rationale>"}\nOR\n{"action": "reject_trade", "reason": "<short rationale>"}\n'
	prompt_text += 'The "reason" field is required and must be one concise sentence (max 20 words).\n'
	prompt_text += 'Do not include any explanation or markdown formatting.\n'
	
	var contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
	var body = {"contents": contents}
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	
	_request_in_flight = true
	var error = http_request.request(API_URL + API_KEY, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		_request_in_flight = false
		print("AiController: HTTP request error during trade evaluation: ", error)
		_resolve_trade_fallback()

func evaluate_auction(state_dict: Dictionary, auction_data: Dictionary):
	_is_evaluating_auction = true
	_pending_auction_data = auction_data
	print("AiController: Evaluating auction...")

	if _request_in_flight:
		print("AiController: Request already in flight during auction evaluation. Passing by fallback.")
		_resolve_auction_fallback()
		return

	# Rate limiter pacing
	var current_time = Time.get_ticks_msec()
	var elapsed = current_time - _last_request_time

	if _last_request_time > 0 and elapsed < MIN_REQUEST_INTERVAL_MSEC:
		var wait_time = (MIN_REQUEST_INTERVAL_MSEC - elapsed) / 1000.0
		print("AiController: Pacing API requests (free tier limits). Waiting ", "%.2f" % wait_time, " seconds...")
		await get_tree().create_timer(wait_time).timeout

	# Recalculate
	current_time = Time.get_ticks_msec()
	_last_request_time = current_time

	var prompt_text = "You are playing a Monopoly-style board game and are participating in an auction.\n"
	prompt_text += "You are playing as " + str(state_dict.get("player_name", "AI")) + " (Player ID: " + str(state_dict.get("player_index", -1)) + ").\n"
	prompt_text += "Here is the current game state:\n"
	prompt_text += JSON.stringify(state_dict, "\t")
	prompt_text += "\nAuction details:\n"
	prompt_text += JSON.stringify(auction_data, "\t")
	prompt_text += "\nDo you want to bid on this property or pass? Your bid MUST be strictly greater than highest_bid and less than or equal to your current balance.\n"
	prompt_text += "If you do not want to bid, or cannot afford to bid higher than highest_bid, choose pass.\n"
	prompt_text += "You MUST output ONLY raw JSON formatted exactly like this:\n"
	prompt_text += '{"action": "auction_bid", "args": {"amount": <integer_amount>}, "reason": "<short rationale>"}\nOR\n{"action": "auction_pass", "reason": "<short rationale>"}\n'
	prompt_text += 'The "reason" field is required and must be one concise sentence (max 20 words).\n'
	prompt_text += 'Do not include any explanation or markdown formatting.\n'

	var contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
	var body = {"contents": contents}
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	_request_in_flight = true
	var error = http_request.request(API_URL + API_KEY, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		_request_in_flight = false
		print("AiController: HTTP request error during auction evaluation: ", error)
		_resolve_auction_fallback()

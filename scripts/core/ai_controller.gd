extends Node

const API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemma-3-27b-it:generateContent?key="
var API_KEY = ""

var http_request: HTTPRequest
var _request_in_flight: bool = false

var _last_request_time: int = 0
const MIN_REQUEST_INTERVAL_MSEC: int = 2100 # ~2.1 seconds to stay under 30 requests/minute
const DEFAULT_RATE_LIMIT_RETRY_SECONDS: float = 60.0
var _rate_limit_until_msec: int = 0

var _queued_follow_up_action_name: String = ""
var _queued_follow_up_action_args: Dictionary = {}
var _queued_follow_up_reason: String = ""

func _clear_queued_follow_up_action() -> void:
	_queued_follow_up_action_name = ""
	_queued_follow_up_action_args = {}
	_queued_follow_up_reason = ""

func _queue_follow_up_action(action_dict: Dictionary) -> void:
	_clear_queued_follow_up_action()

	if not action_dict.has("next_action"):
		return

	var next_action = action_dict.get("next_action", {})
	if typeof(next_action) != TYPE_DICTIONARY:
		return

	var next_action_name := str(next_action.get("action", "")).strip_edges()
	if next_action_name == "":
		return

	var next_args = next_action.get("args", {})
	if typeof(next_args) != TYPE_DICTIONARY:
		next_args = {}

	_queued_follow_up_action_name = next_action_name
	_queued_follow_up_action_args = next_args
	_queued_follow_up_reason = _extract_reason(next_action)

func _execute_queued_follow_up_action() -> bool:
	if _queued_follow_up_action_name == "":
		return false

	var next_action_name := _queued_follow_up_action_name
	var next_args := _queued_follow_up_action_args.duplicate(true)
	var next_reason := _queued_follow_up_reason
	_clear_queued_follow_up_action()

	if next_reason != "":
		print("AiController: LLM follow-up reasoning: ", next_reason)
	print("AiController: Executing queued follow-up action: ", next_action_name, " with args: ", next_args)
	call_deferred("execute_action", next_action_name, next_args)
	return true

func _continue_after_action() -> void:
	if _execute_queued_follow_up_action():
		return
	_resume_ai_turn()

func _on_buy_action_completed() -> void:
	if _execute_queued_follow_up_action():
		return

	# Optimization: when the model buys but does not provide a follow-up,
	# end the turn immediately to avoid a second LLM call for "end_turn".
	print("AiController: No queued follow-up after purchase. Auto-ending turn to save LLM call.")
	AiManager.ai_turn_end()

func _on_trade_finished_continue() -> void:
	# Trade completion already resumes via AiManager.check_trade_completion().
	# Only execute an explicit queued follow-up action here to avoid duplicate turn resumes.
	if _execute_queued_follow_up_action():
		return
	_clear_queued_follow_up_action()

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

func _action_space_is_valid(space_index: int, valid_space_indexes: Array) -> bool:
	for raw_idx in valid_space_indexes:
		if int(raw_idx) == space_index:
			return true
	return false


func _extract_retry_seconds_from_error_body(response_string: String) -> float:
	var retry_seconds := DEFAULT_RATE_LIMIT_RETRY_SECONDS
	var parsed := JSON.new()
	if parsed.parse(response_string) != OK:
		return retry_seconds

	if typeof(parsed.data) != TYPE_DICTIONARY:
		return retry_seconds

	var root: Dictionary = parsed.data
	if not root.has("error"):
		return retry_seconds

	var err_obj = root.get("error", {})
	if typeof(err_obj) != TYPE_DICTIONARY:
		return retry_seconds

	var err: Dictionary = err_obj
	var details = err.get("details", [])
	if details is Array:
		for raw_detail in details:
			if typeof(raw_detail) != TYPE_DICTIONARY:
				continue
			var detail: Dictionary = raw_detail
			if detail.has("retryDelay"):
				var retry_raw := str(detail.get("retryDelay", "")).strip_edges()
				if retry_raw.ends_with("s"):
					retry_raw = retry_raw.substr(0, retry_raw.length() - 1)
				var parsed_seconds := float(retry_raw)
				if parsed_seconds > 0.0:
					retry_seconds = parsed_seconds
					break

	return retry_seconds


func _set_rate_limit_cooldown(response_string: String) -> void:
	var retry_seconds := _extract_retry_seconds_from_error_body(response_string)
	if retry_seconds <= 0.0:
		retry_seconds = DEFAULT_RATE_LIMIT_RETRY_SECONDS

	_rate_limit_until_msec = Time.get_ticks_msec() + int(ceil(retry_seconds * 1000.0))
	AiManager.set_llm_temporary_bypass(true)
	print("AiController: Hit rate limit. Temporarily bypassing LLM for %.1f seconds." % retry_seconds)


func _is_rate_limit_active() -> bool:
	if _rate_limit_until_msec <= 0:
		return false

	if Time.get_ticks_msec() >= _rate_limit_until_msec:
		_rate_limit_until_msec = 0
		AiManager.set_llm_temporary_bypass(false)
		print("AiController: Rate-limit cooldown ended. Resuming LLM decisions.")
		return false

	return true


func _accumulate_group_counts_for_prompt(group_counts: Dictionary, player_name: String, properties) -> void:
	if not (properties is Array):
		return

	for raw_prop in properties:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue

		var prop: Dictionary = raw_prop
		var group_name := str(prop.get("group_name", "None"))
		var monopoly_equivalent := str(prop.get("monopoly_equivalent", "none"))
		var group_size := int(prop.get("group_size", 0))
		if group_name == "None" or monopoly_equivalent == "none" or group_size <= 0:
			continue

		var group_key := group_name + "|" + monopoly_equivalent
		if not group_counts.has(group_key):
			group_counts[group_key] = {
				"group_name": group_name,
				"monopoly_equivalent": monopoly_equivalent,
				"group_size": group_size,
				"by_player": {}
			}

		var entry: Dictionary = group_counts[group_key]
		var by_player: Dictionary = entry.get("by_player", {})
		by_player[player_name] = int(by_player.get(player_name, 0)) + 1
		entry["by_player"] = by_player
		group_counts[group_key] = entry


func _build_group_snapshot_prompt_text(game_state_dictionary: Dictionary) -> String:
	var group_counts: Dictionary = {}
	var my_name := str(game_state_dictionary.get("player_name", "AI"))
	_accumulate_group_counts_for_prompt(group_counts, my_name, game_state_dictionary.get("owned_properties", []))

	var opponents = game_state_dictionary.get("opponents", [])
	if opponents is Array:
		for raw_opp in opponents:
			if typeof(raw_opp) != TYPE_DICTIONARY:
				continue
			var opp: Dictionary = raw_opp
			var opp_name := str(opp.get("name", "Opponent"))
			_accumulate_group_counts_for_prompt(group_counts, opp_name, opp.get("owned_properties", []))

	if group_counts.is_empty():
		return "Group ownership snapshot: no ownable-group ownership data available."

	var lines: Array[String] = []
	var group_keys: Array = group_counts.keys()
	group_keys.sort()
	for raw_key in group_keys:
		var group_key := str(raw_key)
		var entry: Dictionary = group_counts[group_key]
		var group_name := str(entry.get("group_name", "Unknown"))
		var monopoly_equivalent := str(entry.get("monopoly_equivalent", "none"))
		var group_size := int(entry.get("group_size", 0))
		var by_player: Dictionary = entry.get("by_player", {})

		var player_parts: Array[String] = []
		var player_names: Array = by_player.keys()
		player_names.sort()
		for raw_name in player_names:
			var pname := str(raw_name)
			player_parts.append(pname + "=" + str(int(by_player[pname])) + "/" + str(group_size))

		lines.append("- " + group_name + " (" + monopoly_equivalent + ", size " + str(group_size) + "): " + ", ".join(player_parts))

	return "Group ownership snapshot (current):\n" + "\n".join(lines)


func _ready():
	_load_env()
	# Create and configure the HTTPRequest node dynamically
	http_request = HTTPRequest.new()
	http_request.timeout = 40.0
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
	_clear_queued_follow_up_action()

	if _is_rate_limit_active():
		AiManager.execute_temporary_fallback()
		return

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
		prompt_text += '\nOptional: include "next_action" as a second step ONLY if it does not require new board info or player input.\n'
		prompt_text += 'Example: {"action": "mortgage_property", "args": {"space_index": 5}, "reason": "...", "next_action": {"action": "pay_debt", "reason": "..."}}\n'
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
		prompt_text += '\nOptional: include "next_action" as a second step ONLY if it does not require new board info or player input.\n'
		prompt_text += '\nThe "reason" field is required and must be one concise sentence (max 20 words).\n'
		prompt_text += '\nDo not include any explanation or markdown formatting.\n'
	else:
		var can_buy_here := bool(game_state_dictionary.get("can_buy_property_here", false))
		var valid_upgrades = game_state_dictionary.get("valid_upgrades", [])
		var valid_upgrades_to_sell = game_state_dictionary.get("valid_upgrades_to_sell", [])
		var valid_mortgages = game_state_dictionary.get("valid_mortgages", [])
		var valid_unmortgages = game_state_dictionary.get("valid_unmortgages", [])
		var trade_targets = game_state_dictionary.get("trade_targets", [])
		var can_propose_trade: bool = bool(game_state_dictionary.get("can_propose_trade", false)) and (trade_targets is Array) and trade_targets.size() > 0

		var has_upgrade_options: bool = (valid_upgrades is Array) and valid_upgrades.size() > 0
		var has_sell_upgrade_options: bool = (valid_upgrades_to_sell is Array) and valid_upgrades_to_sell.size() > 0
		var has_mortgage_options: bool = (valid_mortgages is Array) and valid_mortgages.size() > 0
		var has_unmortgage_options: bool = (valid_unmortgages is Array) and valid_unmortgages.size() > 0

		var actionable_count := 0
		prompt_text += 'RULES:\n'
		prompt_text += '- You MUST choose exactly ONE action from the allowed list below.\n'
		if can_buy_here:
			actionable_count += 1
			prompt_text += '- Allowed: "buy_property" at current_space_index (only if it is purchasable and unowned).\n'
		if has_upgrade_options:
			actionable_count += 1
			prompt_text += '- Allowed: "upgrade_property" using an index from "valid_upgrades" only.\n'
		if has_sell_upgrade_options:
			actionable_count += 1
			prompt_text += '- Allowed: "sell_upgrade" using an index from "valid_upgrades_to_sell" only.\n'
		if has_mortgage_options:
			actionable_count += 1
			prompt_text += '- Allowed: "mortgage_property" using an index from "valid_mortgages" only.\n'
		if has_unmortgage_options:
			actionable_count += 1
			prompt_text += '- Allowed: "unmortgage_property" using an index from "valid_unmortgages" only.\n'
		if can_propose_trade:
			actionable_count += 1
			prompt_text += _build_group_snapshot_prompt_text(game_state_dictionary) + "\n"
			prompt_text += '- Allowed: "propose_trade" only with a target_player_index listed in "trade_targets".\n'
			prompt_text += '- IMPORTANT payload meaning: offered_properties/offer_cash are assets YOU give away; requested_properties/request_cash are assets YOU receive.\n'
			prompt_text += '- When proposing a trade, include at least one non-zero cash flow or one property in offered/requested lists.\n'
			prompt_text += '- Prefer proposing trade when it improves your long-term position or completes/blocks a group.\n'
			prompt_text += '- Avoid same-group swaps unless they increase your net group ownership.\n'
			prompt_text += '- Be cautious about trades that complete an opponent group without clear compensation.\n'
			prompt_text += '- Use the group ownership snapshot above to verify before/after group counts for both players.\n'

		if actionable_count == 0:
			prompt_text += '- No buy/trade/property-management actions are currently available.\n'

		prompt_text += '- Do not output actions that are not explicitly allowed above.\n\n'
		prompt_text += 'You MUST output ONLY raw JSON formatted exactly like this:\n'

		var output_examples: Array[String] = []
		if can_buy_here:
			output_examples.append('{"action": "buy_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}')
		if can_propose_trade:
			output_examples.append('{"action": "propose_trade", "args": {"target_player_index": <int>, "offer_cash": <int>, "request_cash": <int>, "offered_properties": [<int>], "requested_properties": [<int>]}, "reason": "<short rationale>"}')
		if has_upgrade_options:
			output_examples.append('{"action": "upgrade_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}')
		if has_sell_upgrade_options:
			output_examples.append('{"action": "sell_upgrade", "args": {"space_index": <int>}, "reason": "<short rationale>"}')
		if has_mortgage_options:
			output_examples.append('{"action": "mortgage_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}')
		if has_unmortgage_options:
			output_examples.append('{"action": "unmortgage_property", "args": {"space_index": <int>}, "reason": "<short rationale>"}')

		output_examples.append('{"action": "end_turn", "reason": "<short rationale>"}')

		for i in range(output_examples.size()):
			if i > 0:
				prompt_text += '\nOR\n'
			prompt_text += output_examples[i]

		prompt_text += '\nOptional: include "next_action" as a second step ONLY if it does not require new board info or player input.\n'
		if can_buy_here:
			prompt_text += 'Example: {"action": "buy_property", "args": {"space_index": <int>}, "reason": "...", "next_action": {"action": "end_turn", "reason": "..."}}\n'
		elif can_propose_trade:
			prompt_text += 'Example: {"action": "propose_trade", "args": {"target_player_index": 2, "offer_cash": 100, "request_cash": 0, "offered_properties": [], "requested_properties": [14]}, "reason": "I pay cash to receive a property that improves my group position.", "next_action": {"action": "end_turn", "reason": "..."}}\n'
		else:
			prompt_text += 'Example: {"action": "end_turn", "reason": "..."}\n'
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
		var error_body = body.get_string_from_utf8()
		print(error_body)
		if response_code == 429:
			_set_rate_limit_cooldown(error_body)
			if _is_evaluating_trade:
				_resolve_trade_fallback()
			elif _is_evaluating_auction:
				_resolve_auction_fallback()
			else:
				AiManager.execute_temporary_fallback()
			return
		AiManager.execute_fallback()
		return
		
	var response_string = body.get_string_from_utf8()
	
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
							_queue_follow_up_action(action_dict)
							
							print("AiController: Gemma decided to call function: ", function_name, " with args: ", args)
							if decision_reason != "":
								print("AiController: LLM reasoning: ", decision_reason)
							else:
								print("AiController: LLM reasoning: (none provided)")
							if _queued_follow_up_action_name != "":
								print("AiController: Queued follow-up action: ", _queued_follow_up_action_name)
							
							if _is_evaluating_trade:
								_is_evaluating_trade = false
								_clear_queued_follow_up_action()
								var normalized_trade_action := str(function_name).to_lower().strip_edges()
								if normalized_trade_action == "accept_trade" or normalized_trade_action == "accept":
									AiManager.ai_trade_accept.emit()
								elif normalized_trade_action == "reject_trade" or normalized_trade_action == "reject":
									AiManager.ai_trade_reject.emit()
								else:
									print("AiController: Unexpected trade action '", function_name, "'. Rejecting trade by fallback.")
									_resolve_trade_fallback()
							elif _is_evaluating_auction:
								_is_evaluating_auction = false
								_clear_queued_follow_up_action()
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
	_clear_queued_follow_up_action()
	_is_evaluating_auction = false
	print("AiController: Failed to evaluate auction with LLM, passing by default.")
	AiManager.ai_auction_pass.emit()

func _resolve_trade_fallback():
	_clear_queued_follow_up_action()
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
			if not _action_space_is_valid(space_index, AiManager.validMortgages):
				print("AiController: Invalid mortgage_property space index for current state: ", space_index)
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return
			print("AiController: Executing action: mortgage property at space index ", space_index)
			AiManager.ai_property_mortgage(space_index)
			if _queued_follow_up_action_name != "":
				call_deferred("_continue_after_action")
			elif AiManager._fallback_state == "bankruptcy":
				AiManager.continue_llm_bankruptcy()
			else:
				call_deferred("_resume_ai_turn")

		"sell_upgrade":
			var space_index = int(args.get("space_index", -1))
			if not _action_space_is_valid(space_index, AiManager.validDowngrades):
				print("AiController: Invalid sell_upgrade space index for current state: ", space_index)
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return
			print("AiController: Executing action: sell upgrade at space index ", space_index)
			AiManager.ai_sells_upgrade(space_index)
			if _queued_follow_up_action_name != "":
				call_deferred("_continue_after_action")
			elif AiManager._fallback_state == "bankruptcy":
				AiManager.continue_llm_bankruptcy()
			else:
				call_deferred("_resume_ai_turn")

		"upgrade_property":
			var space_index = int(args.get("space_index", -1))
			if not _action_space_is_valid(space_index, AiManager.validUpgrades):
				print("AiController: Invalid upgrade_property space index for current state: ", space_index)
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return
			print("AiController: Executing action: upgrade property at space index ", space_index)
			AiManager.ai_property_upgrade(space_index)
			call_deferred("_continue_after_action")

		"unmortgage_property":
			var space_index = int(args.get("space_index", -1))
			if not _action_space_is_valid(space_index, AiManager.validUnmortgages):
				print("AiController: Invalid unmortgage_property space index for current state: ", space_index)
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return
			print("AiController: Executing action: unmortgage property at space index ", space_index)
			AiManager.ai_property_unmortgage(space_index)
			call_deferred("_continue_after_action")

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
				if not GameController.action_completed.is_connected(_on_buy_action_completed):
					GameController.action_completed.connect(_on_buy_action_completed, CONNECT_ONE_SHOT)
				
				AiManager.ai_purchase.emit(space_index)
			else:
				print("AiController: Could not find valid purchasable property at space index: ", space_index)
				_clear_queued_follow_up_action()
				AiManager.execute_fallback() # Fallback ending turn gracefully

		"propose_trade":
			var target_idx = int(args.get("target_player_index", -1))
			var offer_cash: int = int(args.get("offer_cash", 0))
			var request_cash: int = int(args.get("request_cash", 0))
			var offer_props: Array[int] = []
			var req_props: Array[int] = []

			if args.has("offered_properties"):
				for p in args["offered_properties"]:
					offer_props.append(int(p))
			if args.has("requested_properties"):
				for p in args["requested_properties"]:
					req_props.append(int(p))

			var current_player_idx := GameState.current_player_index
			if target_idx < 0 or target_idx >= GameState.players.size() or target_idx == current_player_idx:
				print("AiController: Invalid propose_trade target player index: ", target_idx)
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return

			if offer_cash < 0 or request_cash < 0:
				print("AiController: Invalid propose_trade cash values. offer_cash=", offer_cash, " request_cash=", request_cash)
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return

			if offer_cash == 0 and request_cash == 0 and offer_props.is_empty() and req_props.is_empty():
				print("AiController: Invalid propose_trade payload with no exchanged assets.")
				_clear_queued_follow_up_action()
				call_deferred("_resume_ai_turn")
				return

			print("AiController: Proposing trade to player ", target_idx, " offering $", offer_cash, " props:", offer_props, " for $", request_cash, " props:", req_props)

			# Connect before emitting because trade may resolve synchronously or async
			if not GameController.trade_finished.is_connected(_on_trade_finished_continue):
				GameController.trade_finished.connect(_on_trade_finished_continue, CONNECT_ONE_SHOT)

			AiManager.ai_trade_create.emit(GameState.current_player_index, target_idx, offer_cash, request_cash, offer_props, req_props)

		"end_turn":
			var current_player = GameController.get_current_player()
			if current_player != null and current_player.is_in_jail and not current_player.has_rolled:
				print("AiController: Invalid end_turn while jailed before escape attempt. Coercing to jail action.")
				_clear_queued_follow_up_action()
				if current_player.go_for_launch_cards > 0:
					AiManager.ai_jail_card.emit(GameState.current_player_index)
				elif current_player.balance >= 50:
					AiManager.ai_jail_pay.emit(GameState.current_player_index)
				else:
					AiManager.ai_jail_roll_sequence()
				return

			print("AiController: Executing action: ending turn")
			_clear_queued_follow_up_action()
			AiManager.ai_turn_end()
			
		_:
			print("AiController: Unknown action received: ", action_name)
			_clear_queued_follow_up_action()
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
	_clear_queued_follow_up_action()
	_is_evaluating_trade = true
	_pending_trade_offer = trade_offer.duplicate(true)
	print("AiController: Evaluating trade offer...")

	if _is_rate_limit_active():
		_resolve_trade_fallback()
		return

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

	var offered_value := int(trade_offer.get("offered_total_ai_estimated_value", trade_offer.get("offered_total_board_value", trade_offer.get("offer_cash", 0))))
	var requested_value := int(trade_offer.get("requested_total_ai_estimated_value", trade_offer.get("requested_total_board_value", trade_offer.get("request_cash", 0))))
	var net_value := offered_value - requested_value

	var prompt_text = "You are playing a Monopoly-style board game and received a trade offer.\n"
	prompt_text += "You are playing as " + str(state_dict.get("player_name", "AI")) + " (Player ID: " + str(state_dict.get("player_index", -1)) + ").\n"
	prompt_text += "Here is the current game state:\n"
	prompt_text += JSON.stringify(state_dict, "\t")
	prompt_text += "\nTrade details:\n"
	prompt_text += JSON.stringify(trade_offer, "\t")
	prompt_text += "\nInterpretation: offering_player gives offered_* assets TO target_player (you), and target_player gives requested_* assets back.\n"
	prompt_text += "Value summary from your perspective (AI estimate): receive=" + str(offered_value) + ", give=" + str(requested_value) + ", net=" + str(net_value) + ".\n"
	prompt_text += "Use trade_direction_note only as a hint; do NOT follow it blindly.\n"
	prompt_text += "Cross-check the raw fields (offering_player, target_player, offer_cash, request_cash, offered_spaces, requested_spaces) before deciding.\n"
	prompt_text += "If trade_direction_note conflicts with raw fields or values, trust raw fields and treat the offer as risky.\n"
	prompt_text += "Use evaluation_summary and group_trade_impacts to assess this offer.\n"
	prompt_text += "Consider cash liquidity after trade, mortgaged/upgraded assets, and whether either player completes or breaks a group.\n"
	prompt_text += "Make your best strategic decision from this perspective only (you are target_player).\n"
	prompt_text += "Do you accept this trade? You MUST output ONLY raw JSON formatted exactly like this:\n"
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
	_clear_queued_follow_up_action()
	_is_evaluating_auction = true
	_pending_auction_data = auction_data
	print("AiController: Evaluating auction...")

	if _is_rate_limit_active():
		_resolve_auction_fallback()
		return

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

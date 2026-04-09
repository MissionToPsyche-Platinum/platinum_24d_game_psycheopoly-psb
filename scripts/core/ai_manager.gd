extends Node

# Signals called in this class 
signal ai_dice_roll()
signal ai_auction_start(space_num: int)
signal ai_draw_card(space_num: int)
signal ai_pay(space_num: int)
signal ai_move(space_num: int)
signal ai_purchase(space_num: int)

signal ai_auction_pass()
signal ai_auction_bid(amount: int)

signal ai_trade_reject()
signal ai_trade_accept()

signal ai_trade_create(offering_player: int, receiving_player: int, offering_cash: int, receiving_cash: int, offering_properties: Array[int], receiving_properties: Array[int])

signal ai_jail_pay(current_player: int)
signal ai_jail_card(current_player: int)
signal ai_jail_roll(current_player: int)


signal ai_declare_bankruptcy()
signal ai_pay_bankruptcy()

#Signals called by other classes
signal ai_auction_turn(player_index: int, highest_bid: int, space_num: int)
signal ai_trade_turn(trade_offer: Dictionary)
signal ai_doubles_jail()
signal ai_bankruptcy(amount: int)
signal ai_leaves_jail()

var ai_is_mid_turn = false
var rng

var _auction_target_space_num: int = -1
var _auction_max_bid_by_player: Dictionary = {}
var _last_trade_decision_player_index: int = -1

var validUpgrades: Array[int] = [] # holds the space numbers of upgradable properties
var validDowngrades: Array[int] = [] # holds the space numbers of downgradable properties
var validMortgages: Array[int] = [] # holds the space numbers of mortgagable properties
var validUnmortgages: Array[int] = [] # holds the space numbers of mortgagable properties

func _initialize_property_multipliers(player) -> void:
	if not (player is AiPlayerState):
		return

	for i in range(GameState.board.size()):
		if GameState.board[i] is Ownable:
			player.base_property_value_multipliers.append(1.1 + 0.4 * randf()) # TODO: set this based on difficulty, with a bit of variance between different properties/sets
		else:
			player.base_property_value_multipliers.append(0)
		player.current_property_value_multipliers.append(player.base_property_value_multipliers[i])
		player.master_property_value_multiplier = 1.2


func _update_property_multipliers(player) -> void:
	if not (player is AiPlayerState):
		return

	var totalOwnedSpaces = 0 # total number of spaces owned by players across the board
	var AIOwnedSpaces = 0 # total number of spaces owned by the AI
	var upgradableSpaces = 0 # total number of spaces able to be upgraded by the AI

	for i in range(GameState.board.size()):
		var multiplier = 0
		var space = GameState.board[i]
		if space is Ownable:
			multiplier = player.base_property_value_multipliers[i] 
			if (space._is_owned):
				totalOwnedSpaces += 1
				if (space._player_owner == player.player_id):
					AIOwnedSpaces += 1
					multiplier *= 1.2 # Ai values holding on to spaces it already has

			if space is PropertySpace:
				if (GameController._check_if_upgrade_is_valid(space, player.player_id)):
					upgradableSpaces += 1
				var propertySet = GameController._get_property_set(space)
				var ownedPropertiesInSet = 0; # amount of properties owned by the AI
				var otherPlayerOwnedProperties = 0 # properties in set owned by players other than the AI
				for j in range(propertySet.size()):
					if (propertySet[j].is_owned):
						if(propertySet[j]._player_owner == player.player_id):
							ownedPropertiesInSet += 1
						else:
							if (propertySet[j] != space): # Don't count the current space being owned against it
								otherPlayerOwnedProperties += 1 
				if (propertySet.size() == ownedPropertiesInSet):
					multiplier *= 4
				elif (propertySet.size() - ownedPropertiesInSet == 1):
					multiplier *= 1.7
				elif (propertySet.size() - ownedPropertiesInSet == 2 && propertySet.size() == 3):
					multiplier *= 1.3
				if (otherPlayerOwnedProperties == 1):
					multiplier *= 0.8
				elif (otherPlayerOwnedProperties == 2):
					multiplier *= 0.6
		player.current_property_value_multipliers[i] = multiplier
	
	var master_multiplier = 0.8
	# update master multiplier
	if (player.balance >= 500): # Ai is more likely to buy properties when it has a lot of money
		master_multiplier += (player.balance - 500) / 2500.0

	if (AIOwnedSpaces < totalOwnedSpaces / float(GameState.players.size())):
		var difference = totalOwnedSpaces / float(GameState.players.size()) - AIOwnedSpaces
		master_multiplier += difference / 10
	
	# If AI has any spaces that can be upgraded, then AI should propritize upgrading them
	if (upgradableSpaces > 0):
		master_multiplier *= 0.5
	
	player.master_property_value_multiplier = master_multiplier
	
	#for i in range(GameState.board.size()):
	#	print(GameState.board[i]._space_name, ": ", _calculate_AI_property_value(player, i))
	

func _calculate_AI_property_value(player, space_num: int) -> float:
	if not (player is AiPlayerState):
		return 0

	if (GameState.board[space_num] is Ownable):
		return player.current_property_value_multipliers[space_num] * player.master_property_value_multiplier * GameState.board[space_num]._initial_price
	else:
		return 0
	
	
var active_ai_player_index: int = -1

#Right now visibly the AI is just going light speed on board
#and hard to know what is happening without looking at turn log
#This should help a little - some delays between actions.
const AI_PACING := {
	"pre_roll": 0.35,
	"post_roll": 0.75,
	"after_landing": 0.60,
	"card_draw": 0.90,
	"before_purchase": 0.65,
	"before_trade": 0.85,
	"after_trade": 0.75,
	"end_turn": 0.35
}

var ai_pacing_enabled: bool = true
var ai_pacing_scale: float = 1.0

func _ai_pause(key: String) -> void:
	if not ai_pacing_enabled:
		return
	
	var duration := float(AI_PACING.get(key, 0.0)) * ai_pacing_scale
	if duration <= 0.0:
		return
	
	await get_tree().create_timer(duration, true).timeout

var ai_controller_script = preload("res://scripts/core/ai_controller.gd")
var _llm_ai_controller: Node = null

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	_llm_ai_controller = Node.new()
	_llm_ai_controller.set_script(ai_controller_script)
	_llm_ai_controller.name = "AiController"
	add_child(_llm_ai_controller)
	
	GameController.turn_setup_complete.connect(check_if_ai_turn)
	ai_auction_turn.connect(ai_auction_decision)
	ai_trade_turn.connect(ai_trade_decision)
	
	ChanceCardMgr.card_resolved.connect(ai_card_resolve)
	ai_doubles_jail.connect(handle_doubles_jail)
	ai_bankruptcy.connect(ai_bankruptcy_resolve)
	
	GameController.trade_finished.connect(check_trade_completion)
	ai_leaves_jail.connect(ai_turn_start)
	if not AuctionMgr.auction_ended.is_connected(_on_auction_ended_reset_targets):
		AuctionMgr.auction_ended.connect(_on_auction_ended_reset_targets)

# Emits the ai turn start signal if the next player is AI 
# Fallback state vars
var _fallback_state: String = ""
var _last_space_num: int = -1
var _bankruptcy_amount: int = 0

func execute_fallback() -> void:
	print("AiManager: LLM failed or disabled. Permanently falling back to decision tree from state: ", _fallback_state)
	
	# Permanently disable LLM for the remainder of the match to prevent spamming broken API
	GameState.use_llm_ai = false
	
	match _fallback_state:
		"bankruptcy":
			ai_bankruptcy_resolve(_bankruptcy_amount)
		"jail":
			ai_jail_decision()
		"start":
			ai_turn_start()
		"mid":
			ai_turn_mid()
		"lands":
			ai_lands_on_space(_last_space_num)
		"unowned":
			ai_lands_on_unowned_property(_last_space_num)
		_:
			print("AiManager: Unknown fallback state. Ending turn.")
			ai_turn_end()

func check_if_ai_turn(player_index) -> void:
	if GameState.players[player_index].player_is_ai == true:
		ai_turn_start()

func _get_recent_previous_turn_events(max_entries: int = 8) -> Array[String]:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return []

	if not current_scene.has_node("TurnLogLayer/TurnLogPanel"):
		return []

	var panel = current_scene.get_node("TurnLogLayer/TurnLogPanel")
	if panel == null or not panel.has_method("get_previous_turn_entries"):
		return []

	var previous_turn_entries = panel.call("get_previous_turn_entries", max_entries)
	if previous_turn_entries is Array:
		return previous_turn_entries

	return []


func _on_auction_ended_reset_targets(_winner_index: int, _winning_bid: int, _space_num: int, _property_ref) -> void:
	_auction_target_space_num = -1
	_auction_max_bid_by_player.clear()


func _ensure_ai_valuation_model(player) -> void:
	if not (player is AiPlayerState):
		return

	if player.base_property_value_multipliers.is_empty():
		_initialize_property_multipliers(player)
	else:
		_update_property_multipliers(player)


func _get_monopoly_equivalent(space) -> String:
	if space is PropertySpace:
		return "color_group"
	if space is InstrumentSpace:
		return "railroad_like"
	if space is PlanetSpace:
		return "utility_like"
	if space is Ownable:
		return "ownable"
	return "none"


func _get_property_group_members(space_num: int, space) -> Array[int]:
	var members: Array[int] = []
	if space is PropertySpace:
		var property_set = GameController._get_property_set(space)
		for set_space in property_set:
			for i in range(GameState.board.size()):
				if GameState.board[i] == set_space:
					members.append(i)
					break
		return members

	if space is InstrumentSpace:
		for i in range(GameState.board.size()):
			if GameState.board[i] is InstrumentSpace:
				members.append(i)
		return members

	if space is PlanetSpace:
		for i in range(GameState.board.size()):
			if GameState.board[i] is PlanetSpace:
				members.append(i)
		return members

	if space is Ownable:
		members.append(space_num)

	return members


func _get_property_group_name(space) -> String:
	if space is PropertySpace:
		return str(space._property_set)
	if space is InstrumentSpace:
		return "Instruments"
	if space is PlanetSpace:
		return "Planets"
	if space is Ownable:
		return "Ownables"
	return "None"


func _get_board_price(space_num: int) -> int:
	if space_num < 0 or space_num >= GameState.board.size():
		return 0
	var space = GameState.board[space_num]
	if space is Ownable:
		return int(space._initial_price)
	return 0


func _get_ai_estimated_value(ai_player_idx: int, space_num: int) -> int:
	if ai_player_idx < 0 or ai_player_idx >= GameState.players.size():
		return 0
	if space_num < 0 or space_num >= GameState.board.size():
		return 0
	if not (GameState.board[space_num] is Ownable):
		return 0

	var player = GameState.players[ai_player_idx]
	if not (player is AiPlayerState):
		return _get_board_price(space_num)

	var ai_player := player as AiPlayerState
	if ai_player.current_property_value_multipliers.size() <= space_num:
		_ensure_ai_valuation_model(player)

	if ai_player.current_property_value_multipliers.size() <= space_num:
		return _get_board_price(space_num)

	return int(round(_calculate_AI_property_value(player, space_num)))


func _build_property_context(space_num: int, ai_player_idx: int) -> Dictionary:
	if space_num < 0 or space_num >= GameState.board.size():
		return {
			"space_index": space_num,
			"asset_type": "special",
			"name": "Unknown",
			"color": "None",
			"board_price": 0,
			"ai_estimated_value": 0,
			"monopoly_equivalent": "none",
			"group_name": "None",
			"group_member_space_indexes": []
		}

	var space = GameState.board[space_num]
	if not (space is Ownable):
		return {
			"space_index": space_num,
			"asset_type": "non_ownable",
			"name": space._space_name,
			"color": "None",
			"board_price": 0,
			"ai_estimated_value": 0,
			"monopoly_equivalent": "none",
			"group_name": "None",
			"group_member_space_indexes": []
		}

	var members = _get_property_group_members(space_num, space)
	var data = {
		"space_index": space_num,
		"asset_type": "property",
		"name": space._space_name,
		"color": _get_property_group_name(space),
		"is_mortgaged": space._is_mortgaged,
		"is_owned": space._is_owned,
		"owner_index": space._player_owner,
		"board_price": _get_board_price(space_num),
		"ai_estimated_value": _get_ai_estimated_value(ai_player_idx, space_num),
		"monopoly_equivalent": _get_monopoly_equivalent(space),
		"group_name": _get_property_group_name(space),
		"group_member_space_indexes": members,
		"group_size": members.size()
	}

	if space is PropertySpace:
		data["current_upgrades"] = space._current_upgrades

	return data


func _build_trade_offer_context(trade_offer: Dictionary, ai_player_idx: int) -> Dictionary:
	var offer_data = trade_offer.duplicate(true)
	var offered_spaces = offer_data.get("offered_spaces", [])
	var requested_spaces = offer_data.get("requested_spaces", [])

	var offered_property_details: Array = []
	var requested_property_details: Array = []
	var offered_board_total := int(offer_data.get("offer_cash", 0))
	var requested_board_total := int(offer_data.get("request_cash", 0))
	var offered_estimated_total := offered_board_total
	var requested_estimated_total := requested_board_total

	for raw_space_idx in offered_spaces:
		var space_idx := int(raw_space_idx)
		if space_idx < 0:
			offered_property_details.append({
				"space_index": space_idx,
				"asset_type": "special",
				"name": "Go For Launch Card",
				"color": "Cards",
				"board_price": 50,
				"ai_estimated_value": 60,
				"monopoly_equivalent": "none",
				"group_name": "Cards",
				"group_member_space_indexes": []
			})
			offered_board_total += 50
			offered_estimated_total += 60
		else:
			var prop_data = _build_property_context(space_idx, ai_player_idx)
			offered_property_details.append(prop_data)
			offered_board_total += int(prop_data.get("board_price", 0))
			offered_estimated_total += int(prop_data.get("ai_estimated_value", 0))

	for raw_space_idx in requested_spaces:
		var space_idx := int(raw_space_idx)
		if space_idx < 0:
			requested_property_details.append({
				"space_index": space_idx,
				"asset_type": "special",
				"name": "Go For Launch Card",
				"color": "Cards",
				"board_price": 50,
				"ai_estimated_value": 60,
				"monopoly_equivalent": "none",
				"group_name": "Cards",
				"group_member_space_indexes": []
			})
			requested_board_total += 50
			requested_estimated_total += 60
		else:
			var prop_data = _build_property_context(space_idx, ai_player_idx)
			requested_property_details.append(prop_data)
			requested_board_total += int(prop_data.get("board_price", 0))
			requested_estimated_total += int(prop_data.get("ai_estimated_value", 0))

	offer_data["offered_property_details"] = offered_property_details
	offer_data["requested_property_details"] = requested_property_details
	offer_data["offered_total_board_value"] = offered_board_total
	offer_data["requested_total_board_value"] = requested_board_total
	offer_data["offered_total_ai_estimated_value"] = offered_estimated_total
	offer_data["requested_total_ai_estimated_value"] = requested_estimated_total
	offer_data["trade_direction_note"] = "offering_player gives offered_* assets to target_player; target_player gives requested_* assets in return"

	var offered_mortgaged_count := 0
	var requested_mortgaged_count := 0
	var offered_upgraded_count := 0
	var requested_upgraded_count := 0

	for raw_detail in offered_property_details:
		if typeof(raw_detail) != TYPE_DICTIONARY:
			continue
		var detail: Dictionary = raw_detail
		if bool(detail.get("is_mortgaged", false)):
			offered_mortgaged_count += 1
		if int(detail.get("current_upgrades", 0)) > 0:
			offered_upgraded_count += 1

	for raw_detail in requested_property_details:
		if typeof(raw_detail) != TYPE_DICTIONARY:
			continue
		var detail: Dictionary = raw_detail
		if bool(detail.get("is_mortgaged", false)):
			requested_mortgaged_count += 1
		if int(detail.get("current_upgrades", 0)) > 0:
			requested_upgraded_count += 1

	var offering_player_idx := int(offer_data.get("offering_player", -1))
	var target_player_idx := int(offer_data.get("target_player", ai_player_idx))
	var offer_cash := int(offer_data.get("offer_cash", 0))
	var request_cash := int(offer_data.get("request_cash", 0))
	var target_balance_before := 0
	var offering_balance_before := 0

	if target_player_idx >= 0 and target_player_idx < GameState.players.size():
		target_balance_before = int(GameState.players[target_player_idx].balance)

	if offering_player_idx >= 0 and offering_player_idx < GameState.players.size():
		offering_balance_before = int(GameState.players[offering_player_idx].balance)

	offer_data["evaluation_summary"] = {
		"target_player_index": target_player_idx,
		"target_player_name": GameState.get_player_display_name(target_player_idx),
		"offering_player_index": offering_player_idx,
		"offering_player_name": GameState.get_player_display_name(offering_player_idx),
		"you_receive_cash": offer_cash,
		"you_pay_cash": request_cash,
		"net_cash_change": offer_cash - request_cash,
		"you_receive_total_ai_estimated_value": offered_estimated_total,
		"you_give_total_ai_estimated_value": requested_estimated_total,
		"net_ai_estimated_value": offered_estimated_total - requested_estimated_total,
		"you_receive_total_board_value": offered_board_total,
		"you_give_total_board_value": requested_board_total,
		"net_board_value": offered_board_total - requested_board_total,
		"you_receive_mortgaged_assets": offered_mortgaged_count,
		"you_give_mortgaged_assets": requested_mortgaged_count,
		"you_receive_upgraded_assets": offered_upgraded_count,
		"you_give_upgraded_assets": requested_upgraded_count,
		"you_balance_before": target_balance_before,
		"you_balance_after": target_balance_before + offer_cash - request_cash,
		"offering_player_balance_before": offering_balance_before,
		"offering_player_balance_after": offering_balance_before - offer_cash + request_cash
	}

	offer_data["group_trade_impacts"] = _build_trade_group_impacts(offered_spaces, requested_spaces, target_player_idx, offering_player_idx)

	return offer_data


func _count_owned_spaces_for_player(member_space_indexes: Array, player_idx: int) -> int:
	var owned_count := 0
	for raw_space_idx in member_space_indexes:
		var space_idx := int(raw_space_idx)
		if space_idx < 0 or space_idx >= GameState.board.size():
			continue
		var space = GameState.board[space_idx]
		if space is Ownable and space._is_owned and int(space._player_owner) == player_idx:
			owned_count += 1
	return owned_count


func _count_traded_spaces_in_group(space_indexes: Array, member_space_indexes: Array) -> int:
	var member_lookup: Dictionary = {}
	for raw_member_idx in member_space_indexes:
		member_lookup[int(raw_member_idx)] = true

	var traded_count := 0
	for raw_space_idx in space_indexes:
		if member_lookup.has(int(raw_space_idx)):
			traded_count += 1

	return traded_count


func _append_trade_group_if_missing(space_idx: int, groups: Dictionary) -> void:
	if space_idx < 0 or space_idx >= GameState.board.size():
		return

	var space = GameState.board[space_idx]
	if not (space is Ownable):
		return

	var group_name := _get_property_group_name(space)
	var monopoly_equivalent := _get_monopoly_equivalent(space)
	var group_key := group_name + "|" + monopoly_equivalent

	if groups.has(group_key):
		return

	var members = _get_property_group_members(space_idx, space)
	groups[group_key] = {
		"group_key": group_key,
		"group_name": group_name,
		"monopoly_equivalent": monopoly_equivalent,
		"member_space_indexes": members,
		"group_size": members.size()
	}


func _build_trade_group_impacts(offered_spaces: Array, requested_spaces: Array, ai_player_idx: int, offering_player_idx: int) -> Array:
	var relevant_groups: Dictionary = {}

	for raw_space_idx in offered_spaces:
		_append_trade_group_if_missing(int(raw_space_idx), relevant_groups)

	for raw_space_idx in requested_spaces:
		_append_trade_group_if_missing(int(raw_space_idx), relevant_groups)

	var impacts: Array = []
	for group_key in relevant_groups.keys():
		var group_data: Dictionary = relevant_groups[group_key]
		var members: Array = group_data.get("member_space_indexes", [])
		var group_size := int(group_data.get("group_size", members.size()))

		var ai_owned_before := _count_owned_spaces_for_player(members, ai_player_idx)
		var offering_owned_before := _count_owned_spaces_for_player(members, offering_player_idx)

		var ai_receives_in_group := _count_traded_spaces_in_group(offered_spaces, members)
		var ai_gives_in_group := _count_traded_spaces_in_group(requested_spaces, members)

		var ai_owned_after := clampi(ai_owned_before + ai_receives_in_group - ai_gives_in_group, 0, group_size)
		var offering_owned_after := clampi(offering_owned_before - ai_receives_in_group + ai_gives_in_group, 0, group_size)

		impacts.append({
			"group_key": str(group_data.get("group_key", group_key)),
			"group_name": str(group_data.get("group_name", "Unknown")),
			"monopoly_equivalent": str(group_data.get("monopoly_equivalent", "none")),
			"group_size": group_size,
			"ai_owned_before": ai_owned_before,
			"ai_owned_after": ai_owned_after,
			"offering_player_owned_before": offering_owned_before,
			"offering_player_owned_after": offering_owned_after,
			"ai_completes_group": ai_owned_after == group_size and ai_owned_before < group_size,
			"ai_breaks_group": ai_owned_before == group_size and ai_owned_after < group_size,
			"offering_player_completes_group": offering_owned_after == group_size and offering_owned_before < group_size,
			"offering_player_breaks_group": offering_owned_before == group_size and offering_owned_after < group_size
		})

	return impacts


func _get_auction_pressure_bonus(player_index: int, space_num: int) -> int:
	if space_num < 0 or space_num >= GameState.board.size():
		return 0

	var space = GameState.board[space_num]
	if not (space is Ownable):
		return 0

	var members = _get_property_group_members(space_num, space)
	if members.size() <= 1:
		return 0

	var ai_owned := 0
	var top_other_owned := 0
	var owner_counts: Dictionary = {}

	for idx in members:
		var mspace = GameState.board[idx]
		if mspace is Ownable and mspace._is_owned:
			var owner_idx: int = int(mspace._player_owner)
			owner_counts[owner_idx] = int(owner_counts.get(owner_idx, 0)) + 1
			if owner_idx == player_index:
				ai_owned += 1

	for owner_idx in owner_counts.keys():
		if int(owner_idx) == player_index:
			continue
		top_other_owned = maxi(top_other_owned, int(owner_counts[owner_idx]))

	var board_price := _get_board_price(space_num)
	if ai_owned == members.size() - 1:
		return int(board_price * 0.45)
	if top_other_owned == members.size() - 1:
		return int(board_price * 0.30)
	if ai_owned > 0:
		return int(board_price * 0.15)

	return 0


func _get_or_create_auction_max_bid(player_index: int, space_num: int) -> int:
	if _auction_target_space_num != space_num:
		_auction_target_space_num = space_num
		_auction_max_bid_by_player.clear()

	if _auction_max_bid_by_player.has(player_index):
		return int(_auction_max_bid_by_player[player_index])

	if player_index < 0 or player_index >= GameState.players.size():
		return 0

	var player = GameState.players[player_index]
	_ensure_ai_valuation_model(player)

	var board_price := _get_board_price(space_num)
	var estimated_value := _get_ai_estimated_value(player_index, space_num)
	var reserve_cash := 200
	if player.balance >= 1200:
		reserve_cash = 300
	elif player.balance <= 500:
		reserve_cash = 100

	var liquidity_cap := maxi(0, player.balance - reserve_cash)
	var ceiling := estimated_value + _get_auction_pressure_bonus(player_index, space_num)

	if board_price > 0:
		ceiling = maxi(ceiling, int(board_price * 0.65))
		ceiling = mini(ceiling, int(board_price * 1.8))

	ceiling = clampi(ceiling, 0, liquidity_cap)
	_auction_max_bid_by_player[player_index] = ceiling

	print("AiManager: Auction cap for ", GameState.players[player_index].player_name, " on space ", space_num, " is $", ceiling)

	return ceiling

func get_ai_game_state(curr_player_idx: int) -> Dictionary:
	var curr_player = GameState.players[curr_player_idx]
	_ensure_ai_valuation_model(curr_player)

	# Get info about the current space
	var space = GameState.board[curr_player.board_space]
	var can_buy = (space is Ownable) and not space.is_owned()

	# Map out all owned properties for everyone
	var all_owned_properties = {}
	for i in range(GameState.players.size()):
		all_owned_properties[i] = []

	for p_space_idx in range(GameState.board.size()):
		var bs = GameState.board[p_space_idx]
		if bs is Ownable and bs.is_owned():
			var owner_idx = bs.get_property_owner()
			if all_owned_properties.has(owner_idx):
				all_owned_properties[owner_idx].append(_build_property_context(p_space_idx, curr_player_idx))

	var my_tradeable_spaces = GameController.get_tradeable_space_indexes(curr_player_idx)
	if not (my_tradeable_spaces is Array):
		my_tradeable_spaces = []
	var my_tradeable_properties: Array = []
	for raw_space_idx in my_tradeable_spaces:
		my_tradeable_properties.append(_build_property_context(int(raw_space_idx), curr_player_idx))

	var has_trade_offer_assets: bool = curr_player.balance > 0 or my_tradeable_spaces.size() > 0

	var opponents = []
	var trade_targets = []
	for i in range(GameState.players.size()):
		var p = GameState.players[i]
		var bankrupt = p.is_bankrupt if "is_bankrupt" in p else false
		if p != curr_player and not bankrupt:
			var opponent_tradeable_spaces = GameController.get_tradeable_space_indexes(i)
			if not (opponent_tradeable_spaces is Array):
				opponent_tradeable_spaces = []
			var opponent_tradeable_properties: Array = []
			for raw_space_idx in opponent_tradeable_spaces:
				opponent_tradeable_properties.append(_build_property_context(int(raw_space_idx), curr_player_idx))

			opponents.append({
				"player_index": i,
				"name": p.player_name,
				"balance": p.balance,
				"space_index": p.board_space,
				"owned_properties": all_owned_properties[i],
				"tradeable_space_indexes": opponent_tradeable_spaces,
				"tradeable_properties": opponent_tradeable_properties
			})

			var opponent_has_trade_assets: bool = p.balance > 0 or opponent_tradeable_spaces.size() > 0
			if has_trade_offer_assets and opponent_has_trade_assets:
				trade_targets.append({
					"player_index": i,
					"name": p.player_name,
					"balance": p.balance,
					"tradeable_space_indexes": opponent_tradeable_spaces,
					"tradeable_properties": opponent_tradeable_properties
				})

	var owed = _bankruptcy_amount if _fallback_state == "bankruptcy" else 0
	var recent_previous_turn_events: Array[String] = _get_recent_previous_turn_events(8)
	var can_propose_trade = has_trade_offer_assets and trade_targets.size() > 0

	# Pass difficulty setting in the prompt
	return {
		"player_index": curr_player_idx,
		"player_name": curr_player.player_name,
		"balance": curr_player.balance,
		"current_space_name": space._space_name,
		"current_space_index": curr_player.board_space,
		"current_space_board_price": _get_board_price(curr_player.board_space),
		"current_space_monopoly_equivalent": _get_monopoly_equivalent(space),
		"current_space_group_name": _get_property_group_name(space),
		"current_space_group_member_space_indexes": _get_property_group_members(curr_player.board_space, space),
		"has_rolled_dice": curr_player.has_rolled,
		"is_in_jail": curr_player.is_in_jail,
		"turns_in_jail": curr_player.turns_in_jail,
		"jail_cards": curr_player.go_for_launch_cards,
		"amount_owed_in_bankruptcy": owed,
		"valid_upgrades": validUpgrades,
		"valid_upgrades_to_sell": validDowngrades,
		"valid_mortgages": validMortgages,
		"valid_unmortgages": validUnmortgages,
		"your_tradeable_space_indexes": my_tradeable_spaces,
		"your_tradeable_properties": my_tradeable_properties,
		"trade_targets": trade_targets,
		"can_propose_trade": can_propose_trade,
		"owned_properties": all_owned_properties[curr_player_idx],
		"can_buy_property_here": can_buy,
		"opponents": opponents,
		"recent_previous_turn_events": recent_previous_turn_events
	}


func _state_array_has_values(state_dict: Dictionary, key: String) -> bool:
	var raw_value = state_dict.get(key, [])
	return raw_value is Array and raw_value.size() > 0


func _llm_mid_turn_has_valid_actions(state_dict: Dictionary) -> bool:
	if bool(state_dict.get("can_buy_property_here", false)):
		return true
	if _state_array_has_values(state_dict, "valid_upgrades"):
		return true
	if _state_array_has_values(state_dict, "valid_upgrades_to_sell"):
		return true
	if _state_array_has_values(state_dict, "valid_mortgages"):
		return true
	if _state_array_has_values(state_dict, "valid_unmortgages"):
		return true
	if bool(state_dict.get("can_propose_trade", false)):
		return true
	return false

func _run_llm_ai_turn() -> void:
	_begin_ai_turn_context()
	update_valid_mid_turn_targets()
	var curr_player_idx = GameState.current_player_index
	var state_dict = get_ai_game_state(curr_player_idx)

	if _fallback_state == "mid" and not _llm_mid_turn_has_valid_actions(state_dict):
		print("AiManager: No valid LLM mid-turn actions. Ending turn without calling LLM.")
		ai_turn_end()
		return
	
	if _llm_ai_controller:
		_llm_ai_controller.take_turn(state_dict)
	else:
		push_error("AiController not initialized correctly.")
		ai_turn_start()

# Actions that should occur at the start of the AI player's turn
func ai_turn_start() -> void:
	if GameState.use_llm_ai:
		var llm_acting_ai := _begin_ai_turn_context()
		if not _is_same_ai_turn(llm_acting_ai):
			return
		
		var current_player = GameController.get_current_player()
		if current_player.is_in_jail:
			# Guard against stale roll state leaking into a new jailed turn.
			if current_player.has_rolled:
				current_player.has_rolled = false
			_fallback_state = "jail"
			_run_llm_ai_turn()
			return
			
		if not current_player.has_rolled:
			await _ai_pause("pre_roll")
			if not _is_same_ai_turn(llm_acting_ai):
				return
			ai_dice_roll.emit()
			return
			
		return
		
	print("AI Manager: AI turn start")

	var classic_acting_ai := _begin_ai_turn_context()

	if not _is_same_ai_turn(classic_acting_ai):
		return

	if (GameController.get_current_player().base_property_value_multipliers.is_empty()):
		_initialize_property_multipliers(GameController.get_current_player())
	else:
		_update_property_multipliers(GameController.get_current_player())
		
	if GameController.get_current_player().is_in_jail:
		ai_jail_decision()
		return

	if not GameController.get_current_player().has_rolled:
		await _ai_pause("pre_roll")
		if not _is_same_ai_turn(classic_acting_ai):
			return
		ai_dice_roll.emit()
	else:
		ai_turn_mid()

# Specifically handles the case where the AI rolls doubles 3 times in a row, since this path leads to ai never landing on a space
func handle_doubles_jail():
	GameController.get_current_player().last_roll_was_doubles = false
	GameController.get_current_player().has_rolled = true
	ai_turn_mid()


# AI should choose between rolling, paying, and using a card here
func ai_jail_decision():
	print("AI Manager: AI makes jail decision")
	var current_player = GameController.get_current_player()
	
	# Attempt to roll for doubles if still early in jail (< 2 turns)
	if current_player.turns_in_jail < 2:
		ai_jail_roll_sequence()
	elif current_player.go_for_launch_cards > 0:
		ai_jail_card.emit(GameState.current_player_index)
	else:
		ai_jail_pay.emit(GameState.current_player_index)

func ai_jail_roll_sequence():
	var current_player = GameController.get_current_player()
	ai_jail_roll.emit(GameState.current_player_index)
	await get_tree().process_frame  # Let jail popup process before rolling
	await _ai_pause("pre_roll")
	ai_dice_roll.emit()  # Actually trigger the dice roll
	await GameController.player_rolled
	if current_player and current_player.is_in_jail: # move on to middle of turn if still in jail, otherwise landing on a property will trigger first
		ai_turn_mid()



# Controls logic for AI players landing on spaces, then moves the AI to the middle of its turn
func ai_lands_on_space(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	var current_player = GameController.get_current_player()
	if current_player == null:
		return

	# A real landing should only be resolved after has_rolled is true.
	if not current_player.has_rolled and not current_player.is_in_jail:
		return

	print("AI Manager: AI lands on space")

	await _ai_pause("after_landing")
	if not _is_same_ai_turn(acting_ai):
		return

	var property = GameState.board[space_num]
	var scr: Script = property.get_script() as Script
	var gname: String = ""
	if scr != null:
		gname = scr.get_global_name()

	match gname:
		"PropertySpace", "InstrumentSpace", "PlanetSpace":
			if property._is_owned == true:
				ai_pay.emit(space_num)
			else:
				await ai_lands_on_unowned_property(space_num)
				if GameState.use_llm_ai:
					return

		"CardSpace":
			await _ai_pause("card_draw")
			if not _is_same_ai_turn(acting_ai):
				return
			ai_draw_card.emit(space_num)
			return

		"ExpenseSpace":
			ai_pay.emit(space_num)

		"SpecialSpace":
			if space_num == 30:
				ai_move.emit(space_num)

		"GameSpace":
			if space_num == 20:
				var space_info = SpaceData.get_space_info(space_num)
				GameController.credit(acting_ai, space_info.get("amount", 0))

	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_mid()
	

func ai_card_resolve(card_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	var current_player = GameController.get_current_player()
	if current_player == null:
		return

	# Ignore stale card callbacks before this AI has actually rolled/resolved movement
	if not current_player.has_rolled and not current_player.is_in_jail:
		return

	if card_num not in range(18, 33):
		ai_turn_mid()
	elif card_num in range(32, 33):
		ai_turn_mid()

# AI should choose between purchasing and auctioning here
func ai_lands_on_unowned_property(space_num: int) -> void:
	if GameState.use_llm_ai:
		_fallback_state = "unowned"
		_last_space_num = space_num
		_run_llm_ai_turn()
		return
		
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("before_purchase")
	if not _is_same_ai_turn(acting_ai):
		return

	var player = GameController.get_current_player()
	if (player.balance >= GameState.board[space_num]._initial_price && _calculate_AI_property_value(player, space_num) >= GameState.board[space_num]._initial_price):
		ai_purchase.emit(space_num)
	else:
		await _ai_pause("before_trade")
		if not _is_same_ai_turn(acting_ai):
			return

		ai_auction_start.emit(space_num)
		await AuctionMgr.auction_ended
		await GameController.action_completed

	if not _is_same_ai_turn(acting_ai):
		return

# AI should attempt to not go bankrupt through mortgaging properties and selling upgrades, make it do that here. 
func ai_bankruptcy_resolve(amount: int) -> void:
	if GameState.use_llm_ai:
		_bankruptcy_amount = amount
		_fallback_state = "bankruptcy"
		_run_llm_ai_turn()
		return
		
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	update_valid_mid_turn_targets()

	while GameController.get_current_player().balance < amount and (validDowngrades.size() > 0 or validMortgages.size() > 0):
		if not _is_same_ai_turn(acting_ai):
			return

		var decision = randf()
		if validDowngrades.size() == 0:
			decision = 1
		elif validMortgages.size() == 0:
			decision = 0

		if decision <= 0.5:
			ai_sells_upgrade(validDowngrades.pick_random())
		else:
			ai_property_mortgage(validMortgages.pick_random())

		update_valid_mid_turn_targets()

	if not _is_same_ai_turn(acting_ai):
		return

	if GameController.get_current_player().balance >= amount:
		ai_pay_bankruptcy.emit()
	else:
		ai_declare_bankruptcy.emit()

func continue_llm_bankruptcy() -> void:
	if GameState.use_llm_ai and _fallback_state == "bankruptcy":
		# Ensure the board changes had time to propagate logically before polling the API again
		await get_tree().create_timer(0.5).timeout
		_run_llm_ai_turn()

# Updates valid upgrades, downgrades, mortgages, and unmortgages
func update_valid_mid_turn_targets() -> void:
	validUpgrades = [] # holds the space numbers of upgradable properties
	validDowngrades = [] # holds the space numbers of downgradable properties
	validMortgages = []
	validUnmortgages = []
	for i in range(GameState.board.size()):
		if (GameState.board[i] is PropertySpace):
			if GameController._check_if_upgrade_is_valid(GameState.board[i], GameState.current_player_index):
				validUpgrades.append(i)
			if GameController._check_if_downgrade_is_valid(GameState.board[i], GameState.current_player_index):
				validDowngrades.append(i)
		if (GameState.board[i] is Ownable):
			if GameController._check_if_mortgage_is_valid(GameState.board[i], GameState.current_player_index):
				validMortgages.append(i)
			if GameController._check_if_unmortgage_is_valid(GameState.board[i], GameState.current_player_index):
				validUnmortgages.append(i)

# AI should whether to trade or not here
func ai_turn_mid() -> void:
	if GameState.use_llm_ai:
		var current_player := GameController.get_current_player()
		if current_player != null and current_player.is_in_jail:
			# If AI already rolled and is still jailed, the turn is effectively over.
			if current_player.has_rolled:
				ai_turn_end()
			else:
				_fallback_state = "jail"
				_run_llm_ai_turn()
			return

		_fallback_state = "mid"
		_run_llm_ai_turn()
		return
		
	print("AI manager: AI moves to middle of turn")

	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("before_trade")
	if not _is_same_ai_turn(acting_ai):
		return

	var player = GameController.get_current_player()
	if (player.master_property_value_multiplier > 1 && player.master_property_value_multiplier - randf() * 0.5 > 1):
		ai_create_trade_offer(true)
	elif(player.master_property_value_multiplier < 1 && player.master_property_value_multiplier - randf() * 1.5 < 0):
		ai_create_trade_offer(false)
	else:
		ai_turn_post_trade()


# Forces the AI to wait until its trade offer is complete before resuming
func check_trade_completion() -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("after_trade")
	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_post_trade()

# AI should decide between property upgrading and mortgaging before ending the current turn
func ai_turn_post_trade() -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	var decisionAttempts = 4
	var randFloat = randf()

	while randFloat < decisionAttempts / 4.0:
		if not _is_same_ai_turn(acting_ai):
			return

		update_valid_mid_turn_targets()
		randFloat = randf()

		if randFloat > 0.5:
			if validUpgrades.size() > 0:
				var randInt = randi_range(0, validUpgrades.size() - 1)
				ai_property_upgrade(validUpgrades[randInt])
		#elif (randFloat > 0.3):
		#	if (validDowngrades.size() > 0):
		#		var randInt = randi_range(0, validDowngrades.size() - 1)
		#		ai_sells_upgrade(validDowngrades[randInt])
		#elif (randFloat > 0.4):
		#	if (validMortgages.size() > 0):
		#		var randInt = randi_range(0, validMortgages.size() - 1)
		#		ai_property_mortgage(validMortgages[randInt])
		else:
			if validUnmortgages.size() > 0:
				var randInt = randi_range(0, validUnmortgages.size() - 1)
				ai_property_unmortgage(validUnmortgages[randInt])

		randFloat = randf()
		decisionAttempts -= 1

	if not _is_same_ai_turn(acting_ai):
		return

	ai_turn_end()

# sorts the properties from highest multiplier -> lowest
func _sort_by_multiplier(a: int, b: int) -> bool:
	var current_player = GameController.get_current_player()
	if not (current_player is AiPlayerState):
		return a < b

	var ai_player := current_player as AiPlayerState
	if ai_player.current_property_value_multipliers.size() <= maxi(a, b):
		_ensure_ai_valuation_model(ai_player)

	if ai_player.current_property_value_multipliers.size() <= maxi(a, b):
		return a < b

	if (ai_player.current_property_value_multipliers[a] > ai_player.current_property_value_multipliers[b]):
		return true
	return false
	


# AI should decide what to trade here
func ai_create_trade_offer(buying: bool) -> void:
	var current_player := active_ai_player_index
	if not _is_same_ai_turn(current_player):
		return
	
	var offeringProperties: Array[int] = []
	var receivingProperties: Array[int] = []
	var offeringCash = 0
	var receivingCash = 0

	# Generate a random target player to trade with
	var target_player = randi_range(0, GameState.players.size() - 2)
	if target_player >= current_player:
		target_player += 1
		
	var receivablePropeties: Array[int] = []
	if (buying):
		for i in range(GameState.players.size()):
			if (i != current_player):
				receivablePropeties.append_array(GameController.get_tradeable_space_indexes(i))
		receivablePropeties.sort_custom(_sort_by_multiplier)
		if (receivablePropeties.size() > 0):
			receivingProperties.append(receivablePropeties[0])	
			target_player = GameState.board[receivingProperties[0]]._player_owner
		var maxOffer = min(GameController.get_current_player().balance, _calculate_AI_property_value(GameState.players[current_player], receivingProperties[0]))
		offeringCash = randi_range(maxOffer / 2, maxOffer)
	else:
		var offerablePropeties: Array[int] = GameController.get_tradeable_space_indexes(current_player)
		offerablePropeties.sort_custom(_sort_by_multiplier)
		if (offerablePropeties.size() > 0):
			offeringProperties.append(offerablePropeties[offerablePropeties.size() - 1])
		
		var propertyValue = _calculate_AI_property_value(GameState.players[current_player], offeringProperties[0])
		if (propertyValue < GameState.players[target_player].balance):
			receivingCash = randi_range(propertyValue, GameState.players[target_player].balance)
		else:
			receivingCash = GameState.players[current_player]
			
	if (offeringProperties.size() > 0 || receivingProperties.size() > 0):
		ai_trade_create.emit(current_player, target_player, offeringCash, receivingCash, offeringProperties, receivingProperties) # only create offer is AI is trading a property
	else:
		ai_turn_post_trade()


func ai_property_upgrade(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.upgrade_property.emit(GameState.board[space_num], acting_ai)
	
func ai_sells_upgrade(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.downgrade_property.emit(GameState.board[space_num], acting_ai)

	
func ai_property_mortgage(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.mortgage_property.emit(GameState.board[space_num], acting_ai)

	
func ai_property_unmortgage(space_num: int) -> void:
	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return
	GameController.unmortgage_property.emit(GameState.board[space_num], acting_ai)



func ai_turn_end() -> void:
	print("AI manager: AI moves to end of turn")

	var acting_ai := active_ai_player_index
	if not _is_same_ai_turn(acting_ai):
		return

	await _ai_pause("end_turn")
	if not _is_same_ai_turn(acting_ai):
		return

	if GameController.get_current_player().last_roll_was_doubles:
		GameController.get_current_player().has_rolled = false
		GameController.get_current_player().last_roll_was_doubles = false

	if GameController.get_current_player().has_rolled == true or GameController.get_current_player().is_in_jail:
		active_ai_player_index = -1
		GameController.end_turn(true)
	else:
		ai_turn_start()

# AI should decide how much to bid on an auction here
func ai_auction_decision(player_index: int, highest_bid: int, space_num: int) -> void:
	await _ai_pause("before_trade")
	if player_index < 0 or player_index >= GameState.players.size():
		return
	if GameState.current_player_index < 0 or GameState.current_player_index >= GameState.players.size():
		return
	if not GameState.players[player_index].player_is_ai:
		return

	var player = GameState.players[player_index]
	var min_inc := 1
	min_inc = maxi(1, int(AuctionMgr.min_increment))

	var next_required := highest_bid + min_inc
	var max_bid := _get_or_create_auction_max_bid(player_index, space_num)

	if player.balance < next_required or max_bid < next_required:
		ai_auction_pass.emit()
		return

	var chosen_increment := min_inc
	var max_delta := max_bid - highest_bid
	if max_delta >= 50 and player.balance >= highest_bid + 50:
		chosen_increment = 50
	elif max_delta >= 10 and player.balance >= highest_bid + 10:
		chosen_increment = 10

	ai_auction_bid.emit(chosen_increment)
# AI should decide whether to accept or decline a trade here
func ai_trade_decision(trade_offer: Dictionary) -> void:
	_last_trade_decision_player_index = -1
	var player_idx := int(trade_offer.get("target_player", -1))
	if player_idx < 0 or player_idx >= GameState.players.size():
		ai_trade_reject.emit()
		return

	_last_trade_decision_player_index = player_idx

	var enriched_trade_offer: Dictionary = _build_trade_offer_context(trade_offer, player_idx)

	if GameState.use_llm_ai:
		if _llm_ai_controller:
			var state_dict = get_ai_game_state(player_idx)
			_llm_ai_controller.evaluate_trade(enriched_trade_offer, state_dict)
			return

	var value_offered := int(enriched_trade_offer.get("offered_total_ai_estimated_value", enriched_trade_offer.get("offered_total_board_value", 0)))
	var value_requested := int(enriched_trade_offer.get("requested_total_ai_estimated_value", enriched_trade_offer.get("requested_total_board_value", 0)))

	if value_offered > value_requested:
		ai_trade_accept.emit()
	else:
		ai_trade_reject.emit()
	

func _begin_ai_turn_context() -> int:
	active_ai_player_index = GameState.current_player_index
	return active_ai_player_index


func _is_same_ai_turn(expected_player_index: int) -> bool:
	if expected_player_index < 0:
		return false
	if GameState.current_player_index != expected_player_index:
		return false
	if expected_player_index >= GameState.players.size():
		return false
	return GameState.players[expected_player_index].player_is_ai


func get_last_trade_decision_player_index() -> int:
	return _last_trade_decision_player_index


func get_last_trade_decision_player_name() -> String:
	if _last_trade_decision_player_index >= 0 and _last_trade_decision_player_index < GameState.players.size():
		return GameState.get_player_display_name(_last_trade_decision_player_index)
	return "AI"

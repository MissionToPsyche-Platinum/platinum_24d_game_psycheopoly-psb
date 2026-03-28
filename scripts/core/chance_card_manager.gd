extends Node
 
const Board = preload("res://scripts/core/board.gd")
const SpaceDataRef = preload("res://scripts/core/space_data.gd")

signal request_move_forward(spaces: int)
signal request_teleport_movement(space: int)
signal card_resolved(card_num: int)

var player_count = -1
var current_player = -1
var other_player = -1
var forward_movement = -1
var go_for_launch1_available : bool = true
var go_for_launch1_owner : int = -1
var go_for_launch2_available : bool = true
var go_for_launch2_owner : int = -1


func resolve_card(card_num: int, money_value: int, movement_value: int, space_number: int) -> void:
	current_player = GameState.current_player_index
	player_count = GameState.player_count

	var player_name := GameController.get_player_log_name(current_player)

	if card_num in range(0, 10): # cards with a flat earning
		GameController.log_transaction("%s drew a card and collected $%d." % [player_name, money_value])
		GameController.credit(current_player, money_value)

	elif card_num in range(10, 14): # cards with a flat loss
		GameController.log_transaction("%s drew a card and paid $%d." % [player_name, money_value])
		if not GameController.request_payment(current_player, money_value, "Chance card payment"):
			card_resolved.emit(card_num)
			return

	elif card_num == 14: # pay each player 50
		var pay_opponents = (player_count - 1) * 50
		GameController.log_transaction("%s drew a card and paid each other player $50 (total $%d)." % [player_name, pay_opponents])

		if not GameController.request_payment(current_player, pay_opponents, "Chance card: pay each player"):
			card_resolved.emit(card_num)
			return

		var paid_player = (current_player + 1) % player_count
		while paid_player != current_player:
			GameController.credit(paid_player, 50)
			paid_player = (paid_player + 1) % player_count

	elif card_num == 15: # earn 10 from each player
		var earn_from_opponents = (player_count - 1) * 10
		GameController.log_transaction("%s drew a card and collected $10 from each other player (total $%d)." % [player_name, earn_from_opponents])
		GameController.credit(current_player, earn_from_opponents)

		var losing_player = (current_player + 1) % player_count
		while losing_player != current_player:
			GameController.debit(losing_player, 10)
			losing_player = (losing_player + 1) % player_count

	elif card_num == 16: # pay 45 per data point, pay 120 per discovery
		var total_data_points = GameState.players[current_player].total_data_points
		var total_discoveries = GameState.players[current_player].total_discoveries
		var card_fee = (total_data_points * 45) + (total_discoveries * 120)

		GameController.log_transaction("%s drew a card and paid $%d for asset maintenance." % [player_name, card_fee])
		if not GameController.request_payment(current_player, card_fee, "Chance card: asset maintenance"):
			card_resolved.emit(card_num)
			return

	elif card_num == 17: # pay 25 per data point, pay 100 per discovery
		var total_data_points = GameState.players[current_player].total_data_points
		var total_discoveries = GameState.players[current_player].total_discoveries
		var card_fee = (total_data_points * 25) + (total_discoveries * 100)

		GameController.log_transaction("%s drew a card and paid $%d for asset maintenance." % [player_name, card_fee])
		if not GameController.request_payment(current_player, card_fee, "Chance card: asset maintenance"):
			card_resolved.emit(card_num)
			return

	## Cases for silicate cards that are movement based
	elif card_num in range(18, 28): # advance player to specific property
		if space_number < movement_value:
			forward_movement = movement_value - space_number
		elif space_number > movement_value:
			forward_movement = (40 - space_number) + movement_value
		else:
			forward_movement = 0

		var destination_name := "Space %d" % movement_value
		var destination_info = SpaceDataRef.get_space_info(movement_value)
		if destination_info.has("name"):
			var candidate := str(destination_info["name"]).strip_edges()
			if candidate != "":
				destination_name = candidate

		GameController.log_transaction("%s drew a card and advanced to %s." % [player_name, destination_name])
		emit_signal("request_move_forward", forward_movement)

	elif card_num in [28, 29]: # advance to nearest scientific instrument
		var instrument_spaces = [5, 15, 25, 35]
		var min_dist = 40
		for target in instrument_spaces:
			var dist: int
			if target > space_number:
				dist = target - space_number
			else:
				dist = (40 - space_number) + target
			if dist < min_dist:
				min_dist = dist

		GameController.log_transaction("%s drew a card and advanced to the nearest Scientific Instrument." % player_name)
		emit_signal("request_move_forward", min_dist)

	elif card_num == 30: # advance to nearest planet
		var mars_dist: int = (12 - space_number) if 12 > space_number else (40 - space_number) + 12
		var jupiter_dist: int = (27 - space_number) if 27 > space_number else (40 - space_number) + 27

		GameController.log_transaction("%s drew a card and advanced to the nearest Planet." % player_name)
		emit_signal("request_move_forward", min(mars_dist, jupiter_dist))

	elif card_num == 31: # move back 3 spaces
		var backward_movement = -1

		if space_number <= 2:
			backward_movement = (space_number - 3) + 40
		else:
			backward_movement = space_number - 3

		GameController.log_transaction("%s drew a card and moved back 3 spaces." % player_name)
		emit_signal("request_teleport_movement", backward_movement)

	elif card_num in [32, 33]: # move directly to jail
		GameController.log_transaction("%s drew a card and was sent to the Launch Pad." % player_name)
		GameController.send_player_to_jail(current_player)
		emit_signal("request_teleport_movement", movement_value)

	elif card_num == 34: # get out of jail card 
		go_for_launch1_available = false
		go_for_launch1_owner = current_player
		var player = GameState.players[current_player]
		player.go_for_launch_cards += 1

		GameController.log_transaction("%s drew a Get Out of Launch Pad Free card." % player_name)

	elif card_num == 35: # get out of jail card 
		go_for_launch2_available = false
		go_for_launch2_owner = current_player
		var player = GameState.players[current_player]
		player.go_for_launch_cards += 1

		GameController.log_transaction("%s drew a Get Out of Launch Pad Free card." % player_name)

	else: # in place of an error
		pass

	card_resolved.emit(card_num)

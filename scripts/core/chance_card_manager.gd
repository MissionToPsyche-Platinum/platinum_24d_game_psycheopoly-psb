extends Node
 
const Board = preload("res://scripts/core/board.gd")

signal request_move_forward(spaces: int)
signal request_teleport_movement(space: int)

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
	
	if card_num in range(0, 10): #cards with a flat earning
		GameController.credit(current_player,money_value) 
	elif card_num in range(10,14): #cards with a flat loss
		GameController.debit(current_player,money_value) 
	elif card_num == 14: #pay each player 50
		var pay_opponents = (player_count - 1) * 50
		GameController.debit(current_player,pay_opponents) 
		
		var paid_player = (current_player + 1) % player_count
		while paid_player != current_player:
			GameController.credit(paid_player, 50) 
			paid_player = (paid_player + 1) % player_count
	
	elif card_num == 15: #earn 10 from each player
		var earn_from_opponents = (player_count - 1) * 10
		GameController.credit(current_player,earn_from_opponents) 
		
		var losing_player = (current_player + 1) % player_count
		while losing_player != current_player:
			GameController.debit(losing_player, 10) 
			losing_player = (losing_player + 1) % player_count
	
	elif card_num == 16: #pay 45 per data point, pay 120 per discovery
		var total_data_points = GameState.players[current_player].total_data_points
		var total_discoveries = GameState.players[current_player].total_discoveries
		var card_fee = (total_data_points * 45) + (total_discoveries * 120)
		GameController.debit(current_player, card_fee) 
	
	elif card_num == 17: #pay 25 per data point, pay 100 per discovery
		var total_data_points = GameState.players[current_player].total_data_points
		var total_discoveries = GameState.players[current_player].total_discoveries
		var card_fee = (total_data_points * 25) + (total_discoveries * 100)
		GameController.debit(current_player, card_fee) 
		
		##Cases for silicate cards that are movement based
	elif card_num in range(18, 28): #advance player to specific property
		if space_number < movement_value:
			forward_movement = movement_value - space_number
		
		elif space_number > movement_value:
			forward_movement = (40 - space_number) + movement_value
		
		emit_signal ("request_move_forward", forward_movement)
		
	elif card_num in [28, 29]: #move to nearest scientific instrument
		var instrument1_distance = abs(space_number - 5)
		var instrument2_distance = abs(space_number - 15)
		var instrument3_distance = abs(space_number - 25)
		var instrument4_distance = abs(space_number - 35)
		var instrucment_movement = min(instrument1_distance, instrument2_distance, instrument3_distance, instrument4_distance)
		
		if instrucment_movement == instrument1_distance:
			emit_signal ("request_teleport_movement", 5)
		elif instrucment_movement == instrument2_distance:
			emit_signal ("request_teleport_movement", 15)
		elif instrucment_movement == instrument3_distance:
			emit_signal ("request_teleport_movement", 25)
		elif instrucment_movement == instrument4_distance:
			emit_signal ("request_teleport_movement", 35)
	
	elif card_num == 30: #move to nearest planet
		var mars_distance = abs(space_number - 12)
		var jupiter_distance = abs(space_number - 27)
		
		if mars_distance < jupiter_distance:
			emit_signal ("request_teleport_movement", 12)
		else:
			emit_signal ("request_teleport_movement", 27)
		
	elif card_num == 31: #move back 3 spaces
		var backward_movement = -1
		
		if space_number <= 2:
			backward_movement = (space_number - 3) + 40
		else:
			backward_movement = space_number - 3
		
		emit_signal ("request_teleport_movement", backward_movement)
		
	elif card_num in [32, 33]: #move directly to jail
		emit_signal("request_teleport_movement", movement_value)
		GameController.send_player_to_jail(current_player)
		
	elif card_num == 34: #get out of jail card (needs a lock for inventory)
		go_for_launch1_available = false
		go_for_launch1_owner = current_player
		var player = GameState.players[current_player]
		player.go_for_launch_cards += 1
	
	elif card_num == 35: #get out of jail card (needs a lock for inventory)
		go_for_launch2_available = false
		go_for_launch2_owner = current_player
		var player = GameState.players[current_player]
		player.go_for_launch_cards += 1
	else: #in place of an error
		pass

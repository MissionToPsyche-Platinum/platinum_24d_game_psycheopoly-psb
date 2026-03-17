extends Control
class_name JailPopup

@onready var desc_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var pay_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/PayBtn
@onready var card_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CardBtn
@onready var roll_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/RollBtn

var _player_index: int = -1

func _ready() -> void:
	hide()

func show_for_player(player_index: int) -> void:
	_player_index = player_index
	var player = GameState.players[_player_index]
	
	desc_label.text = "Turn %d/3 on Launch Pad" % (player.turns_in_jail + 1)
	
	# Determine if they can afford $50
	var can_afford_bail = GameController.get_player_balance(_player_index) >= 50
	pay_btn.disabled = not can_afford_bail
	
	# Check for get out of jail cards
	card_btn.visible = player.go_for_launch_cards > 0
	
	# If it's turn 3, usually rolling is mandatory if they don't pay.
	# The board logic handles the forced payment on failure.
	
	show()

func hide_popup() -> void:
	hide()

func _on_pay_btn_pressed() -> void:
	if _player_index < 0: return
	# Debit $50 and release
	GameController.debit(_player_index, 50, "Launch Permit")
	GameController.release_player_from_jail(_player_index)
	# Player has NOT rolled yet, so they can use the normal roll UI
	var player = GameState.players[_player_index]
	player.has_rolled = false
	GameController.action_completed.emit() # Triggers UI updates
	hide_popup()

func _on_card_btn_pressed() -> void:
	if _player_index < 0: return
	var player = GameState.players[_player_index]
	if player.go_for_launch_cards > 0:
		player.go_for_launch_cards -= 1
		
		# Return it to the chance card deck
		if not ChanceCardMgr.go_for_launch1_available:
			ChanceCardMgr.go_for_launch1_available = true
			ChanceCardMgr.go_for_launch1_owner = -1
		elif not ChanceCardMgr.go_for_launch2_available:
			ChanceCardMgr.go_for_launch2_available = true
			ChanceCardMgr.go_for_launch2_owner = -1
		
		GameController.release_player_from_jail(_player_index)
		player.has_rolled = false
		GameController.action_completed.emit()
		hide_popup()

func _on_roll_btn_pressed() -> void:
	# Hide the popup and let them use the main dice roll button
	# The board's _on_dice_rolled handles the jail roll resolution
	var player = GameState.players[_player_index]
	player.has_rolled = false # Ensure they can roll
	GameController.action_completed.emit()
	hide_popup()

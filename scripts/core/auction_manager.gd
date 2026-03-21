extends Node
class_name AuctionManager

const SpaceDataRef = preload("res://scripts/core/space_data.gd")

signal auction_started(space_num: int, property_ref, participants: Array[int])
signal turn_changed(current_player_index: int)
signal bid_updated(high_bid: int, high_bidder_index: int)
signal message(text: String)
signal auction_ended(winner_index: int, winning_bid: int, space_num: int, property_ref)

enum State { IDLE, RUNNING }
var state: State = State.IDLE

var space_num: int = -1
var property_ref = null

var participants: Array[int] = []
var active: Array[int] = [] # legacy (kept for now) - we don't rely on this for winner/turn logic anymore
var turn_index: int = 0

var high_bid: int = 0
var high_bidder_index: int = -1
var min_increment: int = 10 # you can change this

var passed: Dictionary = {} # key: player_index -> true


func start_auction(_space_num: int, _participants: Array[int], _starting_bid: int = 0, _min_increment: int = 10, _starting_player_index: int = -1) -> void:
	if state == State.RUNNING:
		return

	space_num = _space_num
	property_ref = GameState.board[space_num] if space_num >= 0 and space_num < GameState.board.size() else null

	participants = _participants.duplicate()
	active = _participants.duplicate()

	# pick who goes first
	turn_index = 0
	if _starting_player_index != -1:
		var idx := participants.find(_starting_player_index)
		if idx != -1:
			turn_index = idx

	# reset pass-tracking + high bidder for a fresh auction
	passed.clear()
	high_bidder_index = -1

	high_bid = _starting_bid
	min_increment = max(1, _min_increment)

	state = State.RUNNING

	# Turn log: auction started
	var property_name := "Space %d" % space_num
	var space_info := SpaceDataRef.get_space_info(space_num)
	if space_info.has("name"):
		var candidate := str(space_info["name"]).strip_edges()
		if candidate != "":
			property_name = candidate

	GameController.log_transaction("Auction started for %s." % property_name)

	emit_signal("auction_started", space_num, property_ref, participants)
	emit_signal("bid_updated", high_bid, high_bidder_index)
	emit_signal("message", "Auction started. Highest bid wins when all other players pass.")

	_announce_turn(true)


func get_current_player_index() -> int:
	if state != State.RUNNING or participants.is_empty():
		return -1
	return participants[turn_index]


func submit_increment(increment: int) -> void:
	# UI sends +10/+50/+100; interpret as "raise current high bid"
	if state != State.RUNNING:
		return
	submit_bid(high_bid + increment)


func submit_bid(amount: int) -> bool:
	if state != State.RUNNING:
		return false

	var p_idx := get_current_player_index()
	if p_idx == -1:
		return false

	var min_required: int
	if high_bidder_index != -1:
		min_required = high_bid + min_increment
	else:
		min_required = maxi(high_bid + min_increment, min_increment)


	if amount < min_required:
		emit_signal("message", "Bid must be at least $" + str(min_required) + ".")
		return false

	var money := GameController.get_player_balance(p_idx)
	if amount > money:
		emit_signal("message", "You only have $" + str(money) + ". Try a lower bid.")
		return false

	# Accept bid
	high_bid = amount
	high_bidder_index = p_idx
	passed.clear() # reset: everyone is back in after a new high bid

	emit_signal("bid_updated", high_bid, high_bidder_index)

	# After a bid, advance to next eligible player
	_advance_turn()

	return true


func pass_turn() -> void:
	if state != State.RUNNING:
		return

	var p_idx := get_current_player_index()
	if p_idx == -1:
		return

	if high_bidder_index != -1 and p_idx == high_bidder_index:
		_end_auction()
		return

	passed[p_idx] = true
	emit_signal("message", GameState.players[p_idx].player_name + " passes.")

	# Check if auction should end now
	if _should_end_auction():
		_end_auction()
		return

	_advance_turn()


func _announce_turn(initial: bool = false) -> void:
	if participants.is_empty():
		_finish_auction()
		return

	var p_idx := get_current_player_index()
	emit_signal("turn_changed", p_idx)




func _finish_auction() -> void:
	var winner_index := high_bidder_index

	var property_name := "Space %d" % space_num
	var space_info := SpaceDataRef.get_space_info(space_num)
	if space_info.has("name"):
		var candidate := str(space_info["name"]).strip_edges()
		if candidate != "":
			property_name = candidate

	# If nobody ever bid, treat as no winner
	if winner_index == -1 or high_bid <= 0:
		GameController.log_transaction("Auction ended with no bids. %s remains unowned." % property_name)
		emit_signal("message", "Auction ended with no valid bids.")
		emit_signal("auction_ended", -1, 0, space_num, property_ref)
		_reset()
		return

	# Only winner pays
	GameController.debit(winner_index, high_bid, "auction win")

	# Transfer ownership if ownable
	if property_ref is Ownable:
		(property_ref as Ownable).set_property_owner(winner_index)
		GameController.property_ownership_changed.emit()

	var winner_name := GameController.get_player_log_name(winner_index)

	GameController.log_transaction("%s won the auction for %s for $%d." % [winner_name, property_name, high_bid])

	emit_signal("message", GameState.players[winner_index].player_name + " wins for $" + str(high_bid) + "!")
	emit_signal("auction_ended", winner_index, high_bid, space_num, property_ref)

	_reset()



func _reset() -> void:
	state = State.IDLE
	space_num = -1
	property_ref = null
	participants.clear()
	active.clear()
	turn_index = 0
	high_bid = 0
	high_bidder_index = -1
	min_increment = 10
	passed.clear()


func _is_passed(player_index: int) -> bool:
	return passed.has(player_index)


func _should_end_auction() -> bool:
	# If nobody ever bid, auction only ends when all players passed
	if high_bidder_index == -1:
		for p in participants:
			if not _is_passed(p):
				return false
		return true

	# Otherwise, end when everyone except high bidder has passed
	for p in participants:
		if p == high_bidder_index:
			continue
		if not _is_passed(p):
			return false
	return true


func _end_auction() -> void:
	_finish_auction()


func _advance_turn() -> void:
	if participants.is_empty():
		_end_auction()
		return

	# If there's already a high bidder and everyone else has passed,
	# end immediately instead of cycling back to the high bidder.
	if high_bidder_index != -1 and _should_end_auction():
		_end_auction()
		return

	var safety := 0
	while safety < participants.size():
		turn_index = (turn_index + 1) % participants.size()
		var next_idx: int = participants[turn_index]

		# Skip anyone who has passed
		if not _is_passed(next_idx):
			_announce_turn()
			return

		safety += 1


	_end_auction()

extends GameSpace

class_name Ownable

var _is_owned: bool = false
var _player_owner: int = 0


func is_owned() -> bool:
	return _is_owned


func get_property_owner() -> int:
	return _player_owner


func set_property_owner(player_id: int) -> void:
	_player_owner = player_id
	_is_owned = true


func clear_property_owner() -> void:
	_player_owner = 0
	_is_owned = false

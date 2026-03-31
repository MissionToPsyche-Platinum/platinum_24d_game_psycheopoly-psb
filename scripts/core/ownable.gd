extends GameSpace

class_name Ownable

const NO_OWNER: int = -1

var _is_owned: bool = false
var _player_owner: int = NO_OWNER
var _is_mortgaged: bool = false


func is_owned() -> bool:
	return _is_owned


func is_mortgaged() -> bool:
	return _is_mortgaged


func get_property_owner() -> int:
	return _player_owner


func set_property_owner(player_id: int) -> void:
	_player_owner = player_id
	_is_owned = true


func clear_property_owner() -> void:
	_player_owner = NO_OWNER
	_is_owned = false
	_is_mortgaged = false

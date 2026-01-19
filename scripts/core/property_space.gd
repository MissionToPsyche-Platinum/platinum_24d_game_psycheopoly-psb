extends Ownable

class_name PropertySpace

var _initial_price: int
var _default_rent: int
var _rent_upgrade1: int
var _rent_upgrade2: int
var _rent_upgrade3: int
var _rent_upgrade4: int
var _current_upgrades: int
var _upgrade_cost: int
var _mortgage_value: int

func _init(
	space_name: String,
	initial_price: int,
	default_rent: int,
	rent_upgrade1: int,
	rent_upgrade2: int,
	rent_upgrade3: int,
	rent_upgrade4: int,
	upgrade_cost: int,
	mortgage_value: int
) -> void:
	_space_name = space_name
	_initial_price = initial_price
	_default_rent = default_rent
	_rent_upgrade1 = rent_upgrade1
	_rent_upgrade2 = rent_upgrade2
	_rent_upgrade3 = rent_upgrade3
	_rent_upgrade4 = rent_upgrade4
	_upgrade_cost = upgrade_cost
	_mortgage_value = mortgage_value
	
	_current_upgrades = 0

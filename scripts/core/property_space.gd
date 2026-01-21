extends Ownable

class_name PropertySpace

var _initial_price: int
var _default_rent: int
var _one_data_rent: int
var _two_data_rent: int
var _three_data_rent: int
var _four_data_rent: int
var _discovery_rent: int
var _upgrade_cost: int
var _mortgage_value: int

var _current_upgrades: int

func _init(
	space_name: String,
	space_description: String,
	initial_price: int,
	default_rent: int,
	one_data_rent: int,
	two_data_rent: int,
	three_data_rent: int,
	four_data_rent: int,
	discovery_rent: int,
	upgrade_cost: int,
	mortgage_value: int,
	color: Color

) -> void:
	_space_name = space_name
	_space_description = space_description
	_initial_price = initial_price
	_default_rent = default_rent
	_one_data_rent = one_data_rent
	_two_data_rent = two_data_rent
	_three_data_rent = three_data_rent
	_four_data_rent = four_data_rent
	_discovery_rent = discovery_rent
	_upgrade_cost = upgrade_cost
	_mortgage_value = mortgage_value
	_color = color

	_current_upgrades = 0

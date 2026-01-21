extends Ownable

class_name PlanetSpace

var _initial_price: int
var _default_multiplier: int
var _two_planet_multiplier: int
var _mortgage_value: int

func _init(
	space_name: String,
	space_description: String,
	initial_price: int,
	default_multiplier: int,
	two_planet_multiplier: int,
	mortgage_value: int,
	color: Color

) -> void:
	_space_name = space_name
	_space_description = space_description
	_initial_price = initial_price
	_default_multiplier = default_multiplier
	_two_planet_multiplier = two_planet_multiplier
	_mortgage_value = mortgage_value
	_color = color

extends Ownable

class_name PlanetSpace

var _initial_price: int
var _default_multiplier: int
var _two_planet_multiplier: int
var _mortgage_value: int

func _init(data: Dictionary) -> void:
	super(data)
	_initial_price = data.get("price", 0)
	_default_multiplier = data.get("mult1Planet", 0)
	_two_planet_multiplier = data.get("mult2Planet", 0)
	_mortgage_value = data.get("mortgage", 0)

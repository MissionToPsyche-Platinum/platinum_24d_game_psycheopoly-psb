extends Node

class_name BaseProperty

var property_name : String
var default_rent : int
var rent_upgrade1 : int
var rent_upgrade2 : int
var rent_upgrade3 : int
var rent_upgrade4 : int
var upgrade_cost : int
var mortgage_value : int

# function constructor
func _init(_name: String, _default_rent: int, _rent_upgrade1: int, _rent_upgrade2: int, _rent_upgrade3: int, _rent_upgrade4: int, _upgrade_cost: int, _mortgage_value: int):
	property_name = _name
	default_rent = _default_rent
	rent_upgrade1 = _rent_upgrade1
	rent_upgrade2 = _rent_upgrade2
	rent_upgrade3 = _rent_upgrade3
	rent_upgrade4 = _rent_upgrade4
	upgrade_cost = _upgrade_cost
	mortgage_value = _mortgage_value
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

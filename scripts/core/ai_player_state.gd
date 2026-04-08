extends PlayerState

class_name AiPlayerState

var difficulty: String = "Normal" # AI difficuly, set this when the class is created depending on the settings

var current_property_value_multipliers: Array[float] # How much the AI "thinks" each property is worth, relative to base price 
# Each index corresponds to that game square
# Set this through AI manager and have it change dymaically throughout the game, adjusting also based on AI difficulty

var base_property_value_multipliers: Array[float] # Holds the base values for the property multipliers, 
# Allos the AI to favor certian properties over the coarse of a game 


var master_property_value_multiplier: float # holds a master value that affects how the AI sees every property at once

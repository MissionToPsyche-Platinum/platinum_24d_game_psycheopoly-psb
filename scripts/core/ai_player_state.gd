extends PlayerState

class_name AiPlayerState

var difficulty: String = "Normal" # AI difficuly, set this when the class is created depending on the settings

var property_values: Array[float] # How much the AI "thinks" each property is worth. 
# Each index corresponds to that game square
# Set this through AI manager and have it change dymaically throughout the game, adjusting also based on AI difficulty

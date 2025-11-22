extends Node

# ============================
#   GAME STATE
# ============================

const DIFFICULTY_EASY := "Easy"
const DIFFICULTY_NORMAL := "Normal"
const DIFFICULTY_HARD := "Hard"

var difficulty: String = DIFFICULTY_NORMAL

func set_difficulty(new_difficulty: String) -> void:
	difficulty = new_difficulty

extends Node

# Stores whether colorblind mode is enabled
var colorblind_mode: bool = false

# Signal that other systems can listen to
signal colorblind_mode_changed(enabled: bool)

func set_colorblind_mode(enabled: bool):
	colorblind_mode = enabled
	colorblind_mode_changed.emit(enabled)

func is_colorblind_enabled() -> bool:
	return colorblind_mode

	

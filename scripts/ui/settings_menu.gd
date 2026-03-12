extends Control
signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_slider: HSlider = %MusicSlider

@onready var master_value_label: Label = %MasterValueLabel
@onready var sfx_value_label: Label = %SfxValueLabel
@onready var music_value_label: Label = %MusicValueLabel

@onready var mute_check: CheckBox = %MuteCheck
@onready var close_button: Button = %CloseButton
@onready var colorblind_check: CheckBox =%ColorblindCheck


# Stores the user's previous volumes so we can restore them after unmuting
var _last_master_volume: float = 80
var _last_sfx_volume: float = 80
var _last_music_volume: float = 80


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Initialize labels immediately
	_update_master_label(master_slider.value)
	_update_sfx_label(sfx_slider.value)
	_update_music_label(music_slider.value)

	# Connect signals (updates when user drags)
	master_slider.value_changed.connect(_update_master_label)
	sfx_slider.value_changed.connect(_update_sfx_label)
	music_slider.value_changed.connect(_update_music_label)

	# Mute behavior
	mute_check.toggled.connect(_on_mute_toggled)

	# Close behavior
	close_button.pressed.connect(_on_close_pressed)
	colorblind_check.button_pressed = SettingsManager.is_colorblind_enabled()
	colorblind_check.toggled.connect(_on_colorblind_toggled)

func _update_master_label(v: float) -> void:
	master_value_label.text = str(int(round(v)))


func _update_sfx_label(v: float) -> void:
	sfx_value_label.text = str(int(round(v)))


func _update_music_label(v: float) -> void:
	music_value_label.text = str(int(round(v)))


func _on_mute_toggled(is_muted: bool) -> void:
	if is_muted:
		# Store current values so we can restore later
		_last_master_volume = master_slider.value
		_last_sfx_volume = sfx_slider.value
		_last_music_volume = music_slider.value

		# Force volumes to zero (labels update automatically via signals)
		master_slider.value = 0
		sfx_slider.value = 0
		music_slider.value = 0

		# Disable sliders
		master_slider.editable = false
		sfx_slider.editable = false
		music_slider.editable = false
	else:
		# Restore previous values
		master_slider.value = _last_master_volume
		sfx_slider.value = _last_sfx_volume
		music_slider.value = _last_music_volume

		# Re-enable sliders
		master_slider.editable = true
		sfx_slider.editable = true
		music_slider.editable = true

func _on_colorblind_toggled(enabled: bool) -> void:
	SettingsManager.set_colorblind_mode(enabled)
	print("Colorblind mode:", enabled)
	
func _on_close_pressed() -> void:
	hide()
	closed.emit()

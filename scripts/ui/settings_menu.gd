extends Control
signal closed

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var settings_background: TextureRect = $SettingsBackground
@onready var panel: PanelContainer = $Panel
@onready var padding: Control = $Panel/Padding
@onready var content: Control = $Panel/Padding/Content
@onready var gameplay_grid: Control = %GameplayGrid
@onready var audio_grid: Control = %AudioGrid
@onready var accessibility_box: Control = %AccessibilityBox

# Audio controls
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_slider: HSlider = %MusicSlider

@onready var master_value_label: Label = %MasterValueLabel
@onready var sfx_value_label: Label = %SfxValueLabel
@onready var music_value_label: Label = %MusicValueLabel

# Main controls
@onready var mute_check: CheckBox = %MuteCheck
@onready var close_button: Button = %CloseButton
@onready var colorblind_check: CheckBox = %ColorblindCheck

@onready var computer_difficulty_option: OptionButton = %DifficultyOption
@onready var computer_difficulty_popup: PopupMenu = computer_difficulty_option.get_popup()

var _last_master_volume: float = 80.0
var _last_sfx_volume: float = 80.0
var _last_music_volume: float = 80.0

# Tracks whether this settings menu is being used while the game is paused
var _pause_context: bool = false


func _ready() -> void:
	# Default to normal behavior (Start Menu-safe)
	process_mode = Node.PROCESS_MODE_INHERIT

	# Root overlay fills parent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	# Root allows children to receive input
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL

	# Z-order safety

	if dim_overlay:
		dim_overlay.z_index = 0
	if settings_background:
		settings_background.z_index = 1
	if panel:
		panel.z_index = 10

	# Full-screen dim blocker

	if dim_overlay:
		dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim_overlay.offset_left = 0
		dim_overlay.offset_top = 0
		dim_overlay.offset_right = 0
		dim_overlay.offset_bottom = 0
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Decorative background only

	if settings_background:
		settings_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		settings_background.offset_left = 0
		settings_background.offset_top = 0
		settings_background.offset_right = 0
		settings_background.offset_bottom = 0
		settings_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Layout containers 

	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
	if padding:
		padding.mouse_filter = Control.MOUSE_FILTER_PASS
	if content:
		content.mouse_filter = Control.MOUSE_FILTER_PASS
	if gameplay_grid:
		gameplay_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	if audio_grid:
		audio_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	if accessibility_box:
		accessibility_box.mouse_filter = Control.MOUSE_FILTER_PASS

	hide()

	# Load current audio settings from AudioManager
	# AudioManager uses 0.0 - 1.0, sliders use 0 - 100
	_load_audio_settings_into_ui()

	# Initial UI sync
	colorblind_check.button_pressed = SettingsManager.is_colorblind_enabled()

	# If all 3 are basically 0, reflect mute state
	mute_check.button_pressed = (
		master_slider.value <= 0.001
		and sfx_slider.value <= 0.001
		and music_slider.value <= 0.001
	)

	
	# Signal hookups

	if not master_slider.value_changed.is_connected(_on_master_slider_changed):
		master_slider.value_changed.connect(_on_master_slider_changed)

	if not sfx_slider.value_changed.is_connected(_on_sfx_slider_changed):
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	if not music_slider.value_changed.is_connected(_on_music_slider_changed):
		music_slider.value_changed.connect(_on_music_slider_changed)

	if not mute_check.toggled.is_connected(_on_mute_toggled):
		mute_check.toggled.connect(_on_mute_toggled)

	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if not colorblind_check.toggled.is_connected(_on_colorblind_toggled):
		colorblind_check.toggled.connect(_on_colorblind_toggled)

	if not computer_difficulty_popup.index_pressed.is_connected(_on_difficulty_changed):
		computer_difficulty_popup.index_pressed.connect(_on_difficulty_changed)


# opwn and close menu for both pause menu and start screen

func open(is_pause_context: bool = false) -> void:
	_pause_context = is_pause_context

	# Refresh values every time menu opens in case something changed elsewhere
	_load_audio_settings_into_ui()
	colorblind_check.button_pressed = SettingsManager.is_colorblind_enabled()

	# If opened while the game is paused, this menu must still process input
	if _pause_context:
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT

	show()
	move_to_front()

	# Make sure controls can grab focus after showing
	await get_tree().process_frame

	if close_button:
		close_button.grab_focus()


func close_menu() -> void:
	hide()
	closed.emit()


# Audio settings loading

func _load_audio_settings_into_ui() -> void:
	# Convert AudioManager linear values (0.0-1.0) to slider values (0-100)
	var master_percent := AudioManager.get_master_volume() * 100.0
	var sfx_percent := AudioManager.get_sfx_volume() * 100.0
	var music_percent := AudioManager.get_music_volume() * 100.0

	# Temporarily block signals to avoid firing value_changed during setup
	master_slider.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	music_slider.set_block_signals(true)

	master_slider.value = master_percent
	sfx_slider.value = sfx_percent
	music_slider.value = music_percent

	master_slider.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	music_slider.set_block_signals(false)

	_update_master_label(master_slider.value)
	_update_sfx_label(sfx_slider.value)
	_update_music_label(music_slider.value)

	# Cache for mute restore
	_last_master_volume = master_slider.value
	_last_sfx_volume = sfx_slider.value
	_last_music_volume = music_slider.value

	# Update mute checkbox state without triggering logic
	mute_check.set_block_signals(true)
	mute_check.button_pressed = (
		master_slider.value <= 0.001
		and sfx_slider.value <= 0.001
		and music_slider.value <= 0.001
	)
	mute_check.set_block_signals(false)

	# Re-enable slider editability appropriately
	var is_muted := mute_check.button_pressed
	master_slider.editable = not is_muted
	sfx_slider.editable = not is_muted
	music_slider.editable = not is_muted


func _on_difficulty_changed(index: int) -> void:
	GameController.set_difficulty(computer_difficulty_option.get_item_text(index))

# Slider handlers

func _on_master_slider_changed(v: float) -> void:
	_update_master_label(v)

	# Convert 0-100 -> 0.0-1.0
	AudioManager.set_master_volume(v / 100.0)

	# If user manually raises any slider, uncheck mute
	_sync_mute_checkbox_from_sliders()


func _on_sfx_slider_changed(v: float) -> void:
	_update_sfx_label(v)

	# SFX slider should affect BOTH SFX and UI buses
	# so clicks/menu sounds stay consistent with "SFX Volume"
	var linear := v / 100.0
	AudioManager.set_sfx_volume(linear)
	AudioManager.set_ui_volume(linear)

	_sync_mute_checkbox_from_sliders()


func _on_music_slider_changed(v: float) -> void:
	_update_music_label(v)

	AudioManager.set_music_volume(v / 100.0)

	_sync_mute_checkbox_from_sliders()



# Label updates

func _update_master_label(v: float) -> void:
	master_value_label.text = str(int(round(v)))


func _update_sfx_label(v: float) -> void:
	sfx_value_label.text = str(int(round(v)))


func _update_music_label(v: float) -> void:
	music_value_label.text = str(int(round(v)))

# Mute logic

func _on_mute_toggled(is_muted: bool) -> void:
	if is_muted:
		# Only save restore values if we're not already at zero
		if master_slider.value > 0.001:
			_last_master_volume = master_slider.value
		if sfx_slider.value > 0.001:
			_last_sfx_volume = sfx_slider.value
		if music_slider.value > 0.001:
			_last_music_volume = music_slider.value

		master_slider.value = 0
		sfx_slider.value = 0
		music_slider.value = 0

		master_slider.editable = false
		sfx_slider.editable = false
		music_slider.editable = false
	else:
		master_slider.value = _last_master_volume
		sfx_slider.value = _last_sfx_volume
		music_slider.value = _last_music_volume

		master_slider.editable = true
		sfx_slider.editable = true
		music_slider.editable = true


func _sync_mute_checkbox_from_sliders() -> void:
	var all_zero := (
		master_slider.value <= 0.001
		and sfx_slider.value <= 0.001
		and music_slider.value <= 0.001
	)

	# Prevent recursive toggled calls
	mute_check.set_block_signals(true)
	mute_check.button_pressed = all_zero
	mute_check.set_block_signals(false)

	# If not muted anymore, make sure sliders are editable
	if not all_zero:
		master_slider.editable = true
		sfx_slider.editable = true
		music_slider.editable = true


# Accessibility

func _on_colorblind_toggled(enabled: bool) -> void:
	SettingsManager.set_colorblind_mode(enabled)
	print("Colorblind mode:", enabled)


func _on_close_pressed() -> void:
	close_menu()

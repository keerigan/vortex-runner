extends "res://scripts/biome_overhaul.gd"

const MUSIC_TRACKS: Array[String] = [
	"res://assets/music/Beyond_The_Barrier.ogg",
	"res://assets/music/Gravity_Horizon.ogg",
	"res://assets/music/Gravity_Break.ogg",
	"res://assets/music/Velocity_of_Starlight.ogg",
	"res://assets/music/Vortex_Escape.ogg",
	"res://assets/music/Warp_Gate_Velocity.ogg",
	"res://assets/music/Sector_Seven_Breach.ogg",
]
const MUSIC_CONFIG := "user://audio.cfg"

var music_player: AudioStreamPlayer
var music_enabled := true
var music_volume := 0.65
var music_index := 0
var music_panel: PanelContainer
var music_button: Button
var music_toggle: CheckButton
var music_slider: HSlider
var music_track_label: Label

func _ready() -> void:
	super._ready()
	_load_music_settings()
	_setup_music_player()
	_build_music_controls()
	_play_track(0)

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)
	_apply_music_settings()

func _load_music_settings() -> void:
	var config := ConfigFile.new()
	if config.load(MUSIC_CONFIG) == OK:
		music_enabled = bool(config.get_value("music", "enabled", true))
		music_volume = clampf(float(config.get_value("music", "volume", 0.65)), 0.0, 1.0)

func _save_music_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("music", "enabled", music_enabled)
	config.set_value("music", "volume", music_volume)
	config.save(MUSIC_CONFIG)

func _apply_music_settings() -> void:
	if music_player == null:
		return
	music_player.volume_db = linear_to_db(maxf(music_volume, 0.001))
	music_player.stream_paused = not music_enabled

func _play_track(index: int) -> void:
	if MUSIC_TRACKS.is_empty() or music_player == null:
		return
	music_index = posmod(index, MUSIC_TRACKS.size())
	var path := MUSIC_TRACKS[music_index]
	if not ResourceLoader.exists(path):
		push_warning("Music track missing: %s" % path)
		_update_track_label()
		return
	music_player.stream = load(path) as AudioStream
	music_player.play()
	_apply_music_settings()
	_update_track_label()

func _on_music_finished() -> void:
	_play_track(music_index + 1)

func _track_name() -> String:
	return MUSIC_TRACKS[music_index].get_file().get_basename().replace("_", " ")

func _update_track_label() -> void:
	if music_track_label:
		music_track_label.text = "♪  " + _track_name()

func _build_music_controls() -> void:
	var layer: CanvasLayer = null
	for child in get_children():
		if child is CanvasLayer:
			layer = child
			break
	if layer == null:
		return

	music_button = Button.new()
	music_button.text = "♫"
	music_button.position = Vector2(470, 24)
	music_button.size = Vector2(48, 48)
	music_button.add_theme_font_size_override("font_size", 24)
	music_button.pressed.connect(_toggle_music_panel)
	layer.add_child(music_button)

	music_panel = PanelContainer.new()
	music_panel.position = Vector2(235, 82)
	music_panel.size = Vector2(283, 205)
	music_panel.visible = false
	layer.add_child(music_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	music_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "MUSIQUE"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	music_toggle = CheckButton.new()
	music_toggle.text = "Activée"
	music_toggle.button_pressed = music_enabled
	music_toggle.toggled.connect(_on_music_toggled)
	box.add_child(music_toggle)

	var volume_row := HBoxContainer.new()
	box.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = "Volume"
	volume_label.custom_minimum_size.x = 72
	volume_row.add_child(volume_label)
	music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = music_volume * 100.0
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_volume_changed)
	volume_row.add_child(music_slider)

	music_track_label = Label.new()
	music_track_label.clip_text = true
	music_track_label.custom_minimum_size = Vector2(245, 28)
	box.add_child(music_track_label)

	var next_button := Button.new()
	next_button.text = "Morceau suivant  ›"
	next_button.pressed.connect(_on_next_track)
	box.add_child(next_button)
	_update_track_label()

func _toggle_music_panel() -> void:
	music_panel.visible = not music_panel.visible

func _on_music_toggled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_music_settings()
	_save_music_settings()

func _on_music_volume_changed(value: float) -> void:
	music_volume = clampf(value / 100.0, 0.0, 1.0)
	_apply_music_settings()
	_save_music_settings()

func _on_next_track() -> void:
	_play_track(music_index + 1)

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 3.4 // AUDIO"

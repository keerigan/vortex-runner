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
var crash_player: AudioStreamPlayer
var music_enabled := true
var music_volume := 0.65
var music_index := 0
var music_panel: PanelContainer
var music_button: Button
var music_toggle: CheckButton
var music_slider: HSlider
var music_track_label: Label
var music_volume_label: Label

func _ready() -> void:
	super._ready()
	_load_music_settings()
	_setup_music_player()
	_setup_crash_player()
	_build_music_controls()
	_play_track(0)

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)
	_apply_music_settings()

func _setup_crash_player() -> void:
	crash_player = AudioStreamPlayer.new()
	crash_player.name = "CrashPlayer"
	crash_player.stream = _make_crash_sound()
	crash_player.volume_db = -2.0
	add_child(crash_player)

func _make_crash_sound() -> AudioStreamWAV:
	# Short synthesized impact/explosion so the game has a crash SFX without another asset.
	var sample_rate := 22050
	var duration := 0.72
	var frame_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in range(frame_count):
		var t := float(i) / float(sample_rate)
		var decay := pow(maxf(0.0, 1.0 - t / duration), 2.2)
		var thump := sin(TAU * (72.0 - t * 35.0) * t) * 0.72
		var metal := sin(TAU * 310.0 * t) * exp(-t * 8.5) * 0.20
		var noise := randf_range(-1.0, 1.0) * 0.65
		var sample := clampf((thump + metal + noise) * decay, -1.0, 1.0)
		var value := int(sample * 32767.0)
		data[i * 2] = value & 0xff
		data[i * 2 + 1] = (value >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

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
	if alive:
		_play_track(music_index + 1)

func _track_name() -> String:
	return MUSIC_TRACKS[music_index].get_file().get_basename().replace("_", " ")

func _update_track_label() -> void:
	if music_track_label:
		music_track_label.text = "♪  " + _track_name()
	if music_volume_label:
		music_volume_label.text = "%d %%" % int(round(music_volume * 100.0))

func _build_music_controls() -> void:
	var layer: CanvasLayer = null
	for child in get_children():
		if child is CanvasLayer:
			layer = child
			break
	if layer == null:
		return

	# Larger button, anchored visually against the right edge of the 540px viewport.
	music_button = Button.new()
	music_button.text = "♫"
	music_button.position = Vector2(456, 20)
	music_button.size = Vector2(64, 64)
	music_button.add_theme_font_size_override("font_size", 30)
	music_button.pressed.connect(_toggle_music_panel)
	layer.add_child(music_button)

	# Larger touch-friendly menu, aligned to the right.
	music_panel = PanelContainer.new()
	music_panel.position = Vector2(118, 96)
	music_panel.size = Vector2(402, 290)
	music_panel.visible = false
	layer.add_child(music_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	music_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title := Label.new()
	title.text = "MUSIQUE"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 42)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(_toggle_music_panel)
	title_row.add_child(close_button)

	music_toggle = CheckButton.new()
	music_toggle.text = "Musique activée"
	music_toggle.button_pressed = music_enabled
	music_toggle.custom_minimum_size.y = 46
	music_toggle.add_theme_font_size_override("font_size", 18)
	music_toggle.toggled.connect(_on_music_toggled)
	box.add_child(music_toggle)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	box.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = "Volume"
	volume_label.custom_minimum_size.x = 78
	volume_label.add_theme_font_size_override("font_size", 17)
	volume_row.add_child(volume_label)
	music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = music_volume * 100.0
	music_slider.custom_minimum_size = Vector2(190, 42)
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_volume_changed)
	volume_row.add_child(music_slider)
	music_volume_label = Label.new()
	music_volume_label.custom_minimum_size.x = 54
	music_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(music_volume_label)

	music_track_label = Label.new()
	music_track_label.clip_text = true
	music_track_label.custom_minimum_size = Vector2(350, 34)
	music_track_label.add_theme_font_size_override("font_size", 16)
	box.add_child(music_track_label)

	var next_button := Button.new()
	next_button.text = "Morceau suivant  ›"
	next_button.custom_minimum_size.y = 48
	next_button.add_theme_font_size_override("font_size", 17)
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
	_update_track_label()

func _on_next_track() -> void:
	_play_track(music_index + 1)

func _hit(body: Node) -> void:
	var was_alive := alive
	super._hit(body)
	if was_alive and not alive:
		if music_player:
			music_player.stop()
		if crash_player:
			crash_player.play()
		if music_panel:
			music_panel.visible = false

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 3.5 // AUDIO+"

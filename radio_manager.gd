# radio_manager.gd
# Disc Golf Empire Radio: persistent compact player and expandable controls.
extends CanvasLayer

const MUSIC_DIRECTORY := "res://music"
const SETTINGS_FILE := "user://radio_settings.cfg"
const UI_SCALE := 1.61

var tracks: Array[String] = []
var current_index: int = -1
var shuffle_enabled: bool = false
var loop_enabled: bool = false
var music_volume: float = 0.65
var expanded: bool = false
var docked_to_toolbar := true
var player: AudioStreamPlayer
var panel: PanelContainer
var heading_button: Button
var track_label: Label
var details_label: Label
var compact_play_button: Button
var expanded_play_button: Button
var shuffle_button: Button
var loop_button: Button
var volume_slider: HSlider
var extra_controls: VBoxContainer
var randomizer := RandomNumberGenerator.new()

func _ready() -> void:
	randomizer.randomize()
	load_preferences()
	build_interface()
	load_playlist()
	if not tracks.is_empty():
		play_track(0)
	else:
		track_label.text = "No music found"
		details_label.text = "Add tracks to res://music/"
	refresh_buttons()

func load_playlist() -> void:
	tracks.clear()
	var directory: DirAccess = DirAccess.open(MUSIC_DIRECTORY)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var filename: String = directory.get_next()
		if filename.is_empty():
			break
		if directory.current_is_dir():
			continue
		var extension: String = filename.get_extension().to_lower()
		if extension == "mp3" or extension == "ogg" or extension == "wav":
			tracks.append(MUSIC_DIRECTORY.path_join(filename))
	directory.list_dir_end()
	tracks.sort()

func build_interface() -> void:
	player = AudioStreamPlayer.new()
	player.name = "RadioAudio"
	player.finished.connect(_on_track_finished)
	add_child(player)
	update_volume()

	var overlay := Control.new()
	overlay.name = "RadioOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Right edge, around the middle of the screen: clear of the top HUD.
	panel = PanelContainer.new()
	panel.name = "PersistentRadio"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.38
	panel.anchor_bottom = 0.38
	panel.offset_left = -535.0
	panel.offset_right = -16.0
	panel.offset_top = 0.0
	panel.offset_bottom = 137.0
	panel.custom_minimum_size = Vector2(519.0, 137.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	panel.visible = false

	# Calm park chrome (matches HUD / CourseUI).
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.95, 0.90, 1.0)
	style.border_color = Color(0.40, 0.60, 0.40, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.18, 0.22, 0.16, 0.28)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	heading_button = Button.new()
	heading_button.text = "  Park Radio"
	heading_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading_button.add_theme_font_size_override("font_size", 16)
	heading_button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94, 1.0))
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.26, 0.46, 0.30, 1.0)
	title_style.border_width_top = 2
	title_style.border_width_bottom = 1
	title_style.border_color = Color(0.58, 0.72, 0.54, 1.0)
	title_style.set_corner_radius_all(10)
	title_style.content_margin_left = 12
	title_style.content_margin_right = 10
	title_style.content_margin_top = 8
	title_style.content_margin_bottom = 8
	heading_button.add_theme_stylebox_override("normal", title_style)
	heading_button.add_theme_stylebox_override("hover", title_style)
	heading_button.add_theme_stylebox_override("pressed", title_style)
	heading_button.pressed.connect(toggle_expanded)
	stack.add_child(heading_button)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 10)
	stack.add_child(main_row)

	var track_column := VBoxContainer.new()
	track_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.add_child(track_column)

	track_label = Label.new()
	track_label.text = "Disc Golf Empire Radio"
	track_label.clip_text = true
	track_label.add_theme_font_size_override("font_size", 20)
	track_label.add_theme_color_override("font_color", Color(0.18, 0.22, 0.18, 1.0))
	track_column.add_child(track_label)

	details_label = Label.new()
	details_label.text = "Original Game Soundtrack"
	details_label.clip_text = true
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", Color(0.40, 0.44, 0.38, 1.0))
	track_column.add_child(details_label)

	var mini_controls := HBoxContainer.new()
	mini_controls.add_theme_constant_override("separation", 3)
	main_row.add_child(mini_controls)
	add_transport_button(mini_controls, "◀◀", previous_track)
	compact_play_button = add_transport_button(mini_controls, "Ⅱ", toggle_pause)
	add_transport_button(mini_controls, "▶▶", next_track)

	extra_controls = VBoxContainer.new()
	extra_controls.visible = false
	extra_controls.add_theme_constant_override("separation", 9)
	stack.add_child(extra_controls)

	var separator := HSeparator.new()
	extra_controls.add_child(separator)

	var label := Label.new()
	label.text = "Playback"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.40, 0.44, 0.38, 1.0))
	extra_controls.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	extra_controls.add_child(row)
	add_transport_button(row, "◀ Previous", previous_track)
	expanded_play_button = add_transport_button(row, "Ⅱ Pause", toggle_pause)
	add_transport_button(row, "Next ▶", next_track)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	extra_controls.add_child(modes)
	shuffle_button = add_transport_button(modes, "Shuffle: Off", toggle_shuffle)
	loop_button = add_transport_button(modes, "Repeat: Off", toggle_loop)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 10)
	extra_controls.add_child(volume_row)
	var volume_text := Label.new()
	volume_text.text = "Music volume"
	volume_text.add_theme_font_size_override("font_size", 14)
	volume_text.add_theme_color_override("font_color", Color(0.18, 0.22, 0.18, 1.0))
	volume_row.add_child(volume_text)
	volume_slider = HSlider.new()
	volume_slider.custom_minimum_size = Vector2(252.0, 45.0)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = music_volume
	volume_slider.value_changed.connect(set_music_volume)
	volume_row.add_child(volume_slider)

func add_transport_button(parent: HBoxContainer, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(64.0, 48.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.16, 0.20, 0.16, 1.0))
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.91, 0.87, 0.76, 1.0)
	face.border_color = Color(0.80, 0.74, 0.60, 0.90)
	face.set_border_width_all(1)
	face.set_corner_radius_all(10)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 6
	face.content_margin_bottom = 6
	face.shadow_color = Color(0.20, 0.22, 0.16, 0.12)
	face.shadow_size = 3
	face.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("normal", face)
	var hover := face.duplicate()
	hover.bg_color = Color(0.70, 0.82, 0.58, 1.0)
	hover.border_color = Color(0.52, 0.68, 0.42, 1.0)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func toggle_expanded() -> void:
	expanded = not expanded
	extra_controls.visible = expanded
	heading_button.text = "  Park Radio  ·  close" if expanded else "  Park Radio"
	if docked_to_toolbar:
		panel.visible = expanded
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 0.0
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var left_edge: float = minf(580.0, viewport_size.x * 0.47)
		var panel_width: float = minf(649.0, maxf(300.0, viewport_size.x - left_edge - 16.0))
		panel.offset_left = left_edge
		panel.offset_right = left_edge + panel_width
		panel.offset_top = minf(viewport_size.y * 0.38, viewport_size.y - 360.0)
		panel.offset_bottom = panel.offset_top + 330.0
		panel.custom_minimum_size = Vector2.ZERO
	else:
		panel.offset_left = -665.0 if expanded else -535.0
		panel.custom_minimum_size.x = 649.0 if expanded else 519.0

func play_track(index: int) -> void:
	if tracks.is_empty() or player == null:
		return
	var next_index: int = posmod(index, tracks.size())
	var stream_resource: Resource = load(tracks[next_index])
	if not (stream_resource is AudioStream):
		push_warning("Disc Golf Empire Radio: Unable to load " + tracks[next_index])
		return
	current_index = next_index
	player.stream = stream_resource as AudioStream
	player.stream_paused = false
	# Dummy/no-device drivers can error on play(); keep UI usable either way.
	player.play()
	if track_label != null:
		track_label.text = tracks[current_index].get_file().get_basename().replace("_", " ")
	if details_label != null:
		details_label.text = "Track %d of %d  •  Original Game Soundtrack" % [current_index + 1, tracks.size()]
	refresh_buttons()

func _on_track_finished() -> void:
	if loop_enabled:
		play_track(current_index)
	else:
		next_track()

func next_track() -> void:
	if tracks.is_empty():
		return
	if shuffle_enabled and tracks.size() > 1:
		play_track(current_index + randomizer.randi_range(1, tracks.size() - 1))
	else:
		play_track(current_index + 1)

func previous_track() -> void:
	if not tracks.is_empty():
		play_track(current_index - 1)

func toggle_pause() -> void:
	if player.stream == null:
		return
	player.stream_paused = not player.stream_paused
	refresh_buttons()

func toggle_shuffle() -> void:
	shuffle_enabled = not shuffle_enabled
	refresh_buttons()
	save_preferences()

func toggle_loop() -> void:
	loop_enabled = not loop_enabled
	refresh_buttons()
	save_preferences()

func refresh_buttons() -> void:
	var paused: bool = player != null and player.stream_paused
	if compact_play_button != null:
		compact_play_button.text = "▶" if paused else "Ⅱ"
	if expanded_play_button != null:
		expanded_play_button.text = "▶ Play" if paused else "Ⅱ Pause"
	if shuffle_button != null:
		shuffle_button.text = "Shuffle: On" if shuffle_enabled else "Shuffle: Off"
	if loop_button != null:
		loop_button.text = "Repeat: On" if loop_enabled else "Repeat: Off"

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	update_volume()
	save_preferences()

func update_volume() -> void:
	if player != null:
		player.volume_db = linear_to_db(maxf(music_volume, 0.0001))

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		music_volume = clampf(float(config.get_value("radio", "volume", 0.65)), 0.0, 1.0)
		shuffle_enabled = bool(config.get_value("radio", "shuffle", false))
		loop_enabled = bool(config.get_value("radio", "loop", false))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("radio", "volume", music_volume)
	config.set_value("radio", "shuffle", shuffle_enabled)
	config.set_value("radio", "loop", loop_enabled)
	config.save(SETTINGS_FILE)

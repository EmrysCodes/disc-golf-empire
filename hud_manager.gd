# Disc Golf Empire — Calm Management HUD
# Beautiful park chrome: soft greens, sand, cream; layered panels; clear verbs.
# Reuses CourseUI / radio callbacks — gameplay wiring unchanged.
extends CanvasLayer

# ------------------------------------------------------------
# CALM CARTOONY PARK PALETTE
# ------------------------------------------------------------

const CREAM := Color(0.97, 0.95, 0.90, 1.0)
const CREAM_WARM := Color(0.95, 0.92, 0.84, 1.0)
const SAND := Color(0.91, 0.87, 0.76, 1.0)
const SAND_DEEP := Color(0.80, 0.74, 0.60, 1.0)
const LEAF := Color(0.40, 0.60, 0.40, 1.0)
const LEAF_DEEP := Color(0.26, 0.46, 0.30, 1.0)
const MOSS := Color(0.58, 0.72, 0.54, 1.0)
const MOSS_SOFT := Color(0.78, 0.86, 0.70, 1.0)
const INSET := Color(0.94, 0.96, 0.91, 1.0)
const INK := Color(0.16, 0.20, 0.16, 1.0)
const MUTED := Color(0.38, 0.42, 0.36, 1.0)
const MONEY := Color(0.14, 0.40, 0.22, 1.0)
const ACTIVE := Color(0.70, 0.82, 0.58, 1.0)
const ACTIVE_DEEP := Color(0.52, 0.68, 0.42, 1.0)
const DANGER := Color(0.62, 0.28, 0.24, 1.0)
const TITLE_TEXT := Color(0.98, 0.98, 0.94, 1.0)
const HIGHLIGHT := Color(1.0, 0.99, 0.94, 0.95)
const SHADOW := Color(0.18, 0.22, 0.16, 0.28)

const CORNER := 14
const CORNER_SM := 10
const TOUCH_H := 48.0

var ui
var course_manager
var economy_manager
var job_manager
var golfer_manager
var radio_manager
var camera_controller

var top_bar: PanelContainer
var bottom_bar: PanelContainer
var window_panel: PanelContainer
var window_title: Label
var window_body: VBoxContainer
var tip_label: Label
var park_label: Label
var money_label: Label
var guests_label: Label
var crew_label: Label
var hole_label: Label
var date_label: Label
var speed_buttons: Array = []
var dock_buttons: Dictionary = {}
var selected_tab := ""
var sim_speeds := [0.0, 1.0, 2.0, 4.0]
var speed_index := 1
var refresh_clock := 0.0
var play_seconds := 0.0

func setup(ui_ref, course_ref, economy_ref, job_ref, golfer_ref, radio_ref, camera_ref) -> void:
	layer = 40
	ui = ui_ref
	course_manager = course_ref
	economy_manager = economy_ref
	job_manager = job_ref
	golfer_manager = golfer_ref
	radio_manager = radio_ref
	camera_controller = camera_ref
	build_hud()
	# Calm HUD owns chrome; hide legacy CourseUI docks that fight the park view.
	if bottom_bar != null and top_bar != null and ui != null:
		if ui.top_panel != null:
			ui.top_panel.hide()
		if ui.empire_sidebar != null:
			ui.empire_sidebar.hide()
		if ui.tool_dock != null:
			ui.tool_dock.hide()
			ui.tool_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for panel_name in ["tooltip_panel", "pending_panel", "inspector_panel"]:
			if ui.get(panel_name) != null:
				var legacy = ui.get(panel_name)
				legacy.hide()
				legacy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout_hud)
	set_process(true)
	for arg in OS.get_cmdline_user_args():
		if str(arg).find("demo_build") >= 0:
			call_deferred("_toggle_tab", "Build")
			break


# ------------------------------------------------------------
# STYLE HELPERS
# ------------------------------------------------------------

func panel_style(face: Color = CREAM, margin: int = 8, radius: int = CORNER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	# Soft leaf frame with a lighter top edge for gentle depth (no harsh bevel).
	style.border_color = Color(LEAF.r, LEAF.g, LEAF.b, 0.42)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.shadow_color = SHADOW
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	return style

func inset_style(face: Color = INSET, margin: int = 6, accent: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = Color(SAND_DEEP.r, SAND_DEEP.g, SAND_DEEP.b, 0.70)
	style.set_border_width_all(1)
	if accent:
		style.border_width_left = 3
		style.border_color = Color(LEAF.r, LEAF.g, LEAF.b, 0.75)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = margin + (2 if accent else 0)
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func title_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LEAF_DEEP
	style.border_width_top = 2
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_bottom = 1
	style.border_color = MOSS
	style.corner_radius_top_left = CORNER
	style.corner_radius_top_right = CORNER
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MOSS_SOFT.r, MOSS_SOFT.g, MOSS_SOFT.b, 0.55)
	style.border_color = Color(LEAF.r, LEAF.g, LEAF.b, 0.35)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func helper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INSET
	style.border_color = Color(SAND_DEEP.r, SAND_DEEP.g, SAND_DEEP.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func button_style(active: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if pressed:
		style.bg_color = SAND_DEEP
		style.border_color = LEAF_DEEP
		style.set_border_width_all(2)
		style.shadow_size = 0
	elif active:
		style.bg_color = ACTIVE
		style.border_color = ACTIVE_DEEP
		style.set_border_width_all(2)
		style.shadow_color = Color(LEAF_DEEP.r, LEAF_DEEP.g, LEAF_DEEP.b, 0.22)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 1)
	else:
		style.bg_color = SAND
		style.border_color = Color(SAND_DEEP.r, SAND_DEEP.g, SAND_DEEP.b, 0.90)
		style.set_border_width_all(1)
		style.shadow_color = Color(0.20, 0.22, 0.16, 0.12)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 1)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func style_label(label: Label, size: int = 13, color: Color = INK, center: bool = false) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if center:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func make_button(label_text: String, callback: Callable, width: float = 84.0, height: float = 56.0) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", LEAF_DEEP)
	button.add_theme_color_override("font_pressed_color", DANGER)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", button_style(false, false))
	button.add_theme_stylebox_override("hover", button_style(true, false))
	button.add_theme_stylebox_override("pressed", button_style(false, true))
	button.add_theme_stylebox_override("focus", button_style(true, false))
	# pressed only — ScreenTouch + mouse emulation double-fires and closes menus.
	button.pressed.connect(callback)
	return button

func make_stat_box(caption: String) -> Dictionary:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", inset_style(INSET, 7, true))
	wrap.custom_minimum_size = Vector2(112, 48)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	wrap.add_child(column)
	var caption_label := Label.new()
	caption_label.text = caption.to_upper()
	style_label(caption_label, 10, MUTED, true)
	column.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = "—"
	style_label(value_label, 16, INK, true)
	column.add_child(value_label)
	return {"panel": wrap, "value": value_label}


# ------------------------------------------------------------
# BUILD
# ------------------------------------------------------------

func build_hud() -> void:
	_build_top_bar()
	_build_bottom_bar()
	_build_tool_window()
	_layout_hud()
	refresh_status()

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.name = "CalmStatusBar"
	top_bar.add_theme_stylebox_override("panel", panel_style(CREAM, 10, CORNER))
	add_child(top_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top_bar.add_child(row)

	var brand := PanelContainer.new()
	brand.add_theme_stylebox_override("panel", _brand_chip_style())
	brand.custom_minimum_size = Vector2(220, 48)
	row.add_child(brand)
	park_label = Label.new()
	park_label.text = "Disc Golf Empire"
	style_label(park_label, 15, TITLE_TEXT, true)
	brand.add_child(park_label)

	var money_box: Dictionary = make_stat_box("Cash")
	money_label = money_box["value"]
	money_label.add_theme_color_override("font_color", MONEY)
	money_box["panel"].custom_minimum_size = Vector2(136, 48)
	row.add_child(money_box["panel"])

	var guests_box: Dictionary = make_stat_box("Guests")
	guests_label = guests_box["value"]
	row.add_child(guests_box["panel"])

	var crew_box: Dictionary = make_stat_box("Crew")
	crew_label = crew_box["value"]
	row.add_child(crew_box["panel"])

	var hole_box: Dictionary = make_stat_box("Hole")
	hole_label = hole_box["value"]
	row.add_child(hole_box["panel"])

	var date_box: Dictionary = make_stat_box("Park time")
	date_label = date_box["value"]
	date_box["panel"].custom_minimum_size = Vector2(128, 48)
	row.add_child(date_box["panel"])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var speed_wrap := PanelContainer.new()
	speed_wrap.add_theme_stylebox_override("panel", inset_style(CREAM_WARM, 5))
	row.add_child(speed_wrap)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 4)
	speed_wrap.add_child(speed_row)
	var speed_caption := Label.new()
	speed_caption.text = "Speed"
	style_label(speed_caption, 11, MUTED, false)
	speed_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_row.add_child(speed_caption)
	speed_buttons.clear()
	# Readable labels (unicode glyphs often fail in captures / some fonts).
	var pause_btn := make_button("Pause", func(): _set_speed(0), 58, 40)
	var play_btn := make_button("1x", func(): _set_speed(1), 48, 40)
	var fast_btn := make_button("2x", func(): _set_speed(2), 48, 40)
	var turbo_btn := make_button("4x", func(): _set_speed(3), 48, 40)
	for btn in [pause_btn, play_btn, fast_btn, turbo_btn]:
		btn.add_theme_font_size_override("font_size", 13)
		speed_row.add_child(btn)
		speed_buttons.append(btn)
	_refresh_speed_buttons()

func _brand_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LEAF_DEEP
	style.border_width_top = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = MOSS
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(LEAF_DEEP.r, LEAF_DEEP.g, LEAF_DEEP.b, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	return style

func _build_bottom_bar() -> void:
	bottom_bar = PanelContainer.new()
	bottom_bar.name = "CalmToolRail"
	bottom_bar.add_theme_stylebox_override("panel", panel_style(CREAM, 12, CORNER))
	add_child(bottom_bar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	bottom_bar.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var tools_chip := PanelContainer.new()
	tools_chip.add_theme_stylebox_override("panel", inset_style(MOSS_SOFT, 5))
	header.add_child(tools_chip)
	var caption := Label.new()
	caption.text = "Tools"
	style_label(caption, 12, LEAF_DEEP, false)
	tools_chip.add_child(caption)

	tip_label = Label.new()
	tip_label.text = "Pick a category — the park stays in view while you choose."
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_label(tip_label, 13, MUTED, false)
	header.add_child(tip_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)

	# Primary verbs: Build / Landscape / Staff / Guests / Course / Radio
	var tabs := [
		["Build", "Build", "Course pieces & trails"],
		["Land", "Landscape", "Mow, brush, trees"],
		["Staff", "Staff", "Grounds crew"],
		["Golfers", "Guests", "Visitor profiles"],
		["Course", "Course", "Holes & inspect"],
		["Radio", "Radio", "Park soundtrack"]
	]
	for entry in tabs:
		var tab_name: String = entry[0]
		var button := make_button(entry[1], _toggle_tab.bind(tab_name), 102, TOUCH_H + 4.0)
		button.tooltip_text = entry[2]
		buttons.add_child(button)
		dock_buttons[tab_name] = button

	var divider := VSeparator.new()
	buttons.add_child(divider)

	var inspect_button := make_button("Inspect", _inspect, 92, TOUCH_H + 4.0)
	inspect_button.tooltip_text = "View object under cursor"
	buttons.add_child(inspect_button)
	var camera_button := make_button("Recenter", _reset_camera, 100, TOUCH_H + 4.0)
	camera_button.tooltip_text = "Reset camera to park center"
	buttons.add_child(camera_button)

func _build_tool_window() -> void:
	window_panel = PanelContainer.new()
	window_panel.name = "CalmToolWindow"
	window_panel.add_theme_stylebox_override("panel", panel_style(CREAM_WARM, 0, CORNER))
	add_child(window_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_panel.add_child(column)

	var title_wrap := PanelContainer.new()
	title_wrap.add_theme_stylebox_override("panel", title_bar_style())
	title_wrap.custom_minimum_size = Vector2(0, 42)
	column.add_child(title_wrap)
	var title_row := HBoxContainer.new()
	title_wrap.add_child(title_row)
	window_title = Label.new()
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_label(window_title, 16, TITLE_TEXT, false)
	title_row.add_child(window_title)
	var close_button := make_button("Close", close_drawer, 64, 32)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_color_override("font_color", TITLE_TEXT)
	close_button.add_theme_color_override("font_hover_color", HIGHLIGHT)
	close_button.add_theme_stylebox_override("normal", _close_button_style())
	close_button.add_theme_stylebox_override("hover", _close_button_style())
	close_button.add_theme_stylebox_override("pressed", _close_button_style())
	title_row.add_child(close_button)

	var body_wrap := MarginContainer.new()
	body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_constant_override("margin_left", 12)
	body_wrap.add_theme_constant_override("margin_right", 12)
	body_wrap.add_theme_constant_override("margin_top", 10)
	body_wrap.add_theme_constant_override("margin_bottom", 12)
	column.add_child(body_wrap)

	# Plain VBox (not ScrollContainer) — avoids empty-body nesting bug.
	window_body = VBoxContainer.new()
	window_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window_body.add_theme_constant_override("separation", 6)
	body_wrap.add_child(window_body)
	window_panel.hide()

func _close_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(LEAF.r, LEAF.g, LEAF.b, 0.85)
	style.border_color = MOSS
	style.set_border_width_all(1)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


# ------------------------------------------------------------
# LAYOUT
# ------------------------------------------------------------

func _layout_hud() -> void:
	if top_bar == null or bottom_bar == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var margin := 10.0
	# Heights must fit content; forcing a short bar clips Button labels (empty chips).
	var top_height := 78.0
	var bottom_height := 126.0
	top_bar.clip_contents = false
	bottom_bar.clip_contents = false
	top_bar.custom_minimum_size = Vector2(320.0, top_height)
	bottom_bar.custom_minimum_size = Vector2(320.0, bottom_height)
	top_bar.position = Vector2(margin, margin)
	top_bar.size = Vector2(maxf(320.0, screen.x - margin * 2.0), top_height)
	bottom_bar.position = Vector2(margin, screen.y - bottom_height - margin)
	bottom_bar.size = Vector2(maxf(320.0, screen.x - margin * 2.0), bottom_height)
	fit_drawer(bottom_height + margin)
	_raise_chrome()

func _raise_chrome() -> void:
	# Tool window must never steal clicks from the persistent tool rail / status bar.
	if top_bar != null:
		move_child(top_bar, get_child_count() - 1)
	if bottom_bar != null:
		move_child(bottom_bar, get_child_count() - 1)

func fit_drawer(rail_reserve: float = 128.0) -> void:
	if window_panel == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var compact := screen.x < 760.0
	# Compact floating card above the rail, toward the right so verbs stay visible.
	var width := minf(290.0 if compact else 336.0, screen.x - 28.0)
	# Tall enough for Build's helper + sections + six touch-sized actions.
	var max_height := maxf(240.0, screen.y - rail_reserve - 88.0)
	var height := minf(560.0, max_height)
	window_panel.custom_minimum_size = Vector2(width, height)
	window_panel.size = Vector2(width, height)
	window_panel.position = Vector2(
		maxf(14.0, screen.x - width - 18.0),
		screen.y - rail_reserve - height - 10.0
	)


# ------------------------------------------------------------
# TABS / ACTIONS
# ------------------------------------------------------------

func _toggle_tab(tab: String) -> void:
	if selected_tab == tab and window_panel.visible:
		close_drawer()
		return
	selected_tab = tab
	window_title.text = _tab_title(tab)
	while window_body.get_child_count() > 0:
		var stale: Node = window_body.get_child(0)
		window_body.remove_child(stale)
		stale.free()
	match tab:
		"Build":
			_add_helper("Place course pieces, then connect walking trails.")
			_add_section("Course pieces")
			add_action("Place Tee Pad", "_on_tee_pressed")
			add_action("Place Basket", "_on_basket_pressed")
			add_action("Edit Flight Path", "_on_path_pressed")
			_add_section("Footpaths")
			add_action("Plan Walking Trail", "_on_walkway_pressed")
			add_action("Construct Trail", "_on_build_walkway_pressed")
			add_action("Cancel Trail Plan", "_on_cancel_walkway_pressed")
		"Land":
			_add_helper("Clear fairways so guests can throw and walk.")
			_add_section("Groundskeeping")
			add_action("Mow Grass", "_on_mower_pressed")
			add_action("Clear Brush", "_on_brush_pressed")
			add_action("Remove Tree", "_on_chainsaw_pressed")
		"Staff":
			_add_helper("Hire and manage the grounds crew.")
			_add_section("Maintenance")
			add_action("Open Grounds Crew", "_on_workers_pressed")
		"Golfers":
			_add_helper("Tap a golfer on the course to open their guest card.")
			_add_section("Guests")
			var message := Label.new()
			message.text = "Guest cards show skill, mood, and round progress."
			message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			style_label(message, 13, INK, false)
			window_body.add_child(message)
		"Course":
			_add_helper("Jump between holes or inspect a selection.")
			_add_section("Hole selection")
			add_action("Previous Hole", "_on_previous_hole_pressed")
			add_action("Next Hole", "_on_next_hole_pressed")
			add_action("Inspect Selection", "_on_view_pressed")
		"Radio":
			_add_helper("Soundtrack for the park — keep it soft while you build.")
			_add_section("Park radio")
			add_radio_action("Previous Track", "previous_track")
			add_radio_action("Play / Pause", "toggle_pause")
			add_radio_action("Next Track", "next_track")
			add_radio_action("Open Full Player", "toggle_expanded")
	window_panel.visible = true
	window_panel.show()
	fit_drawer()
	# Keep chrome above the drawer so category buttons stay readable and clickable.
	_raise_chrome()
	_update_active_buttons()
	_set_tip_for_tab(tab)

func _tab_title(tab: String) -> String:
	match tab:
		"Build":
			return "Build"
		"Land":
			return "Landscape"
		"Staff":
			return "Staff"
		"Golfers":
			return "Guests"
		"Course":
			return "Course"
		"Radio":
			return "Radio"
		_:
			return tab

func _set_tip_for_tab(tab: String) -> void:
	if tip_label == null:
		return
	match tab:
		"Build":
			tip_label.text = "Tip: place a tee and basket first, then draw the flight path."
		"Land":
			tip_label.text = "Tip: mow fairways before you open the park to guests."
		"Staff":
			tip_label.text = "Tip: hire crew for mow and clear jobs on the course."
		"Golfers":
			tip_label.text = "Tip: tap a guest on the map to open their card."
		"Course":
			tip_label.text = "Tip: jump holes to move the camera around the park."
		"Radio":
			tip_label.text = "Tip: open the full player for volume and shuffle."
		_:
			tip_label.text = "Pick a category — the park stays in view while you choose."

func _add_helper(text: String) -> void:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", helper_style())
	var helper := Label.new()
	helper.text = text
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_label(helper, 13, MUTED, false)
	wrap.add_child(helper)
	window_body.add_child(wrap)

func _add_section(title: String) -> void:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", section_style())
	var label := Label.new()
	label.text = title
	style_label(label, 13, LEAF_DEEP, false)
	header.add_child(label)
	window_body.add_child(header)

func add_action(title: String, method_name: String) -> void:
	var action := make_button(title, _invoke_ui.bind(method_name), 260, TOUCH_H)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", 15)
	window_body.add_child(action)

func add_radio_action(title: String, method_name: String) -> void:
	var action := make_button(title, _invoke_radio.bind(method_name), 260, TOUCH_H)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", 15)
	window_body.add_child(action)

func _invoke_ui(method_name: String) -> void:
	if ui != null and ui.has_method(method_name):
		ui.call(method_name)
		if method_name != "_on_workers_pressed":
			close_drawer()

func _invoke_radio(method_name: String) -> void:
	if radio_manager != null and radio_manager.has_method(method_name):
		radio_manager.call(method_name)

func _inspect() -> void:
	_invoke_ui("_on_view_pressed")

func _reset_camera() -> void:
	_invoke_ui("_on_reset_camera_pressed")

func close_drawer() -> void:
	selected_tab = ""
	window_panel.hide()
	_update_active_buttons()
	if tip_label != null:
		tip_label.text = "Pick a category — the park stays in view while you choose."

func _update_active_buttons() -> void:
	for tab_name in dock_buttons:
		var button: Button = dock_buttons[tab_name]
		var active: bool = tab_name == selected_tab and window_panel.visible
		button.add_theme_stylebox_override("normal", button_style(active, false))
		button.add_theme_stylebox_override("hover", button_style(true, false))
		button.add_theme_color_override("font_color", LEAF_DEEP if active else INK)
		button.add_theme_font_size_override("font_size", 16 if active else 15)

func _set_speed(index: int) -> void:
	speed_index = clampi(index, 0, sim_speeds.size() - 1)
	Engine.time_scale = sim_speeds[speed_index]
	_refresh_speed_buttons()

func _refresh_speed_buttons() -> void:
	for i in range(speed_buttons.size()):
		var button: Button = speed_buttons[i]
		var active: bool = i == speed_index
		button.add_theme_stylebox_override("normal", button_style(active, false))
		button.add_theme_color_override("font_color", LEAF_DEEP if active else INK)

func _cycle_speed() -> void:
	_set_speed((speed_index + 1) % sim_speeds.size())

func _process(delta: float) -> void:
	if Engine.time_scale > 0.0:
		play_seconds += delta
	refresh_clock += delta
	if refresh_clock >= 0.35:
		refresh_clock = 0.0
		refresh_status()

func refresh_status() -> void:
	if money_label == null:
		return
	var money_text := "$0"
	if ui != null and ui.money_label != null and not str(ui.money_label.text).is_empty():
		money_text = ui.money_label.text
	elif economy_manager != null and economy_manager.has_method("format_money"):
		money_text = economy_manager.format_money(economy_manager.get_cash())
	money_label.text = money_text

	var golfer_count := 0
	if golfer_manager != null:
		golfer_count = golfer_manager.visitors.size()
	guests_label.text = str(golfer_count)

	var crew_count := 0
	var working := 0
	if job_manager != null:
		crew_count = job_manager.get_worker_count()
		if job_manager.has_method("get_working_worker_count"):
			working = job_manager.get_working_worker_count()
	crew_label.text = "%d / %d" % [working, crew_count]

	var hole_num := 1
	if course_manager != null:
		hole_num = course_manager.selected_hole + 1
	hole_label.text = str(hole_num)

	var total_seconds: int = int(play_seconds)
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	date_label.text = "Day %d  %02d:%02d" % [minutes / 12 + 1, minutes % 60, seconds]

	if park_label != null:
		var completed := 0
		if course_manager != null and course_manager.has_method("get_completed_hole_count"):
			completed = course_manager.get_completed_hole_count()
		park_label.text = "Disc Golf Empire  ·  %d open" % completed

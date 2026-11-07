class_name Hud
extends CanvasLayer
## HUD armado por código: distancia, récord, balas sobre el arma, popups, overlays.

signal retry_pressed
signal tuning_changed
signal test_level(kind: String) # solo para probar: reinicia con un nivel especial
signal test_power(power: String) # solo para probar: da un poder

const INK := Color("2a1838")
const GOLD := Color("fff3a6")
const PILL := Color(0.27, 0.12, 0.35, 0.72)

var _root: Control
var _best: Label
var _dist: Label
var _ammo_box: HBoxContainer
var _ammo: Label
var _vignette: ColorRect
var _start: VBoxContainer
var _over: Control
var _over_title: Label
var _over_dist: Label
var _over_stats: HBoxContainer
var _over_board: GridContainer
var _tune_panel: PanelContainer
var _hurt_flash: ColorRect
var _powers_box: VBoxContainer
var _tune_sliders := {}
var _tune_labels := {}


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5));
	COLOR = vec4(0.24, 0.0, 0.31, smoothstep(0.3, 0.75, d) * 0.65 * strength);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_vignette.material = sm
	_root.add_child(_vignette)

	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_flash.color = Color(1.0, 0.1, 0.25, 0.0)
	_root.add_child(_hurt_flash)

	# Arriba: récord y distancia
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 70
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_best = _label("BEST: 0m", 46, Color.WHITE, 0)
	_best.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	_best.add_theme_constant_override("shadow_offset_y", 4)
	top.add_child(_best)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL
	sb.set_corner_radius_all(70)
	sb.content_margin_left = 60
	sb.content_margin_right = 60
	pill.add_theme_stylebox_override("panel", sb)
	pill.custom_minimum_size.x = 360
	_dist = _label("0m", 96, GOLD, 0)
	pill.add_child(_dist)
	top.add_child(pill)
	_powers_box = VBoxContainer.new()
	_powers_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_powers_box)

	# Balas sobre el arma
	_ammo_box = HBoxContainer.new()
	_ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_box.add_theme_constant_override("separation", 10)
	_ammo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ammo_box.add_child(_bullet_icon())
	_ammo = _label("5", 60, Color.WHITE, 14)
	_ammo_box.add_child(_ammo)
	_root.add_child(_ammo_box)

	# Pantalla de inicio
	_start = VBoxContainer.new()
	_start.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_start.offset_top = -420
	_start.offset_bottom = -120
	_start.alignment = BoxContainer.ALIGNMENT_END
	_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start.add_theme_constant_override("separation", 14)
	_root.add_child(_start)
	_start.add_child(_label("RECOIL RUN", 84, Color.WHITE, 16))
	var hint := _label("Tocá para disparar", 42, Color.WHITE, 10)
	_start.add_child(hint)
	var tw := create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.4, 0.6)
	tw.tween_property(hint, "modulate:a", 1.0, 0.6)
	var sub := _label("Disparás para adelante → vas un poco para atrás\nDisparás para atrás → vas para adelante\nHeadshot +3 · Kill +2", 30, INK, 0)
	_start.add_child(sub)

	# Game over
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.visible = false
	_root.add_child(_over)
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.04, 0.24, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(box)
	_over_title = _label("SIN BALAS", 76, Color.WHITE, 16)
	_over_dist = _label("0m", 120, GOLD, 20)
	box.add_child(_over_title)
	box.add_child(_over_dist)
	_over_stats = HBoxContainer.new()
	_over_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_over_stats.add_theme_constant_override("separation", 18)
	_over_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_over_stats)
	var board_panel := PanelContainer.new()
	var bsb := _pill_style(Color(0.16, 0.06, 0.22, 0.8), 32)
	bsb.content_margin_left = 30
	bsb.content_margin_right = 30
	bsb.content_margin_top = 18
	bsb.content_margin_bottom = 18
	board_panel.add_theme_stylebox_override("panel", bsb)
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(board_panel)
	_over_board = GridContainer.new()
	_over_board.columns = 4
	_over_board.add_theme_constant_override("h_separation", 34)
	_over_board.add_theme_constant_override("v_separation", 4)
	_over_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(_over_board)
	var btn := Button.new()
	btn.text = "OTRA VEZ"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 56)
	for st in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = GOLD if st != "pressed" else GOLD.darkened(0.15)
		s.set_corner_radius_all(70)
		s.content_margin_left = 80
		s.content_margin_right = 80
		s.content_margin_top = 22
		s.content_margin_bottom = 22
		s.shadow_color = Color("c9a93a")
		s.shadow_offset = Vector2(0, 10 if st != "pressed" else 4)
		btn.add_theme_stylebox_override(st, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, INK)
	btn.pressed.connect(func(): retry_pressed.emit())
	box.add_child(btn)

	_build_tuning()


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Sin cortar líneas: en contenedores el autowrap partía "10" o "123m" en renglones.
	# Los textos de varias líneas usan \n explícitos.
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	return l


func _bullet_icon() -> Control:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tip := Panel.new()
	var t := StyleBoxFlat.new()
	t.bg_color = Color("d98a4a")
	t.corner_radius_top_left = 12
	t.corner_radius_top_right = 12
	t.set_border_width_all(3)
	t.border_color = INK
	tip.add_theme_stylebox_override("panel", t)
	tip.custom_minimum_size = Vector2(24, 20)
	var body := Panel.new()
	var b := StyleBoxFlat.new()
	b.bg_color = Color("e9c24a")
	b.set_border_width_all(3)
	b.border_color = INK
	body.add_theme_stylebox_override("panel", b)
	body.custom_minimum_size = Vector2(24, 38)
	c.add_child(tip)
	c.add_child(body)
	return c


# --- Panel de ajustes en vivo (gravedad, retroceso, giro...) ---

func _pill_style(color: Color, radius := 40) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _small_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 34)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, _pill_style(bg if st != "pressed" else bg.darkened(0.2)))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	return b


func _build_tuning() -> void:
	var open_btn := _small_button("AJUSTES", PILL, Color.WHITE)
	open_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	open_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	open_btn.offset_right = -20
	open_btn.offset_top = 20
	_root.add_child(open_btn)

	_tune_panel = PanelContainer.new()
	_tune_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tune_panel.offset_left = 24
	_tune_panel.offset_right = -24
	_tune_panel.offset_top = 100
	_tune_panel.add_theme_stylebox_override("panel", _pill_style(Color(0.16, 0.06, 0.22, 0.92), 32))
	_tune_panel.visible = false
	_root.add_child(_tune_panel)
	open_btn.pressed.connect(func(): _tune_panel.visible = not _tune_panel.visible)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_tune_panel.add_child(col)
	for spec in Tuning.SLIDERS:
		var key: String = spec[0]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 32)
		col.add_child(l)
		var sl := HSlider.new()
		sl.min_value = spec[2]
		sl.max_value = spec[3]
		sl.step = spec[4]
		sl.custom_minimum_size.y = 64
		sl.focus_mode = Control.FOCUS_NONE
		sl.scrollable = false
		# Barra gruesa y rellena en dorado: más fácil de usar con el dedo.
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.22)
		track.set_corner_radius_all(10)
		track.content_margin_top = 10
		track.content_margin_bottom = 10
		var fill := track.duplicate() as StyleBoxFlat
		fill.bg_color = GOLD
		sl.add_theme_stylebox_override("slider", track)
		sl.add_theme_stylebox_override("grabber_area", fill)
		sl.add_theme_stylebox_override("grabber_area_highlight", fill)
		col.add_child(sl)
		_tune_labels[key] = [l, spec[1]]
		_tune_sliders[key] = sl
		sl.value_changed.connect(func(v: float):
			Tuning.set_value(key, v)
			_refresh_tuning_labels()
			tuning_changed.emit())
	for spec in [["PROBAR NIVEL", test_level, [["↓ ESCALERA", "stairs_down"], ["↑ ESCALERA", "stairs_up"], ["AÉREO", "air"]]],
			["PROBAR PODER", test_power, [["∞", "infinite"], ["LÁSER", "laser"], ["+15", "ammo15"], ["★", "untouchable"]]]]:
		var t := Label.new()
		t.text = spec[0]
		t.add_theme_font_size_override("font_size", 28)
		col.add_child(t)
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", 12)
		col.add_child(r)
		for pair in spec[2]:
			var b := _small_button(pair[0], Color(1, 1, 1, 0.18), Color.WHITE)
			b.add_theme_font_size_override("font_size", 28)
			var sig: Signal = spec[1]
			var arg: String = pair[1]
			b.pressed.connect(func():
				_tune_panel.visible = false
				sig.emit(arg))
			r.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var reset := _small_button("VALORES INICIALES", GOLD, INK)
	reset.pressed.connect(func():
		Tuning.reset()
		_sync_tuning()
		tuning_changed.emit())
	row.add_child(reset)
	var close := _small_button("CERRAR", GOLD, INK)
	close.pressed.connect(func(): _tune_panel.visible = false)
	row.add_child(close)
	_sync_tuning()


func _sync_tuning() -> void:
	for key in _tune_sliders:
		_tune_sliders[key].set_value_no_signal(Tuning.values[key])
	_refresh_tuning_labels()


func _refresh_tuning_labels() -> void:
	for key in _tune_labels:
		var pair: Array = _tune_labels[key]
		pair[0].text = "%s: %s" % [pair[1], snappedf(Tuning.values[key], _tune_sliders[key].step)]


# --- API para main.gd ---

func set_values(best: int, dist: int, ammo: int, infinite := false) -> void:
	_best.text = "BEST: %dm" % best
	_dist.text = "%dm" % dist
	_ammo.text = "∞" if infinite else str(ammo)
	_ammo.add_theme_color_override("font_color", Color("ff6b6b") if ammo == 0 and not infinite else Color.WHITE)


const POWER_LABELS := {"infinite": "∞ BALAS", "laser": "LÁSER", "untouchable": "★ INTOCABLE"}


## Poderes activos con su tiempo restante, debajo de la distancia.
func set_powers(powers: Dictionary) -> void:
	var kids := _powers_box.get_children()
	var keys := powers.keys()
	for i in maxi(kids.size(), keys.size()):
		if i >= keys.size():
			kids[i].queue_free()
			continue
		var l: Label = kids[i] if i < kids.size() else null
		if l == null:
			l = _label("", 40, GOLD, 10)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			_powers_box.add_child(l)
		l.text = "%s  %ds" % [POWER_LABELS.get(keys[i], keys[i]), ceili(powers[keys[i]])]


func flash_hurt() -> void:
	_hurt_flash.color.a = 0.45
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(_hurt_flash, "color:a", 0.0, 0.35)


func place_ammo(screen: Vector2) -> void:
	var s := _ammo_box.get_combined_minimum_size()
	_ammo_box.size = s
	var pos := screen - Vector2(s.x / 2.0, s.y)
	var vw := get_viewport().get_visible_rect().size.x
	pos.x = clampf(pos.x, 12.0, vw - s.x - 12.0) # que no se salga por los costados
	_ammo_box.position = pos


func bump_ammo() -> void:
	_ammo_box.pivot_offset = _ammo_box.size / 2.0
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(_ammo_box, "scale", Vector2.ONE * 1.35, 0.12)
	tw.tween_property(_ammo_box, "scale", Vector2.ONE, 0.13)


func set_vignette(strength: float) -> void:
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", clampf(strength, 0.0, 1.0))


func popup_world(camera: Camera3D, world: Vector3, text: String, kind: String) -> void:
	var size := 56
	var color := Color.WHITE
	if kind == "headshot":
		size = 76
		color = Color("ffe14a")
	elif kind == "empty" or kind == "hurt":
		size = 50 if kind == "empty" else 64
		color = Color("ff6b6b")
	elif kind == "clank":
		size = 46
		color = Color("d9dde6")
	var l := _label(text, size, color, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(l)
	var ls := l.get_combined_minimum_size()
	var vw := get_viewport().get_visible_rect().size.x
	var screen := camera.unproject_position(world)
	var margin := ls.x / 2.0 + 16.0 # que no se salga por los costados
	screen.x = clampf(screen.x, margin, vw - margin)
	l.position = screen - ls / 2.0
	l.pivot_offset = ls / 2.0
	l.scale = Vector2.ONE * 0.5
	var dur := 0.7 if kind == "empty" else 1.1
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(l, "scale", Vector2.ONE * 1.15, dur * 0.15)
	tw.tween_property(l, "scale", Vector2.ONE, dur * 0.15)
	tw.parallel().tween_property(l, "position:y", l.position.y - 120.0, dur * 0.85)
	tw.parallel().tween_property(l, "modulate:a", 0.0, dur * 0.85).set_delay(dur * 0.2)
	tw.tween_callback(l.queue_free)


func hide_start() -> void:
	_start.visible = false


const BOARD_ROWS := 5


## attempt: {dist, height, ammo, ...}; result: lo que devuelve Records.add().
func show_over(title: String, attempt: Dictionary, result: Dictionary) -> void:
	_over_title.text = title
	_over_dist.text = "%dm" % attempt.dist
	_best.get_parent().visible = false # el HUD de arriba se pisaría con el título
	_ammo_box.visible = false

	for c in _over_stats.get_children():
		c.queue_free()
	for st in [["height", "ALTURA MÁX", "%dm"], ["ammo", "BALAS MÁX", "%d"], ["dist", "RÉCORD", "%dm"]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var is_new: bool = result.new[st[0]]
		var value: int = attempt[st[0]] if st[0] != "dist" else Records.best.dist
		col.add_child(_cell(st[1], 24, Color.WHITE, 6))
		col.add_child(_cell(st[2] % value, 48, GOLD if is_new else Color.WHITE, 10))
		col.add_child(_cell("¡NUEVO!" if is_new else " ", 22, GOLD, 6))
		_over_stats.add_child(col)

	for c in _over_board.get_children():
		c.queue_free()
	for h in ["#", "DIST", "ALTURA", "BALAS"]:
		_over_board.add_child(_cell(h, 24, Color(1, 1, 1, 0.6), 0))
	var rank: int = result.rank
	for i in mini(BOARD_ROWS, Records.attempts.size()):
		_board_row(i + 1, Records.attempts[i], i + 1 == rank)
	if rank == 0 or rank > BOARD_ROWS:
		for k in 4:
			_over_board.add_child(_cell("·" if k == 0 else "", 24, Color.WHITE, 0))
		_board_row(rank, attempt, true)
	_over.visible = true


func _board_row(rank: int, a: Dictionary, current: bool) -> void:
	var color := GOLD if current else Color.WHITE
	var cells := ["%d" % rank if rank > 0 else "-", "%dm" % a.dist, "%dm" % a.height, "%d" % a.ammo]
	for t in cells:
		_over_board.add_child(_cell(t, 34, color, 6 if current else 0))


## Label de una sola línea (en contenedores sin ancho fijo el autowrap la parte letra por letra).
func _cell(text: String, size: int, color: Color, outline: int) -> Label:
	var l := _label(text, size, color, outline)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

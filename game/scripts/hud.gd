class_name Hud
extends CanvasLayer
## HUD armado por código: distancia, récord, balas sobre el arma, popups, overlays.

signal retry_pressed
signal tuning_changed
signal test_level(kind: String) # solo para probar: reinicia con un nivel especial
signal test_power(power: String) # solo para probar: da un poder
signal market_buy(item: String) # ver Main.MARKET_ITEMS
signal market_close

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
var _perks: Label
var _special_info: Label
var _combo: Label # "COMBO x2", "COMBO x3"
var _combo_hold_until := 0 # ms: hasta acá el combo que dio el poder no se borra
var _market: Control
var _market_box: VBoxContainer
var _arrows: Control
var _arrow_pool: Array[Node2D] = []
var _tune_sliders := {}
var _tune_physics: VBoxContainer # los sliders (escondidos hasta tocar "FÍSICA")
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
	_combo = _label("", 64, Color("ffd23a"), 14)
	_combo.visible = false
	top.add_child(_combo)
	_powers_box = VBoxContainer.new()
	_powers_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_powers_box)
	_perks = _label("", 28, Color("bff3ff"), 8) # mejoras del mercado que tenés
	_perks.visible = false
	_perks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_special_info = _label("", 40, GOLD, 12) # contador del nivel especial
	_special_info.visible = false
	top.add_child(_special_info)
	top.add_child(_perks)

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
	var sub := _label("Disparás para adelante → vas un poco para atrás\nDisparás para atrás → vas para adelante\nHeadshot +4 · Kill +2", 30, INK, 0)
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

	_build_market()
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
	_tune_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tune_panel.offset_left = 24
	_tune_panel.offset_right = -24
	_tune_panel.offset_top = 100
	_tune_panel.offset_bottom = -24
	_tune_panel.add_theme_stylebox_override("panel", _pill_style(Color(0.16, 0.06, 0.22, 0.92), 32))
	_tune_panel.visible = false
	_root.add_child(_tune_panel)
	open_btn.pressed.connect(func(): _tune_panel.visible = not _tune_panel.visible)

	# Con scroll: en pantallas bajas no entra todo.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tune_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	# Los sliders de física van escondidos (abajo de todo, se abren con un botón).
	var physics := VBoxContainer.new()
	physics.add_theme_constant_override("separation", 6)
	physics.visible = false
	_tune_physics = physics
	for spec in Tuning.SLIDERS:
		var key: String = spec[0]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 32)
		physics.add_child(l)
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
		physics.add_child(sl)
		_tune_labels[key] = [l, spec[1]]
		_tune_sliders[key] = sl
		sl.value_changed.connect(func(v: float):
			Tuning.set_value(key, v)
			_refresh_tuning_labels()
			tuning_changed.emit())
	for spec in [["PROBAR NIVEL", test_level, [["PERSEC.", "chase"], ["GALERÍA", "gallery"], ["APAGÓN", "blackout"], ["VENT.", "fan"], ["COHETE", "booster"], ["$ MERCADO", "market"], ["COFRE", "chest"], ["TRAMPA", "trap"]]],
			["PROBAR JEFE", test_level, [["ROBOT", "boss:robot"], ["TOPO", "boss:mole"], ["ZEPELÍN", "boss:zeppelin"], ["MURALLA", "boss:wall"], ["DUELO", "boss:duel"]]],
			["PROBAR PODER", test_power, [["∞", "infinite"], ["LÁSER", "laser"], ["+15", "ammo15"], ["★", "untouchable"], ["DRON", "drone"], ["ESCOPETA", "shotgun"], ["IMÁN", "magnet"], ["COMETA", "comet"]]]]:
		var t := Label.new()
		t.text = spec[0]
		t.add_theme_font_size_override("font_size", 28)
		col.add_child(t)
		var r := HFlowContainer.new() # si no entran en una fila, siguen abajo
		r.alignment = FlowContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("h_separation", 12)
		r.add_theme_constant_override("v_separation", 10)
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
	var close := _small_button("CERRAR", GOLD, INK)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): _tune_panel.visible = false)
	col.add_child(close)
	var sep := Control.new()
	sep.custom_minimum_size.y = 24
	col.add_child(sep)
	var toggle := _small_button("▸ FÍSICA (AVANZADO)", Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.7))
	toggle.add_theme_font_size_override("font_size", 26)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toggle.pressed.connect(func():
		physics.visible = not physics.visible
		toggle.text = ("▾" if physics.visible else "▸") + " FÍSICA (AVANZADO)")
	col.add_child(toggle)
	col.add_child(physics)
	var reset := _small_button("VALORES INICIALES", GOLD, INK)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		Tuning.reset()
		_sync_tuning()
		tuning_changed.emit())
	physics.add_child(reset)
	_sync_tuning()


func _sync_tuning() -> void:
	for key in _tune_sliders:
		_tune_sliders[key].set_value_no_signal(Tuning.values[key])
	_refresh_tuning_labels()


func _refresh_tuning_labels() -> void:
	for key in _tune_labels:
		var pair: Array = _tune_labels[key]
		pair[0].text = "%s: %s" % [pair[1], snappedf(Tuning.values[key], _tune_sliders[key].step)]


# --- Mercado (bañadera con billetes) ---

func _build_market() -> void:
	_market = Control.new()
	_market.set_anchors_preset(Control.PRESET_FULL_RECT)
	_market.visible = false
	_root.add_child(_market)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.1, 0.05, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_market.add_child(dim) # (no deja pasar toques al juego)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.offset_top = 40
	scroll.offset_bottom = -30
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_market.add_child(scroll)
	_market_box = VBoxContainer.new()
	_market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_market_box.add_theme_constant_override("separation", 22)
	scroll.add_child(_market_box)


const MARKET_TEXT := {
	"pierce": ["PENETRANTES", "BALAS PENETRANTES", "Cuando una bala mata, sigue de largo:\nhasta %d enemigos de un tiro." % Config.PIERCE_KILLS],
	"ricochet": ["REBOTE", "BALAS QUE REBOTAN", "Si le pegás al piso, la bala rebota\nuna vez y sigue volando."],
	"sight": ["MIRILLA", "MIRILLA LÁSER", "Una línea roja te muestra\nadónde apunta el cañón."],
	"slowmo": ["LENTA x2", "CÁMARA LENTA x2", "Cada headshot te da el doble\nde cámara lenta."],
	"insurance": ["SEGURO", "SEGURO DE VIDA", "La próxima vez que perdés,\nrevivís con %d balas." % Config.INSURANCE_AMMO],
	"extra_start": ["+1 BALA", "+1 BALA AL INICIO", "Arrancás cada partida\ncon una bala más (hasta %d)." % (Config.START_AMMO + Config.MAX_EXTRA_START)],
}

var _market_sel := ""
var _market_info := {}


## info: {ammo, offers: [{item, price, can, available, owned, bought}]}. Se rearma en cada compra.
func show_market(info: Dictionary) -> void:
	_market_info = info
	var items: Array = info.offers.map(func(o): return o.item)
	if not _market_sel in items:
		_market_sel = items[0] if not items.is_empty() else ""
	_render_market()
	_market.visible = true


func _render_market() -> void:
	var info := _market_info
	for c in _market_box.get_children():
		_market_box.remove_child(c)
		c.queue_free()
	_market_box.add_child(_label("$ MERCADO $", 84, Color("7dff6b"), 18))
	# cuántas balas tenés
	var have := HBoxContainer.new()
	have.alignment = BoxContainer.ALIGNMENT_CENTER
	have.add_theme_constant_override("separation", 14)
	have.mouse_filter = Control.MOUSE_FILTER_IGNORE
	have.add_child(_label("TENÉS", 40, Color(1, 1, 1, 0.8), 10))
	have.add_child(_bullet_icon())
	have.add_child(_label(str(info.ammo), 64, GOLD, 14))
	_market_box.add_child(have)
	_market_box.add_child(_label("Elegí una mejora", 32, Color(1, 1, 1, 0.7), 0))

	# las tres tarjetas con dibujo
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_market_box.add_child(row)
	var sel: Dictionary = {}
	for o in info.offers:
		row.add_child(_market_card(o))
		if o.item == _market_sel:
			sel = o
	if not sel.is_empty():
		_market_box.add_child(_market_detail(sel, info.ammo))

	var go := _small_button("SEGUIR JUGANDO", Color(1, 1, 1, 0.14), Color.WHITE)
	go.add_theme_font_size_override("font_size", 40)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(380, 84)
	go.pressed.connect(func(): market_close.emit())
	_market_box.add_child(go)


## Tarjeta: dibujo grande, nombre corto y precio. Tocarla la elige.
func _market_card(o: Dictionary) -> Button:
	var col := MarketIcon.color_of(o.item)
	var chosen: bool = o.item == _market_sel
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 330)
	var st := _pill_style(col.darkened(0.55) if chosen else Color(1, 1, 1, 0.07), 30)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.set_border_width_all(7 if chosen else 3)
	st.border_color = GOLD if chosen else Color(1, 1, 1, 0.18)
	if chosen:
		st.shadow_color = Color(col, 0.6)
		st.shadow_size = 18
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, st)
	b.pressed.connect(func():
		_market_sel = o.item
		_render_market())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 14
	v.offset_bottom = -14
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var icon := MarketIcon.new()
	icon.item = o.item
	icon.dim = not o.can and not o.bought
	icon.custom_minimum_size = Vector2(170, 170)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	v.add_child(_label(MARKET_TEXT[o.item][0], 32, Color.WHITE, 10))
	var tag: Control
	if o.bought:
		tag = _label("¡COMPRADO!", 30, Color("7dff6b"), 10)
	elif not o.available:
		tag = _label("YA LO TENÉS", 28, Color(1, 1, 1, 0.6), 8)
	else:
		tag = HBoxContainer.new()
		tag.alignment = BoxContainer.ALIGNMENT_CENTER
		tag.add_theme_constant_override("separation", 8)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := _bullet_icon()
		ic.scale = Vector2.ONE * 0.75
		tag.add_child(ic)
		tag.add_child(_label(str(o.price), 44, GOLD if o.can else Color("ff6b6b"), 10))
	v.add_child(tag)
	return b


## Lo elegido, bien grande: qué hace, cuánto dura y el botón de comprar.
func _market_detail(o: Dictionary, ammo: int) -> Control:
	var col := MarketIcon.color_of(o.item)
	var card := PanelContainer.new()
	var st := _pill_style(Color(col.darkened(0.7), 0.95), 32)
	st.set_border_width_all(4)
	st.border_color = col
	st.content_margin_top = 22
	st.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(_label(MARKET_TEXT[o.item][1], 50, col.lightened(0.35), 12))
	v.add_child(_label(MARKET_TEXT[o.item][2], 32, Color.WHITE, 0))
	var lasts := ""
	match o.item:
		"extra_start":
			lasts = "PARA SIEMPRE · ARRANCÁS CON %d" % (Config.START_AMMO + o.owned)
		"insurance":
			lasts = "SE USA UNA VEZ"
		_:
			lasts = "DURA %d PARTIDAS" % Config.PERK_RUNS + (" · TE QUEDAN %d" % o.owned if o.owned > 0 else "")
	v.add_child(_label(lasts, 26, Color(1, 1, 1, 0.6), 0))
	var text := ""
	if not o.available:
		text = "YA LO TENÉS" if o.item == "insurance" else "MÁXIMO"
	elif o.can:
		text = "COMPRAR POR %d BALAS" % o.price
	else:
		text = "TE FALTAN %d BALAS" % (o.price - (ammo - 1))
	var buy := _small_button(text, Color("7dff6b") if o.can else Color(1, 1, 1, 0.15), INK if o.can else Color(1, 1, 1, 0.6))
	buy.add_theme_font_size_override("font_size", 40)
	buy.custom_minimum_size = Vector2(460, 96)
	buy.disabled = not o.can
	buy.add_theme_stylebox_override("disabled", _pill_style(Color(1, 1, 1, 0.12)))
	buy.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(func(): market_buy.emit(o.item))
	v.add_child(buy)
	return card


# --- flechas en el borde: lo peligroso que viene de afuera ---

## threats: [{at: Vector2 (en pantalla, puede estar afuera), color, near: 0..1}]
func set_threats(threats: Array) -> void:
	if _arrows == null:
		_arrows = Control.new()
		_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
		_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_arrows)
		_root.move_child(_arrows, 1) # debajo de los carteles
	while _arrow_pool.size() < threats.size():
		_arrow_pool.append(_make_arrow())
	var vp := get_viewport().get_visible_rect().size
	var c := vp / 2.0
	var margin := 46.0
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 90.0)
	for i in _arrow_pool.size():
		var a := _arrow_pool[i]
		a.visible = i < threats.size()
		if not a.visible:
			continue
		var t: Dictionary = threats[i]
		var dir: Vector2 = (t.at - c)
		if dir.length() < 1.0:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var k := minf((c.x - margin) / maxf(absf(dir.x), 0.001), (c.y - margin) / maxf(absf(dir.y), 0.001))
		a.position = c + dir * k
		a.rotation = dir.angle()
		a.scale = Vector2.ONE * (0.8 + 0.6 * t.near)
		(a.get_node("Fill") as Polygon2D).color = t.color
		a.modulate.a = pulse


func visible_arrows() -> int:
	return _arrow_pool.filter(func(a): return a.visible).size()


func _make_arrow() -> Node2D:
	var a := Node2D.new()
	var pts := PackedVector2Array([Vector2(28, 0), Vector2(-16, -22), Vector2(-8, 0), Vector2(-16, 22)])
	var outline := Polygon2D.new()
	outline.polygon = pts
	outline.color = INK
	outline.scale = Vector2.ONE * 1.3
	outline.position.x = -3
	a.add_child(outline)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = pts
	a.add_child(fill)
	_arrows.add_child(a)
	return a


func hide_market() -> void:
	_market.visible = false


## Mejoras que tenés (debajo de la distancia); "" las esconde.
func set_perks(text: String) -> void:
	_perks.text = text
	_perks.visible = text != ""


# --- API para main.gd ---

func set_values(best: int, dist: int, ammo: int, infinite := false) -> void:
	_best.text = "BEST: %dm" % best
	_dist.text = "%dm" % dist
	_ammo.text = "∞" if infinite else str(ammo)
	_ammo.add_theme_color_override("font_color", Color("ff6b6b") if ammo == 0 and not infinite else Color.WHITE)


## Combo en pantalla: n < 2 lo esconde (salvo que el que dio el poder siga su
## ratito: hold segundos). force lo esconde igual (game over).
func set_combo(n: int, hold := 0.0, force := false) -> void:
	var now := Time.get_ticks_msec()
	if n < Config.COMBO_MIN_SHOW:
		if force or now >= _combo_hold_until:
			_combo.visible = false
			_combo_hold_until = 0
		return
	_combo_hold_until = now + int(hold * 1000.0) if hold > 0.0 else 0
	_combo.text = "COMBO x%d" % n
	_combo.add_theme_color_override("font_color", Color("ffd23a") if n < 3 else Color("ff7a3a"))
	_combo.visible = true
	_combo.pivot_offset = _combo.size / 2.0
	var tw := _combo.create_tween().set_ignore_time_scale(true) # (en slow-mo también)
	_combo.scale = Vector2.ONE * (1.35 if n < 3 else 1.6)
	tw.tween_property(_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(maxf(hold - 0.25, 0.0))
		tw.tween_callback(func():
			if _combo_hold_until != 0 and Time.get_ticks_msec() >= _combo_hold_until - 20:
				_combo.visible = false
				_combo_hold_until = 0)


const POWER_LABELS := {"infinite": "∞ BALAS", "laser": "LÁSER", "untouchable": "★ INTOCABLE", "locked": "CANDADO: PESÁS x2",
	"drone": "DRON", "shotgun": "ESCOPETA x3", "magnet": "IMÁN"}


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


## "¡NIVEL ESPECIAL!" con confeti (en tiempo real, aunque haya slow-mo).
## Resultado de un nivel especial (o del jefe): título grande y las balas que te dio.
func special_banner(title: String, reward: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -10)
	var good := reward > 0
	box.add_child(_label(title, 84, Color("ffe14a") if good else Color("d9dde6"), 18))
	box.add_child(_label("+%d BALAS" % reward if good else "sin premio", 54, Color.WHITE if good else Color(1, 1, 1, 0.7), 14))
	if good:
		_confetti(Vector2(vp.x / 2.0, -20.0), vp.x) # antes que el cartel: queda por detrás
	_root.add_child(box)
	var bs := box.get_combined_minimum_size()
	box.size = bs
	box.position = Vector2((vp.x - bs.x) / 2.0, vp.y * 0.3)
	box.pivot_offset = bs / 2.0
	box.scale = Vector2.ZERO
	box.rotation = -0.25
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(box, "scale", Vector2.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "rotation", 0.06, 0.25)
	for i in 3: # "wichi wow": se bambolea
		tw.tween_property(box, "rotation", -0.06, 0.12)
		tw.tween_property(box, "rotation", 0.06, 0.12)
	tw.tween_property(box, "rotation", 0.0, 0.1)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(1.1)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


## Entrás a un nivel especial: franja de lado a lado con el nombre y el objetivo.
func special_intro(title: String, goal: String, color: Color) -> void:
	var vp := get_viewport().get_visible_rect().size
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(INK, 0.88)
	st.border_color = color
	st.border_width_top = 8
	st.border_width_bottom = 8
	st.content_margin_top = 26
	st.content_margin_bottom = 30
	band.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	band.add_child(v)
	v.add_child(_label("NIVEL ESPECIAL", 34, Color(1, 1, 1, 0.7), 0))
	v.add_child(_label(title, 92, color, 16))
	v.add_child(_label(goal, 40, Color.WHITE, 10))
	_root.add_child(band)
	band.size = Vector2(vp.x, band.get_combined_minimum_size().y)
	band.position = Vector2(vp.x, vp.y * 0.64) # abajo: no tapa el arma
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(band, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(band, "position:x", -vp.x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(band.queue_free)


## Contador del nivel especial (debajo de la distancia); "" lo esconde.
func set_special_info(text: String) -> void:
	_special_info.text = text
	_special_info.visible = text != ""


func _confetti(at: Vector2, width: float) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 140
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width / 2.0, 10.0)
	p.direction = Vector2.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 250.0
	p.initial_velocity_max = 650.0
	p.gravity = Vector2(0, 520)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 10.0
	p.scale_amount_max = 18.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color("ff3b6b"), Color("ffe14a"), Color("4dd2ff"), Color("7dff6b"), Color("b46cff"), Color("ff9a3b")])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.2, true, false, true).timeout.connect(p.queue_free)


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

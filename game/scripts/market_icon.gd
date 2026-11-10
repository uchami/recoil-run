class_name MarketIcon
extends Control
## Dibujo de cada mejora del mercado (vectorial, sin imágenes): que se entienda
## de un vistazo qué hace. Se dibuja en un cuadrado de 100x100 escalado al tamaño.

const INK := Color("2a1838")
const COLORS := {
	"pierce": Color("4fd8ff"),
	"ricochet": Color("ff9f3a"),
	"sight": Color("ff4d6d"),
	"slowmo": Color("a77bff"),
	"insurance": Color("ff6fae"),
	"extra_start": Color("3ddc97"),
}

var item := ""
var dim := false # no te alcanza: se ve apagado
var _font: Font = preload("res://assets/LilitaOne-Regular.ttf")


static func color_of(it: String) -> Color:
	return COLORS.get(it, Color.WHITE)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var k := minf(size.x, size.y) / 100.0
	var off := (size - Vector2.ONE * 100.0 * k) / 2.0
	draw_set_transform(off, 0.0, Vector2.ONE * k)
	var c := color_of(item)
	# fondo: círculo del color de la mejora, con borde
	draw_circle(Vector2(50, 50), 49, INK)
	draw_circle(Vector2(50, 50), 45, c.darkened(0.45))
	draw_circle(Vector2(50, 46), 41, c.darkened(0.25))
	match item:
		"pierce":
			_pierce()
		"ricochet":
			_ricochet()
		"sight":
			_sight()
		"slowmo":
			_slowmo()
		"insurance":
			_insurance()
		"extra_start":
			_extra_start()
	if dim:
		draw_circle(Vector2(50, 50), 49, Color(0.05, 0.08, 0.06, 0.3))


# --- piezas ---

## Bala horizontal con la punta en `tip`, apuntando a `dir` (largo ~16).
func _bullet(tip: Vector2, dir: Vector2, s := 1.0) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var base := tip - d * 7.0 * s
	var back := base - d * 10.0 * s
	var w := 3.6 * s
	var casing := PackedVector2Array([base + n * w, back + n * w, back - n * w, base - n * w])
	draw_colored_polygon(casing, Color("e9c24a"))
	var head := PackedVector2Array([tip, base + n * w, base - n * w])
	draw_colored_polygon(head, Color("d98a4a"))
	draw_polyline(PackedVector2Array([tip, base + n * w, back + n * w, back - n * w, base - n * w, tip]), INK, 1.6 * s)


## Monigote (cabeza + cuerpo) parado en `feet`.
func _dude(feet: Vector2, col: Color) -> void:
	draw_rect(Rect2(feet.x - 5, feet.y - 20, 10, 20), col)
	draw_circle(Vector2(feet.x, feet.y - 26), 6.5, col)


## Texto centrado en x = pos.x (pos.y = línea de base).
func _text(t: String, pos: Vector2, fs: int, col: Color) -> void:
	pos.x -= 30.0
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_CENTER, 60, fs, 6, INK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_CENTER, 60, fs, col)


# --- íconos ---

func _pierce() -> void:
	for x in [36.0, 55.0, 74.0]: # tres en fila
		_dude(Vector2(x, 72), INK)
		draw_line(Vector2(x - 3, 44), Vector2(x + 3, 48), Color.WHITE, 1.5) # ojitos en X
		draw_line(Vector2(x + 3, 44), Vector2(x - 3, 48), Color.WHITE, 1.5)
	draw_line(Vector2(10, 58), Vector2(80, 58), Color(0.7, 0.95, 1.0, 0.45), 8.0) # estela que los atraviesa
	draw_line(Vector2(10, 58), Vector2(80, 58), Color.WHITE, 2.5)
	_bullet(Vector2(94, 58), Vector2.RIGHT, 1.0)


func _ricochet() -> void:
	draw_rect(Rect2(10, 74, 80, 7), INK) # piso
	var a := Vector2(14, 22)
	var b := Vector2(48, 73)
	var e := Vector2(78, 32)
	for seg in [[a, b], [b, e]]:
		var p0: Vector2 = seg[0]
		var p1: Vector2 = seg[1]
		for i in 6: # trazo punteado
			var t0 := i / 6.0
			draw_line(p0.lerp(p1, t0), p0.lerp(p1, t0 + 0.09), Color.WHITE, 3.0)
	for i in 6: # chispa en el rebote
		var ang := PI + i * PI / 5.0
		draw_line(b + Vector2(cos(ang), sin(ang)) * 4.0, b + Vector2(cos(ang), sin(ang)) * 10.0, Color("fff3a6"), 2.5)
	_bullet(e + (e - b).normalized() * 8.0, e - b, 1.0)


func _sight() -> void:
	var center := Vector2(62, 40)
	draw_line(Vector2(12, 84), center, Color(1.0, 0.2, 0.25, 0.4), 9.0) # láser
	draw_line(Vector2(12, 84), center, Color("ff2a3a"), 3.0)
	draw_arc(center, 20, 0, TAU, 40, INK, 6.0)
	draw_arc(center, 20, 0, TAU, 40, Color.WHITE, 3.0)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + d * 12.0, center + d * 28.0, INK, 5.0)
		draw_line(center + d * 12.0, center + d * 27.0, Color.WHITE, 2.5)
	draw_circle(center, 4.0, Color("ff2a3a"))


func _slowmo() -> void:
	var c := Vector2(46, 48)
	draw_circle(c, 28, INK)
	draw_circle(c, 24.5, Color("fffbe8"))
	for i in 12:
		var ang := i * TAU / 12.0
		draw_line(c + Vector2(cos(ang), sin(ang)) * 19.0, c + Vector2(cos(ang), sin(ang)) * 22.0, INK, 2.0)
	draw_line(c, c + Vector2(0, -16), INK, 3.5)
	draw_line(c, c + Vector2(11, 6), INK, 3.5)
	draw_circle(c, 3.0, Color("ff4d6d"))
	_text("x2", Vector2(74, 92), 30, Color("fff3a6"))


func _insurance() -> void:
	var pts := PackedVector2Array()
	for i in 40: # corazón
		var t := i * TAU / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(50, 50) + Vector2(x, y) * 2.1)
	draw_colored_polygon(pts, Color("ff3d6e"))
	pts.append(pts[0])
	draw_polyline(pts, INK, 3.5)
	draw_rect(Rect2(45, 34, 10, 30), Color.WHITE) # cruz de "vida extra"
	draw_rect(Rect2(35, 44, 30, 10), Color.WHITE)


func _extra_start() -> void:
	_bullet(Vector2(40, 16), Vector2.UP, 3.2)
	_text("+1", Vector2(68, 80), 40, Color("fff3a6"))

extends CanvasLayer
# Interfaz: HUD, panel de información, menú, mapa e intro. Todo se construye por código.

const SedeData = preload("res://sede_data.gd")
const AZUL := Color("0b3a75")
const AMAR := Color("ffc72c")
const MAP_W := 340.0
const MAP_H := 420.0

var game
var cnt: Label
var mis: Label
var toast_l: Label
var prompt_l: Label
var info_v: VBoxContainer
var menu_v: VBoxContainer
var map_v: VBoxContainer
var intro_v: VBoxContainer
var mapc: Control
var info_open := false
var th: Theme
var _tt: Tween


func _ready() -> void:
	th = _make_theme()
	var mx := 56.0 if game.touch_mode else 16.0
	cnt = _hud(Vector2(mx, 12))
	mis = _hud(Vector2(mx, 44))
	toast_l = _hud(Vector2(0, 90))
	toast_l.anchor_right = 1.0
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_l.modulate.a = 0.0
	prompt_l = _hud(Vector2(0, 0))
	prompt_l.anchor_top = 1.0
	prompt_l.anchor_bottom = 1.0
	prompt_l.anchor_right = 1.0
	prompt_l.offset_top = -80
	prompt_l.offset_bottom = -40
	prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_counter(0)
	# modales
	info_v = _modal()
	menu_v = _modal()
	map_v = _modal(MAP_W + 40.0)
	intro_v = _modal()
	mapc = Control.new()
	mapc.custom_minimum_size = Vector2(MAP_W, MAP_H)
	mapc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mapc.draw.connect(_draw_map)
	map_v.add_child(mapc)
	var b := _btn(map_v, "Cerrar mapa")
	b.pressed.connect(toggle_map)
	_lbl(intro_v, "Explora Duoc UC\nPlaza Vespucio", 30)
	_lbl(intro_v, "Bienvenido a Duoc UC Plaza Vespucio.")
	_lbl(intro_v, "%s · Froilán Roa 7107, La Florida · desde 2003. La distribución es una aproximación y se marcará como APPROXIMATE hasta verificarla con planos y fotos." % SedeData.VERSION, 14, true)
	_lbl(intro_v, _controls_hint(), 14, true)
	var go := _btn(intro_v, "Entrar")
	go.pressed.connect(func():
		_show(intro_v, false)
		game.set_paused(false))
	_show(intro_v, true)


func _make_theme() -> Theme:
	var t := Theme.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", sb)
	t.set_color("font_color", "Label", Color("0b2447"))
	t.set_font_size("font_size", "Label", 18)
	for st in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = AMAR if st != "hover" else Color("ffd55c")
		bs.set_corner_radius_all(10)
		bs.set_content_margin_all(16 if game.touch_mode else 10)
		t.set_stylebox(st, "Button", bs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", AZUL)
	t.set_font_size("font_size", "Button", 22 if game.touch_mode else 18)
	return t


func _hud(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("0b2447"))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l


func _modal(width := 480.0) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = th
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	c.add_child(p)
	add_child(c)
	c.hide()
	return v


func _show(v: Control, on: bool) -> void:
	v.get_parent().get_parent().visible = on


func _is_shown(v: Control) -> bool:
	return v.get_parent().get_parent().visible


func _clear(v: Control) -> void:
	for ch in v.get_children():
		v.remove_child(ch)
		ch.queue_free()


func _lbl(v: Control, text: String, size := 18, mute := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if mute:
		l.add_theme_color_override("font_color", Color("5a6a85"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(430, 0)
	v.add_child(l)
	return l


func _btn(v: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	v.add_child(b)
	return b


func _controls_hint() -> String:
	if game.touch_mode:
		return "Joystick izquierdo: caminar · Arrastra a la derecha: mirar · Botones: Saltar, Usar, Correr, Mapa y Menú"
	return "WASD caminar · Shift correr · Espacio saltar · E interactuar · M mapa · ESC menú"


func _qtxt() -> String:
	return "Gráficos: " + ["Baja", "Media", "Alta"][game.quality]


# ---------------- API usada por main.gd ----------------
func set_counter(n: int) -> void:
	cnt.text = "Lugares descubiertos: %d/%d" % [n, SedeData.LUGARES.size()]

func set_mission(t: String) -> void:
	mis.text = "Misión: " + t

func set_prompt(t: String) -> void:
	prompt_l.text = t if (t != "" and not game.paused) else ""

func toast(t: String) -> void:
	toast_l.text = t
	toast_l.modulate.a = 1.0
	if _tt:
		_tt.kill()
	_tt = create_tween()
	_tt.tween_interval(2.4)
	_tt.tween_property(toast_l, "modulate:a", 0.0, 0.4)

func discover(l: Dictionary, n: int) -> void:
	set_counter(n)
	toast("Lugar descubierto: " + l["n"])
	info(String(l["n"]).to_upper(), l["t"], l["ex"])

func info(title: String, text: String, ex: String) -> void:
	_clear(info_v)
	_lbl(info_v, title, 24)
	_lbl(info_v, text)
	_lbl(info_v, "Estado del dato: " + SedeData.EXL.get(ex, ex), 14, true)
	var b := _btn(info_v, "Continuar")
	b.pressed.connect(close_info)
	_show(info_v, true)
	info_open = true
	game.set_paused(true)

func talk(n: Dictionary) -> void:
	_clear(info_v)
	_lbl(info_v, "Estudiante", 24)
	var p := _lbl(info_v, n["say"])
	if n["help"] != "":
		var a := _btn(info_v, "Ayudarle")
		a.pressed.connect(func():
			p.text = n["help"]
			a.queue_free())
	var b := _btn(info_v, "Continuar")
	b.pressed.connect(close_info)
	_show(info_v, true)
	info_open = true
	game.set_paused(true)

func close_info() -> void:
	_show(info_v, false)
	info_open = false
	game.set_paused(false)

func intro_open() -> bool:
	return _is_shown(intro_v)

func toggle_menu() -> void:
	if intro_open() or info_open or game.map_open:
		return
	if _is_shown(menu_v):
		_show(menu_v, false)
		game.set_paused(false)
		return
	game.set_paused(true)
	_clear(menu_v)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, clampf(get_viewport().get_visible_rect().size.y - 270.0, 200.0, 420.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_v.add_child(sc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	_lbl(lv, "Lugares descubiertos", 22)
	for l in SedeData.LUGARES:
		_lbl(lv, ("[x] " + l["n"]) if game.found.has(l["id"]) else "[ ] ???")
	_lbl(lv, "Misiones", 22)
	for i in game.MIS.size():
		_lbl(lv, ("[x] " if game.mdone.has(i) else "[ ] ") + game.MIS[i])
	_lbl(lv, _controls_hint(), 14, true)
	var qb := _btn(menu_v, _qtxt())
	qb.pressed.connect(func():
		game.apply_quality((game.quality + 1) % 3)
		qb.text = _qtxt())
	var b := _btn(menu_v, "Continuar")
	b.pressed.connect(toggle_menu)
	_show(menu_v, true)

func toggle_map() -> void:
	if intro_open() or info_open or _is_shown(menu_v):
		return
	game.map_open = not game.map_open
	_show(map_v, game.map_open)
	game.set_paused(game.map_open)
	redraw_map()

func redraw_map() -> void:
	mapc.queue_redraw()


func _draw_map() -> void:
	var x0 := -30.0
	var x1 := 46.0
	var z0 := -38.0
	var z1 := 24.0
	var k := minf(MAP_W / (x1 - x0), MAP_H / (z1 - z0))
	var f := ThemeDB.fallback_font
	mapc.draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color("eef2f8"))
	mapc.draw_string(f, Vector2(8, 18), "Piso %d · %s (aprox.)" % [game.level + 1, SedeData.VERSION], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AZUL)
	for b in game.cols:
		if b[4] != -1 and b[4] != game.level:
			continue
		mapc.draw_rect(Rect2((b[0] - x0) * k, (b[2] - z0) * k, maxf(1.0, (b[1] - b[0]) * k), maxf(1.0, (b[3] - b[2]) * k)), Color("9aa3b2"))
	for l in SedeData.LUGARES:
		if l.get("lv", 0) != game.level:
			continue
		var p := Vector2((l["x"] - x0) * k, (l["z"] - z0) * k)
		var got: bool = game.found.has(l["id"])
		mapc.draw_circle(p, 5.0, Color("1b9e5a") if got else AMAR)
		mapc.draw_string(f, p + Vector2(7, 4), l["n"] if got else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("0b2447"))
	var pc := Vector2((game.px - x0) * k, (game.pz - z0) * k)
	var pts := PackedVector2Array([Vector2(0, -8), Vector2(6, 7), Vector2(-6, 7)])
	for i in 3:
		pts[i] = pts[i].rotated(-game.yaw) + pc
	mapc.draw_colored_polygon(pts, Color("d32f2f"))

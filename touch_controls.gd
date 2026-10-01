extends Control
# Controles táctiles: joystick flotante (mitad izquierda), mirar arrastrando (mitad derecha)
# y botones Saltar / Usar / Correr / Mapa / Menú. Soporta multitoque real.

const JOY_R := 70.0
const LOOK := 0.005
const AZUL := Color("0b3a75")
const AMAR := Color("ffc72c")

var game
var active := false
var move := Vector2.ZERO
var run_toggle := false

var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _look_id := -1
var _held := {}
var _btns := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func set_active(on: bool) -> void:
	active = on
	_reset()
	queue_redraw()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var m := 56.0
	_btns = {
		"jump": {"c": Vector2(w - m - 52.0, h - 96.0), "r": 52.0, "t": "Saltar"},
		"use": {"c": Vector2(w - m - 176.0, h - 70.0), "r": 44.0, "t": "Usar"},
		"run": {"c": Vector2(w - m - 40.0, h - 214.0), "r": 34.0, "t": "Correr"},
		"map": {"c": Vector2(w - m - 92.0, 56.0), "r": 30.0, "t": "Mapa"},
		"menu": {"c": Vector2(w - m + 4.0, 56.0), "r": 30.0, "t": "Menú"},
	}
	queue_redraw()


func _reset() -> void:
	_joy_id = -1
	_look_id = -1
	_held.clear()
	move = Vector2.ZERO


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if not active:
			game.set_touch_mode(true)
		if game.paused:
			return
		if e.pressed:
			_press(e.index, e.position)
		else:
			_release(e.index)
	elif e is InputEventScreenDrag:
		if game.paused or not active:
			return
		_drag(e.index, e.position, e.relative)


func _press(idx: int, p: Vector2) -> void:
	for n in _btns:
		var b: Dictionary = _btns[n]
		if p.distance_to(b["c"]) <= b["r"] * 1.2:
			_held[idx] = n
			_activate(n)
			queue_redraw()
			return
	if p.x < size.x * 0.5:
		if _joy_id == -1:
			_joy_id = idx
			_joy_origin = p
			_joy_knob = p
			move = Vector2.ZERO
	elif _look_id == -1:
		_look_id = idx


func _release(idx: int) -> void:
	_held.erase(idx)
	if idx == _joy_id:
		_joy_id = -1
		move = Vector2.ZERO
	elif idx == _look_id:
		_look_id = -1
	queue_redraw()


func _drag(idx: int, p: Vector2, rel: Vector2) -> void:
	if idx == _joy_id:
		var v := (p - _joy_origin) / JOY_R
		if v.length() > 1.0:
			v = v.normalized()
			_joy_origin = p - v * JOY_R
		_joy_knob = _joy_origin + v * JOY_R
		var mag := v.length()
		if mag < 0.12:
			move = Vector2.ZERO
		else:
			move = v.normalized() * ((mag - 0.12) / 0.88)
	elif idx == _look_id:
		game.yaw -= rel.x * LOOK
		game.pitch = clampf(game.pitch - rel.y * LOOK, -1.2, 1.2)


func _activate(n: String) -> void:
	match n:
		"jump": game._jump()
		"use": game.interact()
		"run": run_toggle = not run_toggle
		"map": game.ui.toggle_map()
		"menu": game.ui.toggle_menu()


func _process(_dt: float) -> void:
	if game.paused and (_joy_id != -1 or _look_id != -1 or not _held.is_empty()):
		_reset()
	game.touch_move = move if (active and not game.paused) else Vector2.ZERO
	game.touch_run = active and (run_toggle or move.length() > 0.93)
	if active:
		queue_redraw()


func _draw() -> void:
	if not active or game.paused:
		return
	var f := ThemeDB.fallback_font
	# joystick
	if _joy_id != -1:
		draw_circle(_joy_origin, JOY_R, Color(1, 1, 1, 0.10))
		draw_arc(_joy_origin, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
		draw_circle(_joy_knob, 30.0, Color(1, 1, 1, 0.50))
	else:
		var hint := Vector2(150.0, size.y - 120.0)
		draw_arc(hint, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 2.0, true)
		draw_circle(hint, 26.0, Color(1, 1, 1, 0.14))
	# botones
	var can_use: bool = game.near_obj != null
	for n in _btns:
		var b: Dictionary = _btns[n]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var down := _held.values().has(n)
		var on: bool = (n == "run" and run_toggle) or (n == "use" and can_use)
		var fill := Color(AZUL.r, AZUL.g, AZUL.b, 0.55)
		var line := Color(1, 1, 1, 0.55)
		var txt := Color(1, 1, 1, 0.95)
		if on:
			fill = Color(AMAR.r, AMAR.g, AMAR.b, 0.85)
			line = Color(1, 1, 1, 0.9)
			txt = AZUL
		if down:
			fill = fill.lightened(0.25)
			r *= 0.94
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, line, 3.0, true)
		var fs := 18 if r > 40.0 else 15
		draw_string(f, Vector2(c.x - r, c.y + fs * 0.35), b["t"], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, txt)

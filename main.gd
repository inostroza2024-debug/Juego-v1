extends Node3D
# Explora Duoc UC — Plaza Vespucio (V0.5), port a Godot 4

const SedeData = preload("res://sede_data.gd")
const WorldBuilder = preload("res://world.gd")
const GameUI = preload("res://ui.gd")
const TouchControls = preload("res://touch_controls.gd")
const H := 3.8
const EMU := -1  # id de dispositivo de eventos de mouse emulados desde touch

const MIS := [
	"Encuentra la biblioteca",
	"Encuentra el patio central",
	"Encuentra un laboratorio",
	"Encuentra el Punto Estudiantil (en el patio central)",
	"Explora dos pisos de la sede",
	"Habla con 3 estudiantes",
	"Descubre el Auditorio y el Taller de Diseño",
	"Encuentra cinco lugares desconocidos",
]

const NPC_DEFS := [
	{"x": -8, "z": 8, "lv": 0, "say": "¿Sabes dónde está la biblioteca?", "help": "Cruza el patio, entra a la galería del edificio y busca el letrero azul de la Biblioteca. También puedes abrir el mapa (M)."},
	{"lv": 0, "path": [[-20, -14.8], [9, -14.8]], "say": "Estoy buscando el laboratorio. ¿Me ayudas?", "help": "Según el mapa, está al extremo derecho de la galería. Mira los letreros junto a cada puerta."},
	{"x": -9.5, "z": -0.2, "lv": 0, "say": "Necesito hacer un trámite. ¿Es aquí el Punto Estudiantil?", "help": "Sí: el Punto Estudiantil está en el patio central."},
	{"x": 9, "z": -1, "lv": 0},
	{"x": 9.9, "z": -1, "lv": 0},
	{"lv": 0, "path": [[-18, 10], [18, 10]], "say": "¡Voy atrasado a clases!"},
	{"x": -20, "z": -21.8, "lv": 0, "say": "Estoy estudiando en la biblioteca para una prueba de Gestión Logística.", "help": "La biblioteca y los espacios de estudio son un buen lugar para preparar pruebas."},
	{"x": -18, "z": -14.8, "lv": 1, "say": "¿Sabías que la sede reúne varias áreas de estudio?", "help": "Administración y Negocios, Informática y Telecomunicaciones, Diseño y Comunicación."},
	{"lv": 1, "path": [[-18, -14.8], [9, -14.8]], "say": "Estoy buscando la sala de mi próxima clase.", "help": "Las salas están numeradas por piso; fíjate en el letrero junto a cada puerta."},
]

var ui
var cam: Camera3D
var cols: Array = []
var npcs: Array = []
var paused := true
var map_open := false
var found := {}
var talked := {}
var mdone := {}
var near_obj = null
var time := 0.0

var touch_mode := false
var touch_move := Vector2.ZERO
var touch_run := false
var touch
var _mobile_os := false
var quality := 2
var sun: DirectionalLight3D
var env: Environment
var clouds: Node3D
var interior_lights: Node3D

var px := 0.0
var pz := 20.0
var yaw := 0.0
var pitch := 0.0
var level := 0
var py := 0.0
var jh := 0.0
var vy := 0.0
var bob := 0.0
var step_t := 0.0


func _ready() -> void:
	_mobile_os = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	touch_mode = _mobile_os
	quality = 1 if _mobile_os else 2
	_setup_environment()
	var wb = WorldBuilder.new()
	wb.build(self)
	cols = wb.cols
	clouds = wb.clouds
	interior_lights = wb.lights
	_build_npcs()
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.15
	cam.far = 400.0
	add_child(cam)
	# controles táctiles (debajo de los menús)
	var tl := CanvasLayer.new()
	add_child(tl)
	touch = TouchControls.new()
	touch.game = self
	tl.add_child(touch)
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	touch.set_active(touch_mode)
	apply_quality(quality)
	set_paused(true)


func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("3b78cc")
	psm.sky_horizon_color = Color("c4dcf0")
	psm.ground_horizon_color = Color("c4dcf0")
	psm.ground_bottom_color = Color("7b9b5d")
	psm.sky_curve = 0.22
	psm.ground_curve = 0.03
	psm.sun_angle_max = 28.0
	psm.sun_curve = 0.12
	psm.use_debanding = true
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color("cfe3f2")
	env.fog_density = 0.0032
	# Solo tienen efecto con el renderer Mobile / Forward+ (ver README)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff0d2")
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.4
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)


# Calidad gráfica: 0 Baja · 1 Media · 2 Alta
func apply_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	var vp := get_viewport()
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.75
			sun.shadow_enabled = false
			env.glow_enabled = false
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 70.0
			env.glow_enabled = false
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 110.0
			env.glow_enabled = true
	if interior_lights:
		interior_lights.visible = quality >= 1


func set_touch_mode(on: bool) -> void:
	touch_mode = on
	if touch:
		touch.set_active(on)
	set_paused(paused)


func set_paused(p: bool) -> void:
	paused = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (p or touch_mode) else Input.MOUSE_MODE_CAPTURED


# ---------------- entrada ----------------
func _notification(what: int) -> void:
	# botón "atrás" de Android
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and ui != null:
		if ui.info_open:
			ui.close_info()
		elif map_open:
			ui.toggle_map()
		else:
			ui.toggle_menu()


func _input(e: InputEvent) -> void:
	# en equipos híbridos, volver a teclado/mouse oculta los controles táctiles
	if touch_mode and not _mobile_os:
		if (e is InputEventKey and e.pressed) or (e is InputEventMouseMotion and e.device != EMU):
			set_touch_mode(false)
	if e is InputEventMouseMotion and not paused and not touch_mode and e.device != EMU:
		yaw -= e.relative.x * 0.003
		pitch = clampf(pitch - e.relative.y * 0.003, -1.2, 1.2)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_E: interact()
			KEY_SPACE: _jump()
			KEY_M: ui.toggle_map()
			KEY_ESCAPE:
				if ui.info_open:
					ui.close_info()
				else:
					ui.toggle_menu()
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_A: _jump()
			JOY_BUTTON_X: interact()
			JOY_BUTTON_START: ui.toggle_menu()
			JOY_BUTTON_BACK: ui.toggle_map()


func _jump() -> void:
	if jh == 0.0 and not paused:
		vy = 4.2


func _dz(v: float) -> float:
	return v if absf(v) > 0.18 else 0.0


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


# ---------------- bucle ----------------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	if not paused:
		_update_player(dt)
		_update_interactions()
		_update_npcs(dt)
	_update_missions()
	if clouds:
		clouds.rotation.y += dt * 0.004
	cam.position = Vector3(px, py + jh + 1.65 + bob, pz)
	cam.rotation = Vector3(pitch, yaw, 0)
	if map_open:
		ui.redraw_map()


func _update_player(dt: float) -> void:
	var f := 0.0
	var s := 0.0
	if _key(KEY_W) or _key(KEY_UP): f += 1.0
	if _key(KEY_S) or _key(KEY_DOWN): f -= 1.0
	if _key(KEY_D) or _key(KEY_RIGHT): s += 1.0
	if _key(KEY_A) or _key(KEY_LEFT): s -= 1.0
	f -= touch_move.y
	s += touch_move.x
	f -= _dz(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	s += _dz(Input.get_joy_axis(0, JOY_AXIS_LEFT_X))
	yaw -= _dz(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)) * 2.2 * dt
	pitch = clampf(pitch - _dz(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)) * 1.6 * dt, -1.2, 1.2)
	var m := sqrt(f * f + s * s)
	if m > 1.0:
		f /= m
		s /= m
	var run := _key(KEY_SHIFT) or touch_run or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	var v := (7.5 if run else 4.2) * dt
	var sn := sin(yaw)
	var cs := cos(yaw)
	px += (-sn * f + cs * s) * v
	pz += (-cs * f - sn * s) * v
	var r := 0.45
	for n in 2:
		for b in cols:
			if b[4] != -1 and b[4] != level:
				continue
			if px > b[0] - r and px < b[1] + r and pz > b[2] - r and pz < b[3] + r:
				var d := [px - (b[0] - r), b[1] + r - px, pz - (b[2] - r), b[3] + r - pz]
				var mi: float = d.min()
				if mi == d[0]: px = b[0] - r
				elif mi == d[1]: px = b[1] + r
				elif mi == d[2]: pz = b[2] - r
				else: pz = b[3] + r
	px = clampf(px, -60.0, 60.0)
	pz = clampf(pz, -40.0, 34.0)
	var in_ramp := px >= 12.0 and px <= 21.5 and pz >= -16.4 and pz <= -13.4
	if in_ramp:
		if px < 13.0: level = 0
		elif px > 20.5: level = 1
	var ty := (px - 12.0) / 9.5 * H if in_ramp else level * H
	py += (ty - py) * minf(1.0, dt * 14.0)
	if jh > 0.0 or vy > 0.0:
		vy -= 11.0 * dt
		jh = maxf(0.0, jh + vy * dt)
		if jh == 0.0:
			vy = 0.0
	step_t += dt * ((11.0 if run else 8.0) if m > 0.1 else 0.0)
	bob = sin(step_t) * 0.035 if m > 0.1 else 0.0


# ---------------- interacción y misiones ----------------
func _update_interactions() -> void:
	for l in SedeData.LUGARES:
		if not found.has(l["id"]) and l.get("lv", 0) == level and Vector2(px - l["x"], pz - l["z"]).length() < l["r"]:
			found[l["id"]] = true
			ui.discover(l, found.size())
	var best = null
	var bd := 1e9
	for o in SedeData.OBJETOS:
		var d := Vector2(px - o["x"], pz - o["z"]).length()
		if o.get("lv", 0) == level and d < o["r"] and d < bd:
			bd = d
			best = o
	for n in npcs:
		if n["say"] == "" or n["lv"] != level:
			continue
		var p: Vector3 = n["g"].position
		var d := Vector2(px - p.x, pz - p.z).length()
		if d < 2.6 and d < bd:
			bd = d
			best = {"n": "Hablar con estudiante", "npc": n}
	near_obj = best
	ui.set_prompt((("Toca USAR · " if touch_mode else "E · ") + best["n"]) if best else "")


func interact() -> void:
	if ui.info_open:
		ui.close_info()
		return
	if paused or near_obj == null:
		return
	var o: Dictionary = near_obj
	if o.has("npc"):
		talked[o["npc"]["id"]] = true
		ui.talk(o["npc"])
	else:
		ui.info(o["n"], o["t"], o["ex"])


func _mission_ok(i: int) -> bool:
	match i:
		0: return found.has("biblioteca")
		1: return found.has("patio")
		2: return found.has("lab")
		3: return found.has("punto")
		4: return found.has("piso2")
		5: return talked.size() >= 3
		6: return found.has("audit") and found.has("taller")
		7: return found.size() >= 5
	return false


func _update_missions() -> void:
	for i in MIS.size():
		if not mdone.has(i) and _mission_ok(i):
			mdone[i] = true
			var t: String = "Misión completada: " + MIS[i]
			get_tree().create_timer(1.2).timeout.connect(func(): ui.toast(t))
	var cur := -1
	for i in MIS.size():
		if not mdone.has(i):
			cur = i
			break
	ui.set_mission("¡Todas las misiones completadas!" if cur < 0 else MIS[cur])


# ---------------- estudiantes (NPC) ----------------
func _mat(col: Color, rough := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	return mat


# forma: "box" | "cap" (cápsula) | "sph" (esfera) | "dome" (media esfera)
func _part(parent: Node3D, size: Vector3, col: Color, pos: Vector3, shape := "box", rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match shape:
		"cap":
			var cm := CapsuleMesh.new()
			cm.radius = minf(size.x, size.z) * 0.5
			cm.height = maxf(size.y, cm.radius * 2.0)
			cm.radial_segments = 14
			cm.rings = 4
			mi.mesh = cm
			mi.scale = Vector3(size.x / (cm.radius * 2.0), 1.0, size.z / (cm.radius * 2.0))
		"sph":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			sm.radial_segments = 16
			sm.rings = 8
			mi.mesh = sm
		"dome":
			var dm := SphereMesh.new()
			dm.radius = size.x * 0.5
			dm.height = dm.radius
			dm.is_hemisphere = true
			dm.radial_segments = 16
			dm.rings = 6
			mi.mesh = dm
		_:
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
	mi.material_override = _mat(col, rough)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(g: Node3D, x: float, y: float) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(x, y, 0)
	g.add_child(p)
	return p


func _build_npcs() -> void:
	var skins := [Color("f1c9a5"), Color("d9a57a"), Color("a8734f"), Color("7a4b30")]
	var hairs := [Color("1b1b1b"), Color("3b2a1a"), Color("6b4423"), Color("c9a24a"), Color("222a44")]
	var shirts := [Color("2e7d32"), Color("1565c0"), Color("c62828"), Color("6a1b9a"), Color("ef6c00"), Color("37474f"), Color("f9a825"), Color("eeeeee")]
	var pants := [Color("263238"), Color("1a237e"), Color("3e2723"), Color("424242")]
	for i in NPC_DEFS.size():
		var d: Dictionary = NPC_DEFS[i]
		var g := Node3D.new()
		var sk: Color = skins[i % 4]
		var sh: Color = shirts[i % 8]
		var pn: Color = pants[i % 4]
		var hc: Color = hairs[(i * 3) % 5]
		# torso, cabeza y pelo
		_part(g, Vector3(0.42, 0.66, 0.26), sh, Vector3(0, 1.15, 0), "cap", 0.9)
		_part(g, Vector3(0.1, 0.1, 0.1), sk, Vector3(0, 1.43, 0), "cap", 0.6)
		_part(g, Vector3(0.27, 0.31, 0.27), sk, Vector3(0, 1.58, 0), "sph", 0.55)
		_part(g, Vector3(0.3, 0.2, 0.3), hc, Vector3(0, 1.6, -0.01), "dome", 0.7)
		_part(g, Vector3(0.29, 0.26, 0.12), hc, Vector3(0, 1.58, -0.085), "sph", 0.7)
		_part(g, Vector3(0.04, 0.04, 0.03), Color("1b1612"), Vector3(-0.06, 1.6, 0.125), "sph", 0.3)
		_part(g, Vector3(0.04, 0.04, 0.03), Color("1b1612"), Vector3(0.06, 1.6, 0.125), "sph", 0.3)
		var al := _pivot(g, -0.27, 1.42)
		var ar := _pivot(g, 0.27, 1.42)
		var ll := _pivot(g, -0.1, 0.85)
		var lr := _pivot(g, 0.1, 0.85)
		for a in [al, ar]:
			_part(a, Vector3(0.12, 0.58, 0.12), sh, Vector3(0, -0.29, 0), "cap", 0.9)
			_part(a, Vector3(0.1, 0.1, 0.1), sk, Vector3(0, -0.6, 0), "sph", 0.55)
		for l in [ll, lr]:
			_part(l, Vector3(0.18, 0.86, 0.18), pn, Vector3(0, -0.43, 0), "cap", 0.85)
			_part(l, Vector3(0.19, 0.09, 0.3), Color("1b1b1f"), Vector3(0, -0.82, 0.05), "box", 0.6)
		if i % 2 == 0:
			_part(g, Vector3(0.34, 0.42, 0.16), Color("263238"), Vector3(0, 1.2, -0.19), "cap", 0.9)
		var path: Array = d.get("path", [])
		var start := Vector2(d.get("x", 0), d.get("z", 0))
		if path.size() > 0:
			start = Vector2(path[0][0], path[0][1])
		g.position = Vector3(start.x, d["lv"] * H, start.y)
		add_child(g)
		npcs.append({"id": i, "g": g, "lv": d["lv"], "path": path, "i": 1, "say": d.get("say", ""), "help": d.get("help", ""), "aL": al, "aR": ar, "lL": ll, "lR": lr})


func _update_npcs(dt: float) -> void:
	for n in npcs:
		var g: Node3D = n["g"]
		var mv := false
		var path: Array = n["path"]
		if path.size() > 0:
			var tg: Array = path[n["i"]]
			var dx: float = tg[0] - g.position.x
			var dz: float = tg[1] - g.position.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist < 0.3:
				n["i"] = (n["i"] + 1) % path.size()
			else:
				mv = true
				g.position.x += dx / dist * 1.1 * dt
				g.position.z += dz / dist * 1.1 * dt
				g.rotation.y = atan2(dx, dz)
				g.position.y = n["lv"] * H + absf(sin(time * 7.0 + n["id"])) * 0.03
		elif n["lv"] == level and Vector2(px - g.position.x, pz - g.position.z).length() < 4.0:
			g.rotation.y = atan2(px - g.position.x, pz - g.position.z)
		var sw := sin(time * 7.0 + n["id"]) * 0.6 if mv else 0.0
		n["lL"].rotation.x = sw
		n["lR"].rotation.x = -sw
		n["aL"].rotation.x = -sw * 0.8
		n["aR"].rotation.x = sw * 0.8

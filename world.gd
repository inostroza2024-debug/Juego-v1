extends RefCounted
# Construye la sede completa por código. cols = cajas de colisión [x1, x2, z1, z2, nivel] (nivel -1 = todos).

const H := 3.8
const AZUL := Color("0b3a75")
const AMAR := Color("ffc72c")

var par: Node3D
var lv := 0
var cols: Array = []
var T := {}


func build(root: Node3D) -> void:
	par = root
	lights = Node3D.new()
	root.add_child(lights)
	_make_textures()
	_main_level()
	_second_floor(root)
	_extras()
	_lights()
	_clouds()


# ---------------- texturas procedurales (albedo + normal + rugosidad) ----------------
const TS := 256
var rng := RandomNumberGenerator.new()
var M := {}
var clouds: Node3D
var lights: Node3D


func _tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _ntex(h: Image, strength: float) -> ImageTexture:
	var n: Image = h.duplicate()
	n.bump_map_to_normal_map(strength)
	n.generate_mipmaps(true)
	return ImageTexture.create_from_image(n)


# ruido fractal que se repite sin costuras (gris -> RGBA)
func _fnoise(freq: float, oct := 4, sd := 1, w := TS, h := TS) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = oct
	n.frequency = freq
	n.seed = sd
	var img: Image = n.get_seamless_image(w, h, false, false, 0.15, true)
	img.convert(Image.FORMAT_RGBA8)
	return img


# ruido estirado en vertical (vetas de madera / corteza)
func _streaks(freq: float, sd: int) -> Image:
	var img := _fnoise(freq, 4, sd, TS, 32)
	img.resize(TS, TS, Image.INTERPOLATE_BILINEAR)
	return img


# compensa el gris medio del ruido para que el color final sea el pedido
func _c(c: Color, a: float) -> Color:
	var k := (1.0 - a) * 0.5
	return Color(clampf((c.r - k) / a, 0.0, 1.0), clampf((c.g - k) / a, 0.0, 1.0), clampf((c.b - k) / a, 0.0, 1.0), a)


func _blank() -> Image:
	return Image.create(TS, TS, false, Image.FORMAT_RGBA8)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func _finish(albedo: Image, layer: Image, height: Image, bump: float, rough: float) -> ImageTexture:
	albedo.blend_rect(layer, Rect2i(0, 0, TS, TS), Vector2i.ZERO)
	var t := _tex(albedo)
	if bump > 0.0:
		t.set_meta("normal", _ntex(height, bump))
	t.set_meta("rough", rough)
	return t


func _surface(base: Color, freq: float, oct: int, grain: float, sd: int, bump: float, rough: float) -> ImageTexture:
	var n := _fnoise(freq, oct, sd)
	var h: Image = n.duplicate()
	var layer := _blank()
	layer.fill(_c(base, 1.0 - grain))
	return _finish(n, layer, h, bump, rough)


func _tiles(base: Color, grout: Color, n: int, sd: int, rough: float, vr := 0.03) -> ImageTexture:
	var s := TS / n
	var noi := _fnoise(0.05, 4, sd)
	var h: Image = noi.duplicate()
	var layer := _blank()
	var hl := _blank()
	layer.fill(Color(grout.r, grout.g, grout.b, 0.92))
	hl.fill(Color(0.1, 0.1, 0.1, 1.0))
	for i in n:
		for j in n:
			var d := rng.randf_range(-vr, vr)
			var r := Rect2i(i * s + 1, j * s + 1, s - 2, s - 2)
			layer.fill_rect(r, _c(Color(base.r + d, base.g + d * 0.9, base.b + d * 0.8), 0.78))
			hl.fill_rect(r, Color(0.7, 0.7, 0.7, 0.8))
	h.blend_rect(hl, Rect2i(0, 0, TS, TS), Vector2i.ZERO)
	return _finish(noi, layer, h, 12.0, rough)


func _wood() -> ImageTexture:
	var np := 8
	var pw := TS / np
	var g := _streaks(0.05, 21)
	var h: Image = g.duplicate()
	var layer := _blank()
	var hl := _blank()
	layer.fill(Color(0.15, 0.09, 0.04, 1.0))
	hl.fill(Color(0.1, 0.1, 0.1, 1.0))
	for i in np:
		var d := rng.randf_range(-0.07, 0.07)
		var col := Color(0.62 + d, 0.43 + d * 0.8, 0.25 + d * 0.6)
		layer.fill_rect(Rect2i(i * pw + 1, 0, pw - 1, TS), _c(col, 0.68))
		hl.fill_rect(Rect2i(i * pw + 1, 0, pw - 1, TS), Color(0.7, 0.7, 0.7, 0.85))
		var jy := rng.randi_range(20, TS - 20)
		layer.fill_rect(Rect2i(i * pw, jy, pw, 1), Color(0.15, 0.09, 0.04, 1.0))
		hl.fill_rect(Rect2i(i * pw, jy, pw, 1), Color(0.1, 0.1, 0.1, 1.0))
	h.blend_rect(hl, Rect2i(0, 0, TS, TS), Vector2i.ZERO)
	return _finish(g, layer, h, 10.0, 0.5)


func _bark() -> ImageTexture:
	var g := _streaks(0.08, 51)
	var h: Image = g.duplicate()
	var layer := _blank()
	layer.fill(_c(Color("5a4026"), 0.6))
	return _finish(g, layer, h, 14.0, 1.0)


func _ceiling() -> ImageTexture:
	var n := _fnoise(0.3, 3, 61)
	var layer := _blank()
	var hl := _blank()
	var h: Image = n.duplicate()
	layer.fill(Color(0.62, 0.64, 0.68, 1.0))
	var s := TS / 4
	for i in 4:
		for j in 4:
			layer.fill_rect(Rect2i(i * s + 1, j * s + 1, s - 2, s - 2), _c(Color("eceef0"), 0.85))
			for k in 14:
				var px := i * s + rng.randi_range(4, s - 6)
				var py := j * s + rng.randi_range(4, s - 6)
				layer.fill_rect(Rect2i(px, py, 2, 2), Color(0.6, 0.62, 0.66, 1.0))
	return _finish(n, layer, h, 0.0, 0.9)


func _paint() -> ImageTexture:
	# una planta (3.8 m): zócalo oscuro abajo y una línea tenue a ~1 m
	var n := _fnoise(0.08, 3, 11)
	var layer := _blank()
	var h: Image = n.duplicate()
	layer.fill(_c(Color("f1ede2"), 0.93))
	layer.fill_rect(Rect2i(0, TS - 5, TS, 5), Color(0.35, 0.37, 0.4, 1.0))
	layer.fill_rect(Rect2i(0, TS - 72, TS, 2), _c(Color(0.8, 0.78, 0.72), 0.9))
	return _finish(n, layer, h, 0.0, 0.95)


func _facade() -> ImageTexture:
	# un módulo de fachada: 3 m de ancho x 1 planta (3.8 m); abajo = nivel de piso
	var n := _fnoise(0.03, 5, 31)
	var layer := _blank()
	var h: Image = n.duplicate()
	var frame := Color(0.12, 0.15, 0.22, 1.0)
	layer.fill(_c(Color("dfe2e6"), 0.82))
	layer.fill_rect(Rect2i(0, TS - 12, TS, 8), Color("0b3a75"))
	layer.fill_rect(Rect2i(0, TS - 4, TS, 4), Color("ffc72c"))
	layer.fill_rect(Rect2i(38, 58, 180, 142), frame)
	layer.fill_rect(Rect2i(34, 200, 188, 6), Color(0.78, 0.8, 0.83, 1.0))
	for y in range(64, 194):
		var t := float(y - 64) / 130.0
		var gc := Color(0.62 - 0.32 * t, 0.78 - 0.33 * t, 0.92 - 0.26 * t, 1.0)
		layer.fill_rect(Rect2i(44, y, 168, 1), gc)
		var sx := 70 + int((y - 64) * 0.55)
		layer.fill_rect(Rect2i(sx, y, 14, 1), gc.lightened(0.18))
		layer.fill_rect(Rect2i(sx + 24, y, 5, 1), gc.lightened(0.12))
	layer.fill_rect(Rect2i(126, 64, 4, 130), frame)
	layer.fill_rect(Rect2i(44, 110, 168, 4), frame)
	return _finish(n, layer, h, 0.0, 0.6)


func _stairs() -> ImageTexture:
	# un peldaño (0.4 m): borde amarillo y ranuras antideslizantes
	var n := _fnoise(0.15, 3, 71)
	var layer := _blank()
	var hl := _blank()
	var h: Image = n.duplicate()
	layer.fill(_c(Color("8b9099"), 0.7))
	hl.fill(Color(0.7, 0.7, 0.7, 0.8))
	layer.fill_rect(Rect2i(0, 0, 24, TS), Color("f2c744"))
	for x in [80, 120, 160, 200, 240]:
		layer.fill_rect(Rect2i(x, 0, 3, TS), Color(0.2, 0.22, 0.26, 1.0))
		hl.fill_rect(Rect2i(x, 0, 3, TS), Color(0.0, 0.0, 0.0, 1.0))
	h.blend_rect(hl, Rect2i(0, 0, TS, TS), Vector2i.ZERO)
	return _finish(n, layer, h, 10.0, 0.6)


func _make_textures() -> void:
	rng.seed = 20260401
	T.paving = _tiles(Color("cdcac2"), Color("8f8b82"), 4, 3, 0.8, 0.04)
	T.tile = _tiles(Color("e8e6df"), Color("b9b6aa"), 4, 5, 0.32, 0.025)
	T.concrete = _surface(Color("c1c4c9"), 0.02, 5, 0.4, 7, 8.0, 0.9)
	T.grass = _surface(Color("6c9a4b"), 0.04, 6, 0.55, 9, 5.0, 0.95)
	T.road = _surface(Color("33363c"), 0.15, 3, 0.5, 13, 10.0, 0.95)
	T.carpet = _surface(Color("5b2f3d"), 0.35, 2, 0.55, 17, 12.0, 1.0)
	T.rubber = _surface(Color("3b4048"), 0.2, 2, 0.5, 19, 14.0, 0.8)
	T.leaf = _surface(Color("3f8230"), 0.12, 4, 0.5, 41, 8.0, 0.9)
	T.ceil = _ceiling()
	T.paint = _paint()
	T.wood = _wood()
	T.bark = _bark()
	T.facade = _facade()
	T.stair = _stairs()
	# materiales 3D con proyección por metro (muros y muebles): la textura no se estira
	M.facade = mw(Color.WHITE, T.facade, 3.0, H)
	M.paint = mw(Color.WHITE, T.paint, 3.0, H)
	M.ceil = mw(Color.WHITE, T.ceil, 2.4)
	M.wood = mw(Color.WHITE, T.wood, 1.6)


# ---------------- helpers ----------------
func mt(c: Color, tex = null, rep := Vector2.ONE, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(rep.x, rep.y, 1)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = tex.get_meta("rough", 0.85)
		if tex.has_meta("normal"):
			m.normal_enabled = true
			m.normal_texture = tex.get_meta("normal")
			m.normal_scale = 1.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.1
	return m


# textura proyectada en coordenadas del mundo (1 repetición cada sx x sy metros)
func mw(c: Color, tex: Texture2D, sx: float, sy := -1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex
	m.roughness = tex.get_meta("rough", 0.85)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / sx, 1.0 / (sy if sy > 0.0 else sx), 1.0 / sx)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func mu(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func add_mesh(mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = m
	o.position = pos
	par.add_child(o)
	return o

func box(x, y, z, w, h, d, m: Material, solid := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	if solid:
		cols.append([x - w / 2.0, x + w / 2.0, z - d / 2.0, z + d / 2.0, lv])
	return add_mesh(bm, m, Vector3(x, y, z))

func boxes(list: Array, m: Material, solid := false) -> void:
	for p in list:
		box(p[0], p[1], p[2], p[3], p[4], p[5], m, solid)

func cyl(x, y, z, r, h, m: Material, solid := false, rtop = -1.0) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if rtop < 0.0 else rtop
	cm.height = h
	cm.radial_segments = 16
	add_mesh(cm, m, Vector3(x, y, z))
	if solid:
		cols.append([x - r, x + r, z - r, z + r, lv])

func sph(x, y, z, r, hh, m: Material) -> void:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = hh
	sm.radial_segments = 20
	sm.rings = 10
	add_mesh(sm, m, Vector3(x, y, z))

func quad(x, y, z, w, h, m: Material, ry := 0.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var o := add_mesh(q, m, Vector3(x, y, z))
	o.rotation.y = ry
	return o

# plano horizontal (marcas de calle, etc.)
func flat(x, y, z, w, d, m: Material) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	add_mesh(pm, m, Vector3(x, y, z))

func fl(x1, x2, z1, z2, key: String, y, step := 2.0) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(x2 - x1, z2 - z1)
	var m := mt(Color.WHITE, T[key], Vector2((x2 - x1) / step, (z2 - z1) / step))
	add_mesh(pm, m, Vector3((x1 + x2) / 2.0, y, (z1 + z2) / 2.0))

func wall(x1, z1, x2, z2, ext := false) -> void:
	var t := 0.6 if ext else 0.4
	var w = absf(x2 - x1) + t
	var d = absf(z2 - z1) + t
	box((x1 + x2) / 2.0, H / 2.0, (z1 + z2) / 2.0, w, H, d, M.facade if ext else M.paint, true)

func blk(x, z, w, d, h, m: Material) -> void:
	box(x, h / 2.0, z, w, h, d, m, true)

# árbol: tronco con corteza + copa de varias esferas
func tree(x: float, z: float, s := 1.0) -> void:
	var bark := mt(Color.WHITE, T.bark, Vector2(2, 2))
	var leaf := mt(Color.WHITE, T.leaf, Vector2(3, 3))
	var leaf2 := mt(Color("c9e6b8"), T.leaf, Vector2(3, 3))
	cyl(x, 1.3 * s, z, 0.24 * s, 2.6 * s, bark, false, 0.15 * s)
	sph(x, 4.1 * s, z, 1.7 * s, 3.2 * s, leaf)
	sph(x + 1.0 * s, 3.5 * s, z + 0.3 * s, 1.2 * s, 2.3 * s, leaf2)
	sph(x - 0.9 * s, 3.7 * s, z - 0.5 * s, 1.3 * s, 2.5 * s, leaf2)
	sph(x + 0.1 * s, 5.2 * s, z - 0.2 * s, 1.1 * s, 2.1 * s, leaf)

func _omni(x: float, y: float, z: float) -> void:
	var o := OmniLight3D.new()
	o.position = Vector3(x, y, z)
	o.light_color = Color("fff3e0")
	o.light_energy = 0.9
	o.omni_range = 9.0
	o.omni_attenuation = 1.3
	o.shadow_enabled = false
	lights.add_child(o)

func label_sign(text: String, w, h, bg: Color, fg: Color, x, y, z, ry := 0.0) -> void:
	var n := Node3D.new()
	n.position = Vector3(x, y, z)
	n.rotation.y = ry
	par.add_child(n)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.material_override = mu(bg)
	n.add_child(q)
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = minf(h * 0.6 / 64.0, w * 0.9 / (text.length() * 34.0))
	l.modulate = fg
	l.shaded = false
	l.position.z = 0.01
	n.add_child(l)


# ---------------- planta baja ----------------
func _main_level() -> void:
	var wood: Material = M.wood
	var blue := mt(AZUL)
	fl(-300, 300, -300, 300, "grass", 0.0, 3.0)
	fl(-60, 60, -12, 34, "paving", 0.02)
	fl(-150, 150, 24, 36, "road", 0.03, 6.0)
	fl(-24, 24, -18, -12, "tile", 0.03)
	# edificio principal
	wall(-24, -36, 24, -36, true)
	wall(-24, -36, -24, -12, true)
	wall(24, -36, 24, -12, true)
	label_sign("DUOC UC", 14, 2.2, AZUL, AMAR, 0, 13.2, -11.95)
	var concrete := mt(Color.WHITE, T.concrete, Vector2(1, 2))
	for i in range(8):
		cyl(-21 + i * 6, H / 2.0, -12.4, 0.25, H, concrete, true)
	for s in [[-24, -19.2], [-16.8, -7.2], [-4.8, 4.8], [7.2, 16.8], [19.2, 24]]:
		wall(s[0], -18, s[1], -18)
	for x in [-12, 0, 12]:
		wall(x, -36, x, -18)
	var fr := []
	for x in [-18, -6, 6, 18]:
		fr.append([x - 1.2, 1.3, -18, 0.14, 2.6, 0.5])
		fr.append([x + 1.2, 1.3, -18, 0.14, 2.6, 0.5])
		fr.append([x, 2.68, -18, 2.5, 0.16, 0.5])
	boxes(fr, blue)
	var names := [["Biblioteca", -18], ["Sala 102", -6], ["Sala 101", 6], ["Laboratorio", 18]]
	for p in names:
		label_sign(p[0], 2.4, 0.5, AZUL, Color.WHITE, p[1], 3.2, -17.75)
	fl(-24, -12, -36, -18, "wood", 0.04)
	fl(-12, 0, -36, -18, "tile", 0.04)
	fl(0, 12, -36, -18, "tile", 0.04)
	fl(12, 24, -36, -18, "concrete", 0.04)
	# biblioteca
	var sh := []
	for z in [-34.5, -31.5]:
		for x in [-21.5, -18, -14.5]:
			sh.append([x, 1.1, z, 3, 2.2, 0.7])
	boxes(sh, wood, true)
	boxes([[-21, 0.4, -23, 2.6, 0.8, 1.4], [-15, 0.4, -23, 2.6, 0.8, 1.4]], wood, true)
	# sala 102 (escritorios) y sala 101
	var d2 := []
	for z in [-22, -25, -28, -31]:
		for x in [-9.4, -2.6, 2.6, 9.4]:
			d2.append([x, 0.38, z, 2.6, 0.76, 0.8])
	boxes(d2, wood, true)
	var board := mt(Color("2f4f3f"))
	quad(-6, 1.9, -35.78, 6, 1.6, board)
	quad(6, 1.9, -35.78, 6, 1.6, board)
	# laboratorio
	var lt := []
	var mo := []
	for z in [-22, -25, -28, -31, -34]:
		for x in [14.6, 21.4]:
			lt.append([x, 0.38, z, 3.2, 0.76, 1])
			mo.append([x, 1.05, z - 0.2, 0.7, 0.45, 0.1])
	boxes(lt, mt(Color("b7bcc6")), true)
	boxes(mo, mu(Color("1c2a44")))
	# segundo edificio
	box(33, 5.5, 0, 18, 11, 24, M.facade)
	cols.append([24, 42, -12, 12, lv])
	# cerco y portal
	var gray := mt(Color("9aa1ab"))
	blk(-13.5, 14.5, 21, 0.3, 1.2, gray)
	blk(13.5, 14.5, 21, 0.3, 1.2, gray)
	blk(-3.2, 14.5, 0.4, 0.4, 4, blue)
	blk(3.2, 14.5, 0.4, 0.4, 4, blue)
	box(0, 4.2, 14.5, 6.8, 0.8, 0.5, blue)
	label_sign("DUOC UC", 6.2, 0.7, AZUL, AMAR, 0, 4.2, 14.76)
	# patio: bancas, Punto Estudiantil, árboles
	var bench := mt(Color("8a6a44"))
	boxes([[-9, 0.25, 4, 2, 0.5, 0.6], [9, 0.25, 4, 2, 0.5, 0.6], [9, 0.25, -4, 2, 0.5, 0.6]], bench, true)
	blk(-10, -3.2, 4.2, 0.9, 1.1, mt(AMAR))
	for p in [[-12.6, -5.5], [-7.4, -5.5], [-12.6, -1], [-7.4, -1]]:
		blk(p[0], p[1], 0.25, 0.25, 3.2, blue)
	box(-10, 3.3, -3.2, 6.4, 0.25, 5.2, blue)
	label_sign("Punto Estudiantil", 5, 0.8, AMAR, AZUL, -10, 3.0, -0.55)
	for p in [[-14, 8], [14, 8], [-14, -6], [14, -6], [0, -8]]:
		tree(p[0], p[1])
	# luces de techo
	var lm := mu(Color.WHITE)
	var ls := []
	for x in range(-21, 22, 6):
		ls.append([x, H - 0.33, -15, 2.2, 0.05, 0.5])
	for p in [[-18, -25], [-18, -31], [-6, -25], [-6, -31], [6, -25], [6, -31], [18, -25], [18, -31]]:
		ls.append([p[0], H - 0.33, p[1], 2.2, 0.05, 0.5])
	boxes(ls, lm)


# ---------------- segundo piso ----------------
func _second_floor(root: Node3D) -> void:
	var g2 := Node3D.new()
	g2.position.y = H
	root.add_child(g2)
	var blue := mt(AZUL)
	var glass := mt(Color("9ccdf0"), null, Vector2.ONE, 0.28)
	for s in [[-24, 24, -36, -16.4], [-24, 24, -13.4, -12], [-24, 12, -16.4, -13.4], [21.5, 24, -16.4, -13.4]]:
		var w = s[1] - s[0]
		var d = s[3] - s[2]
		box((s[0] + s[1]) / 2.0, H - 0.15, (s[2] + s[3]) / 2.0, w, 0.3, d, M.ceil)
	# escalera rampa con baranda de vidrio
	var ang := atan2(H, 9.5)
	var lr := sqrt(9.5 * 9.5 + H * H)
	var ramp := box(16.75, H / 2.0 + 0.02, -14.9, lr, 0.1, 3, mt(Color("6f747d")))
	ramp.rotation.z = ang
	var tread := PlaneMesh.new()
	tread.size = Vector2(lr, 3.0)
	var tpos := Vector3(16.75 - sin(ang) * 0.055, H / 2.0 + 0.02 + cos(ang) * 0.055, -14.9)
	var tm := add_mesh(tread, mt(Color.WHITE, T.stair, Vector2(lr / 0.4, 3.0 / 0.4)), tpos)
	tm.rotation.z = ang
	for z in [-16.4, -13.4]:
		var gq := quad(16.75, H / 2.0 + 0.55, z, lr, 1, glass)
		gq.rotation.z = ang
		var rl := box(16.75, H / 2.0 + 1.08, z, lr, 0.06, 0.08, blue)
		rl.rotation.z = ang
		cols.append([12, 21.5, z - 0.1, z + 0.1, -1])
	cols.append([21.5, 24, -16.4, -13.4, 0])
	cols.append([11.9, 12.1, -16.4, -13.4, 1])
	label_sign("Escaleras", 2.4, 0.5, AZUL, Color.WHITE, 23.65, 2.6, -15, -PI / 2.0)
	# piso 2
	par = g2
	lv = 1
	var tile_rects := [[-24, 12, -18, -12], [12, 21.5, -18, -16.4], [12, 21.5, -13.4, -12], [21.5, 24, -18, -12]]
	for s in tile_rects:
		fl(s[0], s[1], s[2], s[3], "tile", 0.03)
	fl(-24, -12, -36, -18, "rubber", 0.04)
	fl(-12, 12, -36, -18, "tile", 0.04)
	fl(12, 24, -36, -18, "carpet", 0.04)
	wall(-24, -36, 24, -36, true)
	wall(-24, -36, -24, -12, true)
	wall(24, -36, 24, -12, true)
	for s in [[-24, -19.2], [-16.8, -7.2], [-4.8, 4.8], [7.2, 16.8], [19.2, 24]]:
		wall(s[0], -18, s[1], -18)
	for x in [-12, 0, 12]:
		wall(x, -36, x, -18)
	var fr := []
	for x in [-18, -6, 6, 18]:
		fr.append([x - 1.2, 1.3, -18, 0.14, 2.6, 0.5])
		fr.append([x + 1.2, 1.3, -18, 0.14, 2.6, 0.5])
		fr.append([x, 2.68, -18, 2.5, 0.16, 0.5])
	boxes(fr, blue)
	for p in [["Taller de Diseño", -18], ["Sala 201", -6], ["Sala Tecnológica", 6], ["Auditorio", 18]]:
		label_sign(p[0], 2.4, 0.5, AZUL, Color.WHITE, p[1], 3.2, -17.75)
	label_sign("Piso 2", 2.4, 0.5, AZUL, AMAR, 23.65, 2.6, -15, -PI / 2.0)
	# baranda hacia el patio
	cols.append([-24, 24, -12.4, -12, 1])
	quad(0, 0.55, -12.2, 48, 1.1, glass)
	box(0, 1.1, -12.2, 48, 0.06, 0.08, blue)
	var concrete := mt(Color.WHITE, T.concrete, Vector2(1, 2))
	for i in range(8):
		cyl(-21 + i * 6, H / 2.0, -12.4, 0.25, H, concrete, true)
	# taller de diseño
	var dt2 := []
	for z in [-32, -29, -26, -23]:
		for x in [-20.6, -15.4]:
			dt2.append([x, 0.47, z, 2.6, 0.94, 0.9])
	boxes(dt2, mt(Color("e9e4d6")), true)
	quad(-18, 1.9, -35.78, 10, 1.8, mu(Color("d8d4c8")))
	# sala 201 y sala tecnológica
	var dk := []
	for z in [-22, -25, -28, -31]:
		for x in [-9.4, -2.6]:
			dk.append([x, 0.38, z, 2.6, 0.76, 0.8])
	boxes(dk, M.wood, true)
	quad(-6, 1.9, -35.78, 6, 1.6, mt(Color("2f4f3f")))
	var st2 := []
	var mo2 := []
	for z in [-22, -25, -28, -31]:
		for x in [2.6, 9.4]:
			st2.append([x, 0.38, z, 2.8, 0.76, 1])
			mo2.append([x, 1.05, z - 0.2, 0.7, 0.45, 0.1])
	boxes(st2, mt(Color("b7bcc6")), true)
	boxes(mo2, mu(Color("1c2a44")))
	boxes([[6, 1, -35.3, 1.2, 2, 0.8]], mt(Color("2b2f36")), true)
	# auditorio
	var seats := []
	for z in [-22, -24, -26, -28, -30, -32]:
		seats.append([15.6, 0.25, z, 3.6, 0.5, 0.7])
		seats.append([21.3, 0.25, z, 3.6, 0.5, 0.7])
	boxes(seats, mt(Color("8c2f45")), true)
	blk(18, -34.7, 10, 2.6, 0.5, mt(Color("6b4a2b")))
	quad(18, 2.2, -35.78, 8, 3, mu(Color("f2f2f2")))
	# luces
	var ls := []
	for x in range(-21, 22, 6):
		ls.append([x, H - 0.05, -15, 2.2, 0.05, 0.5])
	for x in [-18, -6, 6, 18]:
		ls.append([x, H - 0.05, -25, 2.2, 0.05, 0.5])
		ls.append([x, H - 0.05, -31, 2.2, 0.05, 0.5])
	boxes(ls, mu(Color.WHITE))
	# pisos 3 y 4: masa exterior
	par = root
	lv = 0
	box(0, 2 * H + (15 - 2 * H) / 2.0, -24, 48, 15 - 2 * H, 24, M.facade)


# ---------------- exteriores y detalles ----------------
func _extras() -> void:
	var cor := mt(Color("d4d7dc"))
	for y in [7.6, 15]:
		box(0, y, -24, 48.6, 0.35, 24.6, cor)
	for p in [[48.4, 0.8, 0.4, 0, 15.4, -12.1], [48.4, 0.8, 0.4, 0, 15.4, -35.9], [0.4, 0.8, 24, -24.1, 15.4, -24], [0.4, 0.8, 24, 24.1, 15.4, -24], [18.4, 0.7, 0.4, 33, 11.35, -12.1], [18.4, 0.7, 0.4, 33, 11.35, 12.1], [0.4, 0.7, 24.2, 42.1, 11.35, 0], [0.4, 0.7, 24.2, 23.9, 11.35, 0]]:
		box(p[3], p[4], p[5], p[0], p[1], p[2], cor)
	for x in range(-24, 25, 6):
		box(x, 11.3, -11.8, 0.5, 7.4, 0.5, cor)
	# cordillera: montañas con nieve + cerros bajos al frente
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color("f4f7fb")
	snow.roughness = 1.0
	snow.emission_enabled = true
	snow.emission = Color(0.55, 0.58, 0.62)
	snow.disable_fog = true
	for i in 18:
		var a := float(i) / 18.0 * TAU
		var h := 45.0 + float((i * 53) % 40)
		var rc := Color("7f93ad") if i % 2 == 1 else Color("8ea1ba")
		var rm := StandardMaterial3D.new()
		rm.albedo_color = rc
		rm.roughness = 1.0
		rm.emission_enabled = true
		rm.emission = rc * 0.35
		rm.disable_fog = true
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 38.0
		cm.height = h
		cm.radial_segments = 7
		var mtn := add_mesh(cm, rm, Vector3(cos(a) * 235.0, h / 2.0 - 2.0, sin(a) * 235.0))
		mtn.rotation.y = float(i) * 0.9
		mtn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sh := h * 0.3
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = 38.0 * 0.3 * 1.05
		cap.height = sh
		cap.radial_segments = 7
		var cp := add_mesh(cap, snow, Vector3(cos(a) * 235.0, h - 2.0 - sh / 2.0, sin(a) * 235.0))
		cp.rotation.y = mtn.rotation.y
		cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hill := StandardMaterial3D.new()
	hill.albedo_color = Color("6f8f6a")
	hill.roughness = 1.0
	hill.emission_enabled = true
	hill.emission = Color("6f8f6a") * 0.3
	hill.disable_fog = true
	for i in 14:
		var a2 := (float(i) + 0.5) / 14.0 * TAU
		var hm := CylinderMesh.new()
		hm.top_radius = 0.0
		hm.bottom_radius = 46.0
		hm.height = 20.0 + float((i * 29) % 14)
		hm.radial_segments = 6
		var hi := add_mesh(hm, hill, Vector3(cos(a2) * 200.0, hm.height / 2.0 - 2.0, sin(a2) * 200.0))
		hi.rotation.y = float(i) * 1.3
		hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# marcas de calle
	var yel := mt(Color("f2c744"))
	for x in range(-144, 145, 8):
		flat(x, 0.045, 30.0, 4.0, 0.25, yel)
	var wht := mt(Color("e8e8e8"))
	flat(0, 0.045, 24.4, 300.0, 0.2, wht)
	flat(0, 0.045, 35.6, 300.0, 0.2, wht)
	# salida, máquina expendedora, paneles, plantas, bancas, faroles
	blk(-22.6, -13.5, 1.2, 1.0, 1.9, mt(Color("c62828")))
	label_sign("SALIDA", 1.2, 0.35, Color("1b8f4b"), Color.WHITE, -22, 3.35, -17.77)
	for x in [-12, 0, 12]:
		quad(x, 1.7, -17.77, 1.6, 1.0, mu(Color("f4f1e8")))
		quad(x, 1.7, -17.76, 1.3, 0.7, mu(Color("5b8fd8")))
	for p in [[-21, -16.9], [-9, -17], [3, -17]]:
		cyl(p[0], 0.25, p[1], 0.25, 0.5, mt(Color("8a5a3c")))
		sph(p[0], 0.95, p[1], 0.5, 1.0, mt(Color("2f7d3a")))
	var bench := mt(Color("8a6a44"))
	boxes([[-15, 0.25, -13.2, 2, 0.5, 0.5], [-3, 0.25, -13.2, 2, 0.5, 0.5], [5, 0.25, -13.2, 2, 0.5, 0.5]], bench, true)
	for p in [[-16, 0], [16, 0], [-16, -8], [16, -8]]:
		cyl(p[0], 2.5, p[1], 0.09, 5, mt(Color("444a55")))
		sph(p[0], 5.1, p[1], 0.3, 0.6, mu(Color("fff2b0")))
	boxes([[-11, 0.45, 7, 0.5, 0.9, 0.5], [11, 0.45, 7, 0.5, 0.9, 0.5]], mt(Color("2f6f4f")), true)
	quad(-22.6, 1.0, -12.99, 1.1, 1.7, mu(Color("7a1c1c")))
	fl(-150, 150, 22.2, 24, "concrete", 0.04)


# ---------------- luces interiores (solo calidad media/alta) ----------------
func _lights() -> void:
	for x in [-18, -6, 6, 18]:
		for z in [-25, -31]:
			_omni(x, H - 0.6, z)
			_omni(x, 2.0 * H - 0.6, z)
		_omni(x, H - 0.6, -15)
		_omni(x, 2.0 * H - 0.6, -15)


# ---------------- nubes ----------------
func _clouds() -> void:
	clouds = Node3D.new()
	par.add_child(clouds)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 1)
	cm.roughness = 1.0
	cm.emission_enabled = true
	cm.emission = Color(0.6, 0.63, 0.68)
	cm.disable_fog = true
	for i in 12:
		var a := float(i) * 0.53
		var r := 130.0 + float((i * 37) % 90)
		var c := Node3D.new()
		c.position = Vector3(cos(a) * r, 95.0 + float((i * 17) % 35), sin(a) * r)
		clouds.add_child(c)
		for k in 5:
			var rr := 9.0 + float((i + k * 3) % 5) * 2.0
			var sm := SphereMesh.new()
			sm.radius = rr
			sm.height = rr * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = cm
			mi.position = Vector3((k - 2) * 9.0 + float((i * k) % 3), float(k % 2) * 2.0, float((i + k) % 4) * 3.0 - 4.0)
			mi.scale = Vector3(1.0, 0.45, 1.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.add_child(mi)

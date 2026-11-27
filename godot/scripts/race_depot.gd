## Visual-only tram depot on the opening 268 metres of Tomsk Dust.
## Local +Z always faces the street. Dimensions and setbacks are in metres.
extends Node3D

const DIR := "res://assets/racing/depot/"
const FIRST := -36.0
const LAST := 232.0
const TEAL := Color("#236665")
const IRON := Color("#39474c")
const CREAM := Color("#e2d4ab")
const OXIDE := Color("#a84931")
const ROOF := Color("#596969")
const INK := Color("#202e32")
const WINDOW := Color("#547680")

var track: RaceTrack
var frame := Transform3D.IDENTITY
var meshes := {}
var materials := {}
var batches := {}
var rng := RandomNumberGenerator.new()

static func covers_distance(s: float, lap: float) -> bool:
	return s <= LAST or s >= lap + FIRST

static func covers_point(t: RaceTrack, p: Vector3) -> bool:
	# Narrow broad-phase around the authored part of the main loop.
	if p.x < -80.0 or p.z < -57.0 or p.x > 225.0 or p.z > 150.0:
		return false
	var i := t.nearest_main(p)
	return covers_distance(t.from_start(t.S[i]), t.L) and p.distance_squared_to(t.P[i]) < 54.0 * 54.0

func build(t: RaceTrack) -> void:
	track = t
	rng.seed = 812
	name = "TomskTramDepot"
	_materials()
	# A ticket office gives way to taller workshops. A tower marks the outer bend.
	for plot in [
		[-21, -1, 16, 25, 2, "office"], [8, -1, 15, 26, 3, "office"],
		[45, -1, 15, 38, 2, "shed"], [88, -1, 16, 39, 2, "shed"],
		[130, -1, 16, 29, 3, "office"], [170, -1, 18, 34, 2, "shed"],
		[208, -1, 17, 34, 2, "shed"], [-18, 1, 18, 26, 3, "office"],
		[29, 1, 21, 33, 2, "station"], [72, 1, 20, 31, 3, "office"]]:
		_street(float(plot[0]), float(plot[1]), float(plot[2]))
		if plot[5] == "office":
			_office(float(plot[3]), int(plot[4]))
		elif plot[5] == "station":
			_station(float(plot[3]))
		else:
			_hall(float(plot[3]))
	_street(134, -1, 14.8)
	_clock_tower()
	_street(96, -1, 43)
	_stack(32, 1.55)
	_street(177, -1, 43)
	_stack(23, 1.12)
	_street(75, 1, 11.8)
	_stop()
	_street(37, -1, 12.1)
	_stop()
	_street(61, -1, 0)
	_gallery()
	_street(28, 1, 13.35)
	_tram()
	_street(0, -1, 0)
	_finish()
	_street_furniture()
	_planting()
	_flush()

func _street(s: float, side: float, distance_from_center: float) -> void:
	var i := track.at_s(track.start_s + s)
	var out := track.T[i].cross(Vector3.UP).normalized() * side
	frame = Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.z)), track.P[i] + out * distance_from_center)

func _material(rough: float, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = rough
	mat.metallic = metal
	mat.vertex_color_use_as_albedo = true
	return mat

func _materials() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var cylinder := CylinderMesh.new()
	cylinder.height = 1
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.radial_segments = 16
	cylinder.rings = 0
	var tooth := PrismMesh.new()
	tooth.size = Vector3.ONE
	tooth.left_to_right = 0.9
	meshes = {"box":cube, "round":cylinder, "tooth":tooth}
	materials = {"paint":_material(0.78), "steel":_material(0.55, 0.32), "glass":_material(0.24, 0.14)}
	var brick := _material(0.95)
	brick.albedo_texture = preload("res://assets/racing/depot/brick_diffuse.jpg")
	brick.normal_enabled = true
	brick.normal_texture = preload("res://assets/racing/depot/brick_nor_gl.jpg")
	brick.normal_scale = 0.72
	brick.roughness_texture = preload("res://assets/racing/depot/brick_rough.jpg")
	brick.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	brick.uv1_triplanar = true
	brick.uv1_world_triplanar = true
	brick.uv1_scale = Vector3.ONE / 2.93
	materials.brick = brick
	var roofing := _material(0.75,0.42)
	roofing.albedo_texture = preload("res://assets/racing/depot/roof_color.jpg")
	roofing.normal_enabled = true
	roofing.normal_texture = preload("res://assets/racing/depot/roof_normal.jpg")
	roofing.normal_scale = 0.65
	roofing.uv1_triplanar = true
	roofing.uv1_world_triplanar = true
	roofing.uv1_scale = Vector3.ONE / 2.7
	materials.roof = roofing
	var glazing: StandardMaterial3D = materials.glass
	glazing.metallic = 0.46
	glazing.roughness = 0.38
	glazing.roughness_texture = brick.roughness_texture
	var concrete := track.mats.barrier.duplicate() as StandardMaterial3D
	concrete.albedo_color = Color("#d4e0ee")
	concrete.vertex_color_use_as_albedo = true
	concrete.uv1_world_triplanar = true
	materials.stone = concrete
	var lit := _material(0.41)
	lit.emission_enabled = true
	lit.emission = Color("#ffd49a")
	lit.emission_energy_multiplier = 0.34
	materials.lit = lit
	for key in ["trunk","canopy","shrub","grass"]:
		meshes[key] = load(DIR + key + ".obj")
		var mat := _material(0.95)
		var tex: String = {"trunk":"bark.jpg","canopy":"canopy.webp","shrub":"shrub_02.webp","grass":"grass_medium_01.webp"}[key]
		mat.albedo_texture = load(DIR + tex)
		if key != "trunk":
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.36
		materials[key] = mat

# Batch by cell, mesh and finish so distant blocks can be culled independently.
func _part(mesh: String, local: Transform3D, mat: String, color: Color) -> void:
	var world := frame * local
	var cell := Vector2i(floori(world.origin.x / 48.0), floori(world.origin.z / 48.0))
	var key := "%d/%d/%s/%s" % [cell.x, cell.y, mesh, mat]
	if not batches.has(key):
		batches[key] = []
	batches[key].append([world, color.srgb_to_linear()])

func _shape(pos: Vector3, size: Vector3, color: Color, mat := "paint", mesh := "box", roll := 0.0) -> void:
	_part(mesh, Transform3D(Basis(Vector3.BACK, roll).scaled_local(size), pos), mat, color)

func _box(x: float, y: float, z: float, w: float, h: float, d: float, col: Color, mat := "paint") -> void:
	_shape(Vector3(x,y,z),Vector3(w,h,d),col,mat)

func _strut(a: Vector3, b: Vector3, width: float, col := IRON) -> void:
	var delta := b-a
	var rotation := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_part("round", Transform3D(rotation.scaled_local(Vector3(width,delta.length(),width)),(a+b)*0.5),"steel",col)

func _disk(x: float, y: float, z: float, diameter: float, thickness: float, col: Color, mat: String) -> void:
	var basis := Basis(Vector3.RIGHT,PI/2).scaled_local(Vector3(diameter,thickness,diameter))
	_part("round",Transform3D(basis,Vector3(x,y,z)),mat,col)

func _label(words: String, x: float, y: float, z: float, height: float, col := CREAM, angle := 0.0) -> void:
	var sign := Label3D.new()
	sign.text = words
	sign.font_size = 96
	sign.pixel_size = height/96.0
	sign.modulate = col
	sign.outline_size = 0
	sign.double_sided = false
	sign.transform = frame * Transform3D(Basis(Vector3.UP,angle),Vector3(x,y,z))
	add_child(sign)

func _window(x: float, y: float, w: float, h: float, arched: bool, warm: bool) -> void:
	var glazing := Color("#cbab82") if warm else WINDOW.lerp(INK,rng.randf_range(0.03,0.58))
	var finish := "lit" if warm else "glass"
	_box(x,y,0.09,w+0.26,h+0.22,0.22,INK)
	_box(x,y,0.22,w,h,0.07,glazing,finish)
	_box(x,y-h/2-0.10,0.22,w+0.55,0.17,0.53,CREAM,"stone")
	for mullion in [-0.24,0.24]:
		_box(x+w*mullion,y,0.3,0.07,h,0.08,IRON,"steel")
	_box(x,y+h*0.15,0.31,w,0.075,0.07,IRON)
	if arched:
		var radius := w*0.5
		var center := Vector3(x,y+h/2,0.11)
		# The lower half of the disk is behind the rectangular glazing.
		_disk(x,center.y,0.13,w,0.08,glazing,finish)
		for j in 11:
			var a := PI*(j+0.5)/11.0
			_shape(center+Vector3(cos(a)*(radius+0.11),sin(a)*(radius+0.11),0.05),
				Vector3(0.25,(radius+0.11)*PI/11.0-0.018,0.32),CREAM.darkened(0.12 if j%3==0 else 0.02),"stone","box",a)
		for j in range(1,4):
			var a := PI*j/4
			_strut(center+Vector3.BACK*0.17, center+Vector3(cos(a)*radius,sin(a)*radius,0.17),0.065)
	else:
		_box(x,y+h/2+0.14,0.16,w+0.46,0.24,0.32,CREAM,"stone")

func _office(w: float, floors: int) -> void:
	var h := 3.25*floors+1.5
	_box(0,h/2,-5.2,w,h,10.4,Color.WHITE,"brick")
	_box(0,0.43,-5.2,w+0.42,0.86,10.7,Color("#9b9686"),"stone")
	for y in [3.9,h-0.28,h+0.05]:
		_box(0,y,-5.2,w+0.62,0.21,10.92,CREAM,"stone")
	_box(0,h+0.45,-5.2,w+0.78,0.62,11,ROOF,"steel")
	var bays := floori(w/3.8)
	for j in bays:
		var x := w*((j+0.5)/bays-0.5)
		for floor_i in floors:
			if j == bays/2 and floor_i == 0:
				_box(x,1.42,0.18,2.05,2.84,0.25,TEAL)
				_box(x,3.10,0.67,3.0,0.21,1.66,ROOF,"steel")
				_box(x,0.12,0.61,2.65,0.24,1.12,CREAM,"stone")
			else:
				_window(x,2.02+3.24*floor_i,1.74,1.85,floor_i==floors-1,(j*3+floor_i)%7==2)
	for sx in [-1,1]:
		for j in int(h/0.61):
			_box(sx*(w/2-0.36),0.46+j*0.61,0.13,0.78 if j%2==0 else 0.53,0.53,0.31,CREAM,"stone")
	# Chimneys, a louvred roof monitor and a street-facing enamel address plate.
	_box(-w*0.18,h+0.94,-5,5.5,0.75,2.2,IRON,"steel")
	for k in [-1,1]:
		_box(k*w*0.33,h+1.1,-7,0.9,1.8,0.8,Color.WHITE,"brick")
		_box(k*w*0.33,h+2.02,-7,1.08,0.16,0.98,CREAM,"stone")
	_box(-w*0.38,3.45,0.32,2.4,0.55,0.09,TEAL)
	_label("ДЕПОВСКАЯ", -w*0.38,3.46,0.39,0.30)

func _hall(w: float) -> void:
	var depth := 13.0
	_box(0,4.05,-depth/2,w,8.1,depth,Color("#f0dbca"),"brick")
	_box(0,0.52,-depth/2,w+0.22,1.04,depth+0.25,Color("#8b8c81"),"stone")
	var bays := roundi(w/6.3)
	var interval := w/bays
	for j in bays:
		var x := (j+0.5)*interval-w/2
		_window(x,3.65,3.65,2.85,true,j%4==1)
		_shape(Vector3(x,9.28,-depth/2),Vector3(interval,2.4,depth+0.4),Color("#b4c8cb"),"roof","tooth")
		# Clerestory edge and folded metal cap make the sawtooth readable in silhouette.
		_box(x+interval*0.4,10.45,-depth/2,0.3,0.14,depth+0.75,CREAM,"steel")
		_box(x-interval/2+0.23,4.25,0.14,0.55,8.5,0.56,Color("#e5c0a1"),"brick")
		_box(x-interval/2+0.23,8.45,0.19,0.83,0.23,0.71,CREAM,"stone")
	_box(0,7.78,0.10,w+0.35,0.23,0.51,CREAM,"stone")
	for side in [-1,1]:
		var wall: float = side*(w/2+0.10)
		_label("02",wall,4.75,-depth*0.47,3.15,CREAM,side*PI/2)
		for j in 6:
			_box(wall,2.1+j*0.16,-depth*0.77,0.15,0.08,1.45,IRON,"steel")
	_box(0,0.10,2.1,w+0.5,0.2,4.3,Color("#a7a39a"),"stone")

func _clock_tower() -> void:
	_box(0,8.5,-2.7,6.7,17,5.4,Color.WHITE,"brick")
	for sx in [-1,1]:
		_box(sx*3.16,8.7,0.18,0.44,17.4,0.58,CREAM,"stone")
	_box(0,14.25,-2.7,7.3,0.38,5.9,CREAM,"stone")
	_box(0,17.05,-2.7,7.6,0.52,6.15,CREAM,"stone")
	var base := frame
	for j in 4:
		frame = base * Transform3D(Basis.IDENTITY,Vector3(0,0,-2.7)) * Transform3D(Basis(Vector3.UP,j*PI/2),Vector3.ZERO)
		var face := 3.42 if j%2 else 2.81
		_disk(0,15.57,face,2.68,0.19,IRON,"steel")
		_disk(0,15.57,face+0.12,2.39,0.09,CREAM,"lit")
		for n in 12:
			var a := TAU*n/12.0
			_shape(Vector3(sin(a)*1.02,15.57+cos(a)*1.02,face+0.195),Vector3(0.075,0.20,0.06),INK,"steel","box",-a)
		_strut(Vector3(0,15.57,face+0.23),Vector3(-0.53,16.14,face+0.23),0.12,INK)
		_strut(Vector3(0,15.57,face+0.24),Vector3(0.83,15.91,face+0.24),0.09,INK)
	frame = base
	_box(0,18,-2.7,5.3,1.6,4.6,TEAL,"steel")
	for x in [-2,-1,0,1,2]:
		_box(x,18.04,-0.34,0.5,0.95,0.15,INK)
	var cap := CylinderMesh.new()
	cap.top_radius=0.10
	cap.bottom_radius=0.5
	cap.height=1
	cap.radial_segments=4
	cap.rings=0
	meshes["spire"]=cap
	_part("spire",Transform3D(Basis(Vector3.UP,PI/4).scaled_local(Vector3(8.7,4.1,8.0)),Vector3(0,20.84,-2.7)),"steel",ROOF)
	_strut(Vector3(0,22.85,-2.7),Vector3(0,25.1,-2.7),0.11)

func _stack(h: float, diameter: float) -> void:
	_shape(Vector3(0,h/2,0),Vector3(diameter*1.6,h,diameter*1.6),Color.WHITE,"brick","round")
	for j in 3:
		_shape(Vector3(0,h-1.6-j*2.6,0),Vector3(diameter*1.65,1.28,diameter*1.65),CREAM,"paint","round")
	_shape(Vector3(0,h,0),Vector3(diameter*1.82,0.48,diameter*1.82),IRON,"steel","round")


func _stop() -> void:
	for x in [-3.55,0,3.55]:
		_box(x,1.63,-0.85,0.13,3.25,0.14,TEAL,"steel")
	_box(0,3.17,-0.12,8.25,0.21,2.52,TEAL,"steel")
	_box(0,3.08,1.09,8.2,0.12,0.12,CREAM)
	_box(0,2.63,-0.78,7.25,0.49,0.15,TEAL)
	_label("ТРАМВАЙНОЕ ДЕПО",0,2.64,-0.676,0.39)
	for i in 4:
		_box(-1.3,0.68,-0.61+i*0.13,3.35,0.085,0.11,Color("#aa7650"))
	for x in [-2.6,0.05]:
		_box(x,0.34,-0.44,0.14,0.68,0.6,IRON,"steel")
	_box(2.17,1.49,-0.79,1.35,1.75,0.16,CREAM)
	for stripe in 5:
		_box(2.16,1.95-stripe*0.19,-0.69,0.93-stripe*0.07,0.046,0.035,TEAL)

func _gallery() -> void:
	# Enclosed transfer bridge spanning the street; all supports behind the barriers.
	for side in [-1,1]:
		for x in [-1.7,1.7]:
			_box(x,4.65,side*12,0.34,9.3,0.48,IRON,"steel")
			_box(x,0.64,side*12,0.85,1.28,0.92,Color("#939188"),"stone")
		_strut(Vector3(-1.7,3.4,side*12),Vector3(1.7,7.8,side*12),0.18)
	_box(0,8.28,0,4.75,0.58,33,IRON,"steel")
	_box(0,11.17,0,5.05,0.35,33.8,ROOF,"steel")
	for side in [-1,1]:
		_box(side*2.2,9.72,0,0.15,2.63,32.8,WINDOW,"glass")
		_box(side*2.35,9.0,0,0.15,1.27,33,TEAL,"steel")
		for j in range(-8,9):
			_box(side*2.37,10.13,j*1.95,0.16,1.96,0.085,CREAM,"steel")
		for y in [8.46,9.55,10.38,11.12]:
			_box(side*2.41,y,0,0.15,0.10,33.2,CREAM,"steel")
	_box(-2.49,9.1,0,0.17,2.13,15.8,TEAL)
	_label("Т О М С К    /    Д Е П О   0 2",-2.61,9.11,0,1.09,CREAM,-PI/2)
	# Maintenance lamps recessed into the soffit.
	for z in [-6,-2,2,6]:
		_box(0,7.95,z,1.5,0.075,0.17,CREAM,"lit")

func _finish() -> void:
	# Re-skin the two original structural posts, keeping the collision envelope.
	for side in [-1,1]:
		_box(0,3.0,side*9.2,0.58,6.0,0.59,TEAL,"steel")
		_box(0,0.61,side*9.2,0.78,1.22,0.79,CREAM,"stone")
		_strut(Vector3(0,4.4,side*9.2),Vector3(0,5.83,side*7.64),0.18)
	_box(0,6.28,0,0.7,1.15,19.2,TEAL,"steel")
	for y in [5.76,6.80]:
		_box(0,y,0,0.76,0.09,19.4,CREAM,"steel")
	for side in [-1,1]:
		_label("ТОМСК   •   ПЫЛЬНЫЙ ЗАЕЗД",0.405*side,6.28,0,0.82,CREAM,side*PI/2)
	for z in [-6.8,-5.9,-5.0,5.0,5.9,6.8]:
		_box(0,5.47,z,0.69,0.51,0.68,INK,"steel")
		_box(-0.36,5.48,z,0.055,0.24,0.41,Color("#f3ba72"),"lit")

func _street_furniture() -> void:
	for side in [-1,1]:
		var last_wire := Vector3.ZERO
		for s in range(-32,229,20):
			_street(s,side,track.width(track.start_s+s)*0.5+3.65)
			if not track._free(frame.origin,0.15):
				last_wire = Vector3.ZERO
				continue
			var footing := frame.origin
			# Pavement edging, drainage, pedestrian railing and expansion joints.
			for step in range(0,20,2):
				if s+step>LAST:
					break
				_street(s+step,side,track.width(track.start_s+s+step)*0.5+4.25)
				if not track._free(frame.origin,1.5):
					continue
				_box(0,0.068,0,2.04,0.15,2.65,Color("#b7b3a5"),"stone")
				_box(0,0.14,1.28,1.96,0.18,0.2,CREAM,"stone")
				if step in [2,4,6,8,10]:
					_box(-0.96,0.71,0.92,0.065,1.14,0.07,IRON,"steel")
					for y in [0.49,1.18]:
						_box(0,y,0.92,2.02,0.075,0.07,IRON,"steel")
			_street(s,side,track.width(track.start_s+s)*0.5+3.65)
			_shape(Vector3(0,3.53,0),Vector3(0.13,7.06,0.13),IRON,"steel","round")
			_shape(Vector3(0,0.68,0),Vector3(0.25,1.36,0.25),TEAL,"steel","round")
			_strut(Vector3(0,6.68,0),Vector3(0,7.42,1.38),0.10)
			_strut(Vector3(0,7.42,1.38),Vector3(0,7.38,2.34),0.09)
			_box(0,7.28,2.16,0.49,0.17,0.91,IRON,"steel")
			_box(0,7.17,2.16,0.37,0.068,0.72,CREAM,"lit")
			track.street_light_origins.append(frame*Vector3(0,7.07,2.16))
			var wire := footing + Vector3.UP*6.65
			if last_wire != Vector3.ZERO:
				var midpoint := (wire+last_wire)*0.5 - Vector3.UP*0.34
				var old := frame
				frame = Transform3D.IDENTITY
				_strut(last_wire,midpoint,0.030)
				_strut(midpoint,wire,0.030)
				frame = old
			last_wire = wire
	# Service yard storage on the outer side of the corner.
	for s in [107,151,191,226]:
		_street(s,-1,13.7)
		_box(0,1.29,-1.35,5.90,2.58,2.46,TEAL,"steel")
		for j in 27:
			_box(-2.83+j*0.217,1.31,-0.075,0.067,2.36,0.13,Color("#428381"),"steel")
		_box(0,2.58,-1.34,6.02,0.12,2.55,IRON,"steel")
		_label("ТД  /  02",1.8,2.07,0.025,0.32)
	# Low-profile reflective markers and concrete skin follow the exact wall spans.
	for block in track.depot_blocks:
		frame = Transform3D(Basis(Vector3.UP,float(block[1])),block[0])
		var length_m := float(block[2])
		_box(0,0.15,0,0.60,0.30,length_m,Color("#b5b1a0"),"stone")
		_box(0,0.54,0,0.39,0.54,length_m-0.025,Color("#d2c8ac"),"stone")
		_box(0,0.82,0,0.43,0.09,length_m-0.03,Color("#e1d5b5"),"stone")
		if int(block[3])%10 == 0:
			for side in [-1,1]:
				_box(side*0.205,0.63,0,0.047,0.19,0.43,TEAL)
				_box(side*0.233,0.64,0,0.02,0.07,0.24,CREAM,"lit")

func _planting() -> void:
	for side in [-1,1]:
		for s in range(-31,231,7):
			_street(s+rng.randf_range(-1.2,1.2),side,track.width(track.start_s+s)*0.5+5.75)
			if not track._free(frame.origin,2.1):
				continue
			# Leave the shelter platforms and the service bridge approaches open.
			if absf(s-61)<5 or (side==-1 and absf(s-37)<5) or (side==1 and absf(s-75)<5):
				continue
			var shade := Color.WHITE.darkened(rng.randf_range(0,0.10))
			if (s+31)%21 == 0:
				var size_m := rng.randf_range(1.28,1.76)
				var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled_local(Vector3.ONE*size_m)
				for part in ["trunk","canopy"]:
					_part(part,Transform3D(basis,Vector3.ZERO),part,shade)
			for j in 4:
				var size_m := rng.randf_range(1.55,2.6)
				var p := Vector3(rng.randf_range(-2.6,2.6),0,rng.randf_range(-0.65,0.50))
				var key := "shrub" if j==0 else "grass"
				_part(key,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled_local(Vector3.ONE*size_m),p),key,shade)

func _flush() -> void:
	for key: String in batches:
		var entries: Array = batches[key]
		var kind := key.get_slice("/",2)
		var finish := key.get_slice("/",3)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[kind]
		mm.instance_count = entries.size()
		for i in entries.size():
			mm.set_instance_transform(i,entries[i][0])
			mm.set_instance_color(i,entries[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = materials[finish]
		if kind in ["grass","shrub"]:
			mi.visibility_range_end = 74
			mi.visibility_range_end_margin = 9
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	batches.clear()


func _station(w: float) -> void:
	# A pale, horizontal passenger building opposite the red-brick workshops.
	var plaster := Color("#d4ddce")
	_box(0,3.35,-5.0,w,6.7,10,plaster,"stone")
	_box(0,0.58,-5.0,w+0.22,1.16,10.24,TEAL)
	_box(0,6.76,-5.0,w+0.59,0.33,10.55,ROOF,"roof")
	_box(0,5.57,0.19,w+0.34,0.66,0.52,TEAL,"steel")
	_label("П А С С А Ж И Р С К А Я    С Л У Ж Б А",0,5.59,0.51,0.46)
	for j in 9:
		var x := (j-4)*3.25
		_window(x,3.0,2.12,2.45,false,j==2)
	_box(0,4.54,1.5,w*0.88,0.22,3.55,ROOF,"roof")
	for j in [-12,-6,0,6,12]:
		_box(j,2.21,2.93,0.14,4.42,0.14,TEAL,"steel")
		_strut(Vector3(j,3.62,2.93),Vector3(j,4.45,1.76),0.09,TEAL)
	_box(0,0.14,2.15,w+0.6,0.28,4.40,Color("#bbbfba"),"stone")

func _tram() -> void:
	# Parked heritage car, with a wraparound cab, two bogies and a diamond collector.
	var red := Color("#ae422e")
	var ivory := Color("#e9d9ad")
	for side in [-1,1]:
		_box(0,0.063,side*0.74,18.2,0.13,0.075,IRON,"steel")
	for j in range(-12,13):
		_box(j*0.71,0.012,0,0.19,0.056,2.08,Color("#756751"))
	_box(0,0.72,0,9.5,0.28,1.73,INK,"steel")
	for end in [-1,1]:
		for axle in [-0.64,0.64]:
			var x: float = end*3.4+axle
			for side in [-1,1]:
				_disk(x,0.47,side*0.78,0.81,0.18,INK,"steel")
				_disk(x,0.47,side*0.90,0.43,0.08,IRON,"steel")
	for band in [[1.26,0.94,red],[1.79,0.12,ivory],[2.50,1.32,ivory],[3.20,0.13,red],[3.33,0.18,ROOF]]:
		_box(0,band[0],0,9.0,band[1],2.33,band[2],"steel")
		for end in [-1,1]:
			_shape(Vector3(end*4.50,float(band[0]),0),Vector3(2.38,float(band[1]),2.33),band[2],"steel","round")
	for side in [-1,1]:
		for j in 8:
			var x := -3.98+j*1.13
			_box(x,2.51,side*1.176,0.98,1.04,0.055,INK)
			_box(x,2.51,side*1.21,0.86,0.92,0.035,WINDOW,"glass")
			_box(x,2.70,side*1.24,0.91,0.052,0.029,ivory)
		for x in [-2.83,2.82]:
			_box(x,1.86,side*1.24,0.045,1.86,0.044,IRON)
		for x in [-3.1,-2.6,-2.1]:
			_box(x,1.23,side*1.175,0.37,0.05,0.035,ivory)
		_label("ТТУ   •   214",0,1.25,side*1.19,0.35,ivory,0 if side>0 else PI)
	var base := frame
	for end in [-1,1]:
		for j in range(-2,3):
			var angle: float = end*PI/2+j*0.53
			var point := Vector3(end*4.5+1.19*sin(angle),0,1.17*cos(angle))
			frame = base*Transform3D(Basis(Vector3.UP,angle),point)
			_box(0,2.51,0.008,0.53,0.96,0.08,WINDOW,"glass")
			_box(-0.28,2.51,0.035,0.05,1.09,0.075,ivory)
			if j==0:
				_disk(0,1.38,0.10,0.37,0.14,ivory,"lit")
				_box(0,2.86,0.085,0.51,0.32,0.08,INK)
				_label("2",0,2.86,0.15,0.31)
	frame = base
	_box(-0.9,3.53,0,2.4,0.21,1.46,IRON,"steel")
	for side in [-1,1]:
		var foot := Vector3(-0.8,3.57,side*0.42)
		var top := foot+Vector3(0.12,1.72,0)
		for end in [-1,1]:
			var knuckle := foot+Vector3(end*1.20,0.84,0)
			_strut(foot,knuckle,0.065,IRON)
			_strut(knuckle,top,0.059,IRON)
	_box(-0.68,5.31,0,0.15,0.09,1.6,IRON,"steel")

extends Node3D
## CourseGenerator - Builds 3D geometry for Augusta National holes.
## Creates fairways, greens, bunkers, trees, and tee boxes from hole data.

const COURSE_WIDTH := 60.0
const FAIRWAY_WIDTH := 30.0
const ROUGH_WIDTH := 50.0
const GREEN_RADIUS := 12.0
const TEE_BOX_WIDTH := 8.0
const TEE_BOX_DEPTH := 4.0

var fairway_mat: StandardMaterial3D
var rough_mat: StandardMaterial3D
var green_mat: StandardMaterial3D
var bunker_mat: StandardMaterial3D
var tee_mat: StandardMaterial3D
var tree_mat: StandardMaterial3D
var trunk_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var flag_mat: StandardMaterial3D
var pole_mat: StandardMaterial3D

func _ready() -> void:
	_create_materials()

func _create_materials() -> void:
	fairway_mat = StandardMaterial3D.new()
	fairway_mat.albedo_color = Color(0.25, 0.5, 0.15)
	fairway_mat.roughness = 0.9

	rough_mat = StandardMaterial3D.new()
	rough_mat.albedo_color = Color(0.15, 0.35, 0.1)
	rough_mat.roughness = 1.0

	green_mat = StandardMaterial3D.new()
	green_mat.albedo_color = Color(0.35, 0.65, 0.2)
	green_mat.roughness = 0.7

	bunker_mat = StandardMaterial3D.new()
	bunker_mat.albedo_color = Color(0.85, 0.78, 0.6)
	bunker_mat.roughness = 1.0

	tee_mat = StandardMaterial3D.new()
	tee_mat.albedo_color = Color(0.3, 0.55, 0.18)
	tee_mat.roughness = 0.85

	tree_mat = StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.08, 0.25, 0.05)
	tree_mat.roughness = 1.0

	trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.15)
	trunk_mat.roughness = 1.0

	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.15, 0.35, 0.55)
	water_mat.roughness = 0.1
	water_mat.metallic = 0.1

	flag_mat = StandardMaterial3D.new()
	flag_mat.albedo_color = Color(1, 1, 1, 1)
	flag_mat.roughness = 0.5

	pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.95, 0.95, 0.95)
	pole_mat.roughness = 0.5
	pole_mat.metallic = 0.3

func build_hole(hole_data: Dictionary) -> void:
	for child in get_children():
		child.queue_free()

	var par: int = hole_data.get("par", 4)
	var yards: float = hole_data.get("yards", 400)
	var dogleg: String = hole_data.get("dogleg", "none")
	var hole_name: String = hole_data.get("name", "Unknown")
	var hole_num: int = hole_data.get("number", 0)

	print("[CourseGenerator] Building hole %d - %s (Par %d, %d yards)" % [hole_num, hole_name, par, yards])

	var length_m: float = yards * 0.9144

	_build_ground(length_m)
	_build_fairway(length_m, dogleg)
	_build_green(length_m)
	_build_tee_box()
	_build_bunkers(hole_data.get("bunkers", []), length_m)
	_build_water(hole_data.get("water", []), length_m)
	_build_trees(hole_data.get("trees", "heavy"), length_m)
	_build_flagstick(length_m)

	print("[CourseGenerator] Hole %d complete" % hole_num)

func _build_ground(length_m: float) -> void:
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(COURSE_WIDTH, length_m + 100)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = rough_mat
	instance.position = Vector3(0, -0.01, -length_m / 2)

	add_child(instance)

func _build_fairway(length_m: float, dogleg: String) -> void:
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(FAIRWAY_WIDTH, length_m + 20)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = fairway_mat
	instance.position = Vector3(0, 0.01, -length_m / 2)

	add_child(instance)

func _build_green(length_m: float) -> void:
	var green_mesh = CylinderMesh.new()
	green_mesh.top_radius = GREEN_RADIUS
	green_mesh.bottom_radius = GREEN_RADIUS
	green_mesh.height = 0.05

	var green_instance = MeshInstance3D.new()
	green_instance.mesh = green_mesh
	green_instance.material_override = green_mat
	green_instance.position = Vector3(0, 0.03, -length_m)

	add_child(green_instance)

	var collar_mesh = CylinderMesh.new()
	collar_mesh.top_radius = GREEN_RADIUS + 3.0
	collar_mesh.bottom_radius = GREEN_RADIUS + 3.0
	collar_mesh.height = 0.03

	var collar_instance = MeshInstance3D.new()
	collar_instance.mesh = collar_mesh
	collar_instance.material_override = fairway_mat
	collar_instance.position = Vector3(0, 0.015, -length_m)

	add_child(collar_instance)

func _build_tee_box() -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(TEE_BOX_WIDTH, 0.1, TEE_BOX_DEPTH)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = tee_mat
	instance.position = Vector3(0, 0.05, 0)

	add_child(instance)

func _build_bunkers(bunkers: Array, length_m: float) -> void:
	for bunker in bunkers:
		var bunker_type: String = bunker.get("type", "fairway")
		var position: String = bunker.get("position", "left")
		var yards_from_tee: float = bunker.get("yards_from_tee", 200)

		var x_offset: float = 0
		if position == "left":
			x_offset = -FAIRWAY_WIDTH / 2 - 5
		elif position == "right":
			x_offset = FAIRWAY_WIDTH / 2 + 5
		elif position == "front-left":
			x_offset = -GREEN_RADIUS - 5
		elif position == "front-right":
			x_offset = GREEN_RADIUS + 5
		elif position == "surround":
			_add_surround_bunkers(length_m)
			continue

		var z_pos: float = -yards_from_tee * 0.9144 if bunker_type == "fairway" else -length_m

		var mesh = CylinderMesh.new()
		mesh.top_radius = 3.0 + randf() * 3.0
		mesh.bottom_radius = 3.0 + randf() * 3.0
		mesh.height = 0.1

		var instance = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = bunker_mat
		instance.position = Vector3(x_offset, 0.05, z_pos)

		add_child(instance)

func _add_surround_bunkers(length_m: float) -> void:
	for i in 4:
		var angle: float = i * PI / 2 + PI / 4
		var x_off: float = cos(angle) * (GREEN_RADIUS + 6)
		var z_off: float = -length_m + sin(angle) * (GREEN_RADIUS + 6)

		var mesh = CylinderMesh.new()
		mesh.top_radius = 2.5 + randf() * 2.0
		mesh.bottom_radius = 2.5 + randf() * 2.0
		mesh.height = 0.1

		var instance = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = bunker_mat
		instance.position = Vector3(x_off, 0.05, z_off)

		add_child(instance)

func _build_water(water_features: Array, length_m: float) -> void:
	for water in water_features:
		var water_type: String = water.get("type", "pond")
		var name: String = water.get("name", "Water")
		var crosses: String = water.get("crosses", "")

		if water_type == "creek":
			var mesh = PlaneMesh.new()
			mesh.size = Vector2(8, length_m + 50)

			var instance = MeshInstance3D.new()
			instance.mesh = mesh
			instance.material_override = water_mat
			instance.position = Vector3(-15, 0.02, -length_m / 2)

			add_child(instance)
		elif water_type == "pond":
			var mesh = CylinderMesh.new()
			mesh.top_radius = 8.0
			mesh.bottom_radius = 8.0
			mesh.height = 0.05

			var instance = MeshInstance3D.new()
			instance.mesh = mesh
			instance.material_override = water_mat

			if "front of green" in crosses:
				instance.position = Vector3(0, 0.02, -length_m + 20)
			else:
				instance.position = Vector3(0, 0.02, -length_m / 2)

			add_child(instance)

func _build_trees(density: String, length_m: float) -> void:
	var tree_count: int = 0
	match density:
		"very heavy":
			tree_count = 80
		"heavy":
			tree_count = 50
		"moderate":
			tree_count = 30
		"light":
			tree_count = 15

	for i in tree_count:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var x_pos: float = side * (ROUGH_WIDTH / 2 + randf() * 15)
		var z_pos: float = -randf() * length_m

		if abs(x_pos) < FAIRWAY_WIDTH / 2 + 5:
			continue

		_add_tree(x_pos, z_pos)

func _add_tree(x: float, z: float) -> void:
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 3.0

	var trunk_instance = MeshInstance3D.new()
	trunk_instance.mesh = trunk_mesh
	trunk_instance.material_override = trunk_mat
	trunk_instance.position = Vector3(x, 1.5, z)
	add_child(trunk_instance)

	var foliage_mesh = CylinderMesh.new()
	foliage_mesh.top_radius = 0.1
	foliage_mesh.bottom_radius = 2.5
	foliage_mesh.height = 8.0

	var foliage_instance = MeshInstance3D.new()
	foliage_instance.mesh = foliage_mesh
	foliage_instance.material_override = tree_mat
	foliage_instance.position = Vector3(x, 7.0, z)
	foliage_instance.rotation.y = randf() * TAU
	add_child(foliage_instance)

func _build_flagstick(length_m: float) -> void:
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 3.0

	var pole_instance = MeshInstance3D.new()
	pole_instance.mesh = pole_mesh
	pole_instance.material_override = pole_mat
	pole_instance.position = Vector3(0, 1.5, -length_m)
	add_child(pole_instance)

	var flag_mesh = PlaneMesh.new()
	flag_mesh.size = Vector2(1.0, 0.7)

	var flag_instance = MeshInstance3D.new()
	flag_instance.mesh = flag_mesh
	flag_instance.material_override = flag_mat
	flag_instance.position = Vector3(0.5, 2.5, -length_m)
	add_child(flag_instance)

	var cup_mesh = CylinderMesh.new()
	cup_mesh.top_radius = 0.11
	cup_mesh.bottom_radius = 0.11
	cup_mesh.height = 0.02

	var cup_mat = StandardMaterial3D.new()
	cup_mat.albedo_color = Color(0.05, 0.05, 0.05)

	var cup_instance = MeshInstance3D.new()
	cup_instance.mesh = cup_mesh
	cup_instance.material_override = cup_mat
	cup_instance.position = Vector3(0, 0.06, -length_m)
	add_child(cup_instance)

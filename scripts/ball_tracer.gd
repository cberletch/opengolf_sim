extends Node3D
## BallTracer - Draws the ball flight trail at scene level (world coordinates).

var mesh: ImmediateMesh
var material: StandardMaterial3D
var points: PackedVector3Array = PackedVector3Array()
const MAX_POINTS: int = 500

func _ready() -> void:
	mesh = ImmediateMesh.new()
	material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.8, 0.2, 0.8)
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color(1, 0.6, 0.1, 0.5)
	material.emission_energy_multiplier = 0.5
	mesh.surface_set_material(0, material)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "TrailMesh"
	add_child(mesh_instance)

func add_point(world_pos: Vector3) -> void:
	if points.size() >= MAX_POINTS:
		points.remove_at(0)
	points.append(world_pos)
	_update_mesh()

func clear() -> void:
	points.clear()
	_update_mesh()

func _update_mesh() -> void:
	mesh.clear_surfaces()
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in points.size():
		mesh.surface_add_vertex(points[i])
	mesh.surface_end()

extends Node3D
## AimIndicator - Shows where the ball will actually go (camera dir + aim offset).

var mesh: ImmediateMesh
var aim_angle: float = 0.0
var visible_indicator: bool = false

const LINE_LENGTH: float = 50.0

func _ready() -> void:
	mesh = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.6)
	mat.roughness = 0.5
	mesh.surface_set_material(0, mat)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "AimLine"
	add_child(mesh_instance)
	_update_indicator()

func set_aim(angle_deg: float) -> void:
	aim_angle = angle_deg
	_update_indicator()

func show_indicator() -> void:
	visible_indicator = true
	_update_indicator()

func hide_indicator() -> void:
	visible_indicator = false
	_update_indicator()

func _update_indicator() -> void:
	mesh.clear_surfaces()
	if not visible_indicator:
		return
	var angle_rad: float = deg_to_rad(aim_angle)
	var dir := Vector3(sin(angle_rad), 0, -cos(angle_rad))
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(dir * LINE_LENGTH)
	mesh.surface_end()
	for dist in [50.0, 100.0, 150.0]:
		_draw_ring(dir * dist, 3.0)

func _draw_ring(center: Vector3, radius: float) -> void:
	var segments := 16
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in segments + 1:
		var a: float = TAU * float(i) / float(segments)
		mesh.surface_add_vertex(center + Vector3(cos(a) * radius, 0.1, sin(a) * radius))
	mesh.surface_end()

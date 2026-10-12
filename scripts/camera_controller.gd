extends Camera3D
## CameraController - Orbit around ball + face-target snap.
##
## The camera forward direction IS the aim reference.
## Aim slider adjusts left/right relative to where camera points.

const ORBIT_HEIGHT := 8.0
const ORBIT_DISTANCE := 15.0
const MIN_DISTANCE := 5.0
const MAX_DISTANCE := 60.0
const ORBIT_SPEED := 0.005
const ZOOM_SPEED := 1.5

var ball: Node3D
var mode: String = "tee"

var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.5
var orbit_distance: float = ORBIT_DISTANCE
var is_orbiting: bool = false

var target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	ball = get_node_or_null("/root/Main/Ball")
	if ball:
		ball.flight_started.connect(_on_flight_started)
		ball.flight_landed.connect(_on_flight_landed)

func set_target(target_pos: Vector3) -> void:
	target_position = target_pos

func face_target() -> void:
	if not ball:
		return
	mode = "orbit"
	var to_target := (target_position - ball.global_position).normalized()
	orbit_yaw = atan2(-to_target.x, -to_target.z)
	orbit_pitch = 0.5
	orbit_distance = ORBIT_DISTANCE
	_update_camera_position()

func get_aim_direction() -> float:
	"""Return the camera forward direction as HLA degrees (0 = straight at target)."""
	var forward := -global_transform.basis.z
	var angle := atan2(forward.x, -forward.z)
	return rad_to_deg(angle)

func _on_flight_started() -> void:
	mode = "follow"

func _on_flight_landed(_pos: Vector3, _lie: String) -> void:
	mode = "orbit"
	face_target()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			orbit_distance = max(MIN_DISTANCE, orbit_distance - ZOOM_SPEED)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			orbit_distance = min(MAX_DISTANCE, orbit_distance + ZOOM_SPEED)
			_update_camera_position()

	if event is InputEventMouseMotion and is_orbiting:
		orbit_yaw -= event.relative.x * ORBIT_SPEED
		orbit_pitch = clamp(orbit_pitch + event.relative.y * ORBIT_SPEED, 0.1, 1.4)
		_update_camera_position()

func _process(delta: float) -> void:
	match mode:
		"tee":
			if ball:
				global_position = ball.global_position + Vector3(0, ORBIT_HEIGHT, ORBIT_DISTANCE)
				look_at(ball.global_position + Vector3(0, 0, -30), Vector3.UP)
		"follow":
			if ball:
				global_position = global_position.lerp(ball.global_position + Vector3(0, ORBIT_HEIGHT, ORBIT_DISTANCE), 5.0 * delta)
				look_at(ball.global_position)
		"orbit":
			_update_camera_position()

func _update_camera_position() -> void:
	if not ball:
		return
	var offset := Vector3(
		sin(orbit_yaw) * cos(orbit_pitch),
		sin(orbit_pitch),
		cos(orbit_yaw) * cos(orbit_pitch)
	) * orbit_distance
	global_position = ball.global_position + offset
	look_at(ball.global_position, Vector3.UP)

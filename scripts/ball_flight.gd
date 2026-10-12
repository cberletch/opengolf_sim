extends Node3D
## BallFlight - Simulates golf ball flight with drag, magnus effect, and bounce.

signal flight_started()
signal flight_landed(position: Vector3, lie_type: String)
signal flight_updated(position: Vector3, velocity: Vector3)

const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225
const BALL_MASS: float = 0.04593
const BALL_RADIUS: float = 0.02135
const BALL_AREA: float = PI * BALL_RADIUS * BALL_RADIUS
const DRAG_COEFFICIENT: float = 0.35
const MAGNUS_COEFFICIENT: float = 0.00008
const ROLLING_FRICTION: float = 0.18
const BOUNCE_RESTITUTION: float = 0.45
const STOP_SPEED: float = 0.5

var velocity: Vector3 = Vector3.ZERO
var is_flying: bool = false
var is_rolling: bool = false
var spin_rate: float = 0.0
var spin_axis: float = 0.0
var elapsed_time: float = 0.0
var max_height: float = 0.0
var start_position: Vector3 = Vector3.ZERO
var _bounces: int = 0

var ball_mesh: MeshInstance3D

func _ready() -> void:
	_create_ball_mesh()

func _create_ball_mesh() -> void:
	var sphere = SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2
	sphere.radial_segments = 8
	sphere.rings = 4

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.roughness = 0.3

	ball_mesh = MeshInstance3D.new()
	ball_mesh.mesh = sphere
	ball_mesh.material_override = mat
	add_child(ball_mesh)

func launch(speed_mph: float, vla_deg: float, hla_deg: float, total_spin_rpm: float, spin_axis_deg: float) -> void:
	var speed_ms: float = speed_mph * 0.44704
	velocity = Vector3.ZERO
	elapsed_time = 0.0
	max_height = 0.0
	_bounces = 0
	spin_rate = total_spin_rpm
	spin_axis = spin_axis_deg
	start_position = global_position

	var vla_rad: float = deg_to_rad(vla_deg)
	var hla_rad: float = deg_to_rad(hla_deg)

	var horizontal_speed: float = speed_ms * cos(vla_rad)
	var vertical_speed: float = speed_ms * sin(vla_rad)

	velocity.x = horizontal_speed * sin(hla_rad)
	velocity.z = -horizontal_speed * cos(hla_rad)
	velocity.y = vertical_speed

	is_flying = true
	is_rolling = false
	emit_signal("flight_started")
	print("[BallFlight] Launched: speed=%.1fmph VLA=%.1f HLA=%.1f spin=%.0frpm" % [speed_mph, vla_deg, hla_deg, total_spin_rpm])

func _physics_process(delta: float) -> void:
	if not is_flying and not is_rolling:
		return

	elapsed_time += delta

	if is_flying:
		_simulate_flight(delta)
	elif is_rolling:
		_simulate_roll(delta)

	emit_signal("flight_updated", global_position, velocity)

func _simulate_flight(delta: float) -> void:
	velocity.y -= GRAVITY * delta

	var speed: float = velocity.length()
	if speed > 0.01:
		var drag_force: float = 0.5 * AIR_DENSITY * DRAG_COEFFICIENT * BALL_AREA * speed * speed
		var drag_accel: float = drag_force / BALL_MASS
		velocity -= velocity.normalized() * drag_accel * delta

	if spin_rate > 0:
		var spin_factor: float = clamp(spin_rate / 3000.0, 0.0, 3.0)
		var magnus_force: float = MAGNUS_COEFFICIENT * spin_factor * speed * speed
		var lift_dir: Vector3 = Vector3.UP.cross(velocity.cross(Vector3.UP)).normalized()
		if lift_dir.length() > 0.01:
			velocity += lift_dir * magnus_force * delta / BALL_MASS

	if abs(spin_axis) > 0.5 and speed > 0.01:
		var curve_force: float = MAGNUS_COEFFICIENT * spin_axis * speed * speed * 0.3
		var curve_dir: Vector3 = velocity.cross(Vector3.UP).normalized()
		velocity += curve_dir * curve_force * delta / BALL_MASS

	global_position += velocity * delta

	if global_position.y > max_height:
		max_height = global_position.y

	if global_position.y <= BALL_RADIUS and velocity.y < 0:
		global_position.y = BALL_RADIUS
		_on_bounce()

func _on_bounce() -> void:
	_bounces += 1
	velocity.y = -velocity.y * BOUNCE_RESTITUTION
	velocity.x *= 0.75
	velocity.z *= 0.75
	spin_rate *= 0.6

	if velocity.y < 0.8:
		velocity.y = 0.0
		is_flying = false
		is_rolling = true
		print("[BallFlight] Bounce #%d, switching to roll" % _bounces)

func _simulate_roll(delta: float) -> void:
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed > 0.01:
		var friction_decel: float = ROLLING_FRICTION * GRAVITY
		var new_speed: float = max(0.0, speed - friction_decel * delta)
		var scale: float = new_speed / speed
		velocity.x *= scale
		velocity.z *= scale

	global_position += velocity * delta

	if speed < STOP_SPEED:
		velocity = Vector3.ZERO
		is_rolling = false
		var lie_type := _determine_lie()
		print("[BallFlight] Ball stopped at %s (max height: %.1fm, time: %.1fs, bounces: %d)" % [str(global_position), max_height, elapsed_time, _bounces])
		emit_signal("flight_landed", global_position, lie_type)

func _determine_lie() -> String:
	return "fairway"

func get_flight_stats() -> Dictionary:
	return {
		"carry_distance": start_position.distance_to(Vector3(global_position.x, start_position.y, global_position.z)),
		"max_height": max_height,
		"flight_time": elapsed_time,
		"bounces": _bounces,
		"final_position": global_position,
		"speed": velocity.length(),
	}

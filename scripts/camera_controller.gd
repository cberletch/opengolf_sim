extends Camera3D
## CameraController - Follows the ball during flight, returns to tee view.

const TEE_POSITION := Vector3(0, 8, 15)
const TEE_LOOK_AT := Vector3(0, 0, -50)
const FOLLOW_DISTANCE := 15.0
const FOLLOW_HEIGHT := 8.0
const RETURN_SPEED := 3.0

var ball: Node3D
var mode: String = "tee"  # "tee" or "follow"
var target_position: Vector3 = TEE_POSITION
var target_look_at: Vector3 = TEE_LOOK_AT

func _ready() -> void:
	ball = get_node_or_null("/root/Main/Ball")
	if ball:
		ball.flight_started.connect(_on_flight_started)
		ball.flight_landed.connect(_on_flight_landed)

func _on_flight_started() -> void:
	mode = "follow"

func _on_flight_landed(_pos: Vector3, _lie: String) -> void:
	mode = "returning"

func _process(delta: float) -> void:
	match mode:
		"tee":
			_look_at(TEE_LOOK_AT)
		"follow":
			if ball:
				target_position = ball.global_position + Vector3(0, FOLLOW_HEIGHT, FOLLOW_DISTANCE)
				global_position = target_position
				_look_at(ball.global_position)
		"returning":
			target_position = TEE_POSITION
			target_look_at = TEE_LOOK_AT
			global_position = global_position.lerp(target_position, RETURN_SPEED * delta)
			_look_at(target_look_at)
			if global_position.distance_to(target_position) < 0.5:
				mode = "tee"

func _look_at(target: Vector3) -> void:
	look_at(target, Vector3.UP)

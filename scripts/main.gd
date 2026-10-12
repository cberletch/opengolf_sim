extends Node3D
## Main - Orchestrates the golf simulator scene.

const HOLE_DATA_PATH = "res://data/first_3_holes.json"

var current_hole: int = 0
var shot_history: Array = []
var ball: Node3D
var connector: Node
var course_gen: Node
var camera: Camera3D
var score_tracker: Control
var hud_label: Label
var shot_label: Label
var hole_label: Label
var holes_data: Array = []

func _ready() -> void:
	ball = $Ball
	connector = $SkytrakConnector
	course_gen = $CourseGenerator
	camera = $Camera3D
	score_tracker = $HUD/ScoreTracker
	hud_label = $HUD/ConnectionLabel
	shot_label = $HUD/ShotLabel
	hole_label = $HUD/HoleLabel

	# Connect signals
	connector.shot_received.connect(_on_shot_received)
	connector.player_info_received.connect(_on_player_info_received)
	connector.connection_status_changed.connect(_on_connection_status_changed)
	ball.flight_landed.connect(_on_ball_landed)

	# Load course data
	_load_course_data()

	# Build first hole
	if holes_data.size() > 0:
		_build_hole(0)

	print("[Main] Augusta National Golf Sim ready")
	print("[Main] Waiting for Skytrak connection on port 9210...")

func _load_course_data() -> void:
	var file = FileAccess.open(HOLE_DATA_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		var data = json.data
		holes_data = data.get("holes", [])
		print("[Main] Loaded course data: %d holes" % holes_data.size())
	else:
		push_warning("[Main] Could not load holes.json")

func _build_hole(index: int) -> void:
	if index < 0 or index >= holes_data.size():
		return

	current_hole = index
	var hole: Dictionary = holes_data[index]
	course_gen.build_hole(hole)

	# Update HUD
	var hole_num: int = hole.get("number", index + 1)
	var hole_name: String = hole.get("name", "Unknown")
	var par: int = hole.get("par", 4)
	var yards: int = hole.get("yards", 400)
	hole_label.text = "Hole %d: %s (Par %d, %d yd)" % [hole_num, hole_name, par, yards]

	# Reset ball to tee
	ball.global_position = Vector3(0, 0.02, 0)
	ball.velocity = Vector3.ZERO
	ball.is_flying = false
	ball.is_rolling = false
	ball.clear_trail()

	# Reset camera
	if camera:
		camera.global_position = camera.TEE_POSITION
		camera.look_at(camera.TEE_LOOK_AT, Vector3.UP)

	# Update score tracker
	if score_tracker:
		score_tracker.setup_hole(hole_num, par)

	print("[Main] Built hole %d: %s" % [hole_num, hole_name])

func _on_shot_received(shot_data: Dictionary) -> void:
	var bd: Dictionary = shot_data["BallData"]
	var speed: float = bd.get("Speed", 0)
	var vla: float = bd.get("VLA", 0)
	var hla: float = bd.get("HLA", 0)
	var spin: float = bd.get("TotalSpin", 0)
	var axis: float = bd.get("SpinAxis", 0)

	shot_history.append(shot_data)

	# Record shot in score tracker
	if score_tracker:
		score_tracker.record_shot()

	# Launch the ball
	ball.launch(speed, vla, hla, spin, axis)

	# Update HUD
	var shot_num: int = shot_data.get("ShotNumber", 0)
	shot_label.text = "Shot #%d\nSpeed: %.1f mph\nLaunch: %.1f deg\nSpin: %.0f rpm\nAxis: %.1f deg\nCarry: %.1f yd" % [
		shot_num, speed, vla, spin, axis, bd.get("CarryDistance", 0)
	]

func _on_player_info_received(player_data: Dictionary) -> void:
	var handed: String = player_data.get("Handed", "RH")
	var club: String = player_data.get("Club", "DR")
	shot_label.text = "Player: %s handed\nClub: %s" % [handed, club]

func _on_connection_status_changed(connected: bool, info: String) -> void:
	if connected:
		hud_label.text = "Connected: %s" % info
		hud_label.modulate = Color(0.3, 1.0, 0.3)
	else:
		hud_label.text = "Disconnected: %s" % info
		hud_label.modulate = Color(1.0, 0.3, 0.3)

func _on_ball_landed(position: Vector3, lie_type: String) -> void:
	print("[Main] Ball landed at %s (%s)" % [str(position), lie_type])
	var stats = ball.get_flight_stats()
	var carry_yd: float = stats.get("carry_distance", 0) * 1.09361
	var total_yd: float = position.distance_to(Vector3(0, 0, 0)) * 1.09361
	shot_label.text += "\nCarry: %.1f yd\nTotal: %.1f yd" % [carry_yd, total_yd]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_next_hole()
	elif event.is_action_pressed("ui_left"):
		_prev_hole()

func _next_hole() -> void:
	if current_hole < holes_data.size() - 1:
		_build_hole(current_hole + 1)
	else:
		print("[Main] Already on last hole")

func _prev_hole() -> void:
	if current_hole > 0:
		_build_hole(current_hole - 1)
	else:
		print("[Main] Already on first hole")

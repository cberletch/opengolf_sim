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
var tracer: Node3D
var aim_indicator: Node3D
var hud_label: Label
var shot_label: Label
var hole_label: Label
var holes_data: Array = []
var current_aim: float = 0.0
var hole_length_m: float = 0.0

func _ready() -> void:
	ball = $Ball
	connector = $SkytrakConnector
	course_gen = $CourseGenerator
	camera = $Camera3D
	score_tracker = $HUD/ScoreTracker
	tracer = $BallTracer
	aim_indicator = $AimIndicator
	hud_label = $HUD/ConnectionLabel
	shot_label = $HUD/ShotLabel
	hole_label = $HUD/HoleLabel

	connector.shot_received.connect(_on_shot_received)
	connector.player_info_received.connect(_on_player_info_received)
	connector.connection_status_changed.connect(_on_connection_status_changed)
	ball.flight_landed.connect(_on_ball_landed)
	ball.flight_updated.connect(_on_ball_updated)

	if camera and ball:
		ball.flight_started.connect(camera._on_flight_started)
		ball.flight_landed.connect(camera._on_flight_landed)

	_load_course_data()

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

	var hole_num: int = hole.get("number", index + 1)
	var hole_name: String = hole.get("name", "Unknown")
	var par: int = hole.get("par", 4)
	var yards: int = hole.get("yards", 400)
	hole_label.text = "Hole %d: %s (Par %d, %d yd)" % [hole_num, hole_name, par, yards]
	hole_length_m = yards * 0.9144

	ball.global_position = Vector3(0, 0.02, 0)
	ball.velocity = Vector3.ZERO
	ball.is_flying = false
	ball.is_rolling = false

	if tracer:
		tracer.clear()

	current_aim = 0.0
	if aim_indicator:
		aim_indicator.set_aim(0.0)
		aim_indicator.hide_indicator()
		aim_indicator.global_position = Vector3(0, 0.1, 0)

	if camera:
		camera.set_target(Vector3(0, 0, -hole_length_m))
		camera.face_target()

	if score_tracker:
		score_tracker.setup_hole(hole_num, par)

	print("[Main] Built hole %d: %s" % [hole_num, hole_name])

func set_aim(angle_deg: float) -> void:
	current_aim = angle_deg
	if aim_indicator:
		aim_indicator.set_aim(angle_deg)
		aim_indicator.show_indicator()

func face_target() -> void:
	if camera:
		camera.face_target()
	if aim_indicator:
		aim_indicator.global_position = ball.global_position + Vector3(0, 0.1, 0)
		aim_indicator.set_aim(0.0)
		aim_indicator.show_indicator()
	current_aim = 0.0

func _on_shot_received(shot_data: Dictionary) -> void:
	var bd: Dictionary = shot_data["BallData"]
	var speed: float = bd.get("Speed", 0)
	var vla: float = bd.get("VLA", 0)
	var spin: float = bd.get("TotalSpin", 0)
	var axis: float = bd.get("SpinAxis", 0)

	# HLA = camera direction + aim slider offset
	var camera_hla: float = camera.get_aim_direction() if camera else 0.0
	var hla: float = camera_hla + current_aim

	shot_history.append(shot_data)

	if score_tracker:
		score_tracker.record_shot()

	ball.launch(speed, vla, hla, spin, axis)

	var shot_num: int = shot_data.get("ShotNumber", 0)
	shot_label.text = "Shot #%d\nSpeed: %.1f mph\nLaunch: %.1f deg\nHLA: %.1f deg (cam=%.1f aim=%.1f)\nSpin: %.0f rpm\nCarry: %.1f yd" % [
		shot_num, speed, vla, hla, camera_hla, current_aim, spin, bd.get("CarryDistance", 0)
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

func _on_ball_updated(pos: Vector3, _vel: Vector3) -> void:
	if tracer and (ball.is_flying or ball.is_rolling):
		tracer.add_point(pos)

func _on_ball_landed(position: Vector3, lie_type: String) -> void:
	print("[Main] Ball landed at %s (%s)" % [str(position), lie_type])
	var stats = ball.get_flight_stats()
	var carry_yd: float = stats.get("carry_distance", 0) * 1.09361
	var total_yd: float = position.distance_to(Vector3(0, 0, 0)) * 1.09361
	shot_label.text += "\nCarry: %.1f yd\nTotal: %.1f yd" % [carry_yd, total_yd]

	if aim_indicator:
		aim_indicator.global_position = position + Vector3(0, 0.1, 0)

	var dist_to_hole: float = position.distance_to(Vector3(0, 0, -hole_length_m))
	if dist_to_hole < 20.0:
		_auto_putt(dist_to_hole)

func _auto_putt(dist_to_hole: float) -> void:
	var putts: int = 1 if dist_to_hole < 3.0 else 2
	if score_tracker:
		score_tracker.record_score(score_tracker.shots_taken + putts)
	shot_label.text += "\nAuto-putt: %d putt(s)" % putts
	print("[Main] Auto-putt: %d putt(s) from %.1fm" % [putts, dist_to_hole])
	await get_tree().create_timer(2.0).timeout
	_next_hole()

func _process(_delta: float) -> void:
	# Keep aim indicator synced with camera direction
	if camera and aim_indicator and aim_indicator.visible_indicator:
		var camera_hla: float = camera.get_aim_direction()
		aim_indicator.set_aim(camera_hla + current_aim)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_next_hole()
	elif event.is_action_pressed("ui_left"):
		_prev_hole()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		face_target()

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

extends Control
## ShotTestUtility - UI panel for triggering test shots without Skytrak.

var club_option: OptionButton
var speed_slider: HSlider
var launch_slider: HSlider
var hla_slider: HSlider
var spin_slider: HSlider
var axis_slider: HSlider
var aim_slider: HSlider

var speed_label: Label
var launch_label: Label
var hla_label: Label
var spin_label: Label
var axis_label: Label
var aim_label: Label

var fire_button: Button
var random_button: Button
var face_target_button: Button

var ball: Node3D

const CLUB_PRESETS = {
	"DRIVER": {"speed": 134, "launch": 14, "spin": 3100, "axis": -3},
	"7IRON": {"speed": 100, "launch": 18, "spin": 6000, "axis": 0},
	"9IRON": {"speed": 99, "launch": 23, "spin": 7500, "axis": 2},
	"PITCH": {"speed": 80, "launch": 30, "spin": 9000, "axis": 0},
}

func _ready() -> void:
	ball = get_node_or_null("/root/Main/Ball")
	if not ball:
		push_warning("[ShotTestUtility] Ball node not found")
		return
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.name = "TestPanel"
	panel.position = Vector2(10, 200)
	panel.size = Vector2(300, 550)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Shot Test Utility"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var club_label = Label.new()
	club_label.text = "Club:"
	vbox.add_child(club_label)

	club_option = OptionButton.new()
	club_option.add_item("DRIVER")
	club_option.add_item("7IRON")
	club_option.add_item("9IRON")
	club_option.add_item("PITCH")
	club_option.selected = 0
	club_option.item_selected.connect(_on_club_changed)
	vbox.add_child(club_option)

	vbox.add_child(HSeparator.new())

	_add_slider(vbox, "Aim Direction (deg)", -60, 60, 0, "aim")
	_add_slider(vbox, "Ball Speed (mph)", 50, 180, 134, "speed")
	_add_slider(vbox, "Launch Angle (deg)", 0, 45, 14, "launch")
	_add_slider(vbox, "HLA (deg)", -20, 20, 0, "hla")
	_add_slider(vbox, "Total Spin (rpm)", 500, 12000, 3100, "spin")
	_add_slider(vbox, "Spin Axis (deg)", -15, 15, -3, "axis")

	vbox.add_child(HSeparator.new())

	face_target_button = Button.new()
	face_target_button.text = "Face Target (F)"
	face_target_button.add_theme_font_size_override("font_size", 14)
	face_target_button.pressed.connect(_on_face_target_pressed)
	vbox.add_child(face_target_button)

	fire_button = Button.new()
	fire_button.text = "Fire Shot"
	fire_button.add_theme_font_size_override("font_size", 16)
	fire_button.pressed.connect(_on_fire_pressed)
	vbox.add_child(fire_button)

	random_button = Button.new()
	random_button.text = "Random Shot"
	random_button.add_theme_font_size_override("font_size", 14)
	random_button.pressed.connect(_on_random_pressed)
	vbox.add_child(random_button)

func _add_slider(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, slider_name: String) -> void:
	var label = Label.new()
	label.text = "%s: %.1f" % [label_text, default_val]
	parent.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.5
	slider.value = default_val
	slider.custom_minimum_size = Vector2(250, 20)

	match slider_name:
		"aim":
			aim_slider = slider
			aim_label = label
			slider.value_changed.connect(_on_aim_changed)
		"speed":
			speed_slider = slider
			speed_label = label
			slider.value_changed.connect(_on_speed_changed)
		"launch":
			launch_slider = slider
			launch_label = label
			slider.value_changed.connect(_on_launch_changed)
		"hla":
			hla_slider = slider
			hla_label = label
			slider.value_changed.connect(_on_hla_changed)
		"spin":
			spin_slider = slider
			spin_label = label
			slider.value_changed.connect(_on_spin_changed)
		"axis":
			axis_slider = slider
			axis_label = label
			slider.value_changed.connect(_on_axis_changed)

	parent.add_child(slider)

func _on_club_changed(index: int) -> void:
	var club_name: String = club_option.get_item_text(index)
	var preset: Dictionary = CLUB_PRESETS.get(club_name, {})
	if speed_slider and preset.has("speed"):
		speed_slider.value = preset["speed"]
	if launch_slider and preset.has("launch"):
		launch_slider.value = preset["launch"]
	if spin_slider and preset.has("spin"):
		spin_slider.value = preset["spin"]
	if axis_slider and preset.has("axis"):
		axis_slider.value = preset["axis"]

func _on_aim_changed(value: float) -> void:
	aim_label.text = "Aim Direction (deg): %.1f" % value
	var main = get_node_or_null("/root/Main")
	if main:
		main.set_aim(value)

func _on_speed_changed(value: float) -> void:
	speed_label.text = "Ball Speed (mph): %.1f" % value

func _on_launch_changed(value: float) -> void:
	launch_label.text = "Launch Angle (deg): %.1f" % value

func _on_hla_changed(value: float) -> void:
	hla_label.text = "HLA (deg): %.1f" % value

func _on_spin_changed(value: float) -> void:
	spin_label.text = "Total Spin (rpm): %.0f" % value

func _on_axis_changed(value: float) -> void:
	axis_label.text = "Spin Axis (deg): %.1f" % value

func _on_face_target_pressed() -> void:
	var main = get_node_or_null("/root/Main")
	if main:
		main.face_target()

func _on_fire_pressed() -> void:
	if not ball:
		return

	var speed: float = speed_slider.value if speed_slider else 120
	var launch: float = launch_slider.value if launch_slider else 15
	var hla: float = hla_slider.value if hla_slider else 0
	var spin: float = spin_slider.value if spin_slider else 3000
	var axis: float = axis_slider.value if axis_slider else 0
	var aim: float = aim_slider.value if aim_slider else 0

	var total_hla: float = hla + aim

	print("[ShotTest] Firing: speed=%.1f launch=%.1f hla=%.1f (aim=%.1f) spin=%.0f axis=%.1f" % [speed, launch, total_hla, aim, spin, axis])
	ball.launch(speed, launch, total_hla, spin, axis)

func _on_random_pressed() -> void:
	if not ball:
		return

	var speed: float = randf_range(80, 150)
	var launch: float = randf_range(5, 30)
	var hla: float = randf_range(-10, 10)
	var spin: float = randf_range(2000, 8000)
	var axis: float = randf_range(-8, 8)
	var aim: float = randf_range(-15, 15)

	if speed_slider:
		speed_slider.value = speed
	if launch_slider:
		launch_slider.value = launch
	if hla_slider:
		hla_slider.value = hla
	if spin_slider:
		spin_slider.value = spin
	if axis_slider:
		axis_slider.value = axis
	if aim_slider:
		aim_slider.value = aim

	_on_fire_pressed()

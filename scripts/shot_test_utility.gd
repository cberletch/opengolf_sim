extends Control
## ShotTestUtility - UI panel for triggering test shots without Skytrak.
## Allows manual input of shot parameters to test ball flight and course geometry.

var speed_slider: HSlider
var launch_slider: HSlider
var hla_slider: HSlider
var spin_slider: HSlider
var axis_slider: HSlider

var speed_label: Label
var launch_label: Label
var hla_label: Label
var spin_label: Label
var axis_label: Label

var fire_button: Button
var random_button: Button

var ball: Node3D

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
	panel.size = Vector2(300, 400)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Shot Test Utility"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_add_slider(vbox, "Ball Speed (mph)", 50, 180, 120, "speed")
	_add_slider(vbox, "Launch Angle (deg)", 0, 45, 15, "launch")
	_add_slider(vbox, "HLA (deg)", -20, 20, 0, "hla")
	_add_slider(vbox, "Total Spin (rpm)", 500, 12000, 3000, "spin")
	_add_slider(vbox, "Spin Axis (deg)", -15, 15, 0, "axis")

	vbox.add_child(HSeparator.new())

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

func _on_fire_pressed() -> void:
	if not ball:
		return

	var speed: float = speed_slider.value if speed_slider else 120
	var launch: float = launch_slider.value if launch_slider else 15
	var hla: float = hla_slider.value if hla_slider else 0
	var spin: float = spin_slider.value if spin_slider else 3000
	var axis: float = axis_slider.value if axis_slider else 0

	print("[ShotTest] Firing: speed=%.1f launch=%.1f hla=%.1f spin=%.0f axis=%.1f" % [speed, launch, hla, spin, axis])
	ball.launch(speed, launch, hla, spin, axis)

func _on_random_pressed() -> void:
	if not ball:
		return

	var speed: float = randf_range(80, 150)
	var launch: float = randf_range(5, 30)
	var hla: float = randf_range(-10, 10)
	var spin: float = randf_range(2000, 8000)
	var axis: float = randf_range(-8, 8)

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

	_on_fire_pressed()

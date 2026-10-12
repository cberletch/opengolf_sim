extends Control
## ScoreTracker - Displays current hole score and shot count.

var hole_label: Label
var score_label: Label
var shots_label: Label
var shots_taken: int = 0
var current_hole: int = 1
var current_score: int = 0
var hole_par: int = 4

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 200)
	panel.size = Vector2(200, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 5
	vbox.offset_right = -10
	vbox.offset_bottom = -5
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	hole_label = Label.new()
	hole_label.text = "Hole 1"
	hole_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(hole_label)

	score_label = Label.new()
	score_label.text = "Par 4 | Score: E"
	score_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(score_label)

	shots_label = Label.new()
	shots_label.text = "Shots: 0"
	shots_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(shots_label)

func setup_hole(hole_num: int, par: int) -> void:
	current_hole = hole_num
	hole_par = par
	current_score = 0
	shots_taken = 0
	_update_display()

func record_shot() -> void:
	shots_taken += 1
	current_score += 1
	_update_display()

func record_score(strokes: int) -> void:
	current_score = strokes
	shots_taken = strokes
	_update_display()

func _update_display() -> void:
	hole_label.text = "Hole %d" % current_hole
	var score_str: String = "E"
	if current_score > hole_par:
		score_str = "+%d" % (current_score - hole_par)
	elif current_score < hole_par:
		score_str = "%d" % (current_score - hole_par)
	score_label.text = "Par %d | Score: %s" % [hole_par, score_str]
	shots_label.text = "Shots: %d" % shots_taken

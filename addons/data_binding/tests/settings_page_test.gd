extends Node

# Integration test for demo/settings_page.tscn: initial sync, Model -> View,
# View -> Model (slider / check button / option button / line edit) and Reset.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + label)
	if not ok:
		_fail += 1

func _ready() -> void:
	var scene: Control = load("res://addons/data_binding/demo/settings_page.tscn").instantiate()
	add_child(scene)
	var model: Model = scene.get_model()

	var master: HSlider = scene.get_node("Layout/VBox/Body/Tabs/Audio/AudioGrid/MasterRow/MasterSlider")
	var vsync: CheckButton = scene.get_node("Layout/VBox/Body/Tabs/Display/DisplayGrid/VSyncCheck")
	var res: OptionButton = scene.get_node("Layout/VBox/Body/Tabs/Display/DisplayGrid/ResolutionOption")
	var name_edit: LineEdit = scene.get_node("Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/NameEdit")
	var master_value: Label = scene.get_node("Layout/VBox/Body/Tabs/Audio/AudioGrid/MasterRow/MasterValue")
	var scale_value: Label = scene.get_node("Layout/VBox/Body/Tabs/Display/DisplayGrid/UiScaleRow/UiScaleValue")

	# 1) initial sync Model -> View
	_check("initial master slider = 80", is_equal_approx(master.value, 80.0))
	_check("initial vsync = true", vsync.button_pressed == true)
	_check("initial resolution index = 1", res.selected == 1)
	_check("initial player name = Player", name_edit.text == "Player")
	# one-way formatted bindings (no target signal)
	_check("initial formatted label = 80%", master_value.text == "80%")
	_check("initial formatted scale = 1.00x", scale_value.text == "1.00x")

	# 2) Model -> View for each type
	model.set_value("master_volume", 25.0)
	_check("model->view slider (25)", is_equal_approx(master.value, 25.0))
	_check("model->view formatted label (25%)", master_value.text == "25%")
	model.set_value("vsync", false)
	_check("model->view checkbutton (false)", vsync.button_pressed == false)
	model.set_value("resolution_index", 3)
	_check("model->view optionbutton (3)", res.selected == 3)
	model.set_value("player_name", "Neo")
	_check("model->view lineedit (Neo)", name_edit.text == "Neo")

	# 3) View -> Model for each type (control property + signal, like a user edit)
	master.value = 55.0
	master.value_changed.emit(55.0)
	_check("view->model slider (55)", is_equal_approx(model.get_value("master_volume"), 55.0))
	vsync.button_pressed = true
	vsync.toggled.emit(true)
	_check("view->model checkbutton (true)", model.get_value("vsync") == true)
	res.selected = 0
	res.item_selected.emit(0)
	_check("view->model optionbutton (0)", model.get_value("resolution_index") == 0)
	name_edit.text = "Trinity"
	name_edit.text_changed.emit("Trinity")
	_check("view->model lineedit (Trinity)", model.get_value("player_name") == "Trinity")

	# 4) Reset Defaults = bulk Model -> View
	scene.call("_on_reset_pressed")
	_check("reset model master = 80", is_equal_approx(model.get_value("master_volume"), 80.0))
	_check("reset slider follows = 80", is_equal_approx(master.value, 80.0))
	_check("reset name follows = Player", name_edit.text == "Player")
	_check("reset vsync follows = true", vsync.button_pressed == true)
	_check("reset formatted label follows = 80%", master_value.text == "80%")

	print("== ", "ALL PASS" if _fail == 0 else "%d FAILED" % _fail, " ==")
	get_tree().quit(1 if _fail > 0 else 0)

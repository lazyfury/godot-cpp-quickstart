extends Control

# Minimal demo: one Model, three Bindings (LineEdit / SpinBox / CheckBox).
# The Model never references the Controls and the Controls never reference the
# Model — each Binding is the only glue between them.

var _model: Model
var _bindings: Array[Binding] = []

@onready var _line_edit: LineEdit = $Center/Panel/Margin/VBox/NameRow/LineEdit
@onready var _spin_box: SpinBox = $Center/Panel/Margin/VBox/AgeRow/SpinBox
@onready var _check_box: CheckBox = $Center/Panel/Margin/VBox/EnabledRow/CheckBox
@onready var _dump: Label = $Center/Panel/Margin/VBox/Dump


func _ready() -> void:
	_model = Model.new()
	_model.set_value("name", "Alice")
	_model.set_value("age", 20)
	_model.set_value("enabled", true)
	_model.value_changed.connect(_on_model_changed)

	_bind("name", _line_edit, "text", "text_changed")
	_bind("age", _spin_box, "value", "value_changed")
	_bind("enabled", _check_box, "button_pressed", "toggled")

	_refresh_dump()


func _bind(property: StringName, target: Object, target_property: StringName, target_signal: StringName) -> void:
	var binding := Binding.new()
	if not binding.bind(_model, property, target, target_property, target_signal):
		push_error(binding.get_last_error())
		return
	_bindings.append(binding)


func _on_model_changed(_name: StringName, _value: Variant) -> void:
	_refresh_dump()


func _refresh_dump() -> void:
	_dump.text = "model:  name=%s   age=%s   enabled=%s" % [
		_model.get_value("name"),
		_model.get_value("age"),
		_model.get_value("enabled"),
	]


# --- Model -> View demos: only the Model is written, the Views follow. ---

func _on_set_name_pressed() -> void:
	_model.set_value("name", "Bob")


func _on_age_plus_pressed() -> void:
	_model.set_value("age", int(_model.get_value("age")) + 1)


func _on_toggle_enabled_pressed() -> void:
	_model.set_value("enabled", not bool(_model.get_value("enabled")))

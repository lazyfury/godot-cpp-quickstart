extends Node

# Headless self-test for Model + Binding.
# Run:
#   Godot --headless --path . res://addons/data_binding/tests/binding_test.tscn
# Exits with code 1 when any check fails.

# A cooperative target that transforms the value and re-emits its change signal.
# Without the Binding guard this would recurse forever.
class ReentrantTarget:
	extends Node
	signal value_changed(value: Variant)

	var value: Variant = null:
		set(v):
			value = str(v) + "!"
			set_count += 1
			value_changed.emit(value)

	var set_count: int = 0

	func reset_count() -> void:
		set_count = 0

var _failures: int = 0


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("== data_binding tests ==")
	_test_initial_sync()
	_test_model_to_view()
	_test_view_to_model()
	_test_no_signal_when_unchanged()
	_test_format_one_way()
	_test_loop_prevention()
	_test_unbind()
	_test_invalid_input()
	_test_freed_target()
	print("== ", "ALL PASS" if _failures == 0 else "%d FAILED" % _failures, " ==")
	get_tree().quit(1 if _failures > 0 else 0)


func _test_initial_sync() -> void:
	var model := Model.new()
	model.set_value("name", "Alice")
	var line := LineEdit.new()
	add_child(line)

	var binding := Binding.new()
	var ok := binding.bind(model, "name", line, "text", "text_changed")

	_check("bind() returns true", ok)
	_check("initial sync Model -> View", line.text == "Alice")

	line.queue_free()


func _test_model_to_view() -> void:
	var model := Model.new()
	model.set_value("name", "Alice")
	var line := LineEdit.new()
	add_child(line)
	var binding := Binding.new()
	binding.bind(model, "name", line, "text", "text_changed")

	model.set_value("name", "Bob")
	_check("Model -> View", line.text == "Bob")

	line.queue_free()


func _test_view_to_model() -> void:
	var model := Model.new()
	model.set_value("name", "Alice")
	var line := LineEdit.new()
	add_child(line)
	var binding := Binding.new()
	binding.bind(model, "name", line, "text", "text_changed")

	line.text_changed.emit("Charlie")
	_check("View -> Model", model.get_value("name") == "Charlie")

	line.queue_free()


func _test_no_signal_when_unchanged() -> void:
	var model := Model.new()
	var count := [0]
	model.value_changed.connect(func(_name, _value): count[0] += 1)

	model.set_value("name", "Alice")
	model.set_value("name", "Alice")
	_check("unchanged value does not emit", count[0] == 1)

	model.set_value("name", "Bob")
	_check("changed value emits", count[0] == 2)


func _test_format_one_way() -> void:
	var model := Model.new()
	model.set_value("volume", 42.0)
	var label := Label.new()
	add_child(label)

	# empty target signal => one-way (Model -> View) with a format string
	var binding := Binding.new()
	var ok := binding.bind(model, "volume", label, "text", "", "%d%%")
	_check("one-way bind() returns true", ok)
	_check("one-way is_one_way()", binding.is_one_way())
	_check("one-way get_target_signal empty", binding.get_target_signal() == &"")
	_check("get_format() returns format", binding.get_format() == "%d%%")
	_check("initial format applied (42%)", label.text == "42%")

	model.set_value("volume", 7.0)
	_check("format follows Model -> View (7%)", label.text == "7%")

	# without a format the raw value is written
	var raw := Label.new()
	add_child(raw)
	var plain := Binding.new()
	plain.bind(model, "volume", raw, "text")
	_check("no format -> raw value", raw.text == str(7.0))

	label.queue_free()
	raw.queue_free()


func _test_loop_prevention() -> void:
	var model := Model.new()
	model.set_value("x", "a")

	var target := ReentrantTarget.new()
	add_child(target)
	var binding := Binding.new()
	binding.bind(model, "x", target, "value", "value_changed")

	target.reset_count()
	model.set_value("x", "b")
	_check("loop prevented (one view write)", target.set_count == 1)
	_check("Model value not corrupted by echo", model.get_value("x") == "b")

	target.queue_free()


func _test_unbind() -> void:
	var model := Model.new()
	model.set_value("name", "Alice")
	var line := LineEdit.new()
	add_child(line)
	var binding := Binding.new()
	binding.bind(model, "name", line, "text", "text_changed")

	binding.unbind()
	_check("unbind() clears state", not binding.is_bound())

	model.set_value("name", "Bob")
	_check("Model -> View stopped after unbind", line.text == "Alice")

	line.text_changed.emit("Zed")
	_check("View -> Model stopped after unbind", model.get_value("name") == "Bob")

	line.queue_free()


func _test_invalid_input() -> void:
	var model := Model.new()
	var line := LineEdit.new()
	add_child(line)

	var binding := Binding.new()
	var ok := binding.bind(model, "name", line, "nope", "text_changed")
	_check("missing property rejected", not ok and not binding.get_last_error().is_empty())

	ok = binding.bind(model, "name", line, "text", "nope_signal")
	_check("missing signal rejected", not ok)

	ok = binding.bind(model, "name", line, "text", "pressed") # Button.pressed has 0 args
	_check("0-argument signal rejected", not ok)

	ok = binding.bind(null, "name", line, "text", "text_changed")
	_check("null model rejected", not ok)

	ok = binding.bind(model, "name", null, "text", "text_changed")
	_check("null target rejected", not ok)

	line.queue_free()


func _test_freed_target() -> void:
	var model := Model.new()
	model.set_value("name", "Alice")
	var line := LineEdit.new()
	add_child(line)
	var binding := Binding.new()
	binding.bind(model, "name", line, "text", "text_changed")

	remove_child(line)
	line.free()

	_check("freed target -> is_bound() false", not binding.is_bound())
	# Must not touch the freed Object.
	model.set_value("name", "Bob")
	_check("freed target -> no crash on Model change", true)

	binding.unbind()

extends Control

# UI glue only. All real logic lives in the C++ `QuickStart` node (see src/).
@onready var _quickstart: QuickStart = $QuickStart
@onready var _output: Label = $Center/Panel/Margin/VBox/Output
@onready var _counter: Label = $Center/Panel/Margin/VBox/Counter


func _ready() -> void:
	_quickstart.ready_message.connect(_on_ready_message)
	_quickstart.greeted.connect(_on_greeted)
	_refresh_output()


func _refresh_output() -> void:
	var info: Dictionary = QuickStart.engine_info()
	_output.text = "%s\n\nGodot %s  ·  %s  ·  %s" % [
		_quickstart.message,
		info["godot_version"],
		info["platform"],
		info["os_version"],
	]


func _on_greet_pressed() -> void:
	_output.text = _quickstart.greet("World")


func _on_increment_pressed() -> void:
	_counter.text = "counter = %d" % _quickstart.increment()


func _on_reset_pressed() -> void:
	_quickstart.reset()
	_counter.text = "counter = %d" % _quickstart.get_counter()


func _on_ready_message(text: String) -> void:
	print("signal ready_message -> ", text)


func _on_greeted(name: String) -> void:
	print("signal greeted -> ", name)

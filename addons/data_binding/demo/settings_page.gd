extends Control

# =============================================================================
# Classic game settings page.
#
# One Model holds every setting. Each interactive control is connected through
# its own Binding, so:
#   * editing a control  -> Model updates        (View -> Model)
#   * Reset / code writes -> controls update      (Model -> View)
# The Model never references a Control and no Control references the Model.
#
# The small value labels are ordinary one-way bindings (no target signal) with
# a format string, so they are driven by the same Binding as the editable
# controls. The "LIVE MODEL" panel is a composite readout refreshed from
# Model.value_changed.
# =============================================================================

const DEFAULTS := {
	"master_volume": 80.0,
	"music_volume": 60.0,
	"sfx_volume": 90.0,
	"mute": false,
	"resolution_index": 1,
	"fullscreen": false,
	"vsync": true,
	"max_fps": 144,
	"ui_scale": 1.0,
	"difficulty_index": 1,
	"language_index": 0,
	"mouse_sensitivity": 1.5,
	"invert_y": false,
	"player_name": "Player",
}

const RESOLUTIONS := ["1280x720", "1920x1080", "2560x1440", "3840x2160"]
const DIFFICULTIES := ["Easy", "Normal", "Hard", "Nightmare"]
const LANGUAGES := ["English", "Espanol", "Francais", "Deutsch"]

var _model: Model
var _bindings: Array[Binding] = []

@onready var _master_slider: HSlider = $Layout/VBox/Body/Tabs/Audio/AudioGrid/MasterRow/MasterSlider
@onready var _master_value: Label = $Layout/VBox/Body/Tabs/Audio/AudioGrid/MasterRow/MasterValue
@onready var _music_slider: HSlider = $Layout/VBox/Body/Tabs/Audio/AudioGrid/MusicRow/MusicSlider
@onready var _music_value: Label = $Layout/VBox/Body/Tabs/Audio/AudioGrid/MusicRow/MusicValue
@onready var _sfx_slider: HSlider = $Layout/VBox/Body/Tabs/Audio/AudioGrid/SfxRow/SfxSlider
@onready var _sfx_value: Label = $Layout/VBox/Body/Tabs/Audio/AudioGrid/SfxRow/SfxValue
@onready var _mute_check: CheckButton = $Layout/VBox/Body/Tabs/Audio/AudioGrid/MuteCheck
@onready var _resolution_option: OptionButton = $Layout/VBox/Body/Tabs/Display/DisplayGrid/ResolutionOption
@onready var _fullscreen_check: CheckButton = $Layout/VBox/Body/Tabs/Display/DisplayGrid/FullscreenCheck
@onready var _vsync_check: CheckButton = $Layout/VBox/Body/Tabs/Display/DisplayGrid/VSyncCheck
@onready var _fps_spin: SpinBox = $Layout/VBox/Body/Tabs/Display/DisplayGrid/FpsSpin
@onready var _ui_scale_slider: HSlider = $Layout/VBox/Body/Tabs/Display/DisplayGrid/UiScaleRow/UiScaleSlider
@onready var _ui_scale_value: Label = $Layout/VBox/Body/Tabs/Display/DisplayGrid/UiScaleRow/UiScaleValue
@onready var _difficulty_option: OptionButton = $Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/DifficultyOption
@onready var _language_option: OptionButton = $Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/LanguageOption
@onready var _sens_slider: HSlider = $Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/SensRow/SensSlider
@onready var _sens_value: Label = $Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/SensRow/SensValue
@onready var _invert_y_check: CheckButton = $Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/InvertYCheck
@onready var _name_edit: LineEdit = $Layout/VBox/Body/Tabs/Gameplay/GameplayGrid/NameEdit
@onready var _model_dump: Label = $Layout/VBox/Body/ModelPanel/ModelMargin/ModelVBox/ModelDump
@onready var _status: Label = $Layout/VBox/Footer/Status


func _ready() -> void:
	_populate_options()

	_model = Model.new()
	for key in DEFAULTS:
		_model.set_value(key, DEFAULTS[key])
	_model.value_changed.connect(_on_model_changed)

	_bind_all()
	_model_dump.text = _format_model()
	_status.text = "Ready."


func get_model() -> Model:
	return _model


# ---------------------------------------------------------------------------
# binding setup
# ---------------------------------------------------------------------------

func _bind_all() -> void:
	# Audio
	_bind("master_volume", _master_slider, "value", "value_changed")
	_bind("music_volume", _music_slider, "value", "value_changed")
	_bind("sfx_volume", _sfx_slider, "value", "value_changed")
	_bind("mute", _mute_check, "button_pressed", "toggled")
	# Display
	_bind("resolution_index", _resolution_option, "selected", "item_selected")
	_bind("fullscreen", _fullscreen_check, "button_pressed", "toggled")
	_bind("vsync", _vsync_check, "button_pressed", "toggled")
	_bind("max_fps", _fps_spin, "value", "value_changed")
	_bind("ui_scale", _ui_scale_slider, "value", "value_changed")
	# Gameplay
	_bind("difficulty_index", _difficulty_option, "selected", "item_selected")
	_bind("language_index", _language_option, "selected", "item_selected")
	_bind("mouse_sensitivity", _sens_slider, "value", "value_changed")
	_bind("invert_y", _invert_y_check, "button_pressed", "toggled")
	_bind("player_name", _name_edit, "text", "text_changed")

	# Read-only readouts: empty signal => one-way Model -> View, with formatting.
	# No manual refresh code needed - the Binding writes the formatted text.
	_bind("master_volume", _master_value, "text", &"", "%d%%")
	_bind("music_volume", _music_value, "text", &"", "%d%%")
	_bind("sfx_volume", _sfx_value, "text", &"", "%d%%")
	_bind("ui_scale", _ui_scale_value, "text", &"", "%.2fx")
	_bind("mouse_sensitivity", _sens_value, "text", &"", "%.1f")


func _bind(property: StringName, target: Object, target_property: StringName,
		target_signal: StringName = &"", format: String = "") -> void:
	var binding := Binding.new()
	if not binding.bind(_model, property, target, target_property, target_signal, format):
		push_error(binding.get_last_error())
		return
	_bindings.append(binding)


func _populate_options() -> void:
	_fill_option(_resolution_option, RESOLUTIONS)
	_fill_option(_difficulty_option, DIFFICULTIES)
	_fill_option(_language_option, LANGUAGES)


func _fill_option(option: OptionButton, items: Array) -> void:
	option.clear()
	for item in items:
		option.add_item(str(item))


# ---------------------------------------------------------------------------
# read-only readouts (updated from the Model signal, not bound)
# ---------------------------------------------------------------------------

func _on_model_changed(_name: StringName, _value: Variant) -> void:
	_model_dump.text = _format_model()
	_status.text = "Unsaved changes"


func _format_model() -> String:
	var lines := [
		"[audio]",
		"master_volume   %d" % _model.get_value("master_volume"),
		"music_volume    %d" % _model.get_value("music_volume"),
		"sfx_volume      %d" % _model.get_value("sfx_volume"),
		"mute            %s" % _model.get_value("mute"),
		"",
		"[display]",
		"resolution      %s (%d)" % [RESOLUTIONS[_model.get_value("resolution_index")], _model.get_value("resolution_index")],
		"fullscreen      %s" % _model.get_value("fullscreen"),
		"vsync           %s" % _model.get_value("vsync"),
		"max_fps         %d" % _model.get_value("max_fps"),
		"ui_scale        %.2f" % float(_model.get_value("ui_scale")),
		"",
		"[gameplay]",
		"difficulty      %s (%d)" % [DIFFICULTIES[_model.get_value("difficulty_index")], _model.get_value("difficulty_index")],
		"language        %s (%d)" % [LANGUAGES[_model.get_value("language_index")], _model.get_value("language_index")],
		"mouse_sens      %.1f" % float(_model.get_value("mouse_sensitivity")),
		"invert_y        %s" % _model.get_value("invert_y"),
		"player_name     %s" % _model.get_value("player_name"),
	]
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# footer actions
# ---------------------------------------------------------------------------

# Model -> View: write every default back into the Model; all controls follow.
func _on_reset_pressed() -> void:
	for key in DEFAULTS:
		_model.set_value(key, DEFAULTS[key])
	_status.text = "Defaults restored."


func _on_apply_pressed() -> void:
	print("=== applied settings ===\n", _format_model())
	_status.text = "Applied (see console)."

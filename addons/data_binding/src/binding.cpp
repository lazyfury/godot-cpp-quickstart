#include "binding.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable_method_pointer.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>

using namespace godot;

void Binding::_bind_methods() {
	ClassDB::bind_method(D_METHOD("bind", "model", "model_property", "target", "target_property", "target_signal", "format"),
			&Binding::bind, DEFVAL(StringName()), DEFVAL(String()));
	ClassDB::bind_method(D_METHOD("unbind"), &Binding::unbind);
	ClassDB::bind_method(D_METHOD("get_model"), &Binding::get_model);
	ClassDB::bind_method(D_METHOD("get_target"), &Binding::get_target);
	ClassDB::bind_method(D_METHOD("get_model_property"), &Binding::get_model_property);
	ClassDB::bind_method(D_METHOD("get_target_property"), &Binding::get_target_property);
	ClassDB::bind_method(D_METHOD("get_target_signal"), &Binding::get_target_signal);
	ClassDB::bind_method(D_METHOD("get_format"), &Binding::get_format);
	ClassDB::bind_method(D_METHOD("is_one_way"), &Binding::is_one_way);
	ClassDB::bind_method(D_METHOD("is_bound"), &Binding::is_bound);
	ClassDB::bind_method(D_METHOD("get_last_error"), &Binding::get_last_error);
}

Binding::Binding() {
	model_callable = callable_mp(this, &Binding::_on_model_changed);
	target_callable = callable_mp(this, &Binding::_on_target_changed);
}

Binding::~Binding() {
	unbind();
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

Object *Binding::_target() const {
	if (target_id.is_valid()) {
		return ObjectDB::get_instance(target_id);
	}
	return nullptr;
}

void Binding::_set_error(const String &p_error) {
	last_error = p_error;
}

Variant Binding::_format_value(const Variant &p_value) const {
	if (display_format.is_empty()) {
		return p_value;
	}
	const String pattern = display_format;
	// Use the typed `%` overloads (same path as GDScript). The Variant overload
	// does not accept e.g. a float for "%d".
	switch (p_value.get_type()) {
		case Variant::BOOL:
			return pattern % bool(p_value);
		case Variant::INT:
			return pattern % int64_t(p_value);
		case Variant::FLOAT:
			return pattern % double(p_value);
		case Variant::STRING:
			return pattern % String(p_value);
		default:
			// Array / Object / etc.: fall back to the Variant overload.
			return pattern % p_value;
	}
}

bool Binding::_has_property(Object *p_object, const StringName &p_property) const {
	const TypedArray<Dictionary> properties = p_object->get_property_list();
	for (int64_t i = 0; i < properties.size(); i++) {
		const Dictionary property = properties[i];
		if (StringName(property.get("name", StringName())) == p_property) {
			return true;
		}
	}
	return false;
}

bool Binding::_signal_argument_count(Object *p_object, const StringName &p_signal, int64_t &r_count) const {
	const TypedArray<Dictionary> signals = p_object->get_signal_list();
	for (int64_t i = 0; i < signals.size(); i++) {
		const Dictionary signal = signals[i];
		if (StringName(signal.get("name", StringName())) == p_signal) {
			const Array args = signal.get("args", Array());
			r_count = args.size();
			return true;
		}
	}
	r_count = 0;
	return false;
}

// ---------------------------------------------------------------------------
// bind / unbind
// ---------------------------------------------------------------------------

bool Binding::bind(const Ref<Model> &p_model, const StringName &p_model_property,
		Object *p_target, const StringName &p_target_property,
		const StringName &p_target_signal, const String &p_format) {
	// Start clean so re-binding cannot leave stale connections.
	unbind();
	last_error = String();

	// --- validation (fail loudly, never silently) ---
	if (p_model.is_null()) {
		_set_error("Binding: model is null.");
		return false;
	}
	if (p_target == nullptr) {
		_set_error("Binding: target is null.");
		return false;
	}
	if (p_model_property == StringName()) {
		_set_error("Binding: model property is empty.");
		return false;
	}
	if (p_target_property == StringName()) {
		_set_error("Binding: target property is empty.");
		return false;
	}
	if (!_has_property(p_target, p_target_property)) {
		_set_error(vformat("Binding: target property '%s' does not exist on '%s'.",
				String(p_target_property), p_target->get_class()));
		return false;
	}
	// target_signal is optional: empty means a one-way (Model -> View) binding.
	if (p_target_signal != StringName()) {
		if (!p_target->has_signal(p_target_signal)) {
			_set_error(vformat("Binding: signal '%s' was not found on '%s'.",
					String(p_target_signal), p_target->get_class()));
			return false;
		}
		int64_t argument_count = 0;
		if (!_signal_argument_count(p_target, p_target_signal, argument_count) || argument_count != 1) {
			_set_error(vformat("Binding: signal '%s' must take exactly one argument (the value), got %d.",
					String(p_target_signal), int(argument_count)));
			return false;
		}
	}

	// --- store references ---
	model = p_model;
	target_id = p_target->get_instance_id();
	model_property = p_model_property;
	target_property = p_target_property;
	target_signal = p_target_signal;
	display_format = p_format;

	// --- connect ---
	// Model -> Binding. One connection receives every property and filters by
	// name, so a single binding never reacts to unrelated properties.
	model->connect("value_changed", model_callable);
	// View -> Binding (two-way bindings only).
	if (target_signal != StringName()) {
		p_target->connect(target_signal, target_callable);
	}

	bound = true;

	// --- initial sync: Model -> View (Model is the source of truth) ---
	updating = true;
	p_target->set(target_property, _format_value(model->get_value(model_property)));
	updating = false;

	return true;
}

void Binding::unbind() {
	if (!model.is_null()) {
		if (model->is_connected("value_changed", model_callable)) {
			model->disconnect("value_changed", model_callable);
		}
	}

	Object *target = _target();
	if (target && target_signal != StringName() && target->is_connected(target_signal, target_callable)) {
		target->disconnect(target_signal, target_callable);
	}

	model = Ref<Model>();
	target_id = ObjectID();
	model_property = StringName();
	target_property = StringName();
	target_signal = StringName();
	display_format = String();
	updating = false;
	bound = false;
}

// ---------------------------------------------------------------------------
// synchronisation
// ---------------------------------------------------------------------------

void Binding::_on_model_changed(const StringName &p_name, const Variant &p_value) {
	if (!bound || updating) {
		return;
	}
	if (p_name != model_property) {
		// Not our property.
		return;
	}

	Object *target = _target();
	if (!target) {
		// Target was freed: stop working, never touch the dead Object.
		return;
	}

	updating = true;
	target->set(target_property, _format_value(p_value));
	updating = false;
}

void Binding::_on_target_changed(const Variant &p_value) {
	if (!bound || updating) {
		return;
	}
	if (model.is_null()) {
		return;
	}

	updating = true;
	model->set_value(model_property, p_value);
	updating = false;
}

// ---------------------------------------------------------------------------
// accessors
// ---------------------------------------------------------------------------

Ref<Model> Binding::get_model() const {
	return model;
}

Object *Binding::get_target() const {
	return _target();
}

StringName Binding::get_model_property() const {
	return model_property;
}

StringName Binding::get_target_property() const {
	return target_property;
}

StringName Binding::get_target_signal() const {
	return target_signal;
}

String Binding::get_format() const {
	return display_format;
}

bool Binding::is_one_way() const {
	return target_signal == StringName();
}

bool Binding::is_bound() const {
	return bound && _target() != nullptr;
}

String Binding::get_last_error() const {
	return last_error;
}

#ifndef DATA_BINDING_BINDING_H
#define DATA_BINDING_BINDING_H

#include "model.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/object_id.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

// The only glue between a Model and a View (any Godot Object with a settable
// property).
//
//   Model.value_changed(name, value)  ->  target.set(target_property, value)
//   target.<target_signal>(value)     ->  model.set_value(model_property, value)
//
// When `target_signal` is empty the binding is one-way (Model -> View only),
// which is what read-only views such as Labels use. An optional `format`
// string (Godot's `%` syntax, e.g. "%d%%") is applied on Model -> View before
// writing, so a plain Label can display a formatted value directly.
//
// The Model never references the View and the View never references the Model;
// this Binding is the only boundary between them.
class Binding : public RefCounted {
	GDCLASS(Binding, RefCounted)

private:
	Ref<Model> model;
	// Weak reference: the target is owned by the SceneTree, not by the Binding.
	ObjectID target_id;

	StringName model_property;
	StringName target_property;
	StringName target_signal;
	// Optional Model -> View formatter ("%d%%", "%.2fx", ...). Empty = raw.
	String display_format;

	// Single loop-prevention guard for both directions.
	bool updating = false;
	bool bound = false;

	// Stable Callables so unbind() can disconnect exactly what bind() connected.
	Callable model_callable;
	Callable target_callable;
	String last_error;

	Object *_target() const;
	bool _has_property(Object *p_object, const StringName &p_property) const;
	bool _signal_argument_count(Object *p_object, const StringName &p_signal, int64_t &r_count) const;
	void _set_error(const String &p_error);
	// Applies display_format when set, otherwise returns the value unchanged.
	Variant _format_value(const Variant &p_value) const;

protected:
	static void _bind_methods();

	// Model -> View. Ignores properties this binding does not own.
	void _on_model_changed(const StringName &p_name, const Variant &p_value);
	// View -> Model.
	void _on_target_changed(const Variant &p_value);

public:
	Binding();
	~Binding();

	// Establishes the binding and performs one initial Model -> View sync.
	// p_target_signal: empty for a one-way (Model -> View) binding.
	// p_format: optional Godot `%` format applied on Model -> View.
	// Returns false and stores a message in get_last_error() on invalid input.
	bool bind(const Ref<Model> &p_model, const StringName &p_model_property,
			Object *p_target, const StringName &p_target_property,
			const StringName &p_target_signal = StringName(), const String &p_format = String());
	// Disconnects both sides and clears the references. Safe to call twice.
	void unbind();

	Ref<Model> get_model() const;
	Object *get_target() const;
	StringName get_model_property() const;
	StringName get_target_property() const;
	StringName get_target_signal() const;
	String get_format() const;
	// One-way (Model -> View only) when no target signal was given.
	bool is_one_way() const;
	bool is_bound() const;
	String get_last_error() const;
};

} // namespace godot

#endif // DATA_BINDING_BINDING_H

#ifndef DATA_BINDING_MODEL_H
#define DATA_BINDING_MODEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

// The single Model for the first version.
//
// A Model only stores values, mutates them and announces changes through the
// Godot signal `value_changed(name, value)`. It never knows about Controls,
// Nodes, scenes, bindings or any UI API.
class Model : public RefCounted {
	GDCLASS(Model, RefCounted)

private:
	Dictionary values;

protected:
	static void _bind_methods();

public:
	Model();
	~Model();

	// Stores p_value under p_name. Emits `value_changed` only when the value
	// actually changed (writing the same value is a no-op).
	void set_value(const StringName &p_name, const Variant &p_value);
	Variant get_value(const StringName &p_name) const;
	bool has_value(const StringName &p_name) const;
};

} // namespace godot

#endif // DATA_BINDING_MODEL_H

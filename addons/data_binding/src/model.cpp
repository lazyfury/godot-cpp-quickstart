#include "model.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void Model::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_value", "name", "value"), &Model::set_value);
	ClassDB::bind_method(D_METHOD("get_value", "name"), &Model::get_value);
	ClassDB::bind_method(D_METHOD("has_value", "name"), &Model::has_value);

	// value_changed(name, value) — the Model's only notification API.
	ADD_SIGNAL(MethodInfo("value_changed",
			PropertyInfo(Variant::STRING_NAME, "name"),
			PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "",
					PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_NIL_IS_VARIANT)));
}

Model::Model() {
}

Model::~Model() {
}

void Model::set_value(const StringName &p_name, const Variant &p_value) {
	if (values.has(p_name)) {
		const Variant existing = values[p_name];
		if (existing == p_value) {
			// Unchanged: do not emit (avoids redundant view updates).
			return;
		}
	}

	values[p_name] = p_value;
	emit_signal("value_changed", p_name, p_value);
}

Variant Model::get_value(const StringName &p_name) const {
	return values.get(p_name, Variant());
}

bool Model::has_value(const StringName &p_name) const {
	return values.has(p_name);
}

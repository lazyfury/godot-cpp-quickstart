#include "quick_start.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

// Registers properties, methods and signals with Godot's ClassDB.
// This is what makes everything callable from GDScript and the inspector.
void QuickStart::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_message", "message"), &QuickStart::set_message);
	ClassDB::bind_method(D_METHOD("get_message"), &QuickStart::get_message);
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "message", PROPERTY_HINT_MULTILINE_TEXT),
			"set_message", "get_message");

	ClassDB::bind_method(D_METHOD("get_counter"), &QuickStart::get_counter);
	ClassDB::bind_method(D_METHOD("increment"), &QuickStart::increment);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "counter"), "", "get_counter");

	ClassDB::bind_method(D_METHOD("greet", "name"), &QuickStart::greet);
	ClassDB::bind_method(D_METHOD("reset"), &QuickStart::reset);
	// Static methods need bind_static_method; callable as QuickStart.engine_info().
	ClassDB::bind_static_method("QuickStart", D_METHOD("engine_info"), &QuickStart::engine_info);

	// Custom signal: `quick_start.gd` connects to it.
	ADD_SIGNAL(MethodInfo("ready_message", PropertyInfo(Variant::STRING, "text")));
	ADD_SIGNAL(MethodInfo("greeted", PropertyInfo(Variant::STRING, "name")));
}

void QuickStart::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_READY: {
			// Runs once the node enters the scene tree (after children are ready).
			print_line(vformat("[QuickStart] ready: %s", message));
			emit_signal("ready_message", message);
		} break;
		default:
			break;
	}
}

QuickStart::QuickStart() {
}

QuickStart::~QuickStart() {
}

void QuickStart::set_message(const String &p_message) {
	message = p_message;
}

String QuickStart::get_message() const {
	return message;
}

int64_t QuickStart::get_counter() const {
	return counter;
}

int64_t QuickStart::increment() {
	return ++counter;
}

String QuickStart::greet(const String &p_name) {
	emit_signal("greeted", p_name);
	return vformat("Hi, %s! %s", p_name, message);
}

Dictionary QuickStart::engine_info() {
	Dictionary info;
	const Dictionary version = Engine::get_singleton()->get_version_info();
	info["godot_version"] = version.get("string", "unknown");
	info["platform"] = OS::get_singleton()->get_name();
	info["os_version"] = OS::get_singleton()->get_version();
	return info;
}

void QuickStart::reset() {
	counter = 0;
}

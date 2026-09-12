#ifndef QUICKSTART_QUICK_START_H
#define QUICKSTART_QUICK_START_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Example GDExtension node.
//
// It demonstrates the pieces you will copy for your own C++ classes:
//   * GDCLASS + _bind_methods
//   * exposed properties (with typed setters/getters)
//   * callable methods (incl. one usable from the editor / GDScript)
//   * a custom signal emitted on _ready()
//   * a static helper using the Godot C++ API
class QuickStart : public Node {
	GDCLASS(QuickStart, Node)

private:
	String message = "Hello from C++ GDExtension!";
	int64_t counter = 0;

protected:
	static void _bind_methods();
	void _notification(int p_what);

public:
	QuickStart();
	~QuickStart();

	// --- property: message ---
	void set_message(const String &p_message);
	String get_message() const;

	// --- property: counter (read-only, advanced in C++) ---
	int64_t get_counter() const;
	int64_t increment();

	// --- methods ---
	String greet(const String &p_name);
	static Dictionary engine_info();

	// Called automatically because it is a bound method (see _bind_methods).
	void reset();
};

} // namespace godot

#endif // QUICKSTART_QUICK_START_H

#include "register_types.h"

#include "quick_start.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_quickstart_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	// Register every C++ class exposed to GDScript / the editor here.
	GDREGISTER_CLASS(QuickStart);
}

void uninitialize_quickstart_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// GDExtension entry point. The symbol name must match `entry_symbol` in
// bin/quickstart.gdextension and ENTRY_SYMBOL in SConstruct.
GDExtensionBool GDE_EXPORT quickstart_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_quickstart_module);
	init_obj.register_terminator(uninitialize_quickstart_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}

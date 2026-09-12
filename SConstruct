#!/usr/bin/env python
"""
Godot C++ GDExtension quick-start build script.

Build the whole project (main extension + every addon):

    scons                                   # debug (template_debug)
    scons target=template_release           # release
    scons addons=no                         # main extension only
    scons compiledb=yes                     # clangd compilation database
    scons godot_cpp=/path/to/godot-cpp      # override godot-cpp location

Each addon under addons/*/ is a standalone sub-project and can also be built on
its own:

    cd addons/data_binding && scons

The addon's shared build recipe lives in addons/<name>/SConscript; both this
file and the addon's SConstruct invoke it with the same configured environment.
"""

import os

# --------------------------------------------------------------------------
# Main extension configuration
# --------------------------------------------------------------------------
PROJECT_NAME = "quickstart"
SOURCES_DIR = "src"
OUTPUT_DIR = "bin"
# Must match the symbol declared in src/register_types.cpp.
ENTRY_SYMBOL = PROJECT_NAME + "_library_init"


def resolve_godot_cpp():
    path = ARGUMENTS.get("godot_cpp") or os.environ.get("GODOT_CPP_PATH") or "godot-cpp"
    if not os.path.isfile(os.path.join(path, "SConstruct")):
        raise SCons.Errors.UserError(
            "Could not find godot-cpp at '{}'.\n"
            "Clone it (git submodule update --init --recursive) or pass "
            "`godot_cpp=/path/to/godot-cpp`.".format(path)
        )
    return path


# Configured godot-cpp environment. Kept pristine; each extension clones it.
env = SConscript(os.path.join(resolve_godot_cpp(), "SConstruct"))

# --------------------------------------------------------------------------
# Main extension
# --------------------------------------------------------------------------
main_env = env.Clone()
main_env.Append(CPPPATH=[Dir(SOURCES_DIR).srcnode().abspath])
sources = Glob(SOURCES_DIR + "/*.cpp")

platform = main_env["platform"]
target = main_env["target"]

if platform == "macos":
    # macOS uses a framework bundle (godot-cpp 4.x convention).
    library = main_env.SharedLibrary(
        "{output}/lib{name}.{platform}.{target}.framework/lib{name}.{platform}.{target}".format(
            output=OUTPUT_DIR, name=PROJECT_NAME, platform=platform, target=target
        ),
        source=sources,
    )
elif platform == "ios":
    library = main_env.StaticLibrary(
        "{output}/lib{name}.{platform}.{target}.a".format(
            output=OUTPUT_DIR, name=PROJECT_NAME, platform=platform, target=target
        ),
        source=sources,
    )
else:
    # linux / windows / android / web
    library = main_env.SharedLibrary(
        "{output}/lib{name}{suffix}{shlibsuffix}".format(
            output=OUTPUT_DIR,
            name=PROJECT_NAME,
            suffix=main_env["suffix"],
            shlibsuffix=main_env["SHLIBSUFFIX"],
        ),
        source=sources,
    )

Default(library)

# --------------------------------------------------------------------------
# Addons (optional): scons addons=no to skip
# --------------------------------------------------------------------------
want_addons = ARGUMENTS.get("addons", "yes").lower() not in ("no", "0", "false", "off")
if want_addons:
    for script in sorted(Glob("addons/*/SConscript")):
        addon_library = SConscript(script, exports={"env": env})
        if addon_library is not None:
            Default(addon_library)

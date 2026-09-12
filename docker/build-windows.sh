#!/usr/bin/env bash
#
# Cross-compile the GDExtension for Windows x86_64 in a Linux + MinGW-w64
# container, so the Windows artifacts can be verified from macOS/Linux without
# a Windows machine or MSVC.
#
# Usage:
#   docker/build-windows.sh                                    # debug build
#   TARGETS="template_debug template_release" docker/build-windows.sh
#   docker/build-windows.sh addons=no -j4                      # extra scons args
#   IMAGE=my-img BUILD_VOLUME=my-vol docker/build-windows.sh
#
# The build happens in an isolated tree stored in the Docker volume
# BUILD_VOLUME, so the host project's macOS/Linux build state is untouched.
# Only the resulting *.dll files are copied back into the project.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE="${IMAGE:-quickstart-mingw}"
BUILD_VOLUME="${BUILD_VOLUME:-quickstart-mingw-build}"

# Resolve godot-cpp (works whether it is a symlink, a real clone, or a submodule).
if command -v python3 >/dev/null 2>&1; then
    GODOT_CPP_DIR="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$PROJECT_DIR/godot-cpp")"
else
    GODOT_CPP_DIR="$(cd "$PROJECT_DIR/godot-cpp" && pwd -P)"
fi

if [ ! -f "$GODOT_CPP_DIR/SConstruct" ]; then
    echo "error: godot-cpp not found at '$GODOT_CPP_DIR'." >&2
    echo "       Run 'git submodule update --init --recursive' or create the godot-cpp symlink." >&2
    exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "error: docker not found in PATH" >&2; exit 1; }

echo "==> Project:    $PROJECT_DIR"
echo "==> godot-cpp:  $GODOT_CPP_DIR"
echo "==> Image:      $IMAGE"
echo "==> Build tree: volume '$BUILD_VOLUME' at /build"

echo "==> Building Docker image '$IMAGE'"
docker build -t "$IMAGE" "$SCRIPT_DIR"

echo "==> Cross-compiling for Windows (MinGW-w64)"
docker run --rm \
    -v "$PROJECT_DIR":/src \
    -v "$GODOT_CPP_DIR":/godot-cpp:ro \
    -v "$BUILD_VOLUME":/build \
    -e "TARGETS=${TARGETS:-template_debug}" \
    -e "ARCH=${ARCH:-x86_64}" \
    "$IMAGE" "$@"

#!/usr/bin/env bash
#
# Container entrypoint: cross-compile the GDExtension for Windows x86_64 with
# the MinGW-w64 toolchain.
#
# Mounts expected by docker/build-windows.sh:
#   /src        host project (sources are rsync'ed from here, DLLs written back)
#   /godot-cpp  host godot-cpp checkout (read-only source of truth)
#   /build      isolated build tree, kept in a Docker volume for incremental builds
#
# Environment:
#   TARGETS  space separated scons targets (default: template_debug)
#   ARCH     target architecture (default: x86_64)
#
# Extra CLI arguments are forwarded to scons (e.g. `-j8 addons=no verbose=yes`).
set -euo pipefail

SRC_DIR="${SRC_DIR:-/src}"
GODOT_CPP_SRC="${GODOT_CPP_SRC:-/godot-cpp}"
BUILD_DIR="${BUILD_DIR:-/build}"
ARCH="${ARCH:-x86_64}"
TARGETS="${TARGETS:-template_debug}"

log() { printf '\033[1;34m[mingw]\033[0m %s\n' "$*"; }

if [ ! -f "$GODOT_CPP_SRC/SConstruct" ]; then
    echo "error: godot-cpp not found at '$GODOT_CPP_SRC'" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

# --------------------------------------------------------------------------
# 1. Sync project sources into the isolated build tree.
#    Host build artifacts (.os/.o, DLLs/dylibs, sconsign DB, godot-cpp symlink)
#    are excluded so the macOS/Linux build state is never touched.
# --------------------------------------------------------------------------
log "Syncing project sources -> $BUILD_DIR"
rsync -a --delete \
    --exclude '.git/' \
    --exclude '.godot/' \
    --exclude '.sconsign.dblite' \
    --exclude '*.os' \
    --exclude '*.o' \
    --exclude '*.a' \
    --exclude '*.dll' \
    --exclude '*.so' \
    --exclude '*.dylib' \
    --exclude '*.framework/' \
    --exclude 'compile_commands.json' \
    --exclude 'godot-cpp' \
    "$SRC_DIR"/ "$BUILD_DIR"/

# --------------------------------------------------------------------------
# 2. Sync godot-cpp sources. Generated bindings (*.cpp/*.h under gen/) and
#    previously built objects are kept, so repeated runs stay incremental.
# --------------------------------------------------------------------------
log "Syncing godot-cpp sources -> $BUILD_DIR/godot-cpp"
rsync -a \
    --exclude '.git/' \
    --exclude 'bin/' \
    --exclude '*.o' \
    --exclude '*.os' \
    "$GODOT_CPP_SRC"/ "$BUILD_DIR/godot-cpp"/

# --------------------------------------------------------------------------
# 3. Build every requested target.
# --------------------------------------------------------------------------
for target in $TARGETS; do
    log "scons platform=windows arch=$ARCH target=$target (MinGW-w64)"
    (
        cd "$BUILD_DIR"
        scons \
            platform=windows \
            arch="$ARCH" \
            use_mingw=yes \
            target="$target" \
            godot_cpp="$BUILD_DIR/godot-cpp" \
            "$@"
    )
done

# --------------------------------------------------------------------------
# 4. Copy the produced Windows binaries back to the host project.
# --------------------------------------------------------------------------
log "Copying Windows binaries back to $SRC_DIR"
shopt -s nullglob
copied=0
for f in "$BUILD_DIR"/bin/*.dll "$BUILD_DIR"/addons/*/bin/*.dll; do
    rel="${f#"$BUILD_DIR"/}"
    mkdir -p "$SRC_DIR/$(dirname "$rel")"
    cp -f "$f" "$SRC_DIR/$rel"
    log "  $rel"
    copied=$((copied + 1))
done
shopt -u nullglob

if [ "$copied" -eq 0 ]; then
    echo "error: no Windows .dll was produced" >&2
    exit 1
fi

log "Verifying PE headers of $copied artifact(s):"
for f in "$SRC_DIR"/bin/*.dll "$SRC_DIR"/addons/*/bin/*.dll; do
    [ -e "$f" ] || continue
    file "$f"
done

log "Done."

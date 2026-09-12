# Linux + MinGW-w64 cross-compilation environment for the Godot C++
# GDExtension quick-start project.
#
# Produces Windows x86_64 `.dll` artifacts from a macOS/Linux host without
# needing a Windows machine or MSVC.
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        scons \
        python3 \
        gcc-mingw-w64-x86-64-posix \
        g++-mingw-w64-x86-64-posix \
        binutils-mingw-w64-x86-64 \
        rsync \
        file \
    && rm -rf /var/lib/apt/lists/*

# Sanity check: toolchain on PATH and using the POSIX thread model (needed for
# std::thread / std::mutex, which the win32 thread model does not provide).
RUN x86_64-w64-mingw32-g++ --version \
    && x86_64-w64-mingw32-g++ --version | grep -q -- '-posix' \
    && x86_64-w64-mingw32-gcc-ar --version >/dev/null

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /build

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

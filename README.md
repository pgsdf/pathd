# Pathd

Pathd is a filesystem first, policy driven spatial shell built on drawfs.

It treats filesystem navigation the way a shell treats working directories, and treats windows and views as policy decisions rather than kernel primitives.

Documentation lives in `docs/`.

## Build

Requirements

* Zig 0.15.2

Build

* `zig build`

Run demo mode

* `zig build run -Ddemo=true`

## Status

The input pipeline and policy routing are implemented in user space.
drawfs integration is staged and tracked in `docs/ROADMAP.md`.

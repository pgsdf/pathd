# Contributing

Thanks for contributing to Pathd.

## Principles

* Filesystem first
* Policy in user space
* Deterministic behavior over convenience
* Safe defaults, explicit opt in for destructive actions

## Development

Requirements

* Zig 0.15.2

Build

* `zig build`

Run demo mode

* `zig build run -Ddemo=true`

Notes

* Demo mode does not require drawfs. It exercises the input pipeline and directory model.
* drawfs integration is a tracked milestone in docs/ROADMAP.md.

## Style

* Prefer simple control flow and explicit error handling
* Keep policy code in `src/input` and `src/core`
* Keep drawfs mechanism code isolated in `src/core/drawfs`

## License

By submitting a pull request, you agree your contribution is licensed under the BSD 2 Clause License.

# colorsync

A CLI tool for managing color theme configurations.

## Build & Run with Nix

```bash
nix run github:LarssonMartin1998/colorsync#default
```

## Build & Run without Nix

Requires [Zig](https://ziglang.org/).

```bash
zig build run
# binaries can be found here
zig-out/bin/colorsync
```

## Commands

- `set <theme>`
- `get`
- `show`
- `validate`

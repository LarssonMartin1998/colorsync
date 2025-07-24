{
  description = "Colorsync – Zig project flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs =
    { self, zig2nix, ... }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        env = zig2nix.outputs.zig-env.${system} { };
        pkgs = env.pkgs;
        lib = pkgs.lib;
      in
      {
        packages.colorsync = (
          env.package {
            pname = "colorsync";
            version = "1.0.3";
            src = lib.cleanSource self;

            lockFile = ./build.zig.zon2json-lock;
          }
        );

        packages.default = self.packages.${system}.colorsync;

        apps.default = env.app [ ] "zig build run -- \"$@\"";
        apps.test = env.app [ ] "zig build test -- \"$@\"";
        apps.build = env.app [ ] "zig build \"$@\"";
      }
    );
}

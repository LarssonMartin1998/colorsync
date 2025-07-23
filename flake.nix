{
  description = "Colorsync flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        stdenv = pkgs.stdenv;

        name = "colorsync";
        version = "1.0.1";
      in
      {
        packages.colorsync = stdenv.mkDerivation {
          pname = name;
          version = version;
          src = ./.;

          nativeBuildInputs = with pkgs; [
            zig
          ];

          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
            zig build --verbose --color off --summary all
          '';

          doCheck = true;
          checkPhase = ''
            zig build test --summary all
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out
            cp -r zig-out/* $out/

            runHook postInstall
          '';
        };

        packages.hello = pkgs.hello;
        packages.default = self.packages.${system}.colorsync;
      }
    );
}

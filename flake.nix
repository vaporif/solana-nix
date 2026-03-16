{
  description = "Solana/Anchor tooling for Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat.url = "github:edolstra/flake-compat";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [inputs.flake-parts.flakeModules.easyOverlay];

      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: let
        rust-bin = inputs.rust-overlay.lib.mkRustBin {} pkgs.buildPackages;
        craneLib = inputs.crane.mkLib pkgs;

        solana-source = pkgs.callPackage ./solana-source.nix {};

        solana-platform-tools = pkgs.callPackage ./solana-platform-tools.nix {};

        solana-rust = pkgs.callPackage ./solana-rust.nix {
          inherit solana-platform-tools;
        };

        solana-cli = pkgs.callPackage ./solana-cli.nix {
          inherit rust-bin solana-source solana-platform-tools;
          crane = craneLib;
        };

        anchor-cli = pkgs.callPackage ./anchor-cli.nix {
          inherit rust-bin solana-platform-tools solana-rust;
          crane = craneLib;
        };
      in {
        overlayAttrs = {
          inherit solana-cli anchor-cli solana-rust solana-platform-tools;
        };

        packages = {
          inherit solana-cli anchor-cli solana-rust;
          default = solana-cli;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            anchor-cli
            solana-cli
            solana-rust
            pkgs.nodejs
            pkgs.yarn
          ];
        };
      };
    };
}

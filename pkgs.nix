# Helper for nix repl: `nix repl ./pkgs.nix`
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;
in
  flake.packages.${system}

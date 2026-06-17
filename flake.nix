{
  description = "ACPex flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        unstable-packages = final: _prev: {
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            unstable-packages
          ];
          config.allowUnfree = true;
        };

        isDarwin = builtins.match ".*-darwin" pkgs.stdenv.hostPlatform.system != null;

        claude-code-acp = pkgs.callPackage ./nix/claude-code-acp.nix { };

        # Pin Elixir 1.20 on OTP 28. The default `elixir` attr still tracks
        # 1.18, so select the explicit beam package for the toolchain.
        beam = pkgs.unstable.beam.packages.erlang_28;
        elixir = beam.elixir_1_20;
        erlang = pkgs.unstable.erlang_28;

        shell = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              elixir
              beam.elixir-ls
              erlang
              unstable.livebook
              rebar3
              nodePackages.prettier
              ast-grep

              # for e2e tests
              unstable.claude-code
              claude-code-acp
            ]
            ++ (
              if isDarwin then
                [
                ]
              else
                [ ]
            );
          shellHook = ''
            echo "ACPex dev environment"
          '';
        };

      in
      {
        devShells.default = shell;
      }
    );
}

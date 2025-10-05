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
        };

        isDarwin = builtins.match ".*-darwin" pkgs.stdenv.hostPlatform.system != null;

        shell = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              unstable.elixir
              unstable.elixir-ls
              unstable.erlang
              unstable.livebook
              rebar3
              nodejs_22
              rustc
              cargo
              openssl
              pkg-config
              nodePackages.prettier
              ast-grep
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

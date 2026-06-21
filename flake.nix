{
  description = "Nix flake packaging nesquena/hermes-webui — browser UI for Hermes Agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        hermes-webui = pkgs.callPackage ./package.nix { };
      in
      {
        packages = {
          inherit hermes-webui;
          default = hermes-webui;
        };

        apps.hermes-webui = {
          type = "app";
          program = "${hermes-webui}/bin/hermes-webui";
        };

        apps.default = self.apps.${system}.hermes-webui;
      })
    // {
      overlays.default = final: prev: {
        hermes-webui = final.callPackage ./package.nix { };
      };
      nixosModules.default = import ./module.nix;
      nixosModules.hermes-webui = import ./module.nix;
    };
}

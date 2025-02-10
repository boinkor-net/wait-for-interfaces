{
  description = "wait-for-interfaces - delay a systemd service's startup until an net interface is online";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.flake-parts.flakeModules.partitions
      ];
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        lib,
        system,
        ...
      }: let
        wfiPkg = p:
          p.buildGo123Module {
            pname = "wait-for-interfaces";
            version = "0.0.0";
            vendorHash = builtins.readFile ./wait-for-interfaces.sri;
            src = lib.sourceFilesBySuffices (lib.sources.cleanSource ./.) [".go" ".mod" ".sum"];
            meta.mainProgram = "wait-for-interfaces";
          };
      in {
        overlayAttrs = {
          inherit (config.packages) wait-for-interfaces;
        };
        packages.default = config.packages.wait-for-interfaces;
        packages.wait-for-interfaces = wfiPkg pkgs;
        formatter = pkgs.alejandra;
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module = ./dev/flake-part.nix;
      };
      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        apps = "dev";
      };

      flake = {
        nixosModules = {
          systemConfiguration = import ./nixos;
          withDefaultOverlay = {
            nixpkgs.overlays = [self.overlays.default];
          };
          default = {...}: {
            imports = [
              self.nixosModules.withDefaultOverlay
              self.nixosModules.systemConfiguration
            ];
          };
        };
      };
    };
}

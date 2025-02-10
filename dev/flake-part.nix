{
  self,
  inputs,
  ...
}: {
  imports = [
    inputs.devshell.flakeModule
    inputs.generate-go-sri.flakeModules.default
  ];
  systems = ["x86_64-linux" "aarch64-darwin"];

  perSystem = {
    config,
    pkgs,
    system,
    flocken,
    ...
  }: {
    go-sri-hashes.wait-for-interfaces = {};

    devshells.default = {
      commands = [
        {
          name = "regenSRI";
          category = "dev";
          help = "Regenerate wait-for-interfaces.sri in case the module SRI hash should change";
          command = "${config.apps.generate-sri-wait-for-interfaces.program}";
        }
      ];
      packages = [
        pkgs.go_1_23
        pkgs.gopls
        pkgs.golangci-lint
      ];
    };

    apps = {
      default = config.apps.wait-for-interfaces;
      wait-for-interfaces.program = config.packages.wait-for-interfaces;
    };
  };
}

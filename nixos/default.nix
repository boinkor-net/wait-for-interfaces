{
  pkgs,
  lib,
  config,
}: {
  options = with lib; let
    wfiSubmodule.options = {
      services = mkOption {
        description = "Services that depend on the listed interfaces";
        type = types.listOf (types.oneOf (builtins.attrNames config.systemd.services));
        default = [];
      };
      sockets = mkOption {
        description = "Sockets that depend on the listed interfaces";
        type = types.listOf (types.oneOf (builtins.attrNames config.systemd.sockets));
        default = [];
      };
    };
  in {
    networking.wait-for-interfaces = mkOption {
      description = "An attrset mapping an interface name to services and sockets that depend on the interface being online.";
      type = types.attrsOf (types.submodule wfiSubmodule);
      default = [];
      example = {
        tailscale0 = {
          services = ["prometheus-node-exporter"];
        };
      };
    };
  };

  config = let
    addServiceDependencies = interface: {services, ...}:
      lib.listToAttrs (map
        (service: {
          name = service;
          value = {
            serviceConfig = {
              ExecStartPre = [
                "+${lib.getExe pkgs.wait-for-interfaces} ${lib.escapeShellArg interface}"
              ];
            };
          };
        })
        services);
    addSocketDependencies = interface: {sockets, ...}:
      lib.listToAttrs (map
        (service: {
          name = service;
          value = {
            socketConfig = {
              ExecStartPre = [
                "+${lib.getExe pkgs.wait-for-interfaces} ${lib.escapeShellArg interface}"
              ];
            };
          };
        })
        sockets);
  in
    lib.mkMerge ((lib.mapAttrsToList addServiceDependencies config.networking.wait-for-interfaces)
      ++ (lib.mapAttrsToList addSocketDependencies config.networking.wait-for-interfaces));
}

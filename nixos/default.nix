{
  pkgs,
  lib,
  config,
  ...
}: {
  options = with lib; let
    wfiSubmodule.options = {
      services = mkOption {
        description = "Services that depend on the given interface";
        type = types.listOf types.str;
        default = [];
      };
      sockets = mkOption {
        description = "Sockets that depend on the given interface";
        type = types.listOf types.str;
        default = [];
      };
      requireIPs = mkOption {
        description = "IP addresses that must be set on the interface before services can start. If not set, any address will be accepted.";
        type = types.listOf types.str;
        default = [];
      };
    };
  in {
    networking.wait-for-interfaces = mkOption {
      description = "An attrset mapping an interface name to services and sockets that depend on the interface being online.";
      type = types.attrsOf (types.submodule wfiSubmodule);
      default = {};
      example = {
        tailscale0 = {
          services = ["prometheus-node-exporter"];
          sockets = ["homeauth"];
        };
      };
    };
  };

  config = let
    cmdline = interface: {requireIPs, ...}: (map (ip: "-ip=${ip}") requireIPs) ++ ["-interface=${interface}"];
    addServiceDependencies = interface: args @ {services, ...}:
      lib.listToAttrs (map
        (service: {
          name = service;
          value = {
            serviceConfig = {
              ExecStartPre = [
                "+${lib.getExe pkgs.wait-for-interfaces} ${lib.escapeShellArgs (cmdline interface args)}"
              ];
            };
          };
        })
        services);
    addSocketDependencies = interface: args @ {sockets, ...}:
      lib.listToAttrs (map
        (service: {
          name = service;
          value = {
            socketConfig = {
              ExecStartPre = [
                "+${lib.getExe pkgs.wait-for-interfaces} ${lib.escapeShellArgs (cmdline interface args)}"
              ];
            };
          };
        })
        sockets);
  in {
    systemd.services = lib.mkMerge (lib.mapAttrsToList addServiceDependencies config.networking.wait-for-interfaces);
    systemd.sockets = lib.mkMerge (lib.mapAttrsToList addSocketDependencies config.networking.wait-for-interfaces);
  };
}

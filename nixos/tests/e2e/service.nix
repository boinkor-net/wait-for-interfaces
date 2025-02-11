{
  pkgs,
  nixos-lib,
  nixosModule,
}: let
  stunPort = 3478;
in
  nixos-lib.runTest {
    name = "service-wait-for-interfaces-nixos";
    hostPkgs = pkgs;

    nodes.machine = {
      config,
      pkgs,
      lib,
      ...
    }: {
      imports = [
        nixosModule
      ];

      environment.systemPackages = [
      ];
      virtualisation.cores = 4;
      virtualisation.memorySize = 1024;

      services.prometheus.exporters.node = {
        enable = true;
        listenAddress = "127.0.0.50";
      };
      networking.wait-for-interfaces.lo = {
        services = ["prometheus-node-exporter"];
        requireIPs = ["127.0.0.50"];
      };
    };

    testScript = ''
      machine.start()
      machine.wait_until_succeeds("systemctl show - prometheus-node-exporter | grep 'ActiveState=activating'")
      machine.succeed("ip address add 127.0.0.50/32 dev lo")
      machine.wait_for_unit("prometheus-node-exporter")
    '';
  }

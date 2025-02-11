{
  pkgs,
  nixos-lib,
  nixosModule,
}: let
  stunPort = 3478;
in
  nixos-lib.runTest {
    name = "socket-wait-for-interfaces-nixos";
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

      systemd.sockets.testing = {
        wantedBy = ["multi-user.target"];
        requires = ["setup-testing-socket.service"];
        after = ["setup-testing-socket.service"];
        socketConfig = {
          ListenStream = "192.168.10.50:3000";
        };
      };
      systemd.services.setup-testing-socket = {
        # Ensure that the system can start up before we run tests - it
        # is sockets.target, and it looks like startup of all sockets is
        # required for machine.start() to finish.
        script = "${pkgs.iproute2}/bin/ip address add 192.168.10.50/32 dev lo";
        wantedBy = ["multi-user.target"];
        unitConfig.DefaultDependencies = false;
      };
      systemd.services.testing = {
        wantedBy = ["multi-user.target"];
        script = "echo hi";
      };
      networking.wait-for-interfaces.lo = {
        sockets = ["testing"];
        requireIPs = ["192.168.10.50"];
      };
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("testing.socket")
    '';
  }

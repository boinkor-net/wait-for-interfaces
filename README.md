# wait-for-interfaces - delay a systemd service's startup until a net interface is online

Say you have a machine on a tunnel/wireguard/tailscale tailnet, and you'd like some service on that machine to listen only on that network: So you put `listenAddr = 100.90.64.81:9010` in your fictional service's configuration, and that works! Except, if the tailscale interface isn't ready yet, your service will refuse to start because the IP address isn't available for listening on.

This tool can help there - by adding it to your service's `ExecStartPre` systemd unit configuration, startup for the actual service will be delayed until the network interface counts as "online", "running", and it has an IP address.

## Usage

### In plain systemd units

First, identify the interface that needs waiting on.

Then, identify the services that depend on that interface.

And then, add the following to their unit files (assuming you want to wait for `tailscale0` and `utun3`):

```systemd
ExecStartPre = +/path/to/wait-for-interfaces -interface tailscale0
```

Then, upon a restart of the unit you should see something like the following:

```console
Feb 09 14:00:44 gloria wait-for-interfaces[2019948]: wait-for-interfaces(tailscale0): Interface tailscale0 has address ip+net/100.70.151.16/32
Feb 09 14:00:44 gloria wait-for-interfaces[2019948]: wait-for-interfaces(tailscale0): Interface tailscale0 has address ip+net/fd7a:115c:a1e0::a501:9711/128
Feb 09 14:00:44 gloria wait-for-interfaces[2019948]: wait-for-interfaces(tailscale0): Interface tailscale0 has address ip+net/fe80::2d53:df2d:f9ff:7d04/64
Feb 09 14:00:44 gloria wait-for-interfaces[2019948]: wait-for-interfaces(tailscale0): interfaces tailscale0 is up.
```

### In nixos
You can use the nixos module defined in this flake like so:

```nix
{pkgs, config, inputs, ...}: {
  imports = [inputs.wait-for-interfaces.nixosModules.default];
  config = {
    networking.wait-for-interfaces.tailscale0 = {
      services = ["prometheus-node-exporter"];
      sockets = ["nginx"];
    };
  };
}
```

This will add the above ExecStartPre clause for the `tailscale0` interface to the prometheus-node-exporter service, and to the `nginx` socket units.


## Credits

The foundation for this repo was laid by @andrew-d, who made [systemd-backoff](https://github.com/andrew-d/systemd-backoff), on which the golang code in this repo is heavily based. Together with pre-condition checks in `ExecStartPre`, it would work well if nixos's `switch-to-configuration` didn't interpret a failed precondition in ExecStartPre as a unit startup failure (which it kinda is!) and failed the system upgrade!

# wait-for-interfaces - delay a systemd service's startup until an net interface is online

Say you have a machine on a tunnel/wireguard/tailscale tailnet, and you'd like some service on that machine to listen only on that network: So you put `listenAddr = 100.100.64.81:9010` in your fictional service's configuration, and that works! Except, if the tailscale interface isn't ready yet, your service will refuse to start because the IP address isn't available for listening on.

This tool can help there - by adding it to your service's `ExecStartPre` systemd unit configuration, startup for the actual service will be delayed until the network interface counts as "online", "running", and it has an IP address.

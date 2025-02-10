package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"github.com/jpillora/backoff"
)

var (
	debug  = flag.Bool("debug", false, "print debug messages")
	min    = flag.Duration("min", 100*time.Millisecond, "minimum backoff duration")
	max    = flag.Duration("max", 30*time.Second, "maximum backoff duration")
	factor = flag.Float64("factor", 1.5, "multiplication factor for each attempt")
	jitter = flag.Bool("jitter", false, "randomize backoff steps")
)

func main() {
	log.SetOutput(os.Stderr)
	log.SetPrefix("check-interface-ready: ")
	log.SetFlags(0)
	flag.Parse()

	b := backoff.Backoff{
		Factor: *factor,
		Jitter: *jitter,
		Min:    *min,
		Max:    *max,
	}

	namesToCheck := flag.Args()
outer:
	for {
		interfaces, err := net.Interfaces()
		if err != nil {
			log.Printf("Could not retrieve interfaces: %v", err)
			time.Sleep(b.Duration())
			continue outer
		}
		for _, ifName := range namesToCheck {
			if err := ensureInterface(ifName, interfaces); err != nil {
				log.Printf("Interface %v is not yet up: %v", ifName, err)
				time.Sleep(b.Duration())
				continue outer
			}
		}
		log.Printf("All interfaces out of %v are up!", namesToCheck)
		return
	}
}

func ensureInterface(name string, interfaces []net.Interface) error {
	for _, iface := range interfaces {
		if iface.Name != name {
			continue
		}
		if iface.Flags&(net.FlagUp|net.FlagRunning) == 0 {
			return fmt.Errorf("interface %v is not yet up & running - flags %x", name, iface.Flags)
		}
		addrs, err := iface.Addrs()
		if err != nil {
			return fmt.Errorf("could not retrieve addresses for interface %v: %w", name, err)
		}
		var hasAddr bool
		for _, addr := range addrs {
			log.Printf("Interface %v has address %v/%v", name, addr.Network(), addr.String())
			hasAddr = true
		}
		if !hasAddr {
			return fmt.Errorf("interface %v doesn't have an address yet", name)
		}
		return nil
	}
	return fmt.Errorf("no interface named %v found", name)
}

package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/netip"
	"os"
	"strings"
	"time"

	"github.com/jpillora/backoff"
)

var (
	minDelay = flag.Duration("min", 100*time.Millisecond, "minimum backoff duration")
	maxDelay = flag.Duration("max", 30*time.Second, "maximum backoff duration")
	factor   = flag.Float64("factor", 1.5, "multiplication factor for each attempt")
	jitter   = flag.Bool("jitter", false, "randomize backoff steps")
)

var (
	ips map[netip.Addr]bool
)

func addIP(ipStr string) error {
	ip, err := netip.ParseAddr(ipStr)
	if err != nil {
		return fmt.Errorf("invalid address %v: %w", ipStr, err)
	}
	if ips == nil {
		ips = map[netip.Addr]bool{}
	}
	ips[ip] = true
	return nil
}

func main() {
	log.SetOutput(os.Stderr)
	log.SetPrefix("check-interface-ready: ")
	log.SetFlags(0)

	flag.Func("ip", "IP addresses required for the interfaces to have.\nCan be passed multiple times.\nIf not passed, any address will be accepted.", addIP)
	flag.Parse()

	b := backoff.Backoff{
		Factor: *factor,
		Jitter: *jitter,
		Min:    *minDelay,
		Max:    *maxDelay,
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

var (
	errNotUp  = errors.New("interface is not yet in states UP & RUNNING")
	errNoAddr = errors.New("interface has no wanted address yet")
	errNoIf   = errors.New("Interface doesn't exist (yet)")
)

func ensureInterface(name string, interfaces []net.Interface) error {
	for _, iface := range interfaces {
		if iface.Name != name {
			continue
		}
		if iface.Flags&(net.FlagUp|net.FlagRunning) == 0 {
			return fmt.Errorf("%v with flags %x: %w", name, iface.Flags, errNotUp)
		}
		addrs, err := iface.Addrs()
		if err != nil {
			return fmt.Errorf("could not retrieve addresses for interface %v: %w", name, err)
		}
		var hasAddr bool
		for _, addr := range addrs {
			if ips != nil {
				ip := netip.MustParseAddr(strings.Split(addr.String(), "/")[0])
				if !ips[ip] {
					log.Printf("Interface %v has address %v but that's unwanted", name, addr.String())
					continue
				}
			}
			log.Printf("Interface %v has address %v", name, addr.String())
			hasAddr = true
		}
		if !hasAddr {
			return fmt.Errorf("%v: %w", name, errNoAddr)
		}
		return nil
	}
	return fmt.Errorf("%v: %w", name, errNoIf)
}

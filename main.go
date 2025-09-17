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
	minDelay *time.Duration
	maxDelay *time.Duration
	factor   *float64
	jitter   *bool
	ips      map[netip.Addr]bool
	ifName   *string
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
	minDelay = flag.Duration("min", 100*time.Millisecond, "minimum backoff duration")
	maxDelay = flag.Duration("max", 30*time.Second, "maximum backoff duration")
	factor = flag.Float64("factor", 1.5, "multiplication factor for each attempt")
	jitter = flag.Bool("jitter", false, "randomize backoff steps")
	flag.Func("ip", "IP addresses required for the interfaces to have.\nCan be passed multiple times.\nIf not passed, any address will be accepted.", addIP)
	ifName = flag.String("interface", "", "interface to wait for. Required.")
	flag.Parse()

	log.SetOutput(os.Stderr)
	log.SetPrefix("wait-for-interfaces: ")
	log.SetFlags(0)

	if ifName == nil || *ifName == "" {
		log.Fatal("-interface needs to be passed")
	}
	log.SetPrefix(fmt.Sprintf("wait-for-interfaces(%v): ", *ifName))

	b := backoff.Backoff{
		Factor: *factor,
		Jitter: *jitter,
		Min:    *minDelay,
		Max:    *maxDelay,
	}

outer:
	for {
		interfaces, err := net.Interfaces()
		if err != nil {
			log.Printf("Could not retrieve interfaces: %v", err)
			time.Sleep(b.Duration())
			continue outer
		}
		if err := ensureInterface(*ifName, interfaces); err != nil {
			log.Printf("Interface %s is not yet up: %v", *ifName, err)
			time.Sleep(b.Duration())
			continue outer
		}
		log.Printf("Interface %s is up.", *ifName)
		return
	}
}

var (
	errNotUp  = errors.New("interface is not yet in states UP & RUNNING")
	errNoAddr = errors.New("interface has no wanted address yet")
	errNoIf   = errors.New("interface doesn't exist (yet)")
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
		hasAddr := 0
		needAddr := len(ips)
		for _, addr := range addrs {
			if ips != nil {
				ip := netip.MustParseAddr(strings.Split(addr.String(), "/")[0])
				if !ips[ip] {
					log.Printf("Interface %v has address %v but we're not looking for that", name, addr.String())
					continue
				}
			}
			log.Printf("Interface %v has address %v", name, addr.String())
			hasAddr++
		}
		if hasAddr == 0 || hasAddr < needAddr {
			return fmt.Errorf("%v: %w", name, errNoAddr)
		}
		return nil
	}
	return fmt.Errorf("%v: %w", name, errNoIf)
}

//go:build darwin

package main

import (
	"os"
	"testing"
)

func TestLiveDiscoveryReadOnly(t *testing.T) {
	if os.Getenv("CW_TEST_DISCOVERY") != "1" {
		t.Skip("read-only local probe opt-in")
	}
	devices, e := discover()
	if e != nil {
		t.Fatal(e)
	}
	t.Logf("devices: %+v", devices)
}

//go:build windows

package main

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"golang.org/x/sys/windows"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestWindowsWriterDisposableVHD(t *testing.T) {
	if os.Getenv("CI") != "true" {
		t.Skip("disposable CI VHD only")
	}
	if !windows.GetCurrentProcessToken().IsElevated() {
		t.Fatal("CI fixture requires elevated runner")
	}
	root := t.TempDir()
	vhd := filepath.Join(root, "fixture.vhd")
	script := filepath.Join(root, "diskpart.txt")
	text := fmt.Sprintf("create vdisk file=\"%s\" maximum=128 type=expandable\nselect vdisk file=\"%s\"\nattach vdisk\ncreate partition primary\nformat fs=ntfs quick\n", vhd, vhd)
	if e := os.WriteFile(script, []byte(text), 0600); e != nil {
		t.Fatal(e)
	}
	b, e := exec.Command("diskpart", "/s", script).CombinedOutput()
	if e != nil {
		t.Fatalf("%v: %s", e, b)
	}
	literal := strings.ReplaceAll(vhd, "'", "''")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	defer func() {
		_, e := powershell(ctx, "Dismount-DiskImage -ImagePath '"+literal+"' | Out-Null")
		if e != nil {
			t.Error(e)
		}
	}()
	query := "Get-DiskImage -ImagePath '" + literal + "' | Get-Disk | Select-Object Number,Size,IsBoot,IsSystem,FriendlyName | ConvertTo-Json -Compress"
	inspect := func() (Device, error) {
		b, e := powershell(ctx, query)
		if e != nil {
			return Device{}, e
		}
		var disk struct {
			Number       int
			Size         int64
			IsBoot       bool
			IsSystem     bool
			FriendlyName string
		}
		if e = json.Unmarshal(bytesTrimBOM(b), &disk); e != nil {
			return Device{}, e
		}
		if disk.IsBoot || disk.IsSystem || disk.Size != 128*mib || !strings.Contains(strings.ToLower(disk.FriendlyName), "virtual") {
			return Device{}, fmt.Errorf("unsafe fixture: %+v", disk)
		}
		return Device{ID: fmt.Sprint(disk.Number), Size: disk.Size, Model: disk.FriendlyName, Sector: 512, Serial: vhd}, nil
	}
	selected, e := inspect()
	if e != nil {
		t.Fatal(e)
	}
	old := discoverDevices
	discoverDevices = func() ([]Device, error) { d, e := inspect(); return []Device{d}, e }
	defer func() { discoverDevices = old }()
	source := filepath.Join(root, "image.raw")
	data := make([]byte, mib)
	rand.Read(data)
	os.WriteFile(source, data, 0600)
	img := Image{Path: source, Size: int64(len(data)), SHA256: shaBytes(data)}
	if e = writeWindows(newApp(), selected, img); e != nil {
		t.Fatal(e)
	}
	t.Log("PASS native Windows locks, raw write, flush and SHA256 readback on a new VHD")
}

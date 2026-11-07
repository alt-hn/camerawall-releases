package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"github.com/diskfs/go-diskfs/backend/file"
	"github.com/diskfs/go-diskfs/filesystem/fat32"
	"hash/crc32"
	"io"
	"os"
	"strings"
	"testing"
)

type shortWriter struct{ bytes.Buffer }

func (w *shortWriter) Write(b []byte) (int, error) { return w.Buffer.Write(b[:len(b)/2]) }
func TestShortWritesAndTruncation(t *testing.T) {
	if e := copyProgress(context.Background(), &shortWriter{}, bytes.NewReader([]byte("abcdef")), 6, nil); !errors.Is(e, io.ErrShortWrite) {
		t.Fatal(e)
	}
	if e := copyProgress(context.Background(), io.Discard, bytes.NewReader([]byte("abc")), 6, nil); e == nil {
		t.Fatal("accepted truncated input")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if e := copyProgress(ctx, io.Discard, bytes.NewReader([]byte("abc")), 3, nil); !errors.Is(e, context.Canceled) {
		t.Fatal(e)
	}
}
func TestGPTProtectsExistingPartitionAndCRC(t *testing.T) {
	f, e := os.CreateTemp(t.TempDir(), "image")
	if e != nil {
		t.Fatal(e)
	}
	defer f.Close()
	f.Truncate(4 * mib)
	h := make([]byte, 512)
	le := binary.LittleEndian
	copy(h, "EFI PART")
	le.PutUint32(h[12:], 92)
	le.PutUint64(h[24:], 1)
	le.PutUint64(h[72:], 2)
	le.PutUint32(h[80:], 4)
	le.PutUint32(h[84:], 128)
	f.WriteAt(h, 512)
	f.WriteAt([]byte("EFI sentinel"), 32768)
	if e = appendGPT(f, 2048, 2048, 4*mib); e != nil {
		t.Fatal(e)
	}
	for _, offset := range []int64{512, 4*mib - 512} {
		f.ReadAt(h, offset)
		want := le.Uint32(h[16:])
		le.PutUint32(h[16:], 0)
		if crc32.ChecksumIEEE(h[:92]) != want {
			t.Fatal("header CRC")
		}
		entries := make([]byte, 512)
		f.ReadAt(entries, int64(le.Uint64(h[72:]))*512)
		if crc32.ChecksumIEEE(entries) != le.Uint32(h[88:]) {
			t.Fatal("entries CRC")
		}
	}
	b := make([]byte, 12)
	f.ReadAt(b, 32768)
	if string(b) != "EFI sentinel" {
		t.Fatal("modified EFI")
	}
	if e = appendGPT(f, 2048, 2048, 4*mib); e == nil {
		t.Fatal("overwrote occupied partition")
	}
}
func TestRuntimePayloadAndPackageClosure(t *testing.T) {
	s, e := loadSpec()
	if e != nil {
		t.Fatal(e)
	}
	needed := map[string]bool{"python3-venv": false, "python3.11-venv": false, "python3-pip-whl": false, "python3-setuptools-whl": false, "ffmpeg": false, "network-manager": false, "weston": false, "qt6-wayland": false, "gstreamer1.0-plugins-bad": false}
	for _, p := range s.Packages {
		for name := range needed {
			if len(p.Name) > len(name) && p.Name[:len(name)+1] == name+"_" {
				needed[name] = true
			}
		}
	}
	for k, v := range needed {
		if !v {
			t.Fatal("missing", k)
		}
	}
	files, e := runtimeFiles()
	if e != nil {
		t.Fatal(e)
	}
	if !bytes.Contains(files["preseed.cfg"], []byte("netcfg/enable boolean false")) {
		t.Fatal("offline preseed changed")
	}
	if len(initramfs(files)) == 0 {
		t.Fatal("empty initramfs")
	}
}
func TestComposedFATReadback(t *testing.T) {
	image := os.Getenv("CW_TEST_PREPARED_IMAGE")
	if image == "" {
		t.Skip("optional local composition artifact")
	}
	f, e := os.Open(image)
	if e != nil {
		t.Fatal(e)
	}
	defer f.Close()
	h := make([]byte, 512)
	f.ReadAt(h, 512)
	le := binary.LittleEndian
	entries := make([]byte, 384)
	f.ReadAt(entries, int64(le.Uint64(h[72:]))*512)
	start := int64(le.Uint64(entries[288:]))
	last := int64(le.Uint64(entries[296:]))
	fs, e := fat32.Read(file.New(f, true), (last-start+1)*512, start*512, 512)
	if e != nil {
		t.Fatal(e)
	}
	for _, name := range []string{"SHA256SUMS", "repo/Packages", "cw-initrd.gz", "app.tar.gz", "display.tar.gz"} {
		r, e := fs.OpenFile(name, os.O_RDONLY)
		if e != nil {
			t.Fatal(name, e)
		}
		var buf [8]byte
		if _, e = io.ReadFull(r, buf[:]); e != nil {
			t.Fatal(name, e)
		}
		r.Close()
	}
	manifest, e := fs.OpenFile("SHA256SUMS", os.O_RDONLY)
	if e != nil {
		t.Fatal(e)
	}
	defer manifest.Close()
	scan := bufio.NewScanner(manifest)
	required := map[string]bool{"cw-initrd.gz": false, "app.tar.gz": false, "display.tar.gz": false}
	for scan.Scan() {
		want, name, ok := strings.Cut(scan.Text(), "  ")
		if !ok {
			t.Fatal("invalid checksum line", scan.Text())
		}
		r, e := fs.OpenFile(name, os.O_RDONLY)
		if e != nil {
			t.Fatal(name, e)
		}
		h := sha256.New()
		_, e = io.Copy(h, r)
		r.Close()
		if e != nil || fmt.Sprintf("%x", h.Sum(nil)) != want {
			t.Fatal(name, "payload digest mismatch", e)
		}
		if _, ok := required[name]; ok {
			required[name] = true
		}
	}
	if e = scan.Err(); e != nil {
		t.Fatal(e)
	}
	for name, found := range required {
		if !found {
			t.Fatal("missing checksum:", name)
		}
	}
}

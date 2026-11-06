package main

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type roundTrip func(*http.Request) (*http.Response, error)

func (f roundTrip) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func TestDownloadResumesOnlyMatchingRange(t *testing.T) {
	a := newApp()
	p := Asset{Name: "part", Size: 6, SHA256: shaBytes([]byte("abcdef")), URL: "https://example.invalid/file"}
	target := filepath.Join(t.TempDir(), "partial")
	os.WriteFile(target, []byte("abc"), 0600)
	client := &http.Client{Transport: roundTrip(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Range") != "bytes=3-" {
			t.Fatal("missing resume")
		}
		return &http.Response{StatusCode: 206, Header: http.Header{"Content-Range": []string{"bytes 3-5/6"}}, Body: io.NopCloser(strings.NewReader("def"))}, nil
	})}
	if e := a.downloadAttempt(context.Background(), client, p, target); e != nil {
		t.Fatal(e)
	}
	b, _ := os.ReadFile(target)
	if string(b) != "abcdef" {
		t.Fatal(string(b))
	}
	os.WriteFile(target, []byte("abc"), 0600)
	client.Transport = roundTrip(func(r *http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: 206, Header: http.Header{"Content-Range": []string{"bytes 0-2/6"}}, Body: io.NopCloser(strings.NewReader("xxx"))}, nil
	})
	if e := a.downloadAttempt(context.Background(), client, p, target); e == nil {
		t.Fatal("accepted wrong range")
	}
	b, _ = os.ReadFile(target)
	if string(b) != "abc" {
		t.Fatal("modified partial on wrong range")
	}
}
func TestDeviceReplacementRejectedBeforeWrite(t *testing.T) {
	old := discoverDevices
	defer func() { discoverDevices = old }()
	selected := Device{ID: "disk5", Size: 32 * 1024 * mib, Serial: "original"}
	replacement := selected
	replacement.Serial = "replacement"
	discoverDevices = func() ([]Device, error) { return []Device{replacement}, nil }
	if e := revalidate(selected); e == nil {
		t.Fatal("accepted a replacement device")
	}
}

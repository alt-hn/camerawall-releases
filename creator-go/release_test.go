package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestResolveLatestReleaseRequiresMatchingDisplay(t *testing.T) {
	tag := "v0.1.0-alpha.42"
	displayTag := tag
	publishedAt := "2026-11-23T19:00:00+07:00"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Cache-Control") != "no-cache" {
			t.Error("latest metadata must be revalidated")
		}
		asset := func(name, digest string) map[string]any {
			return map[string]any{"name": name, "size": 123, "digest": "sha256:" + strings.Repeat(digest, 64)}
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"tag_name": tag, "published_at": publishedAt, "assets": []any{
			asset("camerawall_"+tag+"_linux_amd64.tar.gz", "a"),
			asset("camerawall-display_"+displayTag+"_linux_amd64_debian12.tar.gz", "b"),
		}})
	}))
	defer server.Close()
	var s Spec
	if err := s.resolveRelease(context.Background(), server.URL); err != nil {
		t.Fatal(err)
	}
	if s.AppVersion != tag || s.Application.SHA256 != strings.Repeat("a", 64) || s.Display.SHA256 != strings.Repeat("b", 64) || !strings.Contains(string(s.releaseEnv()), "CAMERAWALL_RELEASE_EPOCH=1795435200\n") {
		t.Fatalf("unexpected release metadata: %s", s.releaseEnv())
	}
	tag = "v0.1.0-alpha.43"
	if err := s.resolveRelease(context.Background(), server.URL); err == nil {
		t.Fatal("accepted previous release's renderer for the new backend")
	}
	displayTag = tag
	for _, publishedAt = range []string{"", "invalid", "0001-01-01T00:00:00Z"} {
		if err := s.resolveRelease(context.Background(), server.URL); err == nil {
			t.Fatalf("accepted invalid release publication time %q", publishedAt)
		}
	}
}

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
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Cache-Control") != "no-cache" {
			t.Error("latest metadata must be revalidated")
		}
		asset := func(name, digest string) map[string]any {
			return map[string]any{"name": name, "size": 123, "digest": "sha256:" + strings.Repeat(digest, 64)}
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"tag_name": tag, "assets": []any{
			asset("camerawall_"+tag+"_linux_amd64.tar.gz", "a"),
			asset("camerawall-display_"+displayTag+"_linux_amd64_debian12.tar.gz", "b"),
		}})
	}))
	defer server.Close()
	version, app, display, err := resolveRelease(context.Background(), server.URL)
	if err != nil || version != tag || app.SHA256 != strings.Repeat("a", 64) || display.SHA256 != strings.Repeat("b", 64) {
		t.Fatalf("unexpected resolved release: %s %v %v %v", version, app, display, err)
	}
	tag = "v0.1.0-alpha.43"
	if _, _, _, err = resolveRelease(context.Background(), server.URL); err == nil {
		t.Fatal("accepted previous release's renderer for the new backend")
	}
}

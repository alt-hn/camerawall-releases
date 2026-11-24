package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

const releaseRepo = "alt-hn/camerawall-releases"
const latestReleaseURL = "https://api.github.com/repos/" + releaseRepo + "/releases/latest"

var releaseTag = regexp.MustCompile(`^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$`)
var releaseDigest = regexp.MustCompile(`^sha256:[0-9a-f]{64}$`)

func (s *Spec) resolveRelease(ctx context.Context, endpoint string) error {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GitHub releases/latest: HTTP %d", resp.StatusCode)
	}
	var release struct {
		Tag         string    `json:"tag_name"`
		PublishedAt time.Time `json:"published_at"`
		Draft       bool      `json:"draft"`
		Prerelease  bool      `json:"prerelease"`
		Assets      []struct {
			Name   string `json:"name"`
			Size   int64  `json:"size"`
			Digest string `json:"digest"`
		} `json:"assets"`
	}
	if err = json.NewDecoder(io.LimitReader(resp.Body, 2<<20)).Decode(&release); err != nil {
		return err
	}
	if release.Draft || release.Prerelease || !releaseTag.MatchString(release.Tag) {
		return fmt.Errorf("invalid public CameraWall release: %q", release.Tag)
	}
	if release.PublishedAt.Unix() <= 0 {
		return fmt.Errorf("missing or invalid publication time for %s", release.Tag)
	}
	get := func(name string) (Asset, error) {
		for _, a := range release.Assets {
			if a.Name == name && a.Size > 0 && releaseDigest.MatchString(a.Digest) {
				return Asset{Name: name, Size: a.Size, SHA256: strings.TrimPrefix(a.Digest, "sha256:"),
					URL: "https://github.com/" + releaseRepo + "/releases/download/" + release.Tag + "/" + name}, nil
			}
		}
		return Asset{}, fmt.Errorf("missing verified release asset: %s", name)
	}
	app, err := get("camerawall_" + release.Tag + "_linux_amd64.tar.gz")
	if err != nil {
		return err
	}
	display, err := get("camerawall-display_" + release.Tag + "_linux_amd64_debian12.tar.gz")
	if err != nil {
		return err
	}
	s.AppVersion, s.PublishedAt = release.Tag, release.PublishedAt
	s.Application, s.Display = app, display
	return nil
}

func (s Spec) releaseEnv() []byte {
	return []byte(fmt.Sprintf("CAMERAWALL_VERSION=%s\nCAMERAWALL_RELEASE_EPOCH=%d\nCAMERAWALL_SHA256=%s\nCAMERAWALL_DISPLAY_SHA256=%s\n",
		s.AppVersion, s.PublishedAt.Unix(), s.Application.SHA256, s.Display.SHA256))
}

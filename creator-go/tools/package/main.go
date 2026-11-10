package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func must(e error) {
	if e != nil {
		panic(e)
	}
}
func main() {
	label := "windows-x64"
	if runtime.GOOS == "darwin" {
		label = "macos-intel"
		if runtime.GOARCH == "arm64" {
			label = "macos-arm64"
		}
	}
	out := filepath.Join("..", "dist", "creator-v2.0.14")
	must(os.MkdirAll(out, 0755))
	name := "CameraWall-USB-Creator-2.0.14-" + label
	var target string
	if runtime.GOOS == "windows" {
		target = filepath.Join(out, name+".exe")
		src, e := os.Open("build/bin/CameraWall USB Creator.exe")
		must(e)
		defer src.Close()
		dst, e := os.Create(target)
		must(e)
		_, e = io.Copy(dst, src)
		must(e)
		must(dst.Close())
	} else {
		target = filepath.Join(out, name+".zip")
		cmd := exec.Command("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", "build/bin/CameraWall USB Creator.app", target)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		must(cmd.Run())
	}
	b, e := os.ReadFile(target)
	must(e)
	digest := sha256.Sum256(b)
	source, e := exec.Command("git", "rev-parse", "HEAD").Output()
	must(e)
	sources, e := os.ReadFile("assets/offline/sources.json")
	must(e)
	packages, e := os.ReadFile("assets/offline/debian-packages.json")
	must(e)
	sd := sha256.Sum256(sources)
	pd := sha256.Sum256(packages)
	info := map[string]interface{}{"file": filepath.Base(target), "size": len(b), "sha256": hex.EncodeToString(digest[:]), "source": strings.TrimSpace(string(source)), "os": runtime.GOOS, "arch": runtime.GOARCH, "go": runtime.Version(), "version": "2.0.14", "application": "latest public release at USB preparation", "mode": "offline", "publisher_signed": false, "sources_sha256": hex.EncodeToString(sd[:]), "debian_packages_sha256": hex.EncodeToString(pd[:])}
	raw, e := json.MarshalIndent(info, "", "  ")
	must(e)
	must(os.WriteFile(filepath.Join(out, name+".json"), append(raw, '\n'), 0644))
	fmt.Println(string(raw))
}

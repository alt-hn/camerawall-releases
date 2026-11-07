package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	b, e := exec.Command("go", "list", "-m", "-json", "all").Output()
	if e != nil {
		panic(e)
	}
	d := json.NewDecoder(bytes.NewReader(b))
	var out strings.Builder
	out.WriteString("CameraWall USB Creator 2.0.4 — third-party Go modules\n\nBuilt with Go and Wails. macOS WebKit / Windows WebView2 are system components.\nNo Python, PyInstaller, pycdlib or pyfatfs runtime is bundled in this Creator.\nOffline Linux installation payloads retain their own upstream licenses.\n\n")
	for {
		var m struct {
			Path, Version, Dir string
			Main               bool
		}
		e = d.Decode(&m)
		if e == io.EOF {
			break
		}
		if e != nil {
			panic(e)
		}
		if m.Main {
			continue
		}
		fmt.Fprintf(&out, "\n========== %s %s ==========\n", m.Path, m.Version)
		found := false
		for _, name := range []string{"LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING", "COPYING.txt", "License"} {
			text, e := os.ReadFile(filepath.Join(m.Dir, name))
			if e == nil {
				out.Write(text)
				out.WriteByte('\n')
				found = true
			}
		}
		if !found {
			fmt.Fprintf(&out, "Source and license: https://pkg.go.dev/%s@%s\n", m.Path, m.Version)
		}
	}
	if e = os.WriteFile("THIRD-PARTY-NOTICES.txt", []byte(out.String()), 0644); e != nil {
		panic(e)
	}
}

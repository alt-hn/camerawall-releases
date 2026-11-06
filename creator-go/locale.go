package main

import (
	"context"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

// SystemLanguage reads the user's OS preference without changing process locale.
// The frontend persists an explicit override independently of this default.
func (a *App) SystemLanguage() string {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.CommandContext(ctx, "/usr/bin/defaults", "read", "-g", "AppleLanguages")
	case "windows":
		cmd = exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", "[System.Globalization.CultureInfo]::CurrentUICulture.Name")
	default:
		return os.Getenv("LANG")
	}
	output, err := cmd.Output()
	if err != nil {
		return "en"
	}
	value := strings.TrimSpace(string(output))
	if runtime.GOOS == "darwin" {
		// defaults emits a plist array; its first item is the primary language.
		value = strings.TrimSpace(strings.TrimPrefix(value, "("))
		value = strings.Trim(strings.SplitN(value, ",", 2)[0], "\" \t\r\n)")
	}
	return value
}

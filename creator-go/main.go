package main

import (
	"context"
	"embed"
	"fmt"
	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"io/fs"
	"os"
)

//go:embed frontend/* assets/* THIRD-PARTY-NOTICES.txt LICENSE
var bundled embed.FS

const version = "2.0.1"
const applicationVersion = "v0.1.0-alpha.40"

func main() {
	if len(os.Args) > 1 {
		if os.Args[1] == "--self-test" {
			if _, err := loadSpec(); err != nil {
				panic(err)
			}
			fmt.Println("CameraWall Creator", version, "compiled runtime OK")
			return
		}
		if os.Args[1] == "--write-job" {
			if err := helperMain(os.Args[2:]); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return
		}
		if os.Args[1] == "--prepare-only" {
			if err := prepareOnly(); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return
		}
	}
	assets, _ := fs.Sub(bundled, "frontend")
	app := newApp()
	err := wails.Run(&options.App{Title: "CameraWall USB Creator", Width: 880, Height: 650, MinWidth: 800, MinHeight: 600, AssetServer: &assetserver.Options{Assets: assets}, BackgroundColour: &options.RGBA{R: 245, G: 247, B: 250, A: 1}, OnStartup: app.startup, OnBeforeClose: func(ctx context.Context) bool { return app.isBusy() }, Bind: []interface{}{app}})
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

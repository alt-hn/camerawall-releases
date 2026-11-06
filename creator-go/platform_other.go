//go:build !darwin && !windows

package main

import (
	"context"
	"errors"
)

func discover() ([]Device, error) { return nil, errors.New("Chỉ hỗ trợ macOS và Windows") }
func platformRun(context.Context, *App, Device) error {
	return errors.New("Chỉ hỗ trợ macOS và Windows")
}
func helperMain([]string) error { return errors.New("unsupported platform") }

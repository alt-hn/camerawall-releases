package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	wruntime "github.com/wailsapp/wails/v2/pkg/runtime"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"time"
)

type Device struct {
	ID     string `json:"id"`
	Model  string `json:"model"`
	Size   int64  `json:"size"`
	Serial string `json:"serial"`
	Sector int64  `json:"sector"`
}
type Asset struct {
	URL    string `json:"url"`
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}
type Spec struct {
	Debian      Asset   `json:"debian"`
	Application Asset   `json:"-"`
	Display     Asset   `json:"-"`
	AppVersion  string  `json:"-"`
	Analytics   []Asset `json:"analytics"`
	Packages    []Asset `json:"-"`
}
type FileProgress struct {
	Name     string `json:"name"`
	Category string `json:"category"`
	Size     int64  `json:"size"`
	Done     int64  `json:"done"`
	Status   string `json:"status"`
	Detail   string `json:"detail"`
}
type Stage struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Status string `json:"status"`
	Done   int64  `json:"done"`
	Total  int64  `json:"total"`
	Unit   string `json:"unit"`
	Detail string `json:"detail"`
}
type State struct {
	Version     string         `json:"version"`
	AppVersion  string         `json:"appVersion"`
	Busy        bool           `json:"busy"`
	Cancellable bool           `json:"cancellable"`
	Phase       string         `json:"phase"`
	Status      string         `json:"status"`
	Error       string         `json:"error"`
	Rate        float64        `json:"rate"`
	Elapsed     int64          `json:"elapsed"`
	Cache       string         `json:"cache"`
	Stages      []Stage        `json:"stages"`
	Files       []FileProgress `json:"files"`
	Logs        []string       `json:"logs"`
}
type App struct {
	mu              sync.Mutex
	ctx             context.Context
	cancel          context.CancelFunc
	state           State
	started         time.Time
	lastAt          time.Time
	transferred     int64
	lastTransferred int64
	fileIndex       map[string]int
	lastEvent       time.Time
}

func newApp() *App {
	cache, _ := os.UserCacheDir()
	if runtime.GOOS == "darwin" {
		home, _ := os.UserHomeDir()
		cache = filepath.Join(home, "Library", "Caches")
	}
	a := &App{}
	a.state.Cache = filepath.Join(cache, "CameraWall USB Creator")
	a.reset()
	return a
}
func (a *App) reset() {
	cache := a.state.Cache
	a.state = State{Version: version, AppVersion: "—", Cache: cache, Phase: "idle", Status: "Chọn USB để bắt đầu", Files: []FileProgress{}, Logs: []string{}, Stages: []Stage{{ID: "permission", Title: "Cấp quyền USB", Status: "pending"}, {ID: "download", Title: "Tải thành phần", Status: "pending"}, {ID: "checksum", Title: "Kiểm tra checksum", Status: "pending"}, {ID: "compose", Title: "Tạo bộ cài bootable", Status: "pending"}, {ID: "write", Title: "Ghi USB", Status: "pending"}, {ID: "readback", Title: "Đọc lại kiểm tra", Status: "pending"}, {ID: "finish", Title: "Hoàn tất", Status: "pending"}}}
	if runtime.GOOS == "windows" {
		stages := a.state.Stages
		a.state.Stages = append(append(append([]Stage{}, stages[1:4]...), stages[0]), stages[4:]...)
	}
	a.fileIndex = map[string]int{}
	a.transferred = 0
	a.lastTransferred = 0
	a.lastAt = time.Now()
	a.started = time.Now()
}
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
	go func() {
		ticker := time.NewTicker(250 * time.Millisecond)
		defer ticker.Stop()
		lastPayload := ""
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				a.mu.Lock()
				if a.state.Busy {
					now := time.Now()
					seconds := now.Sub(a.lastAt).Seconds()
					a.state.Rate = float64(a.transferred-a.lastTransferred) / seconds
					a.lastAt = now
					a.lastTransferred = a.transferred
					a.state.Elapsed = int64(now.Sub(a.started).Seconds())
				}
				a.mu.Unlock()
				snapshot := a.GetState()
				payload, _ := json.Marshal(snapshot)
				if string(payload) != lastPayload {
					lastPayload = string(payload)
					wruntime.EventsEmit(ctx, "progress", snapshot)
				}
			}
		}
	}()
}
func (a *App) GetState() State {
	a.mu.Lock()
	defer a.mu.Unlock()
	s := a.state
	s.Stages = append([]Stage{}, s.Stages...)
	s.Files = append([]FileProgress{}, s.Files...)
	s.Logs = append([]string{}, s.Logs...)
	return s
}
func (a *App) isBusy() bool { a.mu.Lock(); defer a.mu.Unlock(); return a.state.Busy }
func (a *App) Discover() ([]Device, error) {
	if a.isBusy() {
		return nil, errors.New("Đang xử lý USB")
	}
	return discover()
}
func (a *App) logLocked(message string) {
	a.state.Logs = append(a.state.Logs, time.Now().Format("15:04:05")+"  "+message)
	if len(a.state.Logs) > 100 {
		a.state.Logs = a.state.Logs[len(a.state.Logs)-100:]
	}
}
func (a *App) phase(id, detail string, total int64, unit string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	for i := range a.state.Stages {
		s := &a.state.Stages[i]
		if s.Status == "active" && s.ID != id {
			s.Status = "done"
			s.Done = s.Total
		}
		if s.ID == id {
			s.Status = "active"
			s.Detail = detail
			s.Total = total
			s.Done = 0
			s.Unit = unit
		}
	}
	a.state.Phase = id
	a.state.Status = detail
	a.state.Rate = 0
	a.lastAt = time.Now()
	a.lastTransferred = a.transferred
	a.logLocked(detail)
}
func (a *App) progress(done, total int64, detail string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	for i := range a.state.Stages {
		s := &a.state.Stages[i]
		if s.ID == a.state.Phase {
			s.Done = done
			s.Total = total
			s.Detail = detail
		}
	}
	a.state.Status = detail
}
func (a *App) transfer(n int64) { a.mu.Lock(); a.transferred += n; a.mu.Unlock() }
func (a *App) file(p Asset, status string, done int64, detail string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	i, ok := a.fileIndex[p.SHA256]
	if !ok {
		return
	}
	f := &a.state.Files[i]
	f.Status = status
	f.Done = done
	f.Detail = detail
	var all int64
	for _, v := range a.state.Files {
		all += v.Done
	}
	if a.state.Phase == "download" {
		for j := range a.state.Stages {
			if a.state.Stages[j].ID == "download" {
				a.state.Stages[j].Done = all
			}
		}
	}
}
func (a *App) Start(selected Device) error {
	a.mu.Lock()
	if a.state.Busy {
		a.mu.Unlock()
		return errors.New("Đang xử lý USB")
	}
	a.reset()
	a.state.Busy = true
	a.state.Cancellable = true
	ctx, cancel := context.WithCancel(context.Background())
	a.cancel = cancel
	a.mu.Unlock()
	go func() {
		err := a.run(ctx, selected)
		a.mu.Lock()
		defer a.mu.Unlock()
		a.state.Busy = false
		a.state.Cancellable = false
		a.state.Rate = 0
		if err != nil {
			a.state.Error = err.Error()
			a.state.Status = "Chưa hoàn tất: " + err.Error()
			for i := range a.state.Stages {
				if a.state.Stages[i].Status == "active" {
					a.state.Stages[i].Status = "error"
				}
			}
			a.logLocked(a.state.Status)
		} else {
			for i := range a.state.Stages {
				a.state.Stages[i].Status = "done"
				a.state.Stages[i].Done = a.state.Stages[i].Total
			}
			a.state.Phase = "done"
			a.state.Status = "USB đã sẵn sàng. Toàn bộ dữ liệu ghi đã đọc lại đúng checksum."
			a.logLocked(a.state.Status)
		}
	}()
	return nil
}
func (a *App) Cancel() error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if !a.state.Cancellable {
		return errors.New("Đang ghi/kiểm tra USB; hãy chờ hoàn tất")
	}
	if a.cancel != nil {
		a.cancel()
		a.logLocked("Đang dừng; giữ các file tải dở để thử lại")
	}
	return nil
}
func (a *App) run(ctx context.Context, selected Device) error {
	if err := revalidate(selected); err != nil {
		return err
	}
	if err := os.MkdirAll(a.state.Cache, 0700); err != nil {
		return err
	}
	return platformRun(ctx, a, selected)
}
func loadSpec() (Spec, error) {
	var s Spec
	b, e := bundled.ReadFile("assets/offline/sources.json")
	if e != nil {
		return s, e
	}
	if e = json.Unmarshal(b, &s); e != nil {
		return s, e
	}
	b, e = bundled.ReadFile("assets/offline/debian-packages.json")
	if e != nil {
		return s, e
	}
	e = json.Unmarshal(b, &s.Packages)
	return s, e
}
func (s Spec) assets() []Asset {
	seen := map[string]bool{}
	out := []Asset{}
	for _, p := range append(append([]Asset{s.Debian, s.Application, s.Display}, s.Analytics...), s.Packages...) {
		if p.SHA256 != "" && !seen[p.SHA256] {
			out = append(out, p)
			seen[p.SHA256] = true
		}
	}
	return out
}
func (a *App) prepare(ctx context.Context) (Image, error) {
	s, e := loadSpec()
	if e != nil {
		return Image{}, e
	}
	a.phase("download", "Kiểm tra bản CameraWall mới nhất trên GitHub", 0, "bytes")
	s.AppVersion, s.Application, s.Display, e = resolveRelease(ctx, latestReleaseURL)
	if e != nil {
		return Image{}, fmt.Errorf("không xác định được bản CameraWall mới nhất: %w", e)
	}
	items := s.assets()
	var total int64
	a.mu.Lock()
	a.state.AppVersion = s.AppVersion
	for _, p := range items {
		category := "Debian packages"
		switch {
		case p.SHA256 == s.Debian.SHA256:
			category = "Debian OS"
		case p.SHA256 == s.Application.SHA256:
			category = "CameraWall"
		case p.SHA256 == s.Display.SHA256:
			category = "Local Display"
		default:
			for _, v := range s.Analytics {
				if v.SHA256 == p.SHA256 {
					category = "AI runtime"
				}
			}
		}
		a.fileIndex[p.SHA256] = len(a.state.Files)
		a.state.Files = append(a.state.Files, FileProgress{Name: p.Name, Category: category, Size: p.Size, Status: "pending"})
		total += p.Size
	}
	a.mu.Unlock()
	a.phase("download", fmt.Sprintf("Tải %d thành phần đã xác định", len(items)), total, "bytes")
	paths, e := a.downloadAll(ctx, items)
	if e != nil {
		return Image{}, e
	}
	a.phase("checksum", "Kiểm tra SHA-256 toàn bộ dữ liệu", total, "bytes")
	var done int64
	for _, p := range items {
		a.file(p, "checking", p.Size, "SHA-256")
		digest, e := hashPath(ctx, paths[p.SHA256], func(n int64) { a.progress(done+n, total, "Kiểm tra "+p.Name) })
		if e != nil {
			return Image{}, e
		}
		if digest != p.SHA256 {
			os.Remove(paths[p.SHA256])
			a.file(p, "error", 0, "Checksum không khớp; đã bỏ file lỗi")
			return Image{}, fmt.Errorf("checksum không khớp: %s; thử lại để tải lại file này", p.Name)
		}
		done += p.Size
		a.file(p, "verified", p.Size, "Checksum đúng")
	}
	return a.compose(ctx, s, paths)
}

var discoverDevices = discover

func revalidate(d Device) error {
	devices, e := discoverDevices()
	if e != nil {
		return e
	}
	for _, current := range devices {
		if current == d {
			return nil
		}
	}
	return errors.New("USB đã thay đổi, bị rút hoặc không còn an toàn. Hãy quét và chọn lại")
}
func prepareOnly() error {
	a := newApp()
	ctx := context.Background()
	go func() {
		for {
			time.Sleep(time.Second)
			s := a.GetState()
			fmt.Printf("%s: %s\n", s.Phase, s.Status)
		}
	}()
	img, e := a.prepare(ctx)
	if e == nil {
		fmt.Printf("%+v\n", img)
	}
	return e
}
func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func (a *App) Licenses() string {
	own, _ := bundled.ReadFile("LICENSE")
	third, _ := bundled.ReadFile("THIRD-PARTY-NOTICES.txt")
	return string(own) + "\n\n" + string(third)
}

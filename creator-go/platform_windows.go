//go:build windows

package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"golang.org/x/sys/windows"
	"net"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf16"
)

func powershell(ctx context.Context, script string) ([]byte, error) {
	u := utf16.Encode([]rune("[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $ErrorActionPreference='Stop'; " + script))
	b := make([]byte, len(u)*2)
	for i, v := range u {
		binary.LittleEndian.PutUint16(b[i*2:], v)
	}
	cmd := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", base64.StdEncoding.EncodeToString(b))
	return cmd.Output()
}
func discover() ([]Device, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	b, e := powershell(ctx, `$items=@(Get-Disk | Where-Object {$_.BusType -eq 'USB' -and -not $_.IsBoot -and -not $_.IsSystem -and -not $_.IsReadOnly -and -not $_.IsOffline} | ForEach-Object {@{id=[string]$_.Number;size=[long]$_.Size;model=[string]$_.FriendlyName;serial=[string]$_.UniqueId;sector=[long]$_.LogicalSectorSize}}); ConvertTo-Json -Compress -InputObject $items`)
	if e != nil {
		return nil, fmt.Errorf("không đọc được danh sách USB Windows: %w", e)
	}
	var devices []Device
	if e = json.Unmarshal(bytesTrimBOM(b), &devices); e != nil {
		return nil, e
	}
	out := []Device{}
	for _, d := range devices {
		if regexp.MustCompile(`^[0-9]+$`).MatchString(d.ID) && strings.TrimSpace(d.Serial) != "" && d.Sector == 512 && d.Size >= 2*1024*1024*1024 {
			out = append(out, d)
		}
	}
	return out, nil
}
func bytesTrimBOM(b []byte) []byte {
	return []byte(strings.TrimPrefix(strings.TrimSpace(string(b)), "\ufeff"))
}

type writeJob struct {
	Device  Device `json:"device"`
	Image   Image  `json:"image"`
	Address string `json:"address"`
	Token   string `json:"token"`
}
type helperEvent struct {
	Token    string  `json:"token"`
	Phase    string  `json:"phase"`
	Detail   string  `json:"detail"`
	Done     int64   `json:"done"`
	Total    int64   `json:"total"`
	Rate     float64 `json:"rate"`
	Error    string  `json:"error"`
	Complete bool    `json:"complete"`
}

func platformRun(ctx context.Context, a *App, d Device) error {
	img, e := a.prepare(ctx)
	if e != nil {
		return e
	}
	if img.Size > d.Size {
		return errors.New("USB không đủ dung lượng")
	}
	a.phase("permission", "Cho phép Windows Administrator để ghi USB", 0, "")
	a.mu.Lock()
	a.state.Cancellable = false
	a.mu.Unlock()
	listener, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		return e
	}
	defer listener.Close()
	var random [32]byte
	if _, e = rand.Read(random[:]); e != nil {
		return e
	}
	job := writeJob{Device: d, Image: img, Address: listener.Addr().String(), Token: hex.EncodeToString(random[:])}
	data, e := json.Marshal(job)
	if e != nil {
		return e
	}
	encoded := base64.RawURLEncoding.EncodeToString(data)
	exe, e := os.Executable()
	if e != nil {
		return e
	}
	wait := make(chan error, 1)
	script := fmt.Sprintf("$p=Start-Process -FilePath '%s' -ArgumentList '--write-job','%s' -Verb RunAs -PassThru -Wait; if($p.ExitCode -ne 0){throw ('Writer exited: '+$p.ExitCode)}", strings.ReplaceAll(exe, "'", "''"), encoded)
	go func() { _, e := powershell(context.Background(), script); wait <- e; listener.Close() }()
	conn, e := listener.Accept()
	if e != nil {
		if err := <-wait; err != nil {
			return fmt.Errorf("Windows chưa cấp quyền hoặc bộ ghi không khởi động: %w", err)
		}
		return e
	}
	defer conn.Close()
	decoder := json.NewDecoder(conn)
	var first helperEvent
	if e = decoder.Decode(&first); e != nil {
		return e
	}
	if subtle.ConstantTimeCompare([]byte(first.Token), []byte(job.Token)) != 1 {
		return errors.New("kết nối helper không hợp lệ")
	}
	a.mu.Lock()
	a.state.Cancellable = false
	a.mu.Unlock()
	finished := false
	lastPhase := ""
	var lastDone int64
	for {
		var event helperEvent
		if e = decoder.Decode(&event); e != nil {
			break
		}
		if event.Error != "" {
			return errors.New(event.Error)
		}
		if event.Complete {
			finished = true
			break
		}
		if event.Phase != "write" && event.Phase != "readback" && event.Phase != "finish" {
			continue
		}
		if a.GetState().Phase != event.Phase {
			a.phase(event.Phase, event.Detail, event.Total, "bytes")
		}
		a.progress(event.Done, event.Total, event.Detail)
		if event.Phase != lastPhase {
			lastPhase = event.Phase
			lastDone = 0
		}
		if event.Done >= lastDone {
			a.transfer(event.Done - lastDone)
		}
		lastDone = event.Done
	}
	if err := <-wait; err != nil {
		return err
	}
	if !finished {
		return errors.New("helper kết thúc trước khi xác nhận checksum USB")
	}
	a.phase("finish", "Ghi và đọc lại USB thành công", 1, "actions")
	a.progress(1, 1, "Có thể tháo USB an toàn")
	return nil
}
func helperMain(args []string) error {
	if len(args) != 1 || len(args[0]) > 16384 {
		return errors.New("job không hợp lệ")
	}
	b, e := base64.RawURLEncoding.DecodeString(args[0])
	if e != nil {
		return e
	}
	var job writeJob
	if e = json.Unmarshal(b, &job); e != nil {
		return e
	}
	host, _, e := net.SplitHostPort(job.Address)
	if e != nil || host != "127.0.0.1" || len(job.Token) != 64 || job.Image.Size <= 0 || job.Image.Size > job.Device.Size || !regexp.MustCompile(`^[a-f0-9]{64}$`).MatchString(job.Image.SHA256) {
		return errors.New("job validation failed")
	}
	if !windows.GetCurrentProcessToken().IsElevated() {
		return errors.New("cần quyền Administrator")
	}
	conn, e := net.DialTimeout("tcp4", job.Address, 10*time.Second)
	if e != nil {
		return e
	}
	defer conn.Close()
	encoder := json.NewEncoder(conn)
	var mu sync.Mutex
	send := func(event helperEvent) { mu.Lock(); defer mu.Unlock(); _ = encoder.Encode(event) }
	send(helperEvent{Token: job.Token})
	a := newApp()
	stop := make(chan struct{})
	go func() {
		ticker := time.NewTicker(200 * time.Millisecond)
		defer ticker.Stop()
		last := int64(0)
		at := time.Now()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				s := a.GetState()
				var d, t int64
				for _, stage := range s.Stages {
					if stage.ID == s.Phase {
						d, t = stage.Done, stage.Total
					}
				}
				a.mu.Lock()
				transferred := a.transferred
				a.mu.Unlock()
				now := time.Now()
				rate := float64(transferred-last) / now.Sub(at).Seconds()
				last = transferred
				at = now
				send(helperEvent{Phase: s.Phase, Detail: s.Status, Done: d, Total: t, Rate: rate})
			}
		}
	}()
	e = writeWindows(a, job.Device, job.Image)
	close(stop)
	if e != nil {
		send(helperEvent{Error: e.Error()})
		return e
	}
	send(helperEvent{Complete: true})
	return nil
}
func writeWindows(a *App, d Device, img Image) error {
	if e := revalidate(d); e != nil {
		return e
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	script := fmt.Sprintf(`$paths=@(Get-Partition | Where-Object {$_.DiskNumber -eq %s} | ForEach-Object {$_.AccessPaths} | Where-Object {$_ -like '\\?\Volume*'}); ConvertTo-Json -Compress -InputObject $paths`, d.ID)
	b, e := powershell(ctx, script)
	if e != nil {
		return e
	}
	var paths []string
	if e = json.Unmarshal(bytesTrimBOM(b), &paths); e != nil {
		return e
	}
	handles := []windows.Handle{}
	defer func() {
		for _, h := range handles {
			windows.CloseHandle(h)
		}
	}()
	control := func(h windows.Handle, code uint32) error {
		var returned uint32
		return windows.DeviceIoControl(h, code, nil, 0, nil, 0, &returned, nil)
	}
	volumePattern := regexp.MustCompile(`^[0-9A-Fa-f-]+$`)
	seen := map[string]bool{}
	for _, p := range paths {
		if seen[p] {
			continue
		}
		seen[p] = true
		if !strings.HasPrefix(p, `\\?\Volume{`) || !strings.HasSuffix(p, `}\`) || !volumePattern.MatchString(strings.TrimSuffix(strings.TrimPrefix(p, `\\?\Volume{`), `}\`)) {
			return errors.New("volume USB không hợp lệ")
		}
		name, e := windows.UTF16PtrFromString(strings.TrimSuffix(p, `\`))
		if e != nil {
			return e
		}
		h, e := windows.CreateFile(name, windows.GENERIC_READ|windows.GENERIC_WRITE, windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE, nil, windows.OPEN_EXISTING, 0, 0)
		if e != nil {
			return e
		}
		handles = append(handles, h)
		if e = control(h, 0x90018); e != nil {
			return e
		}
		if e = control(h, 0x90020); e != nil {
			return e
		}
	}
	if e = revalidate(d); e != nil {
		return e
	}
	name, e := windows.UTF16PtrFromString(`\\.\PhysicalDrive` + d.ID)
	if e != nil {
		return e
	}
	h, e := windows.CreateFile(name, windows.GENERIC_READ|windows.GENERIC_WRITE, windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE, nil, windows.OPEN_EXISTING, 0, 0)
	if e != nil {
		return e
	}
	target := os.NewFile(uintptr(h), "USB")
	defer target.Close()
	if e = revalidate(d); e != nil {
		return e
	}
	if e = a.writeImage(context.Background(), img, target, d); e != nil {
		return e
	}
	return control(h, 0x70140)
}

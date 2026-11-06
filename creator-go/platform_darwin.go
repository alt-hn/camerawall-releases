//go:build darwin

package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"golang.org/x/sys/unix"
	"howett.net/plist"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"time"
)

var diskName = regexp.MustCompile(`^disk[0-9]+$`)
var partitionSuffix = regexp.MustCompile(`s[0-9]+$`)

func command(args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	b, e := cmd.Output()
	if ctx.Err() != nil {
		return nil, errors.New("thiết bị không phản hồi trong 30 giây; kiểm tra cổng/cáp USB rồi quét lại")
	}
	if e != nil {
		return nil, fmt.Errorf("không đọc được thông tin thiết bị (%s): %w", args[0], e)
	}
	return b, nil
}
func plistCommand(out interface{}, args ...string) error {
	b, e := command(args...)
	if e != nil {
		return e
	}
	_, e = plist.Unmarshal(b, out)
	return e
}

type registryNode struct {
	Whole    bool           `plist:"Whole"`
	Name     string         `plist:"BSD Name"`
	ID       uint64         `plist:"IORegistryEntryID"`
	Children []registryNode `plist:"IORegistryEntryChildren"`
}
type diskInfo struct {
	Whole    bool `plist:"WholeDisk"`
	Internal bool
	Virtual  string `plist:"VirtualOrPhysical"`
	Bus      string `plist:"BusProtocol"`
	Writable bool
	Size     int64  `plist:"TotalSize"`
	Sector   int64  `plist:"DeviceBlockSize"`
	Name     string `plist:"MediaName"`
	Parent   string `plist:"ParentWholeDisk"`
	ID       string `plist:"DeviceIdentifier"`
	Stores   []struct {
		ID    string `plist:"DeviceIdentifier"`
		Store string `plist:"APFSPhysicalStore"`
	} `plist:"APFSPhysicalStores"`
}

func discover() ([]Device, error) {
	var list struct{ WholeDisks []string }
	if e := plistCommand(&list, "/usr/sbin/diskutil", "list", "-plist", "external", "physical"); e != nil {
		return nil, e
	}
	var nodes []registryNode
	if e := plistCommand(&nodes, "/usr/sbin/ioreg", "-r", "-c", "IOMedia", "-a"); e != nil {
		return nil, e
	}
	ids := map[string]uint64{}
	var visit func([]registryNode)
	visit = func(items []registryNode) {
		for _, n := range items {
			if n.Whole && n.Name != "" {
				ids[n.Name] = n.ID
			}
			visit(n.Children)
		}
	}
	visit(nodes)
	var root diskInfo
	if e := plistCommand(&root, "/usr/sbin/diskutil", "info", "-plist", "/"); e != nil {
		return nil, e
	}
	protected := map[string]bool{root.Parent: true, root.ID: true}
	for _, s := range root.Stores {
		id := s.ID
		if id == "" {
			id = s.Store
		}
		protected[partitionSuffix.ReplaceAllString(id, "")] = true
	}
	var apfs struct {
		Containers []struct {
			PhysicalStores []struct {
				ID string `plist:"DeviceIdentifier"`
			}
			Volumes []struct {
				MountPoint string
				Roles      []string
			}
		}
	}
	if e := plistCommand(&apfs, "/usr/sbin/diskutil", "apfs", "list", "-plist"); e != nil {
		return nil, e
	}
	for _, c := range apfs.Containers {
		system := false
		for _, v := range c.Volumes {
			if v.MountPoint == "/" {
				system = true
			}
			for _, r := range v.Roles {
				if r == "System" {
					system = true
				}
			}
		}
		if system {
			for _, p := range c.PhysicalStores {
				protected[partitionSuffix.ReplaceAllString(p.ID, "")] = true
			}
		}
	}
	out := []Device{}
	for _, name := range list.WholeDisks {
		if !diskName.MatchString(name) || protected[name] {
			continue
		}
		var info diskInfo
		if e := plistCommand(&info, "/usr/sbin/diskutil", "info", "-plist", name); e != nil {
			return nil, e
		}
		if !info.Whole || info.Internal || info.Virtual == "Virtual" || info.Bus != "USB" || !info.Writable || info.Sector != 512 || info.Size < 2*1024*1024*1024 || ids[name] == 0 {
			continue
		}
		out = append(out, Device{ID: name, Model: info.Name, Size: info.Size, Serial: strconv.FormatUint(ids[name], 10), Sector: info.Sector})
	}
	return out, nil
}
func authorizedUSB(ctx context.Context, d Device) (*os.File, error) {
	if !diskName.MatchString(d.ID) {
		return nil, errors.New("device ID không hợp lệ")
	}
	if e := revalidate(d); e != nil {
		return nil, e
	}
	if _, e := command("/usr/sbin/diskutil", "unmountDisk", "/dev/"+d.ID); e != nil {
		return nil, e
	}
	if e := revalidate(d); e != nil {
		return nil, e
	}
	pair, e := unix.Socketpair(unix.AF_UNIX, unix.SOCK_STREAM, 0)
	if e != nil {
		return nil, e
	}
	unix.CloseOnExec(pair[0])
	unix.CloseOnExec(pair[1])
	parent := os.NewFile(uintptr(pair[0]), "auth-receive")
	child := os.NewFile(uintptr(pair[1]), "auth-send")
	defer parent.Close()
	defer child.Close()
	cmd := exec.CommandContext(ctx, "/usr/libexec/authopen", "-stdoutpipe", "-o", strconv.Itoa(os.O_RDWR), "/dev/r"+d.ID)
	cmd.Stdout = child
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if e = cmd.Start(); e != nil {
		return nil, e
	}
	child.Close()
	data := make([]byte, 1)
	oob := make([]byte, unix.CmsgSpace(4*4))
	_, n, flags, _, receiveErr := unix.Recvmsg(pair[0], data, oob, 0)
	waitErr := cmd.Wait()
	fds := []int{}
	messages, parseErr := unix.ParseSocketControlMessage(oob[:n])
	for _, message := range messages {
		rights, e := unix.ParseUnixRights(&message)
		if e == nil {
			fds = append(fds, rights...)
		}
	}
	if receiveErr != nil || parseErr != nil || waitErr != nil || flags&unix.MSG_CTRUNC != 0 || len(fds) != 1 {
		for _, fd := range fds {
			unix.Close(fd)
		}
		return nil, fmt.Errorf("macOS chưa cấp quyền cho USB. Cho phép truy cập ổ rời khi hệ thống hỏi; nếu đã từ chối, kiểm tra Privacy & Security → Files and Folders. %s", stderr.String())
	}
	f := os.NewFile(uintptr(fds[0]), "/dev/r"+d.ID)
	if e = revalidate(d); e != nil {
		f.Close()
		return nil, e
	}
	var opened, current unix.Stat_t
	if e = unix.Fstat(int(f.Fd()), &opened); e == nil {
		e = unix.Stat("/dev/r"+d.ID, &current)
	}
	if e != nil || opened.Rdev != current.Rdev {
		f.Close()
		return nil, errors.New("USB thay đổi trong khi xin quyền")
	}
	return f, nil
}
func platformRun(ctx context.Context, a *App, d Device) error {
	a.phase("permission", "Cho phép macOS truy cập USB đã chọn", 0, "")
	target, e := authorizedUSB(ctx, d)
	if e != nil {
		return e
	}
	defer target.Close()
	a.progress(1, 1, "Đã cấp quyền cho "+d.Model)
	img, e := a.prepare(ctx)
	if e != nil {
		return e
	}
	if img.Size > d.Size {
		return errors.New("USB không đủ dung lượng")
	}
	if e = a.writeImage(ctx, img, target, d); e != nil {
		return e
	}
	if e = target.Close(); e != nil {
		return e
	}
	a.phase("finish", "Đang eject USB an toàn", 0, "")
	_, e = command("/usr/sbin/diskutil", "eject", "/dev/"+d.ID)
	return e
}
func helperMain(args []string) error {
	return errors.New("không sử dụng helper Windows trên macOS")
}

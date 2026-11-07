package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/md5"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"github.com/diskfs/go-diskfs/backend/file"
	"github.com/diskfs/go-diskfs/filesystem/fat32"
	"github.com/diskfs/go-diskfs/filesystem/iso9660"
	"github.com/klauspost/compress/zstd"
	"github.com/ulikunitz/xz"
	"hash/crc32"
	"io"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
)

const mib int64 = 1024 * 1024

func align(v, n int64) int64   { return (v + n - 1) / n * n }
func shaBytes(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }
func gzipBytes(b []byte) []byte {
	var out bytes.Buffer
	w := gzip.NewWriter(&out)
	_, _ = w.Write(b)
	_ = w.Close()
	return out.Bytes()
}
func runtimeFiles() (map[string][]byte, error) {
	out := map[string][]byte{}
	entries, e := bundled.ReadDir("assets/runtime")
	if e != nil {
		return nil, e
	}
	for _, entry := range entries {
		b, e := bundled.ReadFile("assets/runtime/" + entry.Name())
		if e != nil {
			return nil, e
		}
		out["camerawall/"+entry.Name()] = b
	}
	for _, name := range []string{"mount-media.sh", "late-install.sh", "offline-bootstrap.sh"} {
		b, e := bundled.ReadFile("assets/offline/" + name)
		if e != nil {
			return nil, e
		}
		out["camerawall/"+name] = b
	}
	out["usr/lib/apt-setup/generators/02camerawall"], e = bundled.ReadFile("assets/offline/apt-generator.sh")
	if e != nil {
		return nil, e
	}
	out["preseed.cfg"], e = bundled.ReadFile("assets/offline/preseed.cfg")
	if e != nil {
		return nil, e
	}
	for dest, name := range map[string]string{
		"etc/gtk-2.0/gtkrc":                     "gtkrc",
		"usr/share/graphics/logo_debian.png":    "banner.png",
		"usr/share/graphics/logo_installer.png": "banner.png",
	} {
		out[dest], e = bundled.ReadFile("assets/installer/" + name)
		if e != nil {
			return nil, e
		}
	}
	key := "camerawall/camerawall-firstboot.service"
	out[key] = bytes.ReplaceAll(out[key], []byte("Download and install pinned CameraWall release (Internet needed once)"), []byte("Install cached CameraWall offline"))
	out[key] = bytes.ReplaceAll(out[key], []byte("Wants=network-online.target\nAfter=network-online.target"), []byte("After=network.target"))
	key = "camerawall/console-ready.sh"
	out[key] = bytes.ReplaceAll(out[key], []byte("CameraWall READY: http://%s"), []byte("CameraWall READY (connect Ethernet for LAN access): http://%s"))
	return out, nil
}
func initramfs(files map[string][]byte) []byte {
	var out bytes.Buffer
	inode := 1
	add := func(name string, data []byte, mode int) {
		fields := []int{inode, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(name) + 1, 0}
		out.WriteString("070701")
		for _, v := range fields {
			fmt.Fprintf(&out, "%08x", v)
		}
		out.WriteString(name)
		out.WriteByte(0)
		for out.Len()%4 != 0 {
			out.WriteByte(0)
		}
		out.Write(data)
		for out.Len()%4 != 0 {
			out.WriteByte(0)
		}
		inode++
	}
	dirs := map[string]bool{}
	for name := range files {
		for p := path.Dir(name); p != "."; p = path.Dir(p) {
			dirs[p] = true
		}
	}
	for _, name := range sortedKeys(dirs) {
		add(name, nil, 0040755)
	}
	for _, name := range sortedKeys(files) {
		mode := 0100644
		if strings.HasSuffix(name, ".sh") || strings.Contains(name, "/generators/") {
			mode = 0100755
		}
		add(name, files[name], mode)
	}
	add("TRAILER!!!", nil, 0)
	return gzipBytes(out.Bytes())
}
func debControl(filename string) (string, error) {
	f, e := os.Open(filename)
	if e != nil {
		return "", e
	}
	defer f.Close()
	magic := make([]byte, 8)
	if _, e = io.ReadFull(f, magic); e != nil || string(magic) != "!<arch>\n" {
		return "", errors.New("gói Debian không hợp lệ")
	}
	for {
		header := make([]byte, 60)
		if _, e = io.ReadFull(f, header); e != nil {
			return "", e
		}
		name := strings.TrimSuffix(strings.TrimSpace(string(header[:16])), "/")
		n, e := strconv.ParseInt(strings.TrimSpace(string(header[48:58])), 10, 64)
		if e != nil || n < 0 || string(header[58:]) != "`\n" {
			return "", errors.New("ar header không hợp lệ")
		}
		if strings.HasPrefix(name, "control.tar") {
			if n > 16*mib {
				return "", errors.New("control archive quá lớn")
			}
			raw := make([]byte, n)
			if _, e = io.ReadFull(f, raw); e != nil {
				return "", e
			}
			var r io.Reader = bytes.NewReader(raw)
			switch {
			case strings.HasSuffix(name, ".xz"):
				r, e = xz.NewReader(r)
			case strings.HasSuffix(name, ".gz"):
				var z *gzip.Reader
				z, e = gzip.NewReader(r)
				if e == nil {
					defer z.Close()
					r = z
				}
			case strings.HasSuffix(name, ".zst"):
				var z *zstd.Decoder
				z, e = zstd.NewReader(r)
				if e == nil {
					defer z.Close()
					r = z
				}
			}
			if e != nil {
				return "", e
			}
			t := tar.NewReader(r)
			for {
				h, e := t.Next()
				if e != nil {
					return "", e
				}
				if h.Name == "control" || h.Name == "./control" {
					if h.Size > mib {
						return "", errors.New("control quá lớn")
					}
					b, e := io.ReadAll(t)
					return strings.TrimSpace(string(b)), e
				}
			}
		}
		if _, e = f.Seek(n+n%2, io.SeekCurrent); e != nil {
			return "", e
		}
	}
}

const bootMenu = `insmod part_gpt
insmod fat
insmod ext2
set default=install
set timeout=5
set timeout_style=menu
if search --no-floppy --file --set=cwroot /camerawall-installed.marker; then
 set default=installed
 set timeout=10
 menuentry 'Boot installed CameraWall' --id installed {
  set root=$cwroot
  set prefix=($cwroot)/boot/grub
  set cw_installer_boot_arg=camerawall.installer_boot=1
  export cw_installer_boot_arg
  configfile ($cwroot)/boot/grub/grub.cfg
  halt
 }
fi
if search --no-floppy --label --set=cwdata CWOFFLIN; then
 if loadfont /boot/grub/font.pf2; then
  set gfxmode=auto
  insmod all_video
  insmod gfxterm
  insmod png
  if terminal_output gfxterm; then
   set theme=($cwdata)/grub.theme
   export theme
  fi
 fi
 menuentry 'Install / reinstall CameraWall (erases target disk)' --id install {
  linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/preseed.cfg --- quiet
  initrd /install.amd/gtk/initrd.gz ($cwdata)/cw-initrd.gz
 }
 menuentry 'Install with text console' {
  linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/preseed.cfg --- quiet
  initrd /install.amd/initrd.gz ($cwdata)/cw-initrd.gz
 }
else
 echo 'CameraWall payload missing. Installation is unavailable.'
 if [ "$default" = install ]; then
  halt
 fi
fi
menuentry 'Power off' { halt }
`

func (a *App) compose(ctx context.Context, s Spec, paths map[string]string) (Image, error) {
	a.phase("compose", "Tạo initramfs và kho gói cài offline", int64(len(s.Packages)), "files")
	runtime, e := runtimeFiles()
	if e != nil {
		return Image{}, e
	}
	runtime["camerawall/release.env"] = s.releaseEnv()
	data := map[string][]byte{"cw-initrd.gz": initramfs(runtime)}
	for _, name := range []string{"grub.theme", "mark.png", "selected_c.png"} {
		data[name], e = bundled.ReadFile("assets/installer/" + name)
		if e != nil {
			return Image{}, e
		}
	}
	var index strings.Builder
	for i, p := range s.Packages {
		if e = ctx.Err(); e != nil {
			return Image{}, e
		}
		control, e := debControl(paths[p.SHA256])
		if e != nil {
			return Image{}, fmt.Errorf("%s: %w", p.Name, e)
		}
		fmt.Fprintf(&index, "%s\nFilename: pool/%s\nSize: %d\nSHA256: %s\n\n", control, p.Name, p.Size, p.SHA256)
		a.progress(int64(i+1), int64(len(s.Packages)), "Lập kho gói: "+p.Name)
	}
	data["repo/Packages"] = []byte(index.String())
	data["repo/Packages.gz"] = gzipBytes(data["repo/Packages"])
	release := "Origin: CameraWall offline cache\nLabel: Verified Debian packages\nSuite: offline\nDate: Fri, 06 Nov 2026 00:00:00 UTC\nArchitectures: amd64 all\nSHA256:\n"
	for _, name := range []string{"Packages", "Packages.gz"} {
		b := data["repo/"+name]
		release += fmt.Sprintf(" %s %d %s\n", shaBytes(b), len(b), name)
	}
	data["repo/Release"] = []byte(release)
	sources := map[string]Asset{"app.tar.gz": s.Application, "display.tar.gz": s.Display}
	for _, p := range s.Analytics {
		sources["analytics/"+p.Name] = p
	}
	for _, p := range s.Packages {
		sources["repo/pool/"+p.Name] = p
	}
	var sums strings.Builder
	var payload int64
	for _, name := range sortedKeys(data) {
		fmt.Fprintf(&sums, "%s  %s\n", shaBytes(data[name]), name)
		payload += int64(len(data[name]))
	}
	for _, name := range sortedKeys(sources) {
		p := sources[name]
		fmt.Fprintf(&sums, "%s  %s\n", p.SHA256, name)
		payload += p.Size
	}
	data["SHA256SUMS"] = []byte(sums.String())
	payload += int64(sums.Len())
	fatSize := align(payload*108/100+32*mib, 16*mib)
	fatPath := filepath.Join(a.state.Cache, "payload.fat")
	os.Remove(fatPath)
	fatFile, e := os.OpenFile(fatPath, os.O_CREATE|os.O_EXCL|os.O_RDWR, 0600)
	if e != nil {
		return Image{}, e
	}
	defer fatFile.Close()
	if e = fatFile.Truncate(fatSize); e != nil {
		return Image{}, e
	}
	a.mu.Lock()
	for i := range a.state.Stages {
		if a.state.Stages[i].ID == "compose" {
			a.state.Stages[i].Unit = "bytes"
		}
	}
	a.mu.Unlock()
	a.progress(0, payload, "Tạo phân vùng dữ liệu FAT32")
	fs, e := fat32.Create(file.New(fatFile, false), fatSize, 0, 512, "CWOFFLIN", false)
	if e != nil {
		return Image{}, e
	}
	for _, dir := range []string{"repo", "repo/pool", "analytics"} {
		if e = fs.Mkdir(dir); e != nil {
			return Image{}, e
		}
	}
	var done int64
	for _, name := range sortedKeys(data) {
		if e = ctx.Err(); e != nil {
			return Image{}, e
		}
		f, e := fs.OpenFile(name, os.O_CREATE|os.O_RDWR)
		if e != nil {
			return Image{}, e
		}
		_, e = f.Write(data[name])
		closeErr := f.Close()
		if e != nil {
			return Image{}, e
		}
		if closeErr != nil {
			return Image{}, closeErr
		}
		done += int64(len(data[name]))
		a.progress(done, payload, "Thêm "+name)
	}
	for _, name := range sortedKeys(sources) {
		p := sources[name]
		src, e := os.Open(paths[p.SHA256])
		if e != nil {
			return Image{}, e
		}
		dst, e := fs.OpenFile(name, os.O_CREATE|os.O_RDWR)
		if e != nil {
			src.Close()
			return Image{}, e
		}
		e = copyProgress(ctx, dst, src, p.Size, func(n int64) { a.progress(done+n, payload, "Đóng gói "+name) })
		src.Close()
		closeErr := dst.Close()
		if e != nil {
			return Image{}, e
		}
		if closeErr != nil {
			return Image{}, closeErr
		}
		done += p.Size
	}
	if e = fatFile.Sync(); e != nil {
		return Image{}, e
	}
	imagePath := filepath.Join(a.state.Cache, "camerawall-offline.img")
	image, e := os.OpenFile(imagePath, os.O_CREATE|os.O_TRUNC|os.O_RDWR, 0600)
	if e != nil {
		return Image{}, e
	}
	defer image.Close()
	original, e := os.Open(paths[s.Debian.SHA256])
	if e != nil {
		return Image{}, e
	}
	e = copyProgress(ctx, image, original, s.Debian.Size, func(n int64) { a.progress(n, s.Debian.Size, "Tạo ảnh boot từ Debian chính thức") })
	original.Close()
	if e != nil {
		return Image{}, e
	}
	a.progress(0, 0, "Cấu hình boot tự động và checksum media")
	if e = patchBoot(image, s.Debian.Size); e != nil {
		return Image{}, e
	}
	start := align(s.Debian.Size, mib)
	total := align(start+fatSize+64*512, mib)
	if e = image.Truncate(total); e != nil {
		return Image{}, e
	}
	if _, e = image.Seek(start, io.SeekStart); e != nil {
		return Image{}, e
	}
	if _, e = fatFile.Seek(0, io.SeekStart); e != nil {
		return Image{}, e
	}
	e = copyProgress(ctx, image, fatFile, fatSize, func(n int64) { a.progress(n, fatSize, "Ghép phân vùng bộ cài vào ảnh USB") })
	if e != nil {
		return Image{}, e
	}
	if e = appendGPT(image, start/512, fatSize/512, total); e != nil {
		return Image{}, e
	}
	if e = image.Sync(); e != nil {
		return Image{}, e
	}
	digest, e := hashPath(ctx, imagePath, func(n int64) { a.progress(n, total, "Kiểm tra ảnh bootable vừa tạo") })
	if e != nil {
		return Image{}, e
	}
	return Image{Path: imagePath, Size: total, SHA256: digest}, nil
}
func patchBoot(image *os.File, size int64) error {
	iso, e := iso9660.Read(file.New(image, true), size, 0, 2048)
	if e != nil {
		return e
	}
	read := func(name string) (*iso9660.File, []byte, error) {
		f, e := iso.OpenFile(name, os.O_RDONLY)
		if e != nil {
			return nil, nil, e
		}
		b, e := io.ReadAll(f)
		f.Close()
		v, ok := f.(*iso9660.File)
		if !ok {
			return nil, nil, errors.New("ISO file không có extent")
		}
		return v, b, e
	}
	changed := map[string]string{}
	for name, text := range map[string]string{"/boot/grub/grub.cfg": bootMenu, "/isolinux/isolinux.cfg": "DEFAULT vesamenu.c32\nPROMPT 0\nTIMEOUT 0\nMENU TITLE CameraWall: UEFI required\nLABEL stop\n MENU LABEL Reboot in UEFI mode\n LOCALBOOT -1\n"} {
		f, old, e := read(name)
		if e != nil {
			return e
		}
		if len(text) > len(old) {
			return errors.New("boot menu vượt extent ISO gốc")
		}
		b := append([]byte(text), bytes.Repeat([]byte(" "), len(old)-len(text))...)
		if _, e = image.WriteAt(b, int64(f.Location())*2048); e != nil {
			return e
		}
		digest := md5.Sum(b)
		changed["."+name] = hex.EncodeToString(digest[:])
	}
	f, b, e := read("/md5sum.txt")
	if e != nil {
		return e
	}
	lines := strings.SplitAfter(string(b), "\n")
	for i, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		if digest, ok := changed[fields[len(fields)-1]]; ok {
			if len(line) < 32 {
				return errors.New("MD5 manifest không hợp lệ")
			}
			lines[i] = digest + line[32:]
		}
	}
	patched := []byte(strings.Join(lines, ""))
	if len(patched) != len(b) {
		return errors.New("MD5 manifest thay đổi dung lượng")
	}
	_, e = image.WriteAt(patched, int64(f.Location())*2048)
	return e
}
func appendGPT(f *os.File, start, length, total int64) error {
	h := make([]byte, 512)
	if _, e := f.ReadAt(h, 512); e != nil {
		return e
	}
	le := binary.LittleEndian
	if string(h[:8]) != "EFI PART" {
		return errors.New("Debian GPT hybrid không hợp lệ")
	}
	hs := le.Uint32(h[12:])
	lba := le.Uint64(h[72:])
	count := le.Uint32(h[80:])
	width := le.Uint32(h[84:])
	if hs < 92 || hs > 512 || width != 128 || count < 3 || count > 4096 || lba > 64 {
		return errors.New("GPT layout không hỗ trợ")
	}
	entries := make([]byte, int(count*width))
	if _, e := f.ReadAt(entries, int64(lba)*512); e != nil {
		return e
	}
	for _, b := range entries[256:] {
		if b != 0 {
			return errors.New("GPT có phân vùng thứ ba; từ chối ghi đè")
		}
	}
	entry := entries[256:384]
	copy(entry, []byte{0xa2, 0xa0, 0xd0, 0xeb, 0xe5, 0xb9, 0x33, 0x44, 0x87, 0xc0, 0x68, 0xb6, 0xb7, 0x26, 0x99, 0xc7})
	if _, e := rand.Read(entry[16:32]); e != nil {
		return e
	}
	entry[23] = (entry[23] & 15) | 64
	entry[24] = (entry[24] & 63) | 128
	le.PutUint64(entry[32:], uint64(start))
	le.PutUint64(entry[40:], uint64(start+length-1))
	for i, c := range "CWOFFLIN" {
		le.PutUint16(entry[56+i*2:], uint16(c))
	}
	sectors := align(int64(len(entries)), 512) / 512
	last := total/512 - 1
	if start+length-1 >= last-sectors {
		return errors.New("payload đè lên GPT backup")
	}
	le.PutUint64(h[32:], uint64(last))
	le.PutUint64(h[48:], uint64(last-sectors-1))
	le.PutUint32(h[88:], crc32.ChecksumIEEE(entries))
	checksum := func(header []byte) {
		le.PutUint32(header[16:], 0)
		le.PutUint32(header[16:], crc32.ChecksumIEEE(header[:hs]))
	}
	checksum(h)
	if _, e := f.WriteAt(entries, int64(lba)*512); e != nil {
		return e
	}
	if _, e := f.WriteAt(h, 512); e != nil {
		return e
	}
	backup := append([]byte{}, h...)
	le.PutUint64(backup[24:], uint64(last))
	le.PutUint64(backup[32:], 1)
	le.PutUint64(backup[72:], uint64(last-sectors))
	checksum(backup)
	if _, e := f.WriteAt(entries, (last-sectors)*512); e != nil {
		return e
	}
	if _, e := f.WriteAt(backup, last*512); e != nil {
		return e
	}
	mbr := []byte{0, 254, 255, 255, 12, 254, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0}
	le.PutUint32(mbr[8:], uint32(start))
	le.PutUint32(mbr[12:], uint32(length))
	_, e := f.WriteAt(mbr, 446+32)
	return e
}

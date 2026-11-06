package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type Image struct {
	Path   string `json:"path"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

func copyProgress(ctx context.Context, dst io.Writer, src io.Reader, total int64, progress func(int64)) error {
	buf := make([]byte, 1024*1024)
	var done int64
	for done < total {
		if e := ctx.Err(); e != nil {
			return e
		}
		want := int64(len(buf))
		if total-done < want {
			want = total - done
		}
		n, e := src.Read(buf[:want])
		if n > 0 {
			w, ew := dst.Write(buf[:n])
			if ew != nil {
				return ew
			}
			if w != n {
				return io.ErrShortWrite
			}
			done += int64(n)
			if progress != nil {
				progress(done)
			}
		}
		if e != nil {
			if e == io.EOF && done == total {
				break
			}
			return fmt.Errorf("dữ liệu thiếu ở byte %d/%d: %w", done, total, e)
		}
		if n == 0 {
			return io.ErrNoProgress
		}
	}
	return nil
}
func hashPath(ctx context.Context, path string, progress func(int64)) (string, error) {
	f, e := os.Open(path)
	if e != nil {
		return "", e
	}
	defer f.Close()
	s, e := f.Stat()
	if e != nil {
		return "", e
	}
	return hashStream(ctx, f, s.Size(), progress)
}
func hashStream(ctx context.Context, src io.Reader, size int64, progress func(int64)) (string, error) {
	h := sha256.New()
	e := copyProgress(ctx, h, src, size, progress)
	return hex.EncodeToString(h.Sum(nil)), e
}
func assetPath(cache string, p Asset) string {
	return filepath.Join(cache, "downloads", p.SHA256+".iso")
}
func (a *App) downloadAll(ctx context.Context, items []Asset) (map[string]string, error) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	paths := map[string]string{}
	var mu sync.Mutex
	var first error
	var wg sync.WaitGroup
	queue := make(chan Asset)
	for range 4 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for p := range queue {
				path, e := a.download(ctx, p)
				if e != nil {
					mu.Lock()
					if first == nil {
						first = e
					}
					mu.Unlock()
					cancel()
					return
				}
				mu.Lock()
				paths[p.SHA256] = path
				mu.Unlock()
			}
		}()
	}
feed:
	for _, p := range items {
		select {
		case queue <- p:
		case <-ctx.Done():
			break feed
		}
	}
	close(queue)
	wg.Wait()
	if first != nil {
		return nil, first
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	return paths, nil
}
func (a *App) download(ctx context.Context, p Asset) (string, error) {
	u, e := url.Parse(p.URL)
	if e != nil {
		return "", e
	}
	hosts := map[string]bool{"github.com": true, "cdimage.debian.org": true, "deb.debian.org": true, "security.debian.org": true, "files.pythonhosted.org": true, "media.githubusercontent.com": true, "raw.githubusercontent.com": true}
	if u.Scheme != "https" || !hosts[u.Hostname()] || len(p.SHA256) != 64 || p.Size <= 0 {
		return "", errors.New("nguồn tải không hợp lệ")
	}
	path := assetPath(a.state.Cache, p)
	if e = os.MkdirAll(filepath.Dir(path), 0700); e != nil {
		return "", e
	}
	if s, e := os.Stat(path); e == nil && s.Size() == p.Size {
		a.file(p, "cached", p.Size, "Đã có trong cache; sẽ kiểm checksum")
		return path, nil
	}
	os.Remove(path)
	partial := strings.TrimSuffix(path, ".iso") + ".part"
	client := &http.Client{Timeout: 30 * time.Minute, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if req.URL.Scheme != "https" {
			return errors.New("từ chối chuyển hướng không dùng HTTPS")
		}
		if len(via) > 10 {
			return errors.New("quá nhiều chuyển hướng")
		}
		return nil
	}}
	var last error
	for attempt := 1; attempt <= 3; attempt++ {
		if e = ctx.Err(); e != nil {
			return "", e
		}
		last = a.downloadAttempt(ctx, client, p, partial)
		if last == nil {
			if e = os.Rename(partial, path); e != nil {
				return "", e
			}
			a.file(p, "downloaded", p.Size, "Đã tải; chờ kiểm checksum")
			return path, nil
		}
		a.file(p, "retrying", 0, fmt.Sprintf("Thử lại %d/3: %v", attempt, last))
		if attempt < 3 {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(time.Second * time.Duration(attempt)):
			}
		}
	}
	a.file(p, "error", 0, last.Error())
	return "", fmt.Errorf("tải %s: %w", p.Name, last)
}
func (a *App) downloadAttempt(ctx context.Context, client *http.Client, p Asset, path string) error {
	var offset int64
	if s, e := os.Stat(path); e == nil {
		offset = s.Size()
	}
	if offset > p.Size {
		if e := os.Remove(path); e != nil {
			return e
		}
		offset = 0
	}
	if offset == p.Size {
		return nil
	}
	req, e := http.NewRequestWithContext(ctx, "GET", p.URL, nil)
	if e != nil {
		return e
	}
	req.Header.Set("User-Agent", "CameraWall-USB-Creator/"+version)
	req.Header.Set("Range", fmt.Sprintf("bytes=%d-", offset))
	response, e := client.Do(req)
	if e != nil {
		return e
	}
	defer response.Body.Close()
	flags := os.O_CREATE | os.O_WRONLY
	if response.StatusCode == http.StatusPartialContent {
		expected := fmt.Sprintf("bytes %d-%d/%d", offset, p.Size-1, p.Size)
		if response.Header.Get("Content-Range") != expected {
			return errors.New("Content-Range không khớp dữ liệu đã ghim")
		}
		flags |= os.O_APPEND
	} else if response.StatusCode == http.StatusOK {
		offset = 0
		flags |= os.O_TRUNC
	} else {
		return fmt.Errorf("HTTP %d", response.StatusCode)
	}
	f, e := os.OpenFile(path, flags, 0600)
	if e != nil {
		return e
	}
	defer f.Close()
	a.file(p, "downloading", offset, "Đang tải")
	last := int64(0)
	e = copyProgress(ctx, f, response.Body, p.Size-offset, func(n int64) { a.transfer(n - last); last = n; a.file(p, "downloading", offset+n, "Đang tải") })
	if e != nil {
		return e
	}
	var extra [1]byte
	if n, _ := response.Body.Read(extra[:]); n != 0 {
		return errors.New("máy chủ gửi dữ liệu lớn hơn dung lượng đã ghim")
	}
	return f.Sync()
}
func (a *App) writeImage(ctx context.Context, image Image, target *os.File, selected Device) error {
	// Hash source again before any destructive write. A prepared file is mutable.
	a.phase("write", "Kiểm tra nguồn lần cuối trước khi ghi", image.Size, "bytes")
	digest, e := hashPath(ctx, image.Path, func(n int64) { a.progress(n, image.Size, "Kiểm tra nguồn trước khi ghi") })
	if e != nil {
		return e
	}
	if digest != image.SHA256 {
		return errors.New("ảnh bộ cài đã thay đổi; chưa ghi USB")
	}
	if e = revalidate(selected); e != nil {
		return e
	}
	if e = ctx.Err(); e != nil {
		return e
	}
	a.mu.Lock()
	a.state.Cancellable = false
	a.mu.Unlock()
	a.progress(0, image.Size, "Đang ghi USB — không rút thiết bị")
	source, e := os.Open(image.Path)
	if e != nil {
		return e
	}
	defer source.Close()
	if _, e = target.Seek(0, io.SeekStart); e != nil {
		return e
	}
	last := int64(0)
	e = copyProgress(context.Background(), target, source, image.Size, func(n int64) {
		a.transfer(n - last)
		last = n
		a.progress(n, image.Size, "Đang ghi USB — không rút thiết bị")
	})
	if e != nil {
		return e
	}
	a.progress(image.Size, image.Size, "Đang flush dữ liệu xuống thiết bị")
	if e = target.Sync(); e != nil {
		return e
	}
	a.phase("readback", "Đọc lại USB và đối chiếu SHA-256", image.Size, "bytes")
	if _, e = target.Seek(0, io.SeekStart); e != nil {
		return e
	}
	last = 0
	actual, e := hashStream(context.Background(), target, image.Size, func(n int64) {
		a.transfer(n - last)
		last = n
		a.progress(n, image.Size, "Đang đọc lại từng byte từ USB")
	})
	if e != nil {
		return e
	}
	if actual != image.SHA256 {
		return errors.New("USB đọc lại không khớp checksum; chưa thể dùng để cài")
	}
	return nil
}

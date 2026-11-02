# USB mồi cài CameraWall qua Internet — usb-v0.1.0

Bản thử nghiệm dành cho thin client **x86-64, UEFI, Ethernet**. USB chứa Debian 12.15 netinst và firmware chính thức, không chứa CameraWall hoặc toàn bộ hệ điều hành đã cài. Debian tải gói từ `deb.debian.org`/`security.debian.org`; CameraWall tải **v0.1.0-alpha.29** từ GitHub Releases. OpenCV/NumPy tải từ PyPI, ba model YuNet/SFace/YOLOX từ commit OpenCV Zoo đã ghim; mọi file đều kiểm SHA-256 trước khi dùng. Không cần dịch vụ cloud riêng. Sau khi hoàn tất, CameraWall hoạt động trong LAN không cần Internet; cập nhật phần mềm vẫn cần Internet.

## Chuẩn bị

- Thin client Intel/AMD 64-bit, UEFI; tắt Legacy/CSM. Bản đầu yêu cầu tắt Secure Boot (chưa xác minh Secure Boot).
- RAM tối thiểu 2 GB để cài, khuyến nghị 4 GB trở lên. Đây không phải cam kết số camera/hiệu năng AI.
- SSD SATA/NVMe hoặc eMMC bên trong máy, tối thiểu 24 GiB thực (nên dùng 32 GB trở lên). **Toàn bộ ổ system được chọn sẽ bị xóa**, gồm OS, phân vùng và dữ liệu cũ. Không hỗ trợ cài lên HDD quay, ổ USB, RAID/LVM đang hoạt động.
- USB tối thiểu 2 GB; mọi dữ liệu trên USB cũng bị xóa khi flash.
- Màn hình và bàn phím; Ethernet có DHCP, DNS và Internet tới Debian/GitHub, `files.pythonhosted.org`, `media.githubusercontent.com` và `raw.githubusercontent.com` qua cổng 80/443. Cần thêm dung lượng tải vài GB; không cài qua captive portal. Wi-Fi và USB Ethernet chưa được kiểm thử.
- Sao lưu trước. **Rút HDD/SSD recording và các ổ backup khỏi máy trong lần cài đầu** nếu có thể. Bộ cài khóa chỉ đọc các ổ không được chọn, nhưng không thể đoán SSD nào chứa dữ liệu quý của bạn.

## Tải và kiểm tra

Tải ISO `camerawall-usb-v0.1.0-amd64.iso` cùng `SHA256SUMS` từ [release USB](https://github.com/alt-hn/camerawall-releases/releases/tag/usb-v0.1.0). Đối chiếu đủ 64 ký tự SHA-256 trước khi flash; khác checksum thì xóa file tải lỗi và tải lại.

Windows PowerShell:

```powershell
Get-FileHash .\camerawall-usb-v0.1.0-amd64.iso -Algorithm SHA256
Get-Content .\SHA256SUMS
```

macOS Terminal:

```sh
shasum -a 256 -c SHA256SUMS
```

Linux:

```sh
sha256sum -c SHA256SUMS
```

## Flash USB

**Chọn nhầm ổ sẽ xóa dữ liệu.** Rút ổ USB backup; đối chiếu tên, model và dung lượng USB trước khi bấm ghi. Không chỉ copy file ISO vào USB.

- **Windows:** dùng [Rufus](https://rufus.ie/). Device = đúng USB; Boot selection = ISO vừa tải; Start. Nếu hỏi ISO mode hay DD mode, chọn **DD Image mode**. Xác nhận xóa và chờ Ready. Nếu Windows hỏi format USB sau đó, chọn Cancel.
- **macOS/Linux:** dùng [balenaEtcher](https://etcher.balena.io/): Flash from file → chọn ISO → Select target → kiểm tra đúng USB → Flash. Chờ cả bước verify. Nếu macOS báo không đọc được ổ, chọn Ignore rồi eject; không Initialize.
- Linux cũng có thể dùng GNOME Disks → chọn đúng USB → Restore Disk Image → ISO. Không dùng thao tác Format Partition thay cho ghi image.

Không có lệnh `dd` với tên ổ mặc định để tránh ghi nhầm ổ hệ thống. Việc build/publish release không tự flash bất cứ ổ thật nào.

## Cài trên thin client

1. Tắt máy, rút ổ recording/backup, cắm USB và Ethernet. Mở boot menu của hãng và chọn **UEFI: USB**.
2. Chọn `CameraWall USB 0.1.0 - install Debian 12 + CameraWall`. Menu không tự bắt đầu theo thời gian. Mục serial console chỉ dùng khi có console 115200 hoặc test VM.
3. Đặt mật khẩu cho tài khoản Linux `cwadmin`; đây là tài khoản bảo trì có sudo, **khác** tài khoản admin web CameraWall. Không có mật khẩu chung được ghi sẵn trong ISO.
4. Chọn đúng **SYSTEM SSD/eMMC** trong danh sách model, serial, dung lượng. USB và HDD quay được đánh dấu PROTECTED. Nhập đúng câu `ERASE /dev/... <số-sector>` mà màn hình yêu cầu. Không sao chép ví dụ này làm câu xác nhận. Sai/để trống/hủy sẽ dừng cài, không tự chọn ổ khác.
5. Debian hiển thị phân vùng sẽ ghi. Kiểm tra lần nữa: chỉ ổ system đã chọn. Chọn Yes để ghi thay đổi. Nếu xuất hiện câu hỏi xóa RAID/LVM hoặc ổ khác, dừng cài, không đồng ý.
6. Chờ Debian cài, rồi rút USB khi khởi động lại. Nếu lại thấy menu USB, chọn boot SSD trong firmware.
7. Máy tự tải CameraWall, xác minh checksum và cài dịch vụ. Đợi vài phút, đăng nhập console bằng `cwadmin` và kiểm tra:

```sh
sudo systemctl status camerawall-firstboot
sudo journalctl -u camerawall-firstboot -b
sudo cat /var/lib/camerawall-usb/complete
hostname -I
sudo cat /etc/camerawall/initial-admin-password
```

Chỉ coi là xong khi có file `complete` và log `READY`. Mở `http://IP-của-máy` trong LAN, tài khoản web `admin`, mật khẩu lấy ở lệnh cuối. Đổi mật khẩu; thêm camera và cấu hình recording theo nhu cầu. Không mở port HTTP này ra Internet; truy cập từ xa qua VPN/reverse proxy HTTPS.

Runtime AI CPU, OpenCV 4.12.0.88, NumPy 2.0.2 và ba model được cài sẵn trên SSD trước khi báo READY; không tải model trong lúc inference. GPU/CUDA không được provision. Bản đầu cài **máy chủ headless**, không cài desktop/native HDMI. Thư mục recording mặc định ở SSD system: `/var/lib/camerawall/recordings`. Bộ cài không format/mount HDD recording. Sau khi tắt máy và cắm lại HDD, làm theo tài liệu storage của bản CameraWall đang cài; không giả định tính năng HDD/IP trong admin đã phát hành. Khóa chỉ đọc của bộ cài chỉ tồn tại trong phiên cài, không làm thay đổi dữ liệu hoặc chính sách ổ sau reboot.

## Mất mạng, lỗi và phục hồi

- **Trước bước ghi phân vùng:** khắc phục mạng/driver hoặc tắt máy và thử lại. Ổ system chưa bị xóa bởi script chọn ổ; thao tác phân vùng chỉ xảy ra sau xác nhận Debian.
- **Đang cài Debian:** thử lại bước tải tại màn hình lỗi. Nếu mất điện sau khi đã xác nhận ghi ổ, OS cũ có thể không còn khởi động được. Boot USB để cài lại đúng ổ system; cài lại sẽ xóa ổ đó lần nữa. Không gọi đây là resume phân vùng hay rollback.
- **Debian đã boot, CameraWall tải/cài lỗi:** không boot USB để xóa ổ lần nữa. Khôi phục Ethernet/DNS/giờ hệ thống rồi chạy:

```sh
sudo journalctl -u camerawall-firstboot -b --no-pager
sudo systemctl restart camerawall-firstboot
```

File tải dở nằm trong `/var/lib/camerawall-usb/`; curl thử nối tiếp và retry. Nếu server không hỗ trợ Range, tải lại từ đầu. Sai SHA-256 thì không chạy gói; file `.part` lỗi bị loại. Trạng thái thành công chỉ ghi sau khi dịch vụ và HTTP đều sẵn sàng. Nếu cài app đã bắt đầu nhưng lỗi ở giữa, lưu log trước khi xử lý; không xóa database/config để “sửa nhanh”. Trường hợp state tạo dở cần đánh giá riêng, không có bảo đảm rollback tự động.

- **Không có SSD phù hợp / câu xác nhận sai:** màn hình dừng an toàn; tắt máy, kiểm tra chế độ storage/UEFI và dây cáp, rồi thử lại. Không chuyển sang phân vùng thủ công để vượt bảo vệ.
- **Không có Ethernet/firmware:** dùng NIC được Debian 12 hỗ trợ hoặc kiểm tra firmware chính thức; không tự tải driver từ nguồn lạ. Kernel Debian 12 có thể không hỗ trợ thin client rất mới.
- **Không mở được web:** xem `hostname -I`, IP DHCP trong router, `systemctl status camerawall camerawall-media`, và `journalctl -u camerawall`. `active` riêng lẻ chưa chứng minh HTTP/video đã sẵn sàng.
- **Không boot USB:** flash lại bằng DD/image mode, kiểm checksum, chọn UEFI, tắt Secure Boot, thử cổng USB khác. Không hỗ trợ ARM/Raspberry Pi trong bản này.

Không cần Internet cho xem/ghi camera LAN sau khi đã READY. Tác vụ auto-download CameraWall được tắt trong bản USB; admin chủ động cập nhật. Cần NTP hoặc đồng hồ máy chính xác để timestamp camera đáng tin cậy.

## Nguồn, bảo mật và phạm vi kiểm chứng

Xem `USB-VALIDATION.md`, `BUILD-INFO.json`, `DEBIAN-SIGNATURE.txt`, `BOOT-LAYOUT.txt` và `SHA256SUMS` đính kèm release. ISO này là bản tùy biến CameraWall, không phải ISO nguyên gốc do Debian phát hành.

Nguồn Debian: [Debian 12 installer](https://www.debian.org/releases/bookworm/debian-installer/), [ISO 12.15](https://cdimage.debian.org/cdimage/archive/12.15.0/amd64/iso-cd/), [kiểm chữ ký Debian](https://www.debian.org/CD/verify). Build xác minh chữ ký checksum bằng Debian CD key fingerprint `DF9B9C49EAA9298432589D76DA87E80D6294BE9B`, rồi kiểm SHA-256 ISO. Debian Installer/APT xác minh chữ ký kho và hash gói; không tắt xác minh APT dù mirror dùng HTTP. CameraWall dùng HTTPS và SHA-256 ghim trong ISO, kiểm thêm source commit trong archive; đây không phải chữ ký phát hành độc lập của CameraWall.

Debian/firmware giữ giấy phép upstream; copyright và license của các gói được cài nằm ở `/usr/share/doc/*/copyright`. Mã nguồn Debian tương ứng có tại [Debian package pool](https://deb.debian.org/debian/pool/) và [Debian snapshot](https://snapshot.debian.org/). CameraWall giữ license/third-party notices trong archive và `/opt/camerawall/`. Scripts của bộ USB nằm công khai trong repo release dưới giấy phép `usb/LICENSE`.

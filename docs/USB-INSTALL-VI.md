# USB tự cài CameraWall — usb-v0.2.0

Bản thử nghiệm dành cho thin client **x86-64, UEFI, Ethernet**. USB chứa Debian 12.15 netinst và firmware chính thức, không chứa CameraWall hoặc toàn bộ hệ điều hành đã cài. Debian tải gói từ `deb.debian.org`/`security.debian.org`; CameraWall tải **v0.1.0-alpha.29** từ GitHub Releases. OpenCV/NumPy tải từ PyPI, ba model YuNet/SFace/YOLOX từ commit OpenCV Zoo đã ghim; mọi file đều kiểm SHA-256 trước khi dùng. Không cần dịch vụ cloud riêng. Sau khi hoàn tất, CameraWall hoạt động trong LAN không cần Internet; cập nhật phần mềm vẫn cần Internet.

**USB này tự xóa ổ nhỏ nhất đủ 24 GiB ngoài ổ đang boot, không hỏi xác nhận. Chỉ boot trên máy bạn chủ đích cài lại.**

## Chuẩn bị

- Thin client Intel/AMD 64-bit, UEFI; tắt Legacy/CSM. Bản đầu yêu cầu tắt Secure Boot (chưa xác minh Secure Boot).
- RAM tối thiểu 2 GB để cài, khuyến nghị 4 GB trở lên. Đây không phải cam kết số camera/hiệu năng AI.
- Ổ SSD/HDD/eMMC hoặc USB khác với USB đang boot, tối thiểu 24 GiB thực (nên dùng 32 GB trở lên). **Toàn bộ ổ system được chọn sẽ bị xóa**, gồm OS, phân vùng và dữ liệu cũ. Không hỗ trợ đích RAID/LVM đang hoạt động.
- USB tối thiểu 2 GB; mọi dữ liệu trên USB cũng bị xóa khi flash.
- Màn hình để đọc IP/mật khẩu ban đầu; không cần bàn phím/chuột trong luồng cài bình thường. Ethernet có DHCP, DNS và Internet tới Debian/GitHub, `files.pythonhosted.org`, `media.githubusercontent.com` và `raw.githubusercontent.com` qua cổng 80/443. Cần thêm dung lượng tải vài GB; không cài qua captive portal. Wi-Fi và USB Ethernet chưa được kiểm thử.
- Sao lưu trước. **Rút HDD/SSD recording và các ổ backup khỏi máy trong lần cài đầu** nếu có thể. Bộ cài khóa chỉ đọc các ổ không được chọn, nhưng không thể đoán SSD nào chứa dữ liệu quý của bạn.

## Tải và kiểm tra

Tải ISO `camerawall-usb-v0.2.0-amd64.iso` cùng `SHA256SUMS` từ [release USB](https://github.com/alt-hn/camerawall-releases/releases/tag/usb-v0.2.0). Đối chiếu đủ 64 ký tự SHA-256 (không phân biệt chữ hoa/thường) trước khi flash; khác checksum thì xóa file tải lỗi và tải lại.

Windows PowerShell:

```powershell
Get-FileHash .\camerawall-usb-v0.2.0-amd64.iso -Algorithm SHA256
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

## Cài tự động, không bấm phím

**Bản 0.2.0 tự xóa toàn bộ ổ nhỏ nhất đủ 24 GiB ngoài ổ đang boot. Không hỏi mật khẩu, không chọn ổ, không nhập ERASE, không hỏi xác nhận phân vùng.** Ổ SSD, HDD, eMMC và USB khác đều có thể làm đích. Nếu cùng dung lượng, thứ tự tên thiết bị Linux quyết định (ví dụ `/dev/sda` trước `/dev/sdb`). Dung lượng tối thiểu tính theo GiB thực, không phải nhãn GB của nhà sản xuất.

1. Flash ISO vào USB. Đặt firmware thin client boot USB trước, UEFI, tắt Secure Boot. Đây là thiết lập firmware trước khi dùng; USB không tự thay đổi thứ tự boot của hãng.
2. Cắm USB và Ethernet có DHCP/Internet, bật máy. Sau 3 giây menu tự vào cài đặt. **Mọi dữ liệu trên ổ đích được chọn tự động sẽ mất.** Các ổ khác bị khóa chỉ đọc trong phiên cài.
3. Máy tự cài Debian, tạo mật khẩu Linux riêng, cài GRUB rồi reboot. Có thể để nguyên USB: nếu tìm thấy marker của CameraWall đã cài, USB chuyển sang hệ điều hành đó, không cài/xóa lại.
4. Máy tự tải CameraWall alpha.29, các dependency AI và model, kiểm checksum rồi chạy dịch vụ. Đợi màn hình **CameraWall READY** hiển thị địa chỉ IP và mật khẩu ban đầu. Truy cập `http://IP` từ LAN bằng mật khẩu web được hiển thị. Mật khẩu Linux `cwadmin` khác mật khẩu web; không có mật khẩu chung trong ISO.

Mật khẩu ban đầu được hiển thị **chỉ trên màn hình gắn tại máy**, không ghi journal hoặc gửi mạng. Sau khi ghi lại và đổi mật khẩu, có thể tắt việc hiển thị bằng `sudo systemctl disable camerawall-console.service`. File lưu ban đầu chỉ root đọc được; sau khi đổi mật khẩu, những giá trị này không tự cập nhật.

Không có ổ phù hợp thì máy dừng an toàn; không chọn ổ nhỏ hơn 24 GiB hoặc ổ đang boot. Ổ chỉ đọc, đang mount hoặc có LVM/RAID đang hoạt động không phải đích được hỗ trợ. Không hỗ trợ Ventoy/loop/network boot: ghi ISO trực tiếp theo hướng dẫn flash. Nếu USB không xác định chắc chắn được ổ đang boot, nó dừng trước phân vùng.

Marker `/camerawall-installed.marker` cho phép giữ USB cắm nguyên sau cài, kể cả khi firstboot chưa tải xong app. Nếu đã có một hệ thống CameraWall mang marker trên các ổ gắn kèm, USB ưu tiên boot hệ thống đó. Không tự tái cài hoặc tự chọn ổ khác khi boot hệ thống đã cài bị lỗi. Muốn cài lại phải xử lý có chủ đích hệ thống/marker cũ; không có tái cài phá dữ liệu tự động mỗi lần bật nguồn.

Bản này vẫn là máy chủ headless, không cài native HDMI/desktop. Runtime AI CPU và model được provision trước READY; recording mặc định ở `/var/lib/camerawall/recordings` trên ổ system. Các ổ còn lại không được format/mount làm recording.

Lệnh kiểm tra khi cần bảo trì:

```sh
sudo systemctl status camerawall-firstboot
sudo journalctl -u camerawall-firstboot -b
sudo cat /var/lib/camerawall-usb/complete
hostname -I
sudo cat /etc/camerawall/initial-admin-password
sudo cat /var/lib/camerawall-usb/linux-password
```

## Mất mạng, lỗi và phục hồi

- **Trước khi máy tự ghi phân vùng:** khắc phục mạng/driver hoặc tắt máy và thử lại. Bộ cài không yêu cầu xác nhận: khi đã xác định và bảo vệ đúng ổ boot, nó tự phân vùng ổ đích.
- **Đang cài Debian:** thử lại bước tải tại màn hình lỗi. Nếu mất điện sau khi máy đã bắt đầu ghi ổ, OS cũ có thể không còn khởi động được. Boot USB để kiểm tra tình trạng cài dở. Khi chưa có marker, USB có thể cài lại ổ nhỏ nhất theo cùng chính sách và xóa nó lần nữa. Khi đã có marker, USB boot hệ thống hiện có. Không gọi đây là resume phân vùng hay rollback.
- **Debian đã boot, CameraWall tải/cài lỗi:** không boot USB để xóa ổ lần nữa. Khôi phục Ethernet/DNS/giờ hệ thống rồi chạy:

```sh
sudo journalctl -u camerawall-firstboot -b --no-pager
sudo systemctl restart camerawall-firstboot
```

File tải dở nằm trong `/var/lib/camerawall-usb/`; curl thử nối tiếp và retry. Nếu server không hỗ trợ Range, tải lại từ đầu. Sai SHA-256 thì không chạy gói; file `.part` lỗi bị loại. Trạng thái thành công chỉ ghi sau khi dịch vụ và HTTP đều sẵn sàng. Nếu cài app đã bắt đầu nhưng lỗi ở giữa, lưu log trước khi xử lý; không xóa database/config để “sửa nhanh”. Trường hợp state tạo dở cần đánh giá riêng, không có bảo đảm rollback tự động.

- **Không có ổ phù hợp:** màn hình dừng an toàn; tắt máy, kiểm tra chế độ storage/UEFI và dây cáp, rồi thử lại. Không chuyển sang phân vùng thủ công để vượt bảo vệ.
- **Không có Ethernet/firmware:** dùng NIC được Debian 12 hỗ trợ hoặc kiểm tra firmware chính thức; không tự tải driver từ nguồn lạ. Kernel Debian 12 có thể không hỗ trợ thin client rất mới.
- **Không mở được web:** xem `hostname -I`, IP DHCP trong router, `systemctl status camerawall camerawall-media`, và `journalctl -u camerawall`. `active` riêng lẻ chưa chứng minh HTTP/video đã sẵn sàng.
- **Không boot USB:** flash lại bằng DD/image mode, kiểm checksum, chọn UEFI, tắt Secure Boot, thử cổng USB khác. Không hỗ trợ ARM/Raspberry Pi trong bản này.

Không cần Internet cho xem/ghi camera LAN sau khi đã READY. Tác vụ auto-download CameraWall được tắt trong bản USB; admin chủ động cập nhật. Cần NTP hoặc đồng hồ máy chính xác để timestamp camera đáng tin cậy.

## Nguồn, bảo mật và phạm vi kiểm chứng

Xem `USB-VALIDATION.md`, `BUILD-INFO.json`, `DEBIAN-SIGNATURE.txt`, `BOOT-LAYOUT.txt` và `SHA256SUMS` đính kèm release. ISO này là bản tùy biến CameraWall, không phải ISO nguyên gốc do Debian phát hành.

Nguồn Debian: [Debian 12 installer](https://www.debian.org/releases/bookworm/debian-installer/), [ISO 12.15](https://cdimage.debian.org/cdimage/archive/12.15.0/amd64/iso-cd/), [kiểm chữ ký Debian](https://www.debian.org/CD/verify). Build xác minh chữ ký checksum bằng Debian CD key fingerprint `DF9B9C49EAA9298432589D76DA87E80D6294BE9B`, rồi kiểm SHA-256 ISO. Debian Installer/APT xác minh chữ ký kho và hash gói; không tắt xác minh APT dù mirror dùng HTTP. CameraWall dùng HTTPS và SHA-256 ghim trong ISO, kiểm thêm source commit trong archive; đây không phải chữ ký phát hành độc lập của CameraWall.

Debian/firmware giữ giấy phép upstream; copyright và license của các gói được cài nằm ở `/usr/share/doc/*/copyright`. Mã nguồn Debian tương ứng có tại [Debian package pool](https://deb.debian.org/debian/pool/) và [Debian snapshot](https://snapshot.debian.org/). CameraWall giữ license/third-party notices trong archive và `/opt/camerawall/`. Scripts của bộ USB nằm công khai trong repo release dưới giấy phép `usb/LICENSE`.

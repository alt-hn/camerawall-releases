# CameraWall USB Creator — cài offline

**Bản đầu để thử trên máy thật: chưa kiểm chứng trọn vẹn cài offline tới khi CameraWall chạy.**

**Chỉ tải app Creator cho macOS hoặc Windows. Không cần tải ISO CameraWall.**
App kiểm tra bản CameraWall công khai mới nhất trên GitHub mỗi lần tạo USB,
lấy backend và renderer HDMI cùng phiên bản, rồi kiểm SHA-256. Cache chỉ được
dùng khi khớp gói đã chọn. Nếu không xác định được bản mới nhất, app dừng.
USB đã tạo có thể cài offline. Sau khi cài, vào **Settings → Local display**
và chọn **Hybrid** hoặc **Display** để bật màn hình HDMI.

## Tạo USB

1. Mở app đúng hệ điều hành: Mac Apple Silicon, Mac Intel hoặc Windows x64.
   App Go biên dịch sẵn, không cần Python, Rufus hoặc Etcher.
   Mac cần macOS 13 trở lên; Windows 10/11 cần WebView2 runtime. Máy tạo USB cần Internet.
2. Cắm USB **tối thiểu 2 GiB thực** (khuyến nghị 4 GB trở lên), bấm **Quét lại**,
   chọn đúng tên và dung lượng. Ổ hệ thống/boot của máy tạo USB bị loại trừ.
3. Bấm **Xóa USB và tạo bộ cài**. Toàn bộ dữ liệu trên USB được chọn sẽ mất.
   Trên Mac, app xin quyền cho đúng USB trước khi tải; cho phép truy cập ổ rời
   khi macOS hỏi. App tải, kiểm checksum, ghép bộ cài cục bộ rồi ghi trực tiếp.
   Windows xin quyền quản trị trước khi khóa volume và ghi.
4. Giữ USB cắm nguyên tới khi app đọc lại vùng image và báo checksum khớp.
   Windows có thể đề nghị format phân vùng không nhận diện được: chọn Cancel.
   macOS có thể báo “disk not readable”: chọn Ignore, không Initialize.

Dữ liệu tải lần đầu khoảng **1,1 GiB**, ảnh USB tạo cục bộ khoảng **1,15 GiB**;
đây là bộ cài đầy đủ cho offline, không phải dung lượng của app Creator.
Nên để trống ít nhất 4 GiB trên máy tạo USB cho cache và file tạm. Lần sau app
kiểm tra/tái sử dụng cache, nối tiếp file tải dở. Không tự bỏ qua checksum.

## Cắm vào máy CameraWall

- Đích cài là **Intel/AMD x86-64 UEFI**, tối thiểu 2 GB RAM. Mac Apple Silicon
  có thể tạo USB nhưng không phải đích cài hệ điều hành này. Secure Boot chưa
  được kiểm chứng; dùng UEFI, tắt Secure Boot và ưu tiên boot USB trong firmware.
- **Không cần Internet hoặc Ethernet trong quá trình cài.** USB chứa Debian,
  FFmpeg/Python, CameraWall và toàn bộ wheel/model AI cần thiết.
- Bật máy: USB tự cài không cần bấm phím. **Tự xóa toàn bộ ổ nhỏ nhất đủ 24 GiB
  ngoài ổ đang boot**; nếu bằng dung lượng, chọn theo tên thiết bị Linux. Các ổ
  khác được khóa chỉ đọc trong phiên cài. Không có ổ hợp lệ thì dừng.
- Từ Creator 2.0.1, bộ cài mặc định mở giao diện đồ họa và hiện tiến độ kiểm
  SHA-256 của các tệp trên USB. Nếu kiểm tra thất bại, bộ cài báo lỗi và dừng
  trước khi phân vùng. Cảnh báo hiện tên và
  dung lượng ổ đích, đếm ngược **10 giây** rồi tiếp tục nếu bạn không bấm **Cancel**.
  Từ Creator 2.0.4, giao diện đồ họa đặt các nút trong vùng có lề của
  1024×600, kể cả khi framebuffer báo 1024×768. Có thể chọn **Install with
  text console** ở menu boot khi cần.
- Máy tự reboot và chạy CameraWall bằng root. Giữ USB cắm nguyên không gây cài
  lại khi đã có dấu nhận diện hệ thống. Với USB tạo bằng Creator 2.0.2, chọn
  **UEFI: tên USB** trong menu boot của máy. Menu CameraWall hiện 10 giây và
  mặc định chọn **Boot installed CameraWall**. Chọn **Install / reinstall
  CameraWall (erases target disk)** nếu muốn cài lại. Mất điện trước khi có
  dấu nhận diện có thể dẫn tới một lần cài mới.
- Màn hình hiện READY và mật khẩu. Cắm Ethernet có DHCP để nhận IP và dùng UI
  CameraWall từ một máy khác trong LAN. Internet chỉ cần khi kiểm tra/tải update.
- Khi màn hình hiện `Boot check: pending`, tắt máy, rút USB cài rồi bật lại.
  Màn hình hiện `Boot check: PASS` khi Debian đã khởi động qua UEFI với phân
  vùng hệ thống và EFI trên cùng ổ, không qua GRUB của USB cài. Nếu firmware
  báo không tìm thấy hệ điều hành, cắm lại USB để vào bản đã cài và kiểm tra
  thứ tự boot UEFI.

## Cập nhật về sau

Dùng phần cập nhật trong UI CameraWall; cập nhật app thông thường không cần tạo
lại USB. Chế độ tự động mặc định Off, timer vẫn sẵn sàng cho lựa chọn trong UI.
Profile backend root nằm riêng trong systemd drop-in, giữ qua cập nhật thay unit.
Tính năng quản trị mới phải được triển khai trong CameraWall thì mới có UI dùng;
root không tự tạo giao diện cho mọi lệnh hệ điều hành. Media service vẫn có user riêng.

Các gói Debian và AI vẫn được ghim SHA-256. **Chế độ cài online riêng để
bổ sung sau**; bản Creator này mặc định offline và không tự fallback sang mạng.
Các ISO `usb-v*` cũ là luồng Internet installer riêng, không phải đầu vào Creator.

## Phạm vi phát hành

Các gói .app/.exe kèm runtime, nguồn và workflow build công khai. Xem
[kiểm chứng Creator](USB-CREATOR-2-VALIDATION.md) để phân biệt kiểm tra VM, build
native và USB vật lý. Lần flash do chủ thiết bị chạy trên DataTraveler 3.0 đã
qua cả ghi và đọc lại checksum; cài hoàn chỉnh trên máy đích vẫn cần kiểm chứng.

Gói macOS 2.0.1 trên GitHub chưa được Apple notarize. Bản Windows 2.0.0 chưa có chữ ký Authenticode.

## Theo dõi tiến độ

Giao diện có bảy giai đoạn riêng. Mỗi file hiển thị dung lượng, tiến độ và trạng
thái tải/cache/checksum; thao tác có nhật ký, tốc độ và thời gian đã chạy. Phần trăm
chỉ hiển thị khi biết tổng dữ liệu; hộp thoại hệ điều hành và metadata không có tổng
sẽ hiện trạng thái chờ. Có thể dừng chuẩn bị và thử lại từ cache; không dừng giữa lúc
ghi/đọc lại USB. Windows xin quyền sau khi chuẩn bị, ngay trước khi ghi.

## Ngôn ngữ

App tự chọn VI khi ngôn ngữ chính của máy là tiếng Việt, EN cho các ngôn ngữ khác.
Đổi EN/VI ở góc trên; lựa chọn được lưu cho lần mở sau. Không đổi ngôn ngữ bộ cài Debian.

## Bổ sung HDD helper cho máy đã cài

Không cần cài lại Debian. Dùng gói backend Linux amd64 có cùng phiên bản với
kết quả của `/opt/camerawall/bin/camerawall --version`. Kiểm SHA-256 từ GitHub
Releases, giải nén gói và chép script `usb/install-host-runtime.sh` vào máy.
Trên máy CameraWall, chạy (thay đường dẫn bằng thư mục đã giải nén):

```sh
sudo bash install-host-runtime.sh /path/to/extracted/camerawall_VERSION_linux_amd64
sudo systemctl daemon-reload
sudo systemctl restart camerawall-host.service camerawall.service
sudo curl --fail --unix-socket /run/camerawall-host/control.sock http://host/status
```

Sau đó mở lại **Settings → Storage**. Các lệnh này cài dịch vụ và đọc trạng
thái, không chọn, format hay di chuyển HDD. Nếu hệ thống đã có lịch sử ghi
hình, việc chuyển sang HDD khác cần quy trình di chuyển riêng.

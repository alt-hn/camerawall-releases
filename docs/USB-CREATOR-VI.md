# CameraWall USB Creator 1.0.0 — cài offline

**Bản đầu để thử trên máy thật: chưa kiểm chứng trọn vẹn cài offline tới khi CameraWall chạy.**

**Chỉ tải app Creator cho macOS hoặc Windows. Không cần tải ISO CameraWall.**
App tự lấy Debian chính thức, gói phụ thuộc, CameraWall alpha.40 và AI từ các
nguồn đã ghim SHA-256, rồi tạo USB bootable ngay trên máy bạn.

## Tạo USB

1. Mở app đúng hệ điều hành: Mac Apple Silicon, Mac Intel hoặc Windows x64.
   Không cần cài Python, Rufus hoặc Etcher. Máy tạo USB cần Internet.
2. Cắm USB **tối thiểu 2 GiB thực** (khuyến nghị 4 GB trở lên), bấm **Quét lại**,
   chọn đúng tên và dung lượng. Ổ hệ thống/boot của máy tạo USB bị loại trừ.
3. Bấm **Xóa USB và tạo bộ cài**. Toàn bộ dữ liệu trên USB được chọn sẽ mất.
   App tải và kiểm checksum từng thành phần, ghép bộ cài cục bộ, rồi xin quyền
   quản trị macOS/Windows để unmount/khóa volume và ghi trực tiếp boot image.
4. Giữ USB cắm nguyên tới khi app đọc lại vùng image và báo checksum khớp.
   Windows có thể đề nghị format phân vùng không nhận diện được: chọn Cancel.

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
- Máy tự reboot và chạy CameraWall bằng root. Giữ USB cắm nguyên không gây cài
  lại khi marker hệ điều hành đã cài tồn tại. Mất điện trước khi có marker có thể
  dẫn tới một lần cài mới; không có rollback phân vùng.
- Màn hình hiện READY và mật khẩu. Cắm Ethernet có DHCP để nhận IP và dùng UI
  CameraWall từ một máy khác trong LAN. Internet chỉ cần khi kiểm tra/tải update.

## Cập nhật về sau

Dùng phần cập nhật trong UI CameraWall; cập nhật app thông thường không cần tạo
lại USB. Chế độ tự động mặc định Off, timer vẫn sẵn sàng cho lựa chọn trong UI.
Profile backend root nằm riêng trong systemd drop-in, giữ qua cập nhật thay unit.
Tính năng quản trị mới phải được triển khai trong CameraWall thì mới có UI dùng;
root không tự tạo giao diện cho mọi lệnh hệ điều hành. Media service vẫn có user riêng.

Creator ghim bộ thành phần đã kiểm chứng; nếu upstream thay/xóa gói ghim, cần bản
Creator cập nhật. Không âm thầm đổi sang gói khác. **Chế độ cài online riêng để
bổ sung sau**; bản Creator này mặc định offline và không tự fallback sang mạng.
Các ISO `usb-v*` cũ là luồng Internet installer riêng, không phải đầu vào Creator.

## Phạm vi phát hành

Các gói .app/.exe kèm runtime, nguồn và workflow build công khai. Xem
[kiểm chứng Creator](USB-CREATOR-VALIDATION.md) để phân biệt kiểm tra VM, build
native và USB vật lý. Không có ổ thật nào được flash trong quá trình phát triển.

Bản đầu chưa có chữ ký Developer ID/notarization của Apple hoặc Authenticode của
Windows; hệ điều hành có thể cảnh báo/chặn app tải từ Internet. Không tự sử dụng
chứng chỉ của sản phẩm khác và không tuyên bố app đã ký phát hành.

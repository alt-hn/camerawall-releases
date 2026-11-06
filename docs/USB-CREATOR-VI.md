# CameraWall USB Creator 1.0.0

App tạo **USB boot được**, dành cho macOS Apple Silicon, macOS Intel và Windows x64.
Không cần cài Python, tải ISO thủ công, Rufus hoặc Etcher.

1. Mở app đúng hệ điều hành, cắm USB tối thiểu 2 GiB và bấm **Quét lại**.
2. Chọn đúng tên/dung lượng USB. Bấm **Xóa USB và tạo bộ cài** — toàn bộ dữ liệu
   trên USB này sẽ mất. Không tự chọn sẵn thiết bị.
3. App tải/nối tiếp tải ISO đã ghim từ GitHub, kiểm SHA-256 rồi xin quyền quản trị
   của macOS/Windows. Chấp nhận yêu cầu quyền ghi USB bằng tài khoản quản trị.
4. App unmount/khóa volume, ghi trực tiếp boot image, flush và đọc lại toàn bộ
   vùng ISO để kiểm checksum. Chỉ báo xong khi đọc lại khớp. Giữ USB cắm nguyên.
5. Khi báo hoàn tất, tháo USB; Windows có thể hiện yêu cầu format vì không nhận
   filesystem của bộ cài — chọn Cancel, không format lại.
6. Cắm vào máy CameraWall Intel/AMD x86-64 UEFI đã ưu tiên boot USB, nối Ethernet
   có DHCP/Internet và bật máy. Bộ cài tự xóa ổ nhỏ nhất đủ 24 GiB ngoài ổ USB boot,
   cài Debian + CameraWall alpha.40, rồi chạy backend bằng root. Màn hình máy đích
   hiển thị IP/mật khẩu. Giữ USB cắm nguyên khi reboot không kích hoạt cài lại.

**Mac là máy tạo USB, không phải đích cài CameraWall trên Apple Silicon.**
App chỉ liệt kê ổ vật lý qua USB, loại trừ ổ hệ thống/boot, ổ chỉ đọc và sector 4K.
Nếu rút/đổi thiết bị sau khi chọn, bộ ghi kiểm lại danh tính và từ chối khi khác.
Không có ô nhập đường dẫn thiết bị tùy ý hoặc tùy chọn bỏ qua bảo vệ.

## Cập nhật về sau

Dùng phần cập nhật trong UI CameraWall. Cập nhật app bình thường không cần tạo
lại USB. Profile root của bản appliance nằm riêng trong service drop-in và được
giữ qua việc thay file service khi nâng cấp. Một tính năng quản trị mới cần được
triển khai trong CameraWall thì mới thao tác được qua UI; chạy root không tự tạo
ra UI cho mọi lệnh hệ điều hành.

USB Creator 1.0.0 ghim ISO usb-v0.3.0 và alpha.40 (latest được kiểm tra khi build),
không âm thầm chọn image mới khác checksum. App Creator mới sẽ ghim image mới;
CameraWall đã cài dùng updater riêng.

## Phạm vi kiểm tra và đóng gói

Đã kiểm logic truyền file/ghi/đọc lại và bảo vệ lựa chọn bằng fixture; ghi ISO thật
vào file USB mô phỏng và boot bằng QEMU UEFI. CameraWall alpha.40 đã đạt READY
với UID 0 trong VM, giữ root sau chạy lại install.sh --upgrade. Không flash ổ thật.
Các file .app/.exe đóng gói kèm Python/Tk; mã nguồn và workflow build nằm trong repo.
Xem USB-VALIDATION.md và metadata riêng từng gói để biết OS/kiến trúc thực tế.

Bản đầu chưa có chữ ký Developer ID/notarization của Apple hay Authenticode của
Windows; hệ điều hành có thể chặn hoặc cảnh báo app tải từ Internet. Không tuyên
bố bản đã ký hay trải nghiệm mở app không cảnh báo. Việc cấp chứng chỉ/ký phát hành
cần thông tin phát hành tương ứng; không tự sử dụng chứng chỉ của ứng dụng khác.

Chưa xác minh ghi USB vật lý trên macOS/Windows, hộp thoại cấp quyền trên mọi OS,
Secure Boot hoặc khả năng boot của mọi thin client. Ghi dở do rút USB/mất điện cần
chạy lại; đọc lại checksum xác minh vùng image, không phải kiểm sức khỏe toàn bộ USB.

// Vietnamese source strings are kept intact; localization is presentation-only.
const english = {
  "CÁC BƯỚC": "STEPS",
  "CÀI OFFLINE": "OFFLINE INSTALL",
  "Thông tin bộ cài": "Installer details",
  "THIẾT LẬP MÁY CAMERAWALL": "SET UP CAMERAWALL",
  "Tải thành phần cần thiết, tạo bộ cài và kiểm tra USB trong một quy trình.": "Download components, create the installer and verify your USB in one workflow.",
  "USB đích": "Target USB",
  "Đang tìm thiết bị…": "Finding devices…",
  "Chỉ hiện USB ngoài máy; ổ hệ thống được loại trừ.": "External USB devices only; system disks are excluded.",
  "Quét lại": "Refresh",
  "USB được chọn sẽ bị xóa toàn bộ.": "All data on the selected USB will be erased.",
  "Khi boot USB, chọn Auto để tự cài hoặc Manual để tự chọn ổ đích.": "At USB boot, choose Auto to install automatically or Manual to select the destination disk.",
  "CHƯA BẮT ĐẦU": "NOT STARTED",
  "Chọn USB để bắt đầu": "Select a USB to begin",
  "Tiến độ thao tác hiện tại": "Current action progress",
  "Dữ liệu tải được giữ trong cache để thử lại.": "Downloads stay cached for reuse.",
  "macOS có thể báo “disk not readable” khi thấy phân vùng Linux. Chọn ": "macOS may report “disk not readable” for Linux partitions. Choose ",
  ", không Initialize. Chỉ tháo USB khi bước đọc lại báo thành công.": ", not Initialize. Remove the USB only after readback succeeds.",
  "Không cần tải ISO CameraWall riêng.": "No separate CameraWall ISO download needed.",
  "Dừng chuẩn bị": "Stop preparation",
  "Xóa USB và tạo bộ cài": "Erase USB & create installer",
  "Thành phần": "Components",
  "Nhật ký thao tác": "Activity log",
  "Danh sách và tiến độ từng file sẽ hiện khi bắt đầu.": "Individual files and progress appear when you start.",
  "Đang kết nối bộ điều khiển…": "Connecting to the backend…",
  "Bộ cài offline": "Offline installer",
  "Máy tạo USB cần Internet. USB tạo xong chứa Debian, CameraWall và các gói AI để cài không cần mạng.": "The USB creation computer needs Internet. The finished USB contains Debian, CameraWall and AI packages for installation without a network.",
  "Máy đích: Intel/AMD x86-64, UEFI, tắt Secure Boot. Ưu tiên boot USB trong firmware. Backend CameraWall được cấu hình chạy root.": "Target: Intel/AMD x86-64, UEFI, Secure Boot disabled. Set USB boot priority in firmware. The CameraWall backend is configured to run as root.",
  "Chưa xác nhận cài offline trọn vẹn trên máy thật.": "A complete offline installation on physical hardware is not yet verified.",
  "Đây là bản đang được chủ thiết bị kiểm tra.": "This build is being tested by the device owner.",
  "Cache trên máy này:": "Cache on this computer:",
  "App không tự xóa cache sau khi tạo USB để lần sau không cần tải lại. Không rút USB trong lúc ghi hoặc kiểm tra.": "The app keeps its cache for the next run. Do not unplug the USB while writing or verifying.",
  "Giấy phép thành phần": "Component licenses",
  "Đã hiểu": "Got it",
  "Đang chờ": "Pending",
  "Có trong cache": "Cached",
  "Đang tải": "Downloading",
  "Đã tải": "Downloaded",
  "Kiểm checksum": "Checking checksum",
  "Đã xác minh": "Verified",
  "Đang thử lại": "Retrying",
  "Lỗi": "Error",
  "Chưa hoàn tất": "Incomplete",
  "Cần xử lý": "Needs attention",
  "Đang xử lý": "Working",
  "Hoàn tất": "Complete",
  "Sẵn sàng": "Ready",
  "Thử lại từ cache": "Retry from cache",
  "Dừng trước khi ghi; giữ cache để tiếp tục": "Stop before writing; keep cache to resume",
  "Không dừng giữa lúc ghi hoặc đọc lại USB": "Cannot stop during USB write or readback",
  "Đang thực hiện": "In progress",
  "HOÀN TẤT": "COMPLETE",
  " thao tác": " actions",
  "Còn khoảng ": "About ",
  "Đang chờ hệ điều hành / xử lý metadata": "Waiting for the OS / processing metadata",
  "Đã chạy ": "Elapsed ",
  " đã xác minh": " verified",
  "Đang cập nhật tiến độ trực tiếp": "Updating progress live",
  "Checksum USB khớp — có thể tháo thiết bị": "USB checksum matches — safe to remove",
  "Chọn đúng thiết bị trước khi tạo USB": "Check the selected device before creating the USB",
  "Đang đọc danh sách USB từ hệ điều hành…": "Reading USB devices from the OS…",
  "Chọn USB…": "Select a USB…",
  "Không tìm thấy USB phù hợp": "No eligible USB found",
  "Cắm USB và quét lại. Yêu cầu ít nhất 2 GiB, sector 512 byte.": "Connect a USB and refresh. Requires at least 2 GiB and 512-byte sectors.",
  "Không kết nối được backend. Hãy mở lại app.": "Cannot connect to the backend. Reopen the app.",
  " giây": " sec",
  " phút ": " min ",
  "Cấp quyền USB": "Authorize USB",
  "Tải thành phần": "Download components",
  "Kiểm tra checksum": "Verify checksums",
  "Tạo bộ cài bootable": "Create bootable installer",
  "Ghi USB": "Write USB",
  "Đọc lại kiểm tra": "Verify USB readback",
  "Đang xử lý USB": "USB operation in progress",
  "USB đã sẵn sàng. Toàn bộ dữ liệu ghi đã đọc lại đúng checksum.": "USB is ready. All written data passed checksum readback.",
  "Đang ghi/kiểm tra USB; hãy chờ hoàn tất": "Writing/verifying USB; wait until complete",
  "Đang dừng; giữ các file tải dở để thử lại": "Stopping; keeping partial downloads for retry",
  "Kiểm tra bản CameraWall mới nhất trên GitHub": "Checking GitHub for the latest CameraWall release",
  "Kiểm tra SHA-256 toàn bộ dữ liệu": "Verifying SHA-256 of all data",
  "Kiểm tra ": "Checking ",
  "Checksum không khớp; đã bỏ file lỗi": "Checksum mismatch; removed the invalid file",
  "checksum không khớp: ": "checksum mismatch: ",
  "; thử lại để tải lại file này": "; retry to download this file again",
  "Checksum đúng": "Checksum matches",
  "USB đã thay đổi, bị rút hoặc không còn an toàn. Hãy quét và chọn lại": "The USB changed, was removed or is no longer safe. Refresh and select it again",
  "dữ liệu thiếu ở byte ": "missing data at byte ",
  "nguồn tải không hợp lệ": "invalid download source",
  "Đã có trong cache; sẽ kiểm checksum": "Already cached; checksum verification pending",
  "từ chối chuyển hướng không dùng HTTPS": "refusing a non-HTTPS redirect",
  "quá nhiều chuyển hướng": "too many redirects",
  "Đã tải; chờ kiểm checksum": "Downloaded; checksum verification pending",
  "Thử lại ": "Retry ",
  "Content-Range không khớp dữ liệu đã ghim": "Content-Range does not match pinned data",
  "máy chủ gửi dữ liệu lớn hơn dung lượng đã ghim": "server sent more data than the pinned size",
  "Kiểm tra nguồn lần cuối trước khi ghi": "Final source verification before writing",
  "Kiểm tra nguồn trước khi ghi": "Verifying source before writing",
  "ảnh bộ cài đã thay đổi; chưa ghi USB": "installer image changed; USB has not been written",
  "Đang ghi USB — không rút thiết bị": "Writing USB — do not unplug",
  "Đang flush dữ liệu xuống thiết bị": "Flushing data to the device",
  "Đọc lại USB và đối chiếu SHA-256": "Reading USB back and comparing SHA-256",
  "Đang đọc lại từng byte từ USB": "Reading back every byte from USB",
  "USB đọc lại không khớp checksum; chưa thể dùng để cài": "USB readback checksum mismatch; do not use it to install",
  "gói Debian không hợp lệ": "invalid Debian package",
  "ar header không hợp lệ": "invalid ar header",
  "control archive quá lớn": "control archive too large",
  "control quá lớn": "control data too large",
  "Tạo initramfs và kho gói cài offline": "Creating initramfs and offline package repository",
  "Lập kho gói: ": "Indexing packages: ",
  "Tạo phân vùng dữ liệu FAT32": "Creating FAT32 data partition",
  "Thêm ": "Adding ",
  "Đóng gói ": "Packaging ",
  "Tạo ảnh boot từ Debian chính thức": "Creating boot image from official Debian media",
  "Cấu hình boot tự động và checksum media": "Configuring automatic boot and media checksums",
  "Ghép phân vùng bộ cài vào ảnh USB": "Appending installer partition to USB image",
  "Kiểm tra ảnh bootable vừa tạo": "Verifying the created bootable image",
  "ISO file không có extent": "ISO file has no extent",
  "boot menu vượt extent ISO gốc": "boot menu exceeds original ISO extent",
  "MD5 manifest không hợp lệ": "invalid MD5 manifest",
  "MD5 manifest thay đổi dung lượng": "MD5 manifest size changed",
  "Debian GPT hybrid không hợp lệ": "invalid Debian hybrid GPT",
  "GPT layout không hỗ trợ": "unsupported GPT layout",
  "GPT có phân vùng thứ ba; từ chối ghi đè": "GPT has a third partition; refusing to overwrite",
  "payload đè lên GPT backup": "payload overlaps backup GPT",
  "không đọc được danh sách USB Windows: ": "cannot read Windows USB list: ",
  "USB không đủ dung lượng": "USB capacity is insufficient",
  "Cho phép Windows Administrator để ghi USB": "Allow Windows administrator access to write USB",
  "Windows chưa cấp quyền hoặc bộ ghi không khởi động: ": "Windows permission denied or writer failed to start: ",
  "kết nối helper không hợp lệ": "invalid helper connection",
  "helper kết thúc trước khi xác nhận checksum USB": "helper exited before confirming USB checksum",
  "Ghi và đọc lại USB thành công": "USB write and readback succeeded",
  "Có thể tháo USB an toàn": "Safe to remove USB",
  "job không hợp lệ": "invalid job",
  "cần quyền Administrator": "administrator permission required",
  "volume USB không hợp lệ": "invalid USB volume",
  "thiết bị không phản hồi trong 30 giây; kiểm tra cổng/cáp USB rồi quét lại": "device did not respond within 30 seconds; check the USB port/cable and refresh",
  "không đọc được thông tin thiết bị": "cannot read device information",
  "device ID không hợp lệ": "invalid device ID",
  "macOS chưa cấp quyền cho USB. Cho phép truy cập ổ rời khi hệ thống hỏi; nếu đã từ chối, kiểm tra Privacy & Security → Files and Folders.": "macOS has not authorized this USB. Allow removable-volume access when prompted; if previously denied, check Privacy & Security → Files and Folders.",
  "USB thay đổi trong khi xin quyền": "USB changed during authorization",
  "Cho phép macOS truy cập USB đã chọn": "Allow macOS access to the selected USB",
  "Đã cấp quyền cho ": "Authorized ",
  "Đang eject USB an toàn": "Safely ejecting USB",
  "không sử dụng helper Windows trên macOS": "Windows helper is not used on macOS",
  "Chỉ hỗ trợ macOS và Windows": "Only macOS and Windows are supported"
};
const languageFor = locale => /^vi(?:[-_]|$)/i.test(locale || '') ? 'vi' : 'en';
let language = languageFor(navigator.language);
try { const saved=localStorage.getItem('creator-language'); if(['en','vi'].includes(saved)) language=saved; } catch {}
const escaped = Object.keys(english).sort((a,b)=>b.length-a.length).map(s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'));
const translationPattern = new RegExp(escaped.join('|'),'g');
function translate(text,lang=language) {
  if(lang==='vi') return text;
  return text.replace(/Tải (\d+) thành phần đã xác định/g,'Download $1 selected components')
    .replace(/tải ([^\n]+?): /g,'download $1: ')
    .replace(translationPattern, match=>english[match]);
}
const translatedNodes = new WeakMap();
const translatedAttributes = new WeakMap();
function localize() {
  document.documentElement.lang=language;
  const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
  let node;
  while((node=walker.nextNode())) {
    if(node.parentElement?.closest('script,style,#licenseText,#cachePath,.file-name,.file-meta,.file-size,#device option:not([value=""])')) continue;
    const previous=translatedNodes.get(node);
    const source=previous && node.nodeValue===previous.output ? previous.source : node.nodeValue;
    const output=translate(source);
    if(node.nodeValue!==output) node.nodeValue=output;
    translatedNodes.set(node,{source,output});
  }
  for(const element of document.querySelectorAll('[title],[aria-label]')) {
    for(const key of ['title','aria-label']) {
      if(!element.hasAttribute(key) || element.classList.contains('file-name')) continue;
      const attributes=translatedAttributes.get(element)||{},previous=attributes[key];
      const value=element.getAttribute(key);
      const source=previous && value===previous.output ? previous.source : value;
      const output=translate(source); if(value!==output) element.setAttribute(key,output);
      attributes[key]={source,output}; translatedAttributes.set(element,attributes);
    }
  }
  document.getElementById('language').value=language;
}
async function initLanguage(api) {
  let saved; try {saved=localStorage.getItem('creator-language')} catch {}
  if(!['en','vi'].includes(saved)) {try {language=languageFor(await api.SystemLanguage())}catch{}}
  localize();
}
document.getElementById('language').onchange=event=>{
  language=event.target.value;
  try {localStorage.setItem('creator-language',language)}catch{}
  localize();
};
// Includes asynchronous errors, scan results and live backend progress.
const localeObserver=new MutationObserver(localize);
localeObserver.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['title','aria-label']});
localize();

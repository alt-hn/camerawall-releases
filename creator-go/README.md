# CameraWall USB Creator 2.0 — compiled Go application

Go + Wails v2 desktop application for macOS ARM64/Intel and Windows x64. The UI uses
system WebKit/WebView2. No Python/Tk interpreter or browser runtime is bundled.
The separate Linux installer still provisions its required Python AI environment.

The application downloads pinned upstream Debian, CameraWall and AI components,
verifies SHA-256, constructs the FAT32/initramfs/hybrid boot image locally, writes
the selected USB and verifies a full readback. No CameraWall ISO is published.

Seven visible stages cover permission, download, checksum, composition, write,
readback and finish. Windows requests Administrator after preparation, before
writing. macOS uses Apple's authopen descriptor authorization for the selected USB
before downloading, with NSRemovableVolumesUsageDescription. The main UI remains
unprivileged. Each file has byte progress, cache/checksum state and error detail;
operation logs, transfer rate and elapsed time remain visible. A numeric percentage
is shown only when total work is known. Metadata/OS prompts are indeterminate.

Cancelled preparation retains partial downloads. Once raw writing starts,
cancellation and window close are disabled until completion/failure. Device identity
is revalidated immediately before writing; boot/system disks are excluded.

Build on the target native OS:

```
go test ./...
go install github.com/wailsapp/wails/v2/cmd/wails@v2.17.1
wails build -clean
go run ./tools/package
```

macOS 13+; Windows 10/11 with WebView2 runtime (the framework checks runtime
availability). The checked-in Go module versions and go.sum pin build dependencies.
`assets/offline` and `assets/runtime` carry the existing installer policy; compare
with the source files in `creator/offline` and `usb` when updating those scripts.
The older `creator/` tree is retained as historical Python implementation.

`--prepare-only` composes a local image using the normal cache without opening any
USB device. `--self-test` validates embedded manifests and exits. Neither mode
flashes physical disks. Native Windows CI writes only a newly created, explicitly
associated temporary VHD. Local composition validation reads every payload file
back from the generated FAT filesystem and checks its pinned digest.

Full offline installation on a physical machine remains unvalidated. The installer
automatically erases the smallest eligible non-boot disk >=24 GiB and configures
CameraWall root. Packages are not Developer ID/notarized or Authenticode signed;
local ad-hoc signing is not a trusted publisher signature.

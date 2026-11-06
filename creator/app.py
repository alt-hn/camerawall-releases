"""CameraWall USB Creator: native Tk UI and a narrowly scoped elevated writer."""
import json
import os
from pathlib import Path
import platform
import queue
import sys
import threading

ROOT = Path(getattr(sys, '_MEIPASS', Path(__file__).parent))
MANIFEST = json.loads((ROOT / 'image.json').read_text())


def main():
    if sys.argv[1:] == ['--self-test']:
        import tkinter as tk
        import core, devices, worker, prepare
        assert MANIFEST['mode'] == 'offline' and (ROOT / 'offline/sources.json').is_file()
        root = tk.Tk()
        root.update()
        root.destroy()
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == '--write':
        try:
            from worker import execute
            execute(sys.argv[2], MANIFEST)
        except Exception as error:
            if platform.system() == 'Windows':
                import ctypes
                ctypes.windll.user32.MessageBoxW(None, str(error), 'CameraWall — không thể ghi USB', 0x10)
            elif sys.stderr:
                print(str(error), file=sys.stderr)
            return 1
        return 0
    import tkinter as tk
    from tkinter import ttk, messagebox
    from prepare import prepare
    from devices import discover, revalidate
    from worker import elevated

    root = tk.Tk()
    root.title('CameraWall USB Creator')
    root.geometry('760x700')
    root.minsize(720, 680)
    root.configure(background='#f4f7fb')
    style = ttk.Style(root)
    style.theme_use('clam')
    style.configure('TFrame', background='#f4f7fb')
    style.configure('TLabel', background='#f4f7fb', foreground='#172b4d', font=('Arial', 13))
    style.configure('Title.TLabel', font=('Arial', 26, 'bold'))
    style.configure('Subtitle.TLabel', foreground='#475569')
    style.configure('TButton', font=('Arial', 13), padding=(14, 10))
    style.configure('TProgressbar', background='#2563eb', troughcolor='#e2e8f0')
    style.configure('TCombobox', font=('Arial', 13), padding=8)
    style.configure('Warning.TLabel', foreground='#9f270d')
    panel = ttk.Frame(root, padding=32)
    panel.pack(fill='both', expand=True)
    ttk.Label(panel, text='CameraWall', style='Title.TLabel').pack(anchor='w')
    ttk.Label(panel, text='Tạo USB cài đặt offline', font=('Arial', 19)).pack(anchor='w', pady=(6, 16))
    ttk.Label(panel, text=f"{MANIFEST['installer']}  ·  CameraWall {MANIFEST['application']}  ·  x86-64 UEFI", style='Subtitle.TLabel').pack(anchor='w')
    ttk.Separator(panel).pack(fill='x', pady=20)
    ttk.Label(panel, text='1. Chọn USB để ghi bộ cài').pack(anchor='w', pady=(0, 8))
    row = ttk.Frame(panel)
    row.pack(fill='x')
    selection = ttk.Combobox(row, state='readonly', width=45)
    selection.pack(side='left', fill='x', expand=True)
    refresh = ttk.Button(row, text='Quét lại')
    refresh.pack(side='left', padx=(10, 0))
    ttk.Label(panel, text='Chỉ hiện USB ngoài máy, tối thiểu 2 GiB. Ổ hệ thống được loại trừ.', style='Subtitle.TLabel', wraplength=650).pack(anchor='w', pady=(8, 18))
    warning = ttk.Label(panel, text='Toàn bộ dữ liệu trên USB được chọn sẽ bị xóa.', style='Warning.TLabel', wraplength=650)
    warning.pack(anchor='w')
    start = ttk.Button(panel, text='Xóa USB và tạo bộ cài', state='disabled')
    start.pack(fill='x', pady=(12, 18))
    status = tk.StringVar(value='Đang tìm USB…')
    ttk.Label(panel, textvariable=status, wraplength=650).pack(anchor='w')
    progress = ttk.Progressbar(panel, maximum=100)
    progress.pack(fill='x', pady=(10, 18))
    ttk.Separator(panel).pack(fill='x', pady=(0, 18))
    ttk.Label(panel, text='2. Cắm USB vào máy CameraWall và bật máy', font=('Arial', 14, 'bold')).pack(anchor='w')
    ttk.Label(panel, text='Máy cần ưu tiên boot USB và UEFI. Cài offline, không cần Internet. Bộ cài tự xóa ổ nhỏ nhất đủ 24 GiB ngoài USB boot, rồi chạy CameraWall bằng root. Các ổ còn lại được giữ nguyên.', style='Subtitle.TLabel', wraplength=650).pack(anchor='w', pady=(8, 0))
    events = queue.Queue()
    state = {'busy': False, 'devices': []}

    def event(kind, data=None):
        events.put((kind, data))

    def scan():
        if state['busy']:
            return
        state['busy'] = True
        start.configure(state='disabled')
        refresh.configure(state='disabled')
        selection.configure(state='disabled')
        status.set('Đang tìm USB…')
        def work():
            try:
                event('devices', discover(MANIFEST['minimum_usb_bytes']))
            except Exception as error:
                event('error', str(error))
        threading.Thread(target=work, daemon=True).start()

    def begin():
        index = selection.current()
        if state['busy'] or index < 0:
            return
        selected = state['devices'][index].copy()
        state['busy'] = True
        start.configure(state='disabled')
        refresh.configure(state='disabled')
        selection.configure(state='disabled')
        status.set('Đang tải các thành phần từ Debian, CameraWall và nguồn AI…')
        progress.configure(mode='determinate', value=0)
        def work():
            try:
                cache = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'Library' / 'Caches')) / 'CameraWall USB Creator'
                image, image_info = prepare(ROOT, cache, lambda phase, done, total: event(phase, (done, total)))
                revalidate(selected, image_info['size'])
                event('writing')
                elevated(image, selected, image_info)
                event('done')
            except Exception as error:
                event('error', str(error))
        threading.Thread(target=work, daemon=True).start()

    def poll():
        while not events.empty():
            kind, data = events.get_nowait()
            if kind == 'download':
                done, total = data
                progress.configure(value=100 * done / total)
                status.set(f'Chuẩn bị dữ liệu: {done / 1024**2:.0f} / {total / 1024**2:.0f} MiB — kiểm checksum từng file')
            elif kind == 'prepare':
                status.set('Đang tạo bộ cài offline và cấu trúc USB bootable trên máy này…')
                progress.configure(mode='indeterminate')
                progress.start(20)
            elif kind == 'writing':
                status.set('Đang xin quyền quản trị, ghi và đọc lại USB để kiểm tra. Giữ USB cắm nguyên.')
                progress.configure(mode='indeterminate')
                progress.start(20)
            elif kind == 'devices':
                state['busy'] = False
                state['devices'] = data
                selection.configure(values=[f"{d['model']} · {d['size'] / 1024**3:.1f} GiB · {d['id']}" for d in data], state='readonly')
                selection.set('Chọn USB…' if data else 'Không tìm thấy USB phù hợp')
                refresh.configure(state='normal')
                status.set('Chọn đúng USB rồi bấm tạo bộ cài.' if data else 'Cắm USB rồi bấm Quét lại. Không hỗ trợ USB có sector 4K.')
            elif kind in ('error', 'done'):
                state['busy'] = False
                progress.stop()
                progress.configure(mode='determinate', value=100 if kind == 'done' else 0)
                refresh.configure(state='normal')
                selection.configure(state='readonly')
                start.configure(state='disabled')
                if kind == 'done':
                    status.set('USB đã ghi xong và đọc lại đúng checksum. Bạn có thể tháo USB để cài CameraWall.')
                    warning.configure(text='Cắm USB vào đúng máy cần cài lại. Bộ cài sẽ tự xóa ổ đích.', style='Warning.TLabel')
                else:
                    status.set('Chưa hoàn tất. Quét lại USB để thử lại; file tải dở được giữ để nối tiếp.')
                    messagebox.showerror('Chưa tạo được USB', data, parent=root)
        root.after(100, poll)

    def close():
        if state['busy']:
            messagebox.showinfo('Đang xử lý', 'Chờ thao tác hoàn tất để tránh USB bị ghi dở.', parent=root)
        else:
            root.destroy()

    selection.bind('<<ComboboxSelected>>', lambda _: start.configure(state='normal' if selection.current() >= 0 and not state['busy'] else 'disabled'))
    refresh.configure(command=scan)
    start.configure(command=begin)
    root.protocol('WM_DELETE_WINDOW', close)
    poll()
    scan()
    root.mainloop()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

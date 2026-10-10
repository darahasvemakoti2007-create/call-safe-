import subprocess
import re
import os

def dump():
    subprocess.run(['adb', '-s', 'emulator-5554', 'shell', 'uiautomator', 'dump', '/sdcard/window_dump.xml'], check=True)
    subprocess.run(['adb', '-s', 'emulator-5554', 'pull', '/sdcard/window_dump.xml', 'window_dump.xml'], check=True)

    with open('window_dump.xml', 'r', encoding='utf-8') as f:
        content = f.read()

    texts = [t for t in re.findall(r'text="([^"]+)"', content) if t]
    descs = [d for d in re.findall(r'content-desc="([^"]+)"', content) if d]
    print('Visible Texts:', len(texts), texts)
    print('Visible Content-Descs:', len(descs), descs)

if __name__ == '__main__':
    dump()

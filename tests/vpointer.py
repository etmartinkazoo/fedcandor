#!/usr/bin/python3 -I
"""Drive a virtual mouse in a (headless) sway session, for tests/check.sh.

    vpointer.py WIDTH HEIGHT ACTION...

Actions run in order:  move X Y | press | release | click | dclick | sleep SECONDS
Coordinates are in layout pixels, within WIDTH x HEIGHT.

Speaks the Wayland wire protocol directly (zwlr_virtual_pointer_v1), so it
needs no libraries. A headless sway has no input devices, so without this its
clients never get pointer events.
"""

import os
import socket
import struct
import sys
import time

BTN_LEFT = 0x110


class Wayland:
    def __init__(self):
        path = os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.sock.settimeout(5)
        self.next_id = 2
        self.buf = b""

    def recv(self):
        data = self.sock.recv(65536)
        if not data:
            sys.exit("vpointer: compositor closed the connection")
        return data

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    def send(self, obj, opcode, payload=b""):
        size = 8 + len(payload)
        self.sock.sendall(struct.pack("<II", obj, (size << 16) | opcode) + payload)

    def read_events(self):
        """Read until a wl_callback.done for our sync arrives; yield events."""
        while True:
            while len(self.buf) < 8:
                self.buf += self.recv()
            obj, word = struct.unpack("<II", self.buf[:8])
            size, opcode = word >> 16, word & 0xFFFF
            while len(self.buf) < size:
                self.buf += self.recv()
            body, self.buf = self.buf[8:size], self.buf[size:]
            yield obj, opcode, body


def string(s):
    b = s.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)


def read_string(body, off):
    n = struct.unpack_from("<I", body, off)[0]
    s = body[off + 4:off + 4 + n - 1].decode()
    return s, off + 4 + n + (-n % 4)


def main():
    width, height = int(sys.argv[1]), int(sys.argv[2])
    actions = sys.argv[3:]
    wl = Wayland()

    # wl_display.get_registry, then a sync so we know when the globals are in
    registry = wl.new_id()
    wl.send(1, 1, struct.pack("<I", registry))
    sync = wl.new_id()
    wl.send(1, 0, struct.pack("<I", sync))
    manager_name = manager_version = None
    for obj, opcode, body in wl.read_events():
        if obj == registry and opcode == 0:
            name = struct.unpack_from("<I", body, 0)[0]
            iface, off = read_string(body, 4)
            version = struct.unpack_from("<I", body, off)[0]
            if iface == "zwlr_virtual_pointer_manager_v1":
                manager_name, manager_version = name, version
        elif obj == sync:
            break
        elif obj == 1 and opcode == 0:
            sys.exit("wayland error")
    if manager_name is None:
        sys.exit("vpointer: compositor has no zwlr_virtual_pointer_manager_v1")

    # registry.bind(name, interface, version, new_id)
    manager = wl.new_id()
    wl.send(registry, 0, struct.pack("<I", manager_name) + string("zwlr_virtual_pointer_manager_v1")
            + struct.pack("<II", min(manager_version, 1), manager))
    # manager.create_virtual_pointer(seat = null, new_id)
    pointer = wl.new_id()
    wl.send(manager, 0, struct.pack("<II", 0, pointer))

    def ms():
        return int(time.monotonic() * 1000) & 0xFFFFFFFF

    def frame():
        wl.send(pointer, 4)

    def button(state):
        wl.send(pointer, 2, struct.pack("<III", ms(), BTN_LEFT, state))
        frame()

    time.sleep(0.15)   # let the seat gain its pointer
    i = 0
    while i < len(actions):
        a = actions[i]
        if a == "move":
            x, y = int(actions[i + 1]), int(actions[i + 2])
            wl.send(pointer, 1, struct.pack("<IIIII", ms(), x, y, width, height))
            frame()
            i += 2
        elif a == "press":
            button(1)
        elif a == "release":
            button(0)
        elif a == "click":
            button(1); time.sleep(0.03); button(0)
        elif a == "dclick":
            button(1); time.sleep(0.03); button(0); time.sleep(0.08); button(1); time.sleep(0.03); button(0)
        elif a == "sleep":
            time.sleep(float(actions[i + 1]))
            i += 1
        else:
            sys.exit(f"vpointer: unknown action {a}")
        time.sleep(0.02)
        i += 1

    # Round-trip so everything is delivered before we disconnect
    sync = wl.new_id()
    wl.send(1, 0, struct.pack("<I", sync))
    for obj, _, _ in wl.read_events():
        if obj == sync:
            break


if __name__ == "__main__":
    main()

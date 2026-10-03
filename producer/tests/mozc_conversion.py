#!/usr/bin/env python3
"""Exercise root startup and the compiled-in dictionary through native Mozc IPC."""
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time


def varint(value):
    data = bytearray()
    while value > 127:
        data.append((value & 127) | 128)
        value >>= 7
    return bytes(data) + bytes([value])


def field(number, value):
    if isinstance(value, bytes):
        return varint(number * 8 + 2) + varint(len(value)) + value
    return varint(number * 8) + varint(value)


def read_varint(data, offset=0):
    value = 0
    for shift in range(0, 70, 7):
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, offset
    raise ValueError("invalid varint")


def call(address, request):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(address)
        client.sendall(request)
        client.shutdown(socket.SHUT_WR)
        response = bytearray()
        while chunk := client.recv(65536):
            response.extend(chunk)
            if len(response) > 1024 * 1024:
                raise ValueError("oversized response")
        if not response:
            raise ValueError("empty response")
        return bytes(response)


def main():
    assert os.getuid() == 0, "probe must exercise Scarlet's root startup"
    with tempfile.TemporaryDirectory(prefix="scarlet-mozc-") as directory:
        profile = Path(directory) / ".config/mozc"
        profile.mkdir(parents=True)
        environment = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(profile.parent))
        with tempfile.TemporaryFile() as log:
            server = subprocess.Popen([sys.argv[1], "--logtostderr"], env=environment,
                                      stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 20
                while True:
                    assert server.poll() is None, "server exited before IPC startup"
                    ipc = profile / ".session.ipc"
                    key = re.search(rb"[a-f0-9]{32}", ipc.read_bytes()) if ipc.exists() else None
                    if key:
                        address = b"\0tmp/.mozc." + key.group() + b".session"
                        try:
                            response = call(address, field(1, 1))  # CREATE_SESSION
                            break
                        except (ConnectionRefusedError, FileNotFoundError):
                            pass
                    assert time.monotonic() < deadline, "IPC startup timed out"
                    time.sleep(0.1)
                tag, offset = read_varint(response)
                assert tag == 8, "missing session ID in Output"
                session, _ = read_varint(response, offset)
                assert session != 0
                for char in "nihonn":
                    key_event = field(1, ord(char)) + field(7, 1) + field(9, 1)
                    call(address, field(1, 3) + field(2, session) + field(3, key_event))
                space = field(3, 4) + field(7, 1) + field(9, 1)
                response = call(address, field(1, 3) + field(2, session) + field(3, space))
                assert "日本".encode() in response, "dictionary conversion did not produce 日本"
                print("SCARLET_MOZC_CONVERSION_OK")
            except BaseException:
                log.seek(0)
                print(log.read().decode(errors="replace"), file=sys.stderr)
                raise
            finally:
                if server.poll() is None:
                    server.terminate()
                    try:
                        server.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        server.kill()
                        server.wait()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Four real TUI clients, coupled through the Nim simulated gateway."""
import codecs
import fcntl
import os
from pathlib import Path
import pty
import select
import socket
import struct
import subprocess
import termios
import time

import pyte
from vterm import render

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/multi'
OUT.mkdir(parents=True, exist_ok=True)


def scenario(latency, jitter, loss, crash=False):
    children, masters, screens, streams, decoders = [], [], [], [], []
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    gateway = subprocess.Popen([str(ROOT/'build/gateway'), str(port),
                                str(latency), str(jitter), str(loss)],
                               stdout=subprocess.PIPE, text=True)
    try:
        assert select.select([gateway.stdout], [], [], 5)[0], 'gateway startup timeout'
        assert gateway.stdout.readline().strip() == 'ready'
        for i in range(4):
            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 80, 0, 0))
            env = dict(os.environ, TERM='xterm-256color', LANG='C.UTF-8',
                       A_PEER_ID=str(i+1), A_GATEWAY_PORT=str(port),
                       A_STATE_FILE=str(OUT/f'state-{i}'))
            def terminal():
                os.setsid()
                fcntl.ioctl(0, termios.TIOCSCTTY, 0)
            masters.append(master)
            try:
                child = subprocess.Popen([str(ROOT/'build/A-multi')], stdin=slave,
                                         stdout=slave, stderr=slave, env=env,
                                         cwd=ROOT, preexec_fn=terminal)
            finally:
                os.close(slave)
            children.append(child)
            screen = pyte.Screen(80, 30)
            screens.append(screen)
            streams.append(pyte.Stream(screen))
            decoders.append(codecs.getincrementaldecoder('utf-8')('replace'))

        def pump(seconds):
            end = time.monotonic() + seconds
            while time.monotonic() < end:
                assert gateway.poll() is None, 'gateway died'
                assert all(c.poll() is None for c in children), 'client died'
                for fd in select.select(masters, [], [], 0.02)[0]:
                    i = masters.index(fd)
                    streams[i].feed(decoders[i].decode(os.read(fd, 65536)))

        pump(1)
        if crash:
            children[0].kill()
            children[0].wait(timeout=2)
            print("client crash: supervisor cleanup exercised")
            return
        before = [float((OUT/f'state-{i}').read_text().split()[1]) for i in range(4)]
        for _ in range(8):
            os.write(masters[0], b'\x1b[A')
            pump(0.08)
        pump(5)
        after = [float((OUT/f'state-{i}').read_text().split()[1]) for i in range(4)]
        assert all(a < b - 0.2 for a, b in zip(after, before)), (before, after)
        assert max(after) - min(after) < 0.3, after
        for i, screen in enumerate(screens):
            assert any('A' in row for row in screen.display), 'ship missing'
            render(screen, OUT/f'{latency}-{i}.png')
        for fd in masters:
            os.write(fd, b'\x1b')
        for child in children:
            assert child.wait(timeout=5) == 0, 'unclean client exit'
        print(f'4 clients: latency={latency} jitter={jitter} loss={loss}: passed {after}')
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        for fd in masters:
            os.close(fd)
        gateway.terminate()
        try:
            gateway.wait(timeout=2)
        except subprocess.TimeoutExpired:
            gateway.kill()
            gateway.wait()


scenario(0, 0, 0)
scenario(80, 35, 0.25)
scenario(80, 35, 0.25, crash=True)
print('four-client TUI network tests passed; all child processes reaped')

#!/usr/bin/env python3
"""Keep a PTY ready for A; accept one JSON command per line on stdin."""
import argparse
import codecs
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import sys
import termios

import pyte

ROOT = Path(__file__).resolve().parents[2]
COLORS = dict(zip(
    ['black', 'red', 'green', 'brown', 'blue', 'magenta', 'cyan', 'white',
     'brightblack', 'brightred', 'brightgreen', 'brightbrown', 'brightblue',
     'brightmagenta', 'brightcyan', 'brightwhite'],
    ['000000', '800000', '008000', '808000', '000080', '800080', '008080',
     'c0c0c0', '808080', 'ff0000', '00ff00', 'ffff00', '0000ff', 'ff00ff',
     '00ffff', 'ffffff']))
KEYS = {'Up': b'\x1b[A', 'Down': b'\x1b[B', 'Left': b'\x1b[D',
        'Right': b'\x1b[C', 'Escape': b'\x1b', 'Ctrl-C': b'\x03'}


def render(screen, path):
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(os.environ.get(
        'A_FONT', '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'), 20)
    cw, ch = round(font.getlength('M')), 27
    image = Image.new('RGB', (screen.columns*cw, screen.lines*ch), '#020202')
    draw = ImageDraw.Draw(image)

    def color(value, default):
        if value == 'default': return default
        return '#' + COLORS.get(value, value)

    for y in range(screen.lines):
        for x in range(screen.columns):
            cell = screen.buffer[y][x]
            fg = color(cell.fg, '#fafafa')
            bg = color(cell.bg, '#020202')
            if cell.reverse: fg, bg = bg, fg
            draw.rectangle((x*cw, y*ch, (x + 1)*cw - 1, (y + 1)*ch - 1), fill=bg)
        for x in range(screen.columns):
            cell = screen.buffer[y][x]
            ink = color(cell.bg, '#020202') if cell.reverse else color(cell.fg, '#fafafa')
            draw.text((x*cw, y*ch), cell.data, font=font, fill=ink)
    image.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--width', type=int, default=100)
    parser.add_argument('--height', type=int, default=36)
    args = parser.parse_args()
    width, height = args.width, args.height
    screen = pyte.Screen(width, height)
    stream = pyte.Stream(screen)
    decoder = codecs.getincrementaldecoder('utf-8')('replace')
    master = child = None
    raw = bytearray()
    commands = bytearray()

    def report(**data):
        print(json.dumps(data), flush=True)

    def resize():
        if master is not None:
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', height, width, 0, 0))
        screen.resize(height, width)

    def command(data):
        nonlocal master, child, width, height
        action = data['action']
        if action == 'start':
            if child is not None: raise ValueError('Game already started; create a new session to restart.')
            if not (ROOT / 'build/A').is_file(): raise ValueError('Build first with make.')
            master, slave = pty.openpty()
            resize()
            child = os.fork()
            if child == 0:
                os.close(master)
                os.setsid()
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
                for fd in (0, 1, 2): os.dup2(slave, fd)
                if slave > 2: os.close(slave)
                os.chdir(ROOT)
                env = dict(os.environ, TERM='xterm-256color', LANG='C.UTF-8')
                os.execve(str(ROOT / 'build/A'), ['A'], env)
            os.close(slave)
            report(started=child)
        elif action == 'key':
            if master is None: raise ValueError('Start first.')
            os.write(master, KEYS[data['key']])
        elif action == 'mouse':
            if master is None: raise ValueError('Start first.')
            # SGR coordinates are 1-based; supplied coordinates are 0-based.
            x, y = int(data['x']) + 1, int(data['y']) + 1
            os.write(master, f'\x1b[<0;{x};{y}M\x1b[<0;{x};{y}m'.encode())
        elif action == 'resize':
            width, height = int(data['width']), int(data['height'])
            if width < 1 or height < 1: raise ValueError('Dimensions must be positive.')
            resize()
        elif action == 'capture':
            name = data.get('name', 'frame')
            if not name or Path(name).name != name: raise ValueError('Use a filename stem.')
            out = ROOT / 'build/captures'
            out.mkdir(parents=True, exist_ok=True)
            (out / f'{name}.txt').write_text('\n'.join(screen.display))
            (out / f'{name}.ansi').write_bytes(raw)
            render(screen, out / f'{name}.png')
            report(capture=str(out / f'{name}.png'))
        elif action == 'stop':
            return False
        else:
            raise ValueError(f'Unknown action: {action}')
        return True

    report(ready=True, game_started=False, width=width, height=height)
    try:
        running = True
        while running:
            readable, _, _ = select.select([sys.stdin.fileno()] + ([master] if master is not None else []), [], [], 1)
            # Drain game output before processing a capture request.
            if master in readable:
                try: chunk = os.read(master, 65536)
                except OSError: chunk = b''
                if chunk:
                    raw.extend(chunk)
                    stream.feed(decoder.decode(chunk))
                else:
                    os.close(master); master = None
                    _, status = os.waitpid(child, 0)
                    report(exited=os.waitstatus_to_exitcode(status))
                    child = None
            if sys.stdin.fileno() in readable:
                chunk = os.read(sys.stdin.fileno(), 4096)
                if not chunk: break
                commands.extend(chunk)
                while b'\n' in commands:
                    line, _, remainder = commands.partition(b'\n')
                    commands[:] = remainder
                    try: running = command(json.loads(line))
                    except (ValueError, KeyError, OSError) as error: report(error=str(error))
                    if not running: break
    finally:
        if child is not None:
            os.kill(child, signal.SIGTERM)
            os.waitpid(child, 0)
        if master is not None: os.close(master)


if __name__ == '__main__':
    main()

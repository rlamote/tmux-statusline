#!/usr/bin/env python3
"""Render the status bar of a real tmux server to PNG.

Each theme is rendered in its own tmux server (isolated socket and config) so
options never leak between screenshots. tmux is driven through a pty and the
resulting screen is replayed with pyte, so the captured cells - including the
status line - are exactly what tmux drew.

Every glyph is traced from the Nerd Font into a path before rasterising, so the
result does not depend on the fonts available to the renderer.
"""

import fcntl
import os
import pty
import select
import shutil
import struct
import subprocess
import sys
import termios
import time
from pathlib import Path

import cairosvg
import pyte
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

REPO = Path(__file__).resolve().parent.parent
THEMES = ["nordfox", "catppuccin", "tokyonight", "rose-pine", "gruvbox"]

COLS, ROWS = 120, 9

# The font is monospaced at half its em, so a cell is exactly FONT_SIZE / 2
# wide and glyphs land on the grid without drifting.
FONT_SIZE = 19.0
CELL_W = FONT_SIZE / 2
CELL_H = 23.0
BASELINE = (CELL_H - FONT_SIZE) / 2 + FONT_SIZE * 0.83
PAD = 14.0
SCALE = 2  # rasterise at 2x for high-density displays

# Powerline separators. The hard dividers are drawn as geometry so they tile
# with the background runs instead of leaving antialiasing seams.
SEP_SOLID_RIGHT = "\ue0b0"  # filled triangle pointing right
SEP_SOLID_LEFT = "\ue0b2"   # filled triangle pointing left
SOLID_SEPARATORS = {SEP_SOLID_RIGHT, SEP_SOLID_LEFT}

DEMO_COMMANDS = [
    "git log --oneline -3",
]

# Shown by the `#h` field; a namespace keeps the real machine name out of the
# committed screenshots.
HOSTNAME = "workstation"

FONT_DIR = Path.home() / ".local/share/fonts"
NERD_FONTS = {
    False: FONT_DIR / "UbuntuMonoNerdFontMono-Regular.ttf",
    True: FONT_DIR / "UbuntuMonoNerdFontMono-Bold.ttf",
}


_fonts = {}
_outlines = {}


def load_font(bold):
    """Return (glyphset, cmap, unitsPerEm, hmtx) for the requested weight."""
    if bold not in _fonts:
        path = NERD_FONTS[bold]
        if not path.is_file():
            raise SystemExit(f"required font not found: {path}")
        ttf = TTFont(str(path))
        _fonts[bold] = (
            ttf.getGlyphSet(),
            ttf.getBestCmap(),
            ttf["head"].unitsPerEm,
            ttf["hmtx"],
        )
    return _fonts[bold]


def outline(char, bold):
    """Return (path data, x offset) for a glyph, or None when it has no ink."""
    key = (char, bold)
    if key not in _outlines:
        glyphset, cmap, upem, hmtx = load_font(bold)
        name = cmap.get(ord(char))
        if name is None:
            _outlines[key] = None
        else:
            pen = SVGPathPen(glyphset)
            glyphset[name].draw(pen)
            commands = pen.getCommands()
            if not commands:
                _outlines[key] = None
            else:
                scale = FONT_SIZE / upem
                advance = hmtx[name][0] * scale
                _outlines[key] = (commands, (CELL_W - advance) / 2, scale)
    return _outlines[key]


def glyph_path(char, x, y, fill, bold):
    """Trace a character into an SVG path positioned on the cell grid."""
    traced = outline(char, bold)
    if traced is None:
        return None
    commands, offset, scale = traced
    transform = (
        f"translate({x + offset:.2f},{y + BASELINE:.2f}) scale({scale:.5f},{-scale:.5f})"
    )
    return f'<path d="{commands}" fill="{fill}" transform="{transform}"/>'


def separator_polygon(char, x, y, fill):
    """Draw a hard divider as geometry so it tiles with the background runs."""
    left, right = x, x + CELL_W
    top, bottom, mid = y, y + CELL_H, y + CELL_H / 2

    if char == SEP_SOLID_RIGHT:
        points = f"{left},{top} {right},{mid} {left},{bottom}"
    else:
        points = f"{right},{top} {left},{mid} {right},{bottom}"
    return f'<polygon points="{points}" fill="{fill}"/>'


class TmuxScreen(pyte.Screen):
    """pyte rejects the private form of DSR that tmux emits while probing."""

    def report_device_status(self, mode, private=False):
        if private:
            return
        super().report_device_status(mode)


def theme_colors(theme):
    """Read the semantic colours a theme resolves to."""
    script = f'source "{REPO}/themes/{theme}.conf"; ' + "; ".join(
        f'echo "${name}_color"'
        for name in ("bg", "text", "accent", "active", "inactive", "border", "copy")
    )
    out = subprocess.run(
        ["bash", "-c", script], capture_output=True, text=True, check=True
    ).stdout.split()
    keys = ("bg", "text", "accent", "active", "inactive", "border", "copy")
    return dict(zip(keys, out))


def capture(theme, socket):
    """Run tmux with `theme` and return the rendered pyte screen."""
    rcfile = REPO / f".screenshot-{theme}.bashrc"
    rcfile.write_text("PS1='\\w $ '\n")

    conf = REPO / f".screenshot-{theme}.conf"
    conf.write_text(
        "\n".join(
            [
                'set -g default-terminal "tmux-256color"',
                'set -ga terminal-overrides ",*:Tc"',
                f'set -g default-command "bash --noprofile --rcfile {rcfile} -i"',
                "set -g status-interval 1",
                "set -g history-limit 100",
                f"set -g @tmux-statusline-theme '{theme}'",
                f"run-shell '{REPO}/tmux-statusline.tmux'",
                "",
            ]
        )
    )

    env = dict(
        os.environ,
        TERM="xterm-256color",
        COLORTERM="truecolor",
        PS1="\\w $ ",
    )
    env.pop("TMUX", None)

    tmux = shutil.which("tmux")
    run = lambda *args: subprocess.run(
        [tmux, "-L", socket, *args], env=env, capture_output=True, text=True
    )

    run("-f", str(conf), "new-session", "-d", "-s", "work",
        "-x", str(COLS), "-y", str(ROWS), "-n", "editor")
    run("new-window", "-t", "work", "-n", "shell")
    run("new-window", "-t", "work", "-n", "logs")
    run("select-window", "-t", "work:1")

    screen = TmuxScreen(COLS, ROWS)
    stream = pyte.Stream(screen)

    pid, fd = pty.fork()
    if pid == 0:
        os.environ.update(env)
        os.execv(tmux, [tmux, "-L", socket, "attach-session", "-t", "work"])

    # Without an explicit size the pty defaults to 80x24 and tmux clips the
    # window list, so the size has to match the screen being emulated.
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))

    def pump(seconds):
        end = time.time() + seconds
        while time.time() < end:
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if not data:
                return False
            stream.feed(data.decode("utf-8", "replace"))
        return True

    try:
        pump(1.5)
        run("send-keys", "-t", "work:1", "clear", "Enter")
        pump(0.5)
        for command in DEMO_COMMANDS:
            run("send-keys", "-t", "work:1", command, "Enter")
            pump(1.0)
        pump(1.5)
    finally:
        run("kill-server")
        os.close(fd)
        os.waitpid(pid, 0)
        conf.unlink(missing_ok=True)
        rcfile.unlink(missing_ok=True)

    return screen


def resolve(color, default):
    """pyte reports colours as bare hex or a named default."""
    if not color or color == "default":
        return default
    if len(color) == 6 and all(c in "0123456789abcdefABCDEF" for c in color):
        return f"#{color}"
    return default


def cells(screen, colors):
    """Flatten the pyte screen into (row, col, char, fg, bg, bold) tuples."""
    for y in range(screen.lines):
        line = screen.buffer[y]
        for x in range(screen.columns):
            ch = line[x]
            fg = resolve(ch.fg, colors["text"])
            bg = resolve(ch.bg, colors["bg"])
            if ch.reverse:
                fg, bg = bg, fg
            yield y, x, ch.data, fg, bg, ch.bold


def to_svg(screen, colors, theme):
    width = COLS * CELL_W + PAD * 2
    height = ROWS * CELL_H + PAD * 2
    grid = list(cells(screen, colors))

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" '
        f'height="{height:.0f}" viewBox="0 0 {width:.1f} {height:.1f}" '
        f'role="img" aria-label="tmux status line using the {theme} theme">',
        f'<rect width="{width:.1f}" height="{height:.1f}" rx="8" fill="{colors["bg"]}"/>',
    ]

    # Background runs first, merging adjacent cells that share a colour.
    for y in range(ROWS):
        row = [c for c in grid if c[0] == y]
        run_start, run_bg = 0, row[0][4]
        for x in range(1, COLS + 1):
            bg = row[x][4] if x < COLS else None
            if bg != run_bg:
                if run_bg != colors["bg"]:
                    parts.append(
                        f'<rect x="{PAD + run_start * CELL_W:.1f}" '
                        f'y="{PAD + y * CELL_H:.1f}" '
                        f'width="{(x - run_start) * CELL_W:.1f}" '
                        f'height="{CELL_H:.1f}" fill="{run_bg}"/>'
                    )
                run_start, run_bg = x, bg

    # Hard dividers are geometry; every other glyph is traced from the font.
    for y, x, char, fg, bg, bold in grid:
        if not char.strip():
            continue
        px, py = PAD + x * CELL_W, PAD + y * CELL_H
        if char in SOLID_SEPARATORS:
            parts.append(separator_polygon(char, px, py, fg))
            continue
        path = glyph_path(char, px, py, fg, bold)
        if path:
            parts.append(path)

    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def reexec_with_demo_hostname():
    """Re-run inside a UTS namespace so `#h` renders a neutral hostname."""
    if os.environ.get("STATUSLINE_SHOT_NS") == "1":
        return
    unshare = shutil.which("unshare")
    if unshare is None:
        return

    env = dict(os.environ, STATUSLINE_SHOT_NS="1")
    probe = subprocess.run(
        [unshare, "-Ur", "--uts", "hostname", HOSTNAME], capture_output=True
    )
    if probe.returncode != 0:
        print("note: user namespaces unavailable, using the real hostname",
              file=sys.stderr)
        return

    os.execve(
        unshare,
        [unshare, "-Ur", "--uts", "bash", "-c",
         'hostname "$1"; shift; exec "$@"', "ns",
         HOSTNAME, sys.executable, os.path.abspath(__file__)],
        env,
    )


def main():
    reexec_with_demo_hostname()

    out_dir = REPO / "screenshots"
    out_dir.mkdir(exist_ok=True)

    for index, theme in enumerate(THEMES):
        colors = theme_colors(theme)
        screen = capture(theme, f"statusline-shot-{os.getpid()}-{index}")
        target = out_dir / f"{theme}.png"
        cairosvg.svg2png(
            bytestring=to_svg(screen, colors, theme).encode("utf-8"),
            write_to=str(target),
            scale=SCALE,
        )
        size = target.stat().st_size // 1024
        print(f"{theme:<12} {size:>4}K  {target.name}")


if __name__ == "__main__":
    sys.exit(main())

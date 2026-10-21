"""Filesystem discovery: platform candidate roots and icon enumeration.

Ports the behaviour of scan-icons.sh (candidate roots, nesting fold) and the
installer's find-based listing, without the shell — pure os.walk. Incremental
indexing lives in indexer.py; this module only enumerates and classifies.

Known ports/limits vs 0.x (documented, intentional):
- snap/flatpak mount globs kept; CoreTypes bundle kept for macOS.
- Windows: no system icon roots (icons live inside DLL resources) — users
  add folders manually; a Windows root scanner is a recorded future item.
"""

from __future__ import annotations

import glob
import os
import re
import sys
from pathlib import Path

ICON_EXTS = {"png", "svg", "ico", "jpg", "jpeg", "gif", "webp", "bmp", "xpm", "icns"}

_SIZE_RE = re.compile(r"^(?P<w>\d+)(?:x(?P<h>\d+))?$")
# theme-layout segments that are size categories without a numeric size
_SIZE_WORDS = {"scalable", "symbolic", "symbolic-links", "cursors"}


def platform_candidates(extra_dirs: list[str] | None = None) -> list[Path]:
    """Existing icon-source candidate roots, nested ones folded into parents.

    Port of scan-icons.sh:59-77 (candidate roots) and its nesting fold
    (scan-icons.sh:23-24). `extra_dirs` are the user-configured asset
    folders from the first-run routine / Settings screen; they participate
    in the same nesting fold so a platform root inside a user folder
    doesn't get scanned twice.
    """
    found: list[Path] = []

    def add(p: str | Path) -> None:
        p = Path(p).expanduser()
        if p.is_dir():
            found.append(p)

    for d in (extra_dirs or []):
        add(d)
    add("/usr/share/icons")
    add("/usr/local/share/icons")
    add(Path.home() / ".icons")
    add(Path.home() / ".local/share/icons")
    add("/usr/share/pixmaps")
    if sys.platform == "darwin":
        add("/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources")
        add(Path.home() / "Library/Icons")
    else:
        for pattern in (
            "/snap/*/current/usr/share/icons",
            "/var/lib/flatpak/app/*/current/active/files/share/icons",
            str(Path.home() / ".local/share/flatpak/app/*/"
                "current/active/files/share/icons"),
        ):
            for p in sorted(glob.glob(pattern)):
                add(p)

    return fold_nested(found)


def fold_nested(paths: list[Path]) -> list[Path]:
    """Drop candidates fully contained inside another candidate."""
    resolved = sorted({os.path.realpath(str(p)) for p in paths},
                      key=lambda s: s.count(os.sep))
    kept: list[str] = []
    for p in resolved:
        if any(p == k or p.startswith(k + os.sep) for k in kept):
            continue
        kept.append(p)
    return [Path(p) for p in kept]


def iter_icon_files(root: str | Path):
    """Yield previewable icon files under root (hidden dirs skipped).

    os.walk with followlinks=False guards against symlink cycles (the 0.x
    shell hit this with --icons link installs — see refresh-icons.sh:83-85).
    Symlinked files are kept when they resolve; dangling links are dropped.
    """
    root = str(root)
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            ext = fn.rsplit(".", 1)[-1].lower() if "." in fn else ""
            if ext not in ICON_EXTS:
                continue
            p = os.path.join(dirpath, fn)
            if os.path.isfile(p):  # False for dangling symlinks
                yield p


def derive_meta(path: str | Path, source_root: str | Path) -> dict:
    """Derive (name, theme, context, size_px) from a path, porting the 0.x
    path parser (list.txt entries like <root>/<Theme>/<size>/<context>/f.png).

    Examples:
      /usr/share/icons/Adwaita/16x16/actions/foo.png
        -> theme=Adwaita, context=actions, size_px=16
      /usr/share/icons/Adwaita/scalable/apps/foo.svg
        -> theme=Adwaita, context=apps, size_px=None
      /usr/share/pixmaps/foo.png
        -> theme=pixmaps, context=None, size_px=None
    """
    path = str(path)
    root = str(source_root)
    rel = os.path.relpath(path, root)
    parts = rel.split(os.sep)
    name = os.path.splitext(os.path.basename(path))[0]
    ext = os.path.splitext(path)[1].lower().lstrip(".")

    theme = None
    context = None
    size_px = None

    for i, part in enumerate(parts[:-1]):
        m = _SIZE_RE.match(part)
        if m:
            size_px = int(m.group("w"))
            theme = parts[i - 1] if i > 0 else os.path.basename(root)
            if i + 1 <= len(parts) - 2:
                context = parts[i + 1]
            break
        if part.lower() in _SIZE_WORDS:
            theme = parts[i - 1] if i > 0 else os.path.basename(root)
            if i + 1 <= len(parts) - 2:
                context = parts[i + 1]
            break

    if theme is None:
        theme = parts[0] if len(parts) > 1 else os.path.basename(root)
        if len(parts) > 2:
            context = parts[1]

    if os.path.basename(root) == "pixmaps":
        theme, context, size_px = "pixmaps", None, None

    return dict(name=name, theme=theme, context=context, ext=ext, size_px=size_px)

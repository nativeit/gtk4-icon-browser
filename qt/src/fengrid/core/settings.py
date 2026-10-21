"""Key/value settings on the library's `setting` table (replaces gib-* keys).

Thin wrappers over core.db; kept as a module so the Qt bridges and the tests
share one vocabulary. The first-run configuration routine and the
Settings/Preferences screen store everything here under namespaced keys —
complex values (asset folder lists, feature toggles) travel as JSON.
"""

from __future__ import annotations

import json
import sqlite3

from .db import get_setting as _get
from .db import set_setting as _set

# -- setting keys ------------------------------------------------------------
FIRST_RUN_DONE = "first_run_done"
ASSET_FOLDERS = "asset_folders"
ASSET_SCOPES = "asset_scopes"          # json: {"icons": bool, "fonts": bool}
VISUAL_LAYOUT = "visual_layout"        # "classic" | "compact" | "cozy"
FEATURE_COLORS = "feature_colors"
FEATURE_FONTS = "feature_fonts"
FEATURE_SNIPPETS = "feature_snippets"
FEATURE_TERMINAL = "feature_terminal"
COMMAND_HOTKEY = "command_hotkey"       # e.g. "Alt+`" — palette toggle

_DEFAULTS = {
    ASSET_SCOPES: {"icons": True, "fonts": True},
    VISUAL_LAYOUT: "classic",
    FEATURE_COLORS: True,
    FEATURE_FONTS: True,
    FEATURE_SNIPPETS: True,
    FEATURE_TERMINAL: False,
    COMMAND_HOTKEY: "Alt+`",
}


def get(con: sqlite3.Connection, key: str, default=None):
    return _get(con, key, default)


def set(con: sqlite3.Connection, key: str, value) -> None:
    _set(con, key, value)


def _get_bool(con: sqlite3.Connection, key: str, default: bool) -> bool:
    """Boolean round-trip for db.set_setting's str() storage.

    set_setting stringifies every value, so False lands as the text "False"
    — which bool() would happily treat as truthy. Decode the known textual
    forms explicitly; anything unrecognised falls back to the default.
    """
    raw = _get(con, key, default)
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, (int, float)):
        return bool(raw)
    if isinstance(raw, str):
        text = raw.strip().lower()
        if text in ("true", "1", "yes", "on"):
            return True
        if text in ("false", "0", "no", "off"):
            return False
    return bool(default)


# --------------------------------------------------------------- first run

def is_first_run(con: sqlite3.Connection) -> bool:
    """True until the one-time configuration routine has been completed."""
    return not _get_bool(con, FIRST_RUN_DONE, False)


def mark_first_run_done(con: sqlite3.Connection) -> None:
    _set(con, FIRST_RUN_DONE, True)


# ------------------------------------------------------------ asset folders

def get_asset_folders(con: sqlite3.Connection) -> list[str]:
    raw = _get(con, ASSET_FOLDERS, "[]") or "[]"
    try:
        folders = json.loads(raw)
        return folders if isinstance(folders, list) else []
    except (json.JSONDecodeError, TypeError):
        return []


def set_asset_folders(con: sqlite3.Connection, folders: list[str]) -> None:
    _set(con, ASSET_FOLDERS, json.dumps(list(folders)))


# --------------------------------------------------------- feature toggles

def get_feature(con: sqlite3.Connection, key: str) -> bool:
    default = _DEFAULTS.get(key, False)
    return _get_bool(con, key, default)


def set_feature(con: sqlite3.Connection, key: str, value: bool) -> None:
    _set(con, key, bool(value))


def get_visual_layout(con: sqlite3.Connection) -> str:
    return _get(con, VISUAL_LAYOUT, _DEFAULTS[VISUAL_LAYOUT]) \
        or _DEFAULTS[VISUAL_LAYOUT]


def set_visual_layout(con: sqlite3.Connection, layout: str) -> None:
    _set(con, VISUAL_LAYOUT, layout)


def get_command_hotkey(con: sqlite3.Connection) -> str:
    """Keyboard shortcut toggling the command palette (default "Alt+`")."""
    return _get(con, COMMAND_HOTKEY, None) or _DEFAULTS[COMMAND_HOTKEY]


def set_command_hotkey(con: sqlite3.Connection, hotkey: str) -> None:
    _set(con, COMMAND_HOTKEY, (hotkey or "").strip() or _DEFAULTS[COMMAND_HOTKEY])


def get_asset_scopes(con: sqlite3.Connection) -> dict:
    raw = _get(con, ASSET_SCOPES, None)
    if raw is None:
        return dict(_DEFAULTS[ASSET_SCOPES])
    try:
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else dict(_DEFAULTS[ASSET_SCOPES])
    except (json.JSONDecodeError, TypeError):
        return dict(_DEFAULTS[ASSET_SCOPES])

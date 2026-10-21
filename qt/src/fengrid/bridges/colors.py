"""Colors bridge: palette state over the SQLite core (colors pane, M3).

Thin adapter like bridges/fonts.py: the 5-swatch working palette lives in
memory (hex + locked), generation/edit math is core.colors, and saved
palettes persist in the library DB (palette / palette_color tables — the
0.x pane used per-pane server endpoints; same data, no server).
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Property, QObject, Signal, Slot

from ..core import colors as core_colors
from ..core import db as core_db
from ..core import settings


class Colors(QObject):
    message = Signal(str)
    exportDone = Signal(str)
    exportFailed = Signal(str)
    swatchesChanged = Signal()
    palettesChanged = Signal()
    selectionChanged = Signal()
    nameChanged = Signal()
    ruleChanged = Signal()

    def __init__(self, con, parent=None):
        super().__init__(parent)
        self._con = con
        self._swatches: list[dict] = []
        self._rule = settings.get(con, "colors_rule", "pleasing")
        if self._rule not in core_colors.GENERATION_MODES:
            self._rule = "pleasing"
        self._selected = -1
        self._name = ""
        self._palette_id: int | None = None
        # increments on every Generate press — feeds core generate()'s
        # variation seed so repeated presses always yield fresh unlocked
        # colors (anchor rotation + seeded jitter), even with locks present
        self._variation = 0
        # optional collection filter for the side rail (palette kind)
        self._collection: int | None = None
        # active smart collection (sidebar) — criteria filtered in Python
        self._smart_id = 0
        self._refresh_palettes()
        # seed the pane with one roll so it never opens empty
        self._swatches = core_colors.generate(self._rule, [], mode="dark")

    # ---------------------------------------------------------------- state
    @Property("QVariantList", notify=swatchesChanged)
    def swatches(self) -> list:
        out = []
        for s in self._swatches:
            rgb = core_colors.hex2rgb(s["hex"])
            h, sat, li = core_colors.rgb2hsl(*rgb)
            cw = core_colors.contrast(rgb, (255, 255, 255))
            cb = core_colors.contrast(rgb, (16, 20, 24))
            out.append({
                "hex": s["hex"], "locked": s["locked"],
                "cw": round(cw, 1), "cb": round(cb, 1),
                "wcagW": core_colors.wcag_label(cw),
                "wcagB": core_colors.wcag_label(cb),
                "name": core_colors.color_name(s["hex"]),
                "ink": core_colors.best_ink(rgb),
                # editor sliders read these; set_hsl converts back
                "h": round(h), "s": round(sat), "l": round(li),
            })
        return out

    @Property(int, notify=selectionChanged)
    def selectedIdx(self) -> int:
        return self._selected

    @Property(str, notify=nameChanged)
    def paletteName(self) -> str:
        return self._name

    @Property(str, notify=ruleChanged)
    def rule(self) -> str:
        return self._rule

    @Slot(result="QVariantList")
    def rule_names(self) -> list:
        """Valid generation rules — the Settings screen's picker model."""
        return list(core_colors.GENERATION_MODES)

    @Property("QVariantList", notify=palettesChanged)
    def palettes(self) -> list:
        return self._palettes

    @Property(int, notify=palettesChanged)
    def paletteId(self) -> int:
        """The working palette's saved row id (-1 when unsaved) — the
        Properties panel targets this for tags/fields/links."""
        return self._palette_id if self._palette_id is not None else -1

    @Property(str, notify=palettesChanged)
    def collectionFilter(self) -> str:
        return "" if self._collection is None else str(self._collection)

    @Property(str, notify=palettesChanged)
    def smartFilter(self) -> str:
        return "" if not self._smart_id else str(self._smart_id)

    @Slot(str)
    def set_smart(self, sc_id: str) -> None:
        """Toggle the sidebar smart-collection filter (palette kind)."""
        sid = int(sc_id) if str(sc_id).strip().isdigit() else 0
        if sid and sid == self._smart_id:
            sid = 0
        self._smart_id = sid
        self._refresh_palettes()

    # ---------------------------------------------------------------- slots
    @Slot(str)
    def set_rule(self, rule: str) -> None:
        if rule not in core_colors.GENERATION_MODES or rule == self._rule:
            return
        self._rule = rule
        settings.set(self._con, "colors_rule", rule)
        self.ruleChanged.emit()

    @Slot(str)
    def set_collection(self, coll: str) -> None:
        """Toggle the side-rail collection filter (palette kind)."""
        s = (coll or "").strip()
        cid = int(s) if s.isdigit() else None
        if cid is None or cid == self._collection:
            self._collection = None
        else:
            self._collection = cid
        self._refresh_palettes()

    @Slot()
    def generate(self) -> None:
        self._variation += 1
        self._swatches = core_colors.generate(
            self._rule, self._swatches, variation=self._variation)
        self.swatchesChanged.emit()

    @Slot(int)
    def toggle_lock(self, i: int) -> None:
        if 0 <= i < len(self._swatches):
            self._swatches[i]["locked"] = not self._swatches[i]["locked"]
            self.swatchesChanged.emit()

    @Slot(int)
    def remove_swatch(self, i: int) -> None:
        if 0 <= i < len(self._swatches) and len(self._swatches) > 2:
            del self._swatches[i]
            if self._selected >= len(self._swatches):
                self._selected = -1
                self.selectionChanged.emit()
            self.swatchesChanged.emit()

    @Slot(int, int)
    def move_swatch(self, frm: int, to: int) -> None:
        if (0 <= frm < len(self._swatches) and 0 <= to < len(self._swatches)
                and frm != to):
            moved = self._swatches.pop(frm)
            self._swatches.insert(to, moved)
            self.swatchesChanged.emit()

    @Slot(int, float, float, float)
    def set_hsl(self, i: int, h: float, s: float, l: float) -> None:
        if 0 <= i < len(self._swatches):
            rgb = core_colors.hsl2rgb(h, s, l)
            self._swatches[i]["hex"] = core_colors.rgb2hex(*rgb)
            self.swatchesChanged.emit()

    @Slot(int, str)
    def set_hex(self, i: int, hex_str: str) -> None:
        hex_str = (hex_str or "").strip()
        if not hex_str.startswith("#"):
            hex_str = "#" + hex_str
        if 0 <= i < len(self._swatches):
            try:
                core_colors.hex2rgb(hex_str)
            except ValueError:
                return  # half-typed hex — ignore until valid
            self._swatches[i]["hex"] = hex_str
            self.swatchesChanged.emit()

    @Slot(int)
    def select(self, i: int) -> None:
        i = -1 if i == self._selected else i
        self._selected = i
        self.selectionChanged.emit()

    @Slot(str)
    def set_name(self, name: str) -> None:
        self._name = name or ""
        self.nameChanged.emit()

    @Slot(str)
    def save(self, tags: str) -> None:
        hexes = [s["hex"] for s in self._swatches]
        if not hexes:
            self.message.emit("Nothing to save")
            return
        locks = [bool(s["locked"]) for s in self._swatches]
        name = self._name or "Untitled palette"
        self._palette_id = core_colors.save_palette(
            self._con, name, hexes, tags, self._palette_id, locked=locks)
        # keep item_tag in sync with the editor's CSV tags (single
        # source of truth going forward)
        if self._palette_id:
            core_db._sync_item_tags(self._con, self._palette_id,
                                    "palette", tags)
        self._refresh_palettes()
        self.message.emit(f"Saved: {name}")

    @Slot(int)
    def open_palette(self, palette_id: int) -> None:
        rows = self._con.execute(
            "SELECT name FROM palette WHERE id = ?", (palette_id,)).fetchone()
        if rows is None:
            return
        self._swatches = core_colors.palette_colors(self._con, palette_id)
        self._selected = -1
        self._name = rows["name"]
        self._palette_id = palette_id
        self.swatchesChanged.emit()
        self.selectionChanged.emit()
        self.nameChanged.emit()
        # paletteId is the Properties panel's item target — its QML binding
        # re-evaluates on palettesChanged, which open_palette never fired
        # (save_palette did), so the panel stayed hidden for opened palettes
        self.palettesChanged.emit()

    @Slot(int)
    def delete_palette(self, palette_id: int) -> None:
        core_colors.delete_palette(self._con, palette_id)
        if self._palette_id == palette_id:
            self._palette_id = None
        self._refresh_palettes()
        self.message.emit("Palette deleted")

    @Slot(int)
    def new_from_palette(self, palette_id: int) -> None:
        # load as a copy: clears the id so Save creates a new row
        self.open_palette(palette_id)
        self._palette_id = None

    @Slot(str, str)
    def export(self, kind: str, dest_dir: str) -> None:
        if not dest_dir:
            self.exportFailed.emit("choose a folder first")
            return
        hexes = [s["hex"] for s in self._swatches]
        try:
            out = core_colors.write_exports(self._name or "Untitled palette",
                                            hexes, dest_dir, kind)
        except (ValueError, OSError) as e:
            self.exportFailed.emit(str(e))
            return
        self.exportDone.emit(str(out))

    # ------------------------------------------------------------ internals
    def _refresh_palettes(self) -> None:
        self._palettes = core_colors.list_palettes(
            self._con, collection_id=self._collection)
        if self._smart_id:
            self._palettes = [p for p in self._palettes
                              if _matches_smart(self._con, self._smart_id, p)]
        self.palettesChanged.emit()


def _matches_smart(con, smart_id: int, row: dict) -> bool:
    """Tag/q criteria match for a palette/snippet-style row (tags column)."""
    import json as _json
    r = con.execute("SELECT criteria FROM smart_collection WHERE id = ?",
                    (smart_id,)).fetchone()
    if r is None:
        return True
    try:
        crit = _json.loads(r["criteria"] or "{}")
    except ValueError:
        return True
    tags = [t.strip().lower() for t in crit.get("tags", []) if t.strip()]
    row_tags = [t.strip().lower() for t in (row.get("tags") or "").split(",")
                if t.strip()]
    if tags:
        hit = [t in row_tags for t in tags]
        if not (all(hit) if crit.get("tag_match_all") else any(hit)):
            return False
    if crit.get("q") and str(crit["q"]).lower() not in str(
            row.get("name") or row.get("title") or "").lower():
        return False
    return True

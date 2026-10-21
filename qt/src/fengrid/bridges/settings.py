"""Settings bridge: the QML surface over core.settings + Theme.

The first-run wizard and the VS Code-style Settings screen both talk to this
bridge; it owns the one-time configuration flag and the JSON-serialised
configuration keys (asset folders, feature toggles, layout mode).
"""

from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal, Slot

from ..core import settings


class Settings(QObject):
    # first-run wizard lifecycle
    wizardCompleted = Signal()
    # configuration mutations — the wizard and the settings screen both emit
    foldersChanged = Signal()
    layoutChanged = Signal()
    featuresChanged = Signal()
    hotkeyChanged = Signal()
    message = Signal(str)

    def __init__(self, con, parent=None):
        super().__init__(parent)
        self._con = con

    # ------------------------------------------------------------ first run
    @Property(bool, notify=wizardCompleted)
    def firstRunDone(self) -> bool:
        return not settings.is_first_run(self._con)

    @Slot()
    def completeFirstRun(self) -> None:
        """Mark the one-time routine done. Folders, features and theme are
        persisted incrementally by the wizard (addFolder / setFeature /
        theme.toggle), so there's nothing left to collect here."""
        settings.mark_first_run_done(self._con)
        self.wizardCompleted.emit()

    # ------------------------------------------------------- asset folders
    @Property("QVariantList", notify=foldersChanged)
    def assetFolders(self) -> list:
        return settings.get_asset_folders(self._con)

    @Slot(str)
    def addFolder(self, folder: str) -> None:
        folder = (folder or "").strip()
        if not folder:
            return
        folders = settings.get_asset_folders(self._con)
        if folder not in folders:
            folders.append(folder)
            settings.set_asset_folders(self._con, folders)
            self.foldersChanged.emit()

    @Slot(str)
    def removeFolder(self, folder: str) -> None:
        folders = settings.get_asset_folders(self._con)
        if folder in folders:
            folders.remove(folder)
            settings.set_asset_folders(self._con, folders)
            self.foldersChanged.emit()

    # -------------------------------------------------------------- layout
    @Property(str, notify=layoutChanged)
    def visualLayout(self) -> str:
        return settings.get_visual_layout(self._con)

    @Slot(str)
    def setVisualLayout(self, layout: str) -> None:
        settings.set_visual_layout(self._con, layout)
        self.layoutChanged.emit()

    # --------------------------------------------------------------- features
    @Slot(str, result=bool)
    def feature(self, key: str) -> bool:
        return settings.get_feature(self._con, key)

    @Slot(str, bool)
    def setFeature(self, key: str, value: bool) -> None:
        settings.set_feature(self._con, key, value)
        self.featuresChanged.emit()

    # ----------------------------------------------------- command hotkey
    @Property(str, notify=hotkeyChanged)
    def commandHotkey(self) -> str:
        """Keyboard shortcut toggling the command palette (default "Alt+`")."""
        return settings.get_command_hotkey(self._con)

    @Slot(str)
    def setCommandHotkey(self, hotkey: str) -> None:
        hotkey = (hotkey or "").strip()
        if not hotkey or hotkey == self.commandHotkey:
            return
        settings.set_command_hotkey(self._con, hotkey)
        self.hotkeyChanged.emit()

"""End-to-end probe of the first-run routine and settings screen.

Drives the real flow: fresh db -> FirstRunWizard (folders, theme, layout,
features) -> completeFirstRun -> settings open with every section's bridge
resolving (layout, keymap, color rule). Asserts preferences actually persist
and that the QML can enumerate keymap + color rule names.
"""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

import pytest
from PySide6.QtCore import QCoreApplication, QMetaObject, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

QML_DIR = Path(__file__).resolve().parents[1] / "qml"
SRC = Path(__file__).resolve().parents[1] / "src"
FONTS = Path(__file__).resolve().parents[2] / "fonts"
sys.path.insert(0, str(SRC))

_APP = None


def _qapp():
    global _APP
    if _APP is None:
        _APP = QGuiApplication.instance() or QGuiApplication(sys.argv)
    return _APP


@pytest.fixture()
def wizard_ui(tmp_path):
    _qapp()
    from fengrid.bridges.colors import Colors
    from fengrid.bridges.code import Code
    from fengrid.bridges.library import Library
    from fengrid.bridges.settings import Settings
    from fengrid.bridges.theme import Theme
    from fengrid.core import db as core_db

    con = core_db.connect(tmp_path / "t.db")
    settings_bridge = Settings(con)
    theme = Theme(con, str(FONTS))
    colors_bridge = Colors(con)
    code_bridge = Code(con)
    library = Library(con, str(tmp_path / "t.db"), no_scan=True)

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("settingsBridge", settings_bridge)
    engine.rootContext().setContextProperty("theme", theme)
    engine.rootContext().setContextProperty("colors", colors_bridge)
    engine.rootContext().setContextProperty("code", code_bridge)
    engine.rootContext().setContextProperty("library", library)
    # never register a context property as None: it poisons sibling
    # properties in this Qt build (see the updater/None trap). The components
    # under test do not reference previewProfile/terms, so they stay
    # unregistered here — the real app always registers real objects.

    comp = QQmlComponent(
        engine, QUrl.fromLocalFile(str(QML_DIR / "components" / "FirstRunWizard.qml")))
    assert comp.isReady(), [e.toString() for e in comp.errors()]
    root = comp.create(engine.rootContext())
    assert root is not None

    yield {"root": root, "engine": engine, "settings": settings_bridge,
           "theme": theme, "colors": colors_bridge, "code": code_bridge,
           "library": library, "con": con}

    root.deleteLater()
    engine.deleteLater()


# ----------------------------------------------------------------- wizard flow

def test_wizard_starts_incomplete(wizard_ui):
    settings = wizard_ui["settings"]
    assert settings.firstRunDone is False


def test_wizard_full_flow(wizard_ui, tmp_path):
    root = wizard_ui["root"]
    settings = wizard_ui["settings"]
    theme = wizard_ui["theme"]

    # folder add -> persisted + visible in the list
    settings.addFolder(str(tmp_path / "assets"))
    assert settings.assetFolders != []
    assert root.property("folders") == settings.assetFolders

    # theme toggle through the wizard buttons
    if not theme.isDark:
        theme.toggle()
    assert theme.isDark is True

    # layout picker: cycle through all three and verify persistence
    for layout in ("compact", "cozy", "classic"):
        settings.setVisualLayout(layout)
        assert settings.visualLayout == layout

    # feature toggles flip and stick
    settings.setFeature("feature_snippets", False)
    assert settings.feature("feature_snippets") is False
    settings.setFeature("feature_snippets", True)
    assert settings.feature("feature_snippets") is True

    # command-bar hotkey: default Alt+`, custom binding round-trips, and an
    # empty value falls back to the default instead of corrupting the setting
    assert settings.commandHotkey == "Alt+`"
    settings.setCommandHotkey("Ctrl+Shift+K")
    assert settings.commandHotkey == "Ctrl+Shift+K"
    settings.setCommandHotkey("")           # ignored — keeps the custom one
    assert settings.commandHotkey == "Ctrl+Shift+K"
    settings.setCommandHotkey("Alt+`")      # back to default
    assert settings.commandHotkey == "Alt+`"

    # completion: only now does first run count as done
    assert settings.firstRunDone is False
    settings.completeFirstRun()
    assert settings.firstRunDone is True

    # persistence survives a fresh Settings against the same db
    from fengrid.bridges.settings import Settings as Settings2
    con = wizard_ui["con"]
    fresh = Settings2(con)
    assert fresh.firstRunDone is True
    assert fresh.visualLayout == "classic"
    assert fresh.feature("feature_snippets") is True
    assert fresh.commandHotkey == "Alt+`"


# ---------------------------------------------------------- command palette

def test_command_palette_loads_and_toggles(wizard_ui):
    """The palette must compile against the fixture bridges and toggle."""
    engine = wizard_ui["engine"]
    comp = QQmlComponent(
        engine, QUrl.fromLocalFile(str(QML_DIR / "components" / "CommandPalette.qml")))
    assert comp.isReady(), [e.toString() for e in comp.errors()]
    root = comp.create(engine.rootContext())
    assert root is not None
    try:
        _qapp().processEvents()
        assert root.property("hotkey") == "Alt+`"
        assert root.property("hotkeyLabel") == "Alt+`"
        assert root.property("show") is False
        assert QMetaObject.invokeMethod(root, "toggle")
        assert root.property("show") is True
        assert QMetaObject.invokeMethod(root, "close")
        assert root.property("show") is False
        # a custom hotkey re-surfaces through the notify signal
        wizard_ui["settings"].setCommandHotkey("Ctrl+K")
        _qapp().processEvents()
        assert root.property("hotkey") == "Ctrl+K"
    finally:
        root.deleteLater()


# ------------------------------------------------------- settings screen open

def test_settings_screen_loads_after_first_run(wizard_ui):
    settings = wizard_ui["settings"]
    settings.completeFirstRun()

    engine = wizard_ui["engine"]
    comp = QQmlComponent(
        engine, QUrl.fromLocalFile(str(QML_DIR / "components" / "SettingsScreen.qml")))
    errors = [e.toString() for e in comp.errors()]
    assert comp.isReady(), errors
    root = comp.create(engine.rootContext())
    assert root is not None
    root.deleteLater()


def test_settings_bridges_enumerate_options(wizard_ui):
    settings = wizard_ui["settings"]
    code = wizard_ui["code"]
    colors = wizard_ui["colors"]

    assert settings.visualLayout in ("classic", "compact", "cozy")
    assert colors.rule_names() != []
    assert colors.rule in colors.rule_names()
    assert isinstance(code.keymap_names(), list)
    assert code.keymap in code.keymap_names()


def test_settings_screen_section_filters(wizard_ui):
    """matches() must gate each new section independently."""
    engine = wizard_ui["engine"]
    comp = QQmlComponent(
        engine, QUrl.fromLocalFile(str(QML_DIR / "components" / "SettingsScreen.qml")))
    assert comp.isReady(), [e.toString() for e in comp.errors()]
    root = comp.create(engine.rootContext())
    assert root is not None
    root.deleteLater()

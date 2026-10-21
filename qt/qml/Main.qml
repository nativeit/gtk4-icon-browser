import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    minimumWidth: 960
    minimumHeight: 560
    visible: true
    title: qsTr("Fengrid — the UI asset explorer")
    color: theme.tokens.bg
    font.family: theme.uiFont
    font.pixelSize: 13

    property int iconSize: sizeSlider.value
    // 0 = icons, 1 = fonts, 2 = colors, 3 = code, 4 = projects (top-bar
    // pane switcher); --pane N (QA) overrides via the initialPane context
    property int pane: typeof initialPane !== "undefined" ? initialPane : 0
    // settings overlay + first-run routine state
    property bool showSettings: false
    // command palette (Alt+` by default, user-configurable in settings)
    property bool showPalette: false
    property bool firstRunComplete: settingsBridge !== null
                                    && settingsBridge.firstRunDone
    // the configured command-bar hotkey as a QKeySequence string. The stored
    // value is already canonical for the platform: on X11/Windows/macOS a
    // plain Alt+` press reports as Key_QuoteLeft+Alt with no folded Shift, so
    // a single binding matches reliably (unlike Alt+~, whose key needs Shift —
    // see the probe notes in components/CommandPalette.qml).
    readonly property string paletteSequence:
        settingsBridge !== null ? settingsBridge.commandHotkey : "Alt+`"
    // display form for placeholder tips — Qt's "Alt" IS Option on macOS
    readonly property string paletteHotkeyLabel:
        Qt.platform.os === "osx"
        ? paletteSequence.replace(/Alt/g, "Option")
        : paletteSequence

    header: Rectangle {
        height: 52
        // subtle vertical depth: surface fading toward bg at the bottom,
        // with a hairline divider — reads as a floating translucent bar
        // over the content
        gradient: Gradient {
            GradientStop { position: 0; color: theme.tokens.surface }
            GradientStop { position: 0.82; color: theme.tokens.surface }
            GradientStop { position: 1; color: Qt.rgba(
                theme.tokens.surface.r, theme.tokens.surface.g,
                theme.tokens.surface.b, 0.86) }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: theme.tokens.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 12

            // main menu button — settings/preferences, rescan, about
            IconButton {
                id: mainMenuBtn
                icon_name: "menu"
                ToolTip.text: qsTr("Main menu")
                onClicked: mainMenu.popup(mainMenuBtn.x, mainMenuBtn.y + height + 4)
            }

            // glint-quad mini mark (branding/assets/fengrid-mark.svg shape)
            Item {
                width: 22
                height: 22
                Layout.alignment: Qt.AlignVCenter
                Grid {
                    anchors.fill: parent
                    columns: 2
                    columnSpacing: 2
                    rowSpacing: 2
                    Repeater {
                        model: 4
                        Rectangle {
                            width: 9
                            height: 9
                            radius: 2
                            color: index === 3 ? theme.tokens.litPane : "transparent"
                            border.color: index === 3 ? "transparent" : theme.tokens.accent
                            border.width: 1.6
                        }
                    }
                }
            }

            Text {
                text: qsTr("Fengrid")
                font.family: theme.headingFont
                font.pixelSize: 20
                font.letterSpacing: 1.6
                font.capitalization: Font.AllUppercase
                color: theme.tokens.text
            }

            Rectangle {
                width: 1
                height: 22
                color: theme.tokens.border
                Layout.alignment: Qt.AlignVCenter
            }

            // search mode: smart (FTS) | fuzzy | regex | content
            ComboBox {
                id: searchModeBox
                Layout.preferredHeight: 32
                Layout.preferredWidth: 104
                model: [qsTr("Smart"), qsTr("Fuzzy"), qsTr("Regex"),
                        qsTr("Content")]
                ToolTip.visible: hovered
                ToolTip.text: qsTr(
                    "Smart: fast indexed prefix search · Fuzzy: close matches"
                    + " rank first · Regex: regular expressions over names"
                    + " and paths · Content: search inside snippets and text"
                    + " files (bounded I/O)")
                onActivated: function (idx) {
                    library !== null && library.set_search_mode(
                        ["smart", "fuzzy", "regex", "content"][idx])
                }
                background: Rectangle {
                    radius: 6
                    color: theme.tokens.surface2
                    border.color: theme.tokens.border
                }
                contentItem: Text {
                    text: searchModeBox.displayText
                    font.family: theme.monoFont
                    font.pixelSize: 11
                    color: theme.tokens.textMuted
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                }
            }

            Rectangle {
                id: searchBox
                // The command bar: live asset search inline, and it expands
                // into the full command palette on click or the hotkey.
                // flexible: fills the space the pane switcher leaves, so the
                // right-side controls never clip at minimum window width
                Layout.fillWidth: true
                Layout.minimumWidth: 140
                Layout.maximumWidth: 320
                Layout.preferredHeight: 32
                radius: 6
                color: theme.tokens.surface2
                border.color: searchField.activeFocus ? theme.tokens.accent
                                                      : theme.tokens.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 5
                        color: barMa.containsMouse
                               ? theme.tokens.border : "transparent"
                        IconImage {
                            anchors.centerIn: parent
                            name: "search"
                            px: 15
                            tint: barMa.containsMouse ? theme.tokens.accent
                                                      : theme.tokens.textMuted
                        }
                        MouseArea {
                            id: barMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.text: qsTr("Open the command bar (%1)")
                                          .arg(root.paletteHotkeyLabel)
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 400
                            onClicked: commandPalette.open(searchField.text)
                        }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        // the tip surfaces the user's configured hotkey
                        placeholderText: qsTr("Search or run a command  ( %1 )")
                                         .arg(root.paletteHotkeyLabel)
                        color: theme.tokens.text
                        placeholderTextColor: theme.tokens.textMuted
                        background: null
                        selectByMouse: true
                        font.family: theme.uiFont
                        font.pixelSize: 12
                        onTextChanged: searchDebounce.restart()
                        // Enter expands into the palette with the seed term
                        onAccepted: commandPalette.open(text)
                    }

                    IconImage {
                        name: "x"
                        px: 13
                        tint: theme.tokens.textMuted
                        visible: searchField.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.clear()
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 180
                    onTriggered: library.set_search(searchField.text)
                }
            }

            Item { Layout.fillWidth: true }

            IconImage {
                name: "grid"
                px: 15
                tint: theme.tokens.textMuted
                Layout.alignment: Qt.AlignVCenter
            }
            Slider {
                id: sizeSlider
                from: 16
                to: 256
                stepSize: 16
                value: 32
                Layout.preferredWidth: 110
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: sizeSlider.value + "px"
                font.family: theme.monoFont
                font.pixelSize: 11
                color: theme.tokens.textMuted
                Layout.preferredWidth: 34
                Layout.alignment: Qt.AlignVCenter
            }

            IconButton {
                icon_name: theme.isDark ? "sun" : "moon"
                ToolTip.text: theme.isDark ? qsTr("Switch to light")
                                           : qsTr("Switch to dark")
                onClicked: theme.toggle()
            }
            IconButton {
                icon_name: "refresh"
                enabled: !library.scanning
                ToolTip.text: qsTr("Re-scan library")
                onClicked: library.rescan()
            }
            BusyIndicator {
                visible: library.scanning
                running: library.scanning
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SideRail {
            id: sideRail
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            pane: root.pane
            onPanePicked: idx => root.pane = idx
        }
        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: theme.tokens.border
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.pane

            AssetGrid {
                id: grid
                iconPx: root.iconSize
            }
            Fonts {}
            Colors {}
            Code {}
            Projects {}
        }

        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: theme.tokens.border
            visible: inspectorPanel.visible
        }
        InspectorPanel {
            id: inspectorPanel
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            gridView: grid
            index: grid.currentIndex
            visible: root.pane === 0 && grid.currentIndex >= 0
        }
        // universal Properties panel for the other asset kinds (fonts,
        // color schemes, code snippets) — tags, custom fields, links
        PropertiesPanel {
            id: propsPanel
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            itemKind: root.pane === 1 ? "font"
                      : root.pane === 2 ? "palette" : "snippet"
            itemId: root.pane === 1
                    ? (fonts !== null
                       ? fonts.family_primary_id(fonts.selectedFamily) : -1)
                    : root.pane === 2
                      ? (colors !== null ? colors.paletteId : -1)
                      : (code !== null ? code.currentId : -1)
            visible: root.pane >= 1 && root.pane <= 3 && itemId >= 0
        }
    }

    // full-window accent flash on pane switch — a translucent wash of the
    // incoming pane's category color, fading fast
    Rectangle {
        id: paneFlash
        anchors.fill: parent
        color: theme.tokens.accent
        opacity: 0
        z: 99
        enabled: false
        function flash() {
            color = [theme.tokens.accentIcon, theme.tokens.accentFont,
                     theme.tokens.accentColor, theme.tokens.accentCode,
                     theme.tokens.accentProject][root.pane]
            paneFlashAnim.restart()
        }
        Connections {
            target: root
            function onPaneChanged() { paneFlash.flash() }
        }
        NumberAnimation {
            id: paneFlashAnim
            target: paneFlash
            property: "opacity"
            from: 0.07
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    footer: Rectangle {
        height: 26
        color: theme.tokens.surface
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6
            Text {
                text: library !== null
                      ? (library.scanning
                         ? qsTr("indexing… %1").arg(library.scanCount)
                         : qsTr("%1 assets%2").arg(library.totalAssets)
                           .arg(library.lastScan !== ""
                                ? qsTr(" · indexed ") + library.lastScan : ""))
                      : ""
                font.family: theme.monoFont
                font.pixelSize: 11
                color: theme.tokens.textMuted
            }
            Item { Layout.fillWidth: true }
            Text {
                id: versionText
                // shows the version; flips to an amber notice when the
                // background release probe finds something newer — click
                // either state to re-check / open the releases page
                text: updater !== null && updater.updateAvailable
                      ? qsTr("update available: ") + updater.latestVersion
                      + " — click to open"
                      : "fengrid " + appVersion
                font.family: theme.monoFont
                font.pixelSize: 11
                color: updater !== null && updater.updateAvailable
                       ? theme.tokens.hlInk : theme.tokens.textMuted
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (updater === null)
                            return
                        if (updater.updateAvailable)
                            Qt.openUrlExternally(updater.releasesUrl)
                        else
                            updater.check()
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "/"
        enabled: !searchField.activeFocus
        onActivated: {
            searchField.forceActiveFocus()
            searchField.selectAll()
        }
    }
    Shortcut {
        sequence: "Ctrl+C"
        enabled: grid.currentIndex >= 0
        onActivated: library.copy_name(grid.currentIndex)
    }
    Shortcut {
        sequence: "Escape"
        enabled: grid.currentIndex >= 0
        onActivated: grid.currentIndex = -1
    }
    // Ctrl+1..5 — quick pane switching matching the top-bar order
    Shortcut { sequence: "Ctrl+1"; onActivated: root.pane = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: root.pane = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: root.pane = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: root.pane = 3 }
    Shortcut { sequence: "Ctrl+5"; onActivated: root.pane = 4 }

    // command palette toggle — user-configurable, defaults to Alt+`
    // (Option+` on macOS). Disabled during the first-run routine so the
    // wizard can't be covered by an invisible overlay.
    Shortcut {
        sequence: root.paletteSequence
        enabled: !(settingsBridge !== null && !settingsBridge.firstRunDone)
        onActivated: commandPalette.toggle()
    }

    // QA: --dialog <name> opens a registered modal after load — delayed so
    // the window is mapped first (a Popup opened pre-show never appears)
    function openQaModal(name) {
        var dlg = (sideRail && sideRail.qaModals
                   && sideRail.qaModals[name])
                  ? sideRail.qaModals[name]
                  : (inspectorPanel && inspectorPanel.qaModals
                     ? inspectorPanel.qaModals[name] : null)
        if (dlg)
            dlg.open()
    }
    Timer {
        interval: 400
        running: typeof qaOpenModal !== "undefined" && qaOpenModal !== ""
        onTriggered: openQaModal(qaOpenModal)
    }

    // QA: --palette / --settings open those overlays after the window maps
    Timer {
        interval: 400
        running: typeof initialPalette !== "undefined" && initialPalette
        onTriggered: commandPalette.open()
    }
    Timer {
        interval: 400
        running: typeof initialSettings !== "undefined" && initialSettings
        onTriggered: root.showSettings = true
    }

    Toast { id: toast }

    Connections {
        target: library
        function onMessage(msg) { toast.show(msg) }
        function onExportDone(path) { toast.show(qsTr("Exported to %1").arg(path)) }
        function onExportFailed(err) { toast.show(qsTr("Export failed: %1").arg(err)) }
    }
    Connections {
        target: fonts
        function onMessage(msg) { toast.show(msg) }
        function onExportDone(path) { toast.show(qsTr("Exported to %1").arg(path)) }
        function onExportFailed(err) { toast.show(qsTr("Export failed: %1").arg(err)) }
    }
    Connections {
        target: colors
        function onMessage(msg) { toast.show(msg) }
        function onExportDone(path) { toast.show(qsTr("Exported to %1").arg(path)) }
        function onExportFailed(err) { toast.show(qsTr("Export failed: %1").arg(err)) }
    }
    Connections {
        target: code
        function onMessage(msg) { toast.show(msg) }
        function onImportFailed(err) { toast.show(qsTr("Import failed: %1").arg(err)) }
    }
    Connections {
        target: projects
        function onMessage(msg) { toast.show(msg) }
        function onExportDone(path) { toast.show(qsTr("Exported to %1").arg(path)) }
        function onExportFailed(err) { toast.show(qsTr("Export failed: %1").arg(err)) }
    }

    // ------------------------------------------------------- main menu
    Menu {
        id: mainMenu
        background: Rectangle {
            color: theme.tokens.surface
            border.color: theme.tokens.border
            radius: 8
        }
        MenuItem {
            text: qsTr("Settings / Preferences…")
            height: 30
            onTriggered: root.showSettings = true
        }
        MenuSeparator { }
        MenuItem {
            text: qsTr("Re-scan library")
            height: 30
            enabled: library !== null && !library.scanning
            onTriggered: library.rescan()
        }
    }

    // -------------------------------------------------- settings overlay
    // VS Code-style full-screen settings; the workbench hides while open
    SettingsScreen {
        id: settingsOverlay
        anchors.fill: parent
        visible: root.showSettings
        z: 400
        onClosed: root.showSettings = false
    }

    // --------------------------------------------------- command palette
    // expands from the command bar: VS Code command palette + Spotlight +
    // Alfred-style live asset search, one overlay.
    CommandPalette {
        id: commandPalette
        anchors.fill: parent
        onPaneRequested: idx => root.pane = idx
        onSettingsRequested: root.showSettings = true
        onSearchRequested: term => searchField.text = term
        // a picked suggestion: jump to its pane and surface the item there
        onAssetRequested: function (kind, itemId, label) {
            if (kind === "icon")
                searchField.text = label
            else if (kind === "font" && fonts !== null) {
                fonts.set_filter(label)
                fonts.select(label)
            } else if (kind === "palette" && colors !== null)
                colors.open_palette(itemId)
            else if (kind === "snippet" && code !== null)
                code.open_snippet(itemId)
        }
    }

    // ---------------------------------------------------- first-run overlay
    // one-time configuration routine: paths, theme, features — shown once
    // on the very first launch, never again once marked done
    FirstRunWizard {
        anchors.fill: parent
        visible: settingsBridge !== null && !settingsBridge.firstRunDone
        z: 500
        onFinished: root.firstRunComplete = true
    }
}

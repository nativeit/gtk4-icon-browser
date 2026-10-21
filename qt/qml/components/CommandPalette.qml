import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Command palette — Spotlight/VS Code hybrid. Toggled by the user's
// configured hotkey (default Alt+`, Option+` on macOS). Searches and runs
// commands: pane navigation, theme, settings, rescans — plus Alfred-style
// live asset suggestions across all four kinds (a pick jumps to the item in
// its pane). Escape or a backdrop click closes it.
Rectangle {
    id: palette

    anchors.fill: parent
    color: "transparent"
    z: 450

    // visibility is data-driven (a bare `visible` binding is what the
    // open/close functions toggle through the window-owned property) — the
    // palette is only interactive while `show` is true
    property bool show: false
    visible: show

    signal paneRequested(int idx)
    signal settingsRequested()
    signal searchRequested(string term)
    signal assetRequested(string kind, int itemId, string label)

    // ---- hotkey handling -------------------------------------------------
    // The stored sequence (e.g. "Alt+`") is shown verbatim on Windows/Linux
    // and with "Alt" re-labelled "Option" on macOS.
    readonly property string hotkey: settingsBridge !== null
                                     ? settingsBridge.commandHotkey
                                     : "Alt+`"
    readonly property string hotkeyLabel: Qt.platform.os === "osx"
                                          ? hotkey.replace(/Alt/g, "Option")
                                          : hotkey

    readonly property int rowH: 40
    readonly property int listMax: 340

    function open(seed) {
        field.text = seed !== undefined ? String(seed) : ""
        list.currentIndex = 0
        show = true
        field.forceActiveFocus()
    }
    function close() {
        show = false
        field.text = ""
    }
    function toggle() {
        show ? close() : open()
    }

    // ------------------------------------------------------------ commands
    // Free text always offers a live asset-search action; the fixed command
    // list is filtered by case-insensitive substring on label/detail.
    readonly property var baseCommands: [
        {
            label: qsTr("Go to Icons"),
            detail: qsTr("Browse the icon grid"),
            icon: "grid", hint: "Ctrl+1",
            run: function () { palette.paneRequested(0) }
        },
        {
            label: qsTr("Go to Fonts"),
            detail: qsTr("Browse the font library"),
            icon: "type", hint: "Ctrl+2",
            run: function () { palette.paneRequested(1) }
        },
        {
            label: qsTr("Go to Colors"),
            detail: qsTr("Open the color designer"),
            icon: "droplet", hint: "Ctrl+3",
            run: function () { palette.paneRequested(2) }
        },
        {
            label: qsTr("Go to Code"),
            detail: qsTr("Open the snippet workbench"),
            icon: "code", hint: "Ctrl+4",
            run: function () { palette.paneRequested(3) }
        },
        {
            label: qsTr("Go to Projects"),
            detail: qsTr("Open the project board"),
            icon: "package", hint: "Ctrl+5",
            run: function () { palette.paneRequested(4) }
        },
        {
            label: theme.isDark ? qsTr("Switch to light theme")
                                : qsTr("Switch to dark theme"),
            detail: qsTr("Toggle the visual theme"),
            icon: theme.isDark ? "sun" : "moon",
            run: function () { theme.toggle() }
        },
        {
            label: qsTr("Open Settings / Preferences…"),
            detail: qsTr("Configure Fengrid"),
            icon: "settings",
            run: function () { palette.settingsRequested() }
        },
        {
            label: qsTr("Re-scan asset library"),
            detail: qsTr("Re-index every configured folder"),
            icon: "refresh",
            enabled: library !== null && !library.scanning,
            run: function () { if (library !== null) library.rescan() }
        }
    ]

    property var results: palette.buildRows(field.text)

    // Deterministic list height: the model length is always known even when
    // the ListView has not yet instantiated delegates (contentHeight reads 0
    // until items exist, which closes a sizing feedback loop).
    readonly property int resultsCount: results ? results.length : 0
    readonly property int listH:
        Math.min(resultsCount * rowH, listMax)

    function buildRows(text) {
        var cmds = []
        var term = text.trim().toLowerCase()
        for (var i = 0; i < baseCommands.length; ++i) {
            var c = baseCommands[i]
            if (c.enabled === false)
                continue
            if (term !== "" &&
                c.label.toLowerCase().indexOf(term) < 0 &&
                c.detail.toLowerCase().indexOf(term) < 0)
                continue
            cmds.push(c)
        }
        // free text also routes into the main asset search — the Dash/Alfred
        // piece of the hybrid
        if (term !== "") {
            cmds.push({
                label: qsTr("Search assets for \u201C%1\u201D").arg(text.trim()),
                detail: qsTr("Filter the asset grid"),
                icon: "search",
                run: function () { palette.searchRequested(text.trim()) }
            })
            // live cross-kind suggestions: picking one jumps to the item in
            // its pane
            if (library !== null) {
                var hits = library.suggest(text.trim())
                for (var j = 0; j < hits.length; ++j) {
                    cmds.push({
                        label: hits[j].label,
                        detail: hits[j].kind,
                        icon: hits[j].icon,
                        run: (function (h) {
                            return function () {
                                palette.paneRequested(h.pane)
                                palette.assetRequested(h.kind, h.item_id,
                                                       h.label)
                            }
                        })(hits[j])
                    })
                }
            }
        }
        return cmds
    }

    function runRow(idx) {
        if (idx < 0 || idx >= results.length)
            return
        var cmd = results[idx]
        close()
        if (cmd && cmd.run)
            cmd.run()
    }

    // ----------------------------------------------------------- backdrop
    // translucent scrim — a click anywhere outside the panel dismisses
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, theme.isDark ? 0.45 : 0.25)
        MouseArea {
            anchors.fill: parent
            onClicked: palette.close()
            // wheel/backdrop drags should not reach the workbench below
            onWheel: function (w) { w.accepted = true }
        }
    }

    // -------------------------------------------------------------- panel
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 96
        width: Math.min(620, palette.width - 96)
        // height sized from the model count (see listH) — reading the
        // children's laid-out height here closes a ColumnLayout feedback loop
        // that collapses the list to zero.
        height: 48 + palette.listH + 1
        color: theme.tokens.surface
        radius: 10
        border.color: theme.tokens.border

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // input row
            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    IconImage {
                        name: "search"
                        px: 17
                        tint: theme.tokens.textMuted
                        Layout.alignment: Qt.AlignVCenter
                    }
                    TextField {
                        id: field
                        Layout.fillWidth: true
                        // dynamic tip: always surfaces the configured hotkey
                        placeholderText: qsTr(
                            "Search or run a command — press %1 to toggle")
                            .arg(palette.hotkeyLabel)
                        color: theme.tokens.text
                        placeholderTextColor: theme.tokens.textMuted
                        background: null
                        selectByMouse: true
                        font.family: theme.uiFont
                        font.pixelSize: 14
                        verticalAlignment: TextInput.AlignVCenter

                        Keys.onUpPressed: {
                            if (list.currentIndex > 0)
                                list.currentIndex--
                        }
                        Keys.onDownPressed: {
                            if (list.currentIndex < results.length - 1)
                                list.currentIndex++
                        }
                        Keys.onReturnPressed: palette.runRow(list.currentIndex)
                        Keys.onEnterPressed: palette.runRow(list.currentIndex)
                        Keys.onEscapePressed: palette.close()
                    }
                    IconButton {
                        icon_name: "x"
                        visible: field.text.length > 0
                        ToolTip.text: qsTr("Clear")
                        onClicked: {
                            field.clear()
                            field.forceActiveFocus()
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: theme.tokens.border
                }
            }

            // results
            Rectangle {
                id: listContainer
                Layout.fillWidth: true
                Layout.preferredHeight: palette.listH
                color: "transparent"
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    model: palette.results
                    currentIndex: 0
                    keyNavigationWraps: false
                    spacing: 0

                    ScrollIndicator.vertical: ScrollIndicator { }

                    delegate: Rectangle {
                        width: list.width
                        height: palette.rowH
                        color: list.currentIndex === index
                               ? theme.tokens.surface2 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Rectangle {
                                width: 26; height: 26; radius: 6
                                // accent is a hex string in the theme tokens,
                                // so a translucent tint has to come from a
                                // child overlay rather than Qt.rgba(x.r, …)
                                color: theme.tokens.surface2
                                IconImage {
                                    anchors.centerIn: parent
                                    name: modelData.icon
                                    px: 14
                                    tint: theme.tokens.textMuted
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: theme.tokens.accent
                                    opacity: list.currentIndex === index ? 0.16 : 0
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    name: modelData.icon
                                    px: 14
                                    tint: theme.tokens.accent
                                    opacity: list.currentIndex === index ? 1 : 0
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.family: theme.uiFont
                                font.pixelSize: 13
                                color: theme.tokens.text
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: modelData.detail !== ""
                                text: modelData.detail
                                font.family: theme.uiFont
                                font.pixelSize: 11
                                color: theme.tokens.textMuted
                                elide: Text.ElideRight
                                Layout.maximumWidth: panel.width * 0.3
                            }
                            Text {
                                visible: !!modelData.hint
                                // rows without a hint must not push
                                // undefined into a QString binding
                                text: modelData.hint !== undefined
                                     ? modelData.hint : ""
                                font.family: theme.monoFont
                                font.pixelSize: 10
                                color: theme.tokens.textMuted
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = index
                            onClicked: palette.runRow(index)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: qsTr("No matching commands")
                        font.family: theme.uiFont
                        font.pixelSize: 12
                        color: theme.tokens.textMuted
                    }
                }
            }
        }

        // footer: keeps the hotkey tip visible even while typing
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: theme.tokens.border
        }
    }
}

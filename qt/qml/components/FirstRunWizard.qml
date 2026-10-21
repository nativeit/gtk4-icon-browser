import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// First-run configuration routine: ONE screen shown once on first launch.
// The user defines asset folders (scan starts immediately while they finish
// the visual + feature sections), picks the theme, and toggles core
// features. Completing the routine marks first_run_done in Settings and
// the main workbench takes over.
Rectangle {
    id: wizard
    color: theme.tokens.bg
    z: 500
    anchors.fill: parent

    property var folders: (settingsBridge !== null) ? settingsBridge.assetFolders : []

    // initial scan fired as soon as folders are defined — the routine runs
    // while the user configures the rest of the screen
    function startScan() {
        if (library !== null) library.rescan()
    }

    signal finished()

    Rectangle {
        id: content
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 780)
        height: Math.min(parent.height - 60, 620)
        color: theme.tokens.surface
        radius: 10
        border.color: theme.tokens.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            Text {
                text: qsTr("Welcome to Fengrid")
                font.family: theme.headingFont
                font.pixelSize: 28
                color: theme.tokens.text
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("A one-time setup: pick your asset folders — the first index " +
                           "runs while you finish configuring the rest.")
                font.family: theme.uiFont
                font.pixelSize: 13
                color: theme.tokens.textMuted
                wrapMode: Text.Wrap
            }

            // ------------------------------------------------ asset folders
            Text {
                text: qsTr("Asset folders")
                font.family: theme.uiFont
                font.pixelSize: 12
                font.bold: true
                color: theme.tokens.text
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.tokens.bg
                radius: 6
                border.color: theme.tokens.border
                ListView {
                    id: folderList
                    anchors.fill: parent
                    anchors.margins: 8
                    model: wizard.folders
                    spacing: 4
                    clip: true
                    delegate: RowLayout {
                        width: folderList.width
                        height: 30
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            font.family: theme.monoFont
                            font.pixelSize: 12
                            color: theme.tokens.text
                            elide: Text.ElideMiddle
                        }
                        IconButton {
                            icon_name: "trash"
                            onClicked: {
                                settingsBridge.removeFolder(modelData)
                                wizard.folders = settingsBridge.assetFolders
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: folderList.count === 0
                        text: qsTr("No folders yet — add one below")
                        color: theme.tokens.textMuted
                        font.pixelSize: 12
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: folderInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("/path/to/icon/library")
                    color: theme.tokens.text
                    font.family: theme.monoFont
                    font.pixelSize: 12
                    background: Rectangle {
                        color: theme.tokens.bg
                        radius: 4
                        border.color: folderInput.activeFocus
                                      ? theme.tokens.accent : theme.tokens.border
                    }
                    onAccepted: addBtn.clicked()
                }
                Button {
                    id: addBtn
                    text: qsTr("Add")
                    enabled: folderInput.text.length > 0
                    onClicked: {
                        settingsBridge.addFolder(folderInput.text.trim())
                        folderInput.text = ""
                        wizard.folders = settingsBridge.assetFolders
                        wizard.startScan()
                    }
                }
            }

            // ----------------------------------------------------- theme row
            Text {
                text: qsTr("Visual theme")
                font.family: theme.uiFont
                font.pixelSize: 12
                font.bold: true
                color: theme.tokens.text
            }
            RowLayout {
                spacing: 12
                Button {
                    text: qsTr("Dark")
                    checkable: true
                    checked: theme.isDark
                    onClicked: if (!theme.isDark) theme.toggle()
                }
                Button {
                    text: qsTr("Light")
                    checkable: true
                    checked: !theme.isDark
                    onClicked: if (theme.isDark) theme.toggle()
                }
            }

            // ------------------------------------------------ visual layout
            Text {
                text: qsTr("Visual layout")
                font.family: theme.uiFont
                font.pixelSize: 12
                font.bold: true
                color: theme.tokens.text
            }
            RowLayout {
                spacing: 12
                Repeater {
                    model: ["classic", "compact", "cozy"]
                    Button {
                        text: modelData
                        checkable: true
                        checked: settingsBridge.visualLayout === modelData
                        onClicked: settingsBridge.setVisualLayout(modelData)
                    }
                }
            }

            // ------------------------------------------------ command bar
            Text {
                text: qsTr("Command bar shortcut")
                font.family: theme.uiFont
                font.pixelSize: 12
                font.bold: true
                color: theme.tokens.text
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("One keystroke opens search, commands, and navigation —" +
                           " like Spotlight or Alfred. Default Alt+` (Option+` on" +
                           " macOS); change it here or anytime in Settings.")
                font.family: theme.uiFont
                font.pixelSize: 12
                color: theme.tokens.textMuted
                wrapMode: Text.Wrap
            }
            HotkeyField {
                hotkey: settingsBridge !== null
                        ? settingsBridge.commandHotkey : "Alt+`"
                onCommitted: seq => {
                    if (settingsBridge !== null)
                        settingsBridge.setCommandHotkey(seq)
                }
            }

            // ------------------------------------------------ feature toggles
            Text {
                text: qsTr("Core features")
                font.family: theme.uiFont
                font.pixelSize: 12
                font.bold: true
                color: theme.tokens.text
            }
            CheckBox {
                text: qsTr("Colors pane")
                checked: settingsBridge.feature("feature_colors")
                onCheckedChanged: settingsBridge.setFeature(
                    "feature_colors", checked)
            }
            CheckBox {
                text: qsTr("Fonts pane")
                checked: settingsBridge.feature("feature_fonts")
                onCheckedChanged: settingsBridge.setFeature(
                    "feature_fonts", checked)
            }
            CheckBox {
                text: qsTr("Code snippets")
                checked: settingsBridge.feature("feature_snippets")
                onCheckedChanged: settingsBridge.setFeature(
                    "feature_snippets", checked)
            }
            CheckBox {
                text: qsTr("Terminal color designer")
                checked: settingsBridge.feature("feature_terminal")
                onCheckedChanged: settingsBridge.setFeature(
                    "feature_terminal", checked)
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    visible: library !== null && library.scanning
                    text: qsTr("Indexing… %1 assets so far")
                          .arg(library !== null ? library.scanCount : 0)
                    color: theme.tokens.textMuted
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Start Fengrid")
                    highlighted: true
                    onClicked: {
                        wizard.startScan()
                        settingsBridge.completeFirstRun()
                        wizard.finished()
                    }
                }
            }
        }
    }
}

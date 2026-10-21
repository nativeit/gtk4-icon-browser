import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Settings/Preferences screen (VS Code style): search across all settings,
// category list on the left, the matched section on the right. Everything
// Fengrid can be configured from here — asset folders, theme, layout,
// feature toggles.
Rectangle {
    id: settingsScreen
    color: theme.tokens.bg

    signal closed()

    property string query: ""

    function matches(text) {
        return query === "" || text.toLowerCase().indexOf(query.toLowerCase()) >= 0
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------- search column
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: theme.tokens.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: qsTr("Settings")
                    font.family: theme.headingFont
                    font.pixelSize: 18
                    color: theme.tokens.text
                }
                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: qsTr("search settings")
                    color: theme.tokens.text
                    font.pixelSize: 12
                    background: Rectangle {
                        color: theme.tokens.bg
                        radius: 4
                        border.color: search.activeFocus
                                      ? theme.tokens.accent : theme.tokens.border
                    }
                    onTextChanged: settingsScreen.query = text
                }

                Item { Layout.fillHeight: true }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: theme.tokens.border }

        // ------------------------------------------------------- content
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                width: settingsScreen.width - 220
                spacing: 20

                // -- folders -------------------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("asset folders")
                             || settingsScreen.matches("library paths")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Asset Folders")
                        font.family: theme.headingFont
                        font.pixelSize: 16
                        color: theme.tokens.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Folders Fengrid scans for icon assets.")
                        color: theme.tokens.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: settingsBridge.assetFolders
                        RowLayout {
                            Layout.fillWidth: true
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
                                onClicked: settingsBridge.removeFolder(modelData)
                            }
                        }
                    }
                    RowLayout {
                        spacing: 8
                        TextField {
                            id: addFolder
                            Layout.preferredWidth: 320
                            placeholderText: qsTr("add folder…")
                            color: theme.tokens.text
                            font.pixelSize: 12
                            background: Rectangle {
                                color: theme.tokens.bg
                                radius: 4
                                border.color: addFolder.activeFocus
                                              ? theme.tokens.accent
                                              : theme.tokens.border
                            }
                            onAccepted: addFolderBtn.clicked()
                        }
                        Button {
                            id: addFolderBtn
                            text: qsTr("Add")
                            enabled: addFolder.text.length > 0
                            onClicked: {
                                settingsBridge.addFolder(addFolder.text.trim())
                                addFolder.text = ""
                            }
                        }
                        Button {
                            text: qsTr("Re-scan")
                            onClicked: if (library !== null) library.rescan()
                        }
                    }
                }

                Rectangle {
                    visible: settingsScreen.matches("asset folders")
                             || settingsScreen.matches("library paths")
                    Layout.fillWidth: true; height: 1; color: theme.tokens.border }

                // -- theme ---------------------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("theme")
                             || settingsScreen.matches("visual")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Visual Theme")
                        font.family: theme.headingFont
                        font.pixelSize: 16
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
                }

                Rectangle {
                    visible: settingsScreen.matches("theme")
                             || settingsScreen.matches("visual")
                    Layout.fillWidth: true; height: 1; color: theme.tokens.border }

                // -- layout ---------------------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("layout")
                             || settingsScreen.matches("visual")
                             || settingsScreen.matches("density")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Layout")
                        font.family: theme.headingFont
                        font.pixelSize: 16
                        color: theme.tokens.text
                    }
                    Text {
                        text: qsTr("Density and spacing of the asset grids.")
                        font.pixelSize: 11
                        color: theme.tokens.textMuted
                    }
                    RowLayout {
                        spacing: 6
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
                }

                Rectangle {
                    visible: settingsScreen.matches("layout")
                             || settingsScreen.matches("visual")
                             || settingsScreen.matches("density")
                    Layout.fillWidth: true; height: 1; color: theme.tokens.border }

                // -- editor ---------------------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("editor")
                             || settingsScreen.matches("keymap")
                             || settingsScreen.matches("keyboard")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Editor Keymap")
                        font.family: theme.headingFont
                        font.pixelSize: 16
                        color: theme.tokens.text
                    }
                    Text {
                        text: qsTr("Keyboard scheme used inside code panes and dialogs.")
                        font.pixelSize: 11
                        color: theme.tokens.textMuted
                    }
                    RowLayout {
                        spacing: 6
                        visible: code !== null
                        Repeater {
                            model: (code !== null) ? code.keymap_names() : []
                            Button {
                                text: modelData
                                checkable: true
                                checked: (code !== null) && code.keymap === modelData
                                onClicked: if (code !== null) code.set_keymap(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: settingsScreen.matches("editor")
                             || settingsScreen.matches("keymap")
                             || settingsScreen.matches("keyboard")
                    Layout.fillWidth: true; height: 1; color: theme.tokens.border }

                // -- command bar hotkey ---------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("command")
                             || settingsScreen.matches("hotkey")
                             || settingsScreen.matches("shortcut")
                             || settingsScreen.matches("palette")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Command Bar Shortcut")
                        font.family: theme.headingFont
                        font.pixelSize: 16
                        color: theme.tokens.text
                    }
                    Text {
                        text: qsTr("Keystroke that expands the command bar into"
                                   + " the palette — search, navigation, and"
                                   + " actions from one place.")
                        font.pixelSize: 11
                        color: theme.tokens.textMuted
                    }
                    HotkeyField {
                        hotkey: settingsBridge !== null
                                ? settingsBridge.commandHotkey : "Alt+`"
                        onCommitted: seq => {
                            if (settingsBridge !== null)
                                settingsBridge.setCommandHotkey(seq)
                        }
                    }
                }

                Rectangle {
                    visible: settingsScreen.matches("command")
                             || settingsScreen.matches("hotkey")
                             || settingsScreen.matches("shortcut")
                             || settingsScreen.matches("palette")
                    Layout.fillWidth: true; height: 1; color: theme.tokens.border }

                // -- colors rule ----------------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("color")
                             || settingsScreen.matches("rule")
                             || settingsScreen.matches("harmony")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Color Rule")
                        font.family: theme.headingFont
                        font.pixelSize: 16
                        color: theme.tokens.text
                    }
                    Text {
                        text: qsTr("Harmony used when generating palettes.")
                        font.pixelSize: 11
                        color: theme.tokens.textMuted
                    }
                    RowLayout {
                        spacing: 6
                        visible: colors !== null
                        Repeater {
                            model: (colors !== null) ? colors.rule_names() : []
                            Button {
                                text: modelData
                                checkable: true
                                checked: (colors !== null) && colors.rule === modelData
                                onClicked: if (colors !== null) colors.set_rule(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: settingsScreen.matches("color")
                             || settingsScreen.matches("rule")
                             || settingsScreen.matches("harmony")
                    Layout.fillWidth: true; height: 1; color: theme.tokens.border }

                // -- features ------------------------------------------
                ColumnLayout {
                    visible: settingsScreen.matches("features")
                             || settingsScreen.matches("panes")
                    width: parent.width
                    spacing: 8

                    Text {
                        text: qsTr("Core Features")
                        font.family: theme.headingFont
                        font.pixelSize: 16
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
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 24 }
            }
        }
    }
}

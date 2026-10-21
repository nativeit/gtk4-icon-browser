import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Reusable hotkey capture control: shows the stored shortcut, and lets the
// user re-bind it — click "Change", press the new chord, it's validated and
// committed through the `committed` signal. "Reset" restores Alt+`.
//
// Used by the first-run wizard and the Settings/Preferences screen so both
// speak the same one-keystroke vocabulary.
ColumnLayout {
    id: field
    spacing: 6

    // current stored sequence, e.g. "Alt+`"
    property string hotkey: "Alt+`"
    // emitted when the user commits a new sequence
    signal committed(string sequence)

    readonly property bool capturing: captureItem.activeFocus

    // macOS: Qt's "Alt" IS the Option key — label it so in the UI
    readonly property string display: Qt.platform.os === "osx"
                                      ? hotkey.replace(/Alt/g, "Option")
                                      : hotkey

    // ------------------------------------------------------------ capture
    // key + modifiers -> QKeySequence text. Printable ASCII keys have Qt key
    // codes equal to their character code; everything else needs a name.
    readonly property var _names: ({
        "32": "Space", "16777235": "Escape", "16777215": "Enter",
        "16777217": "Tab", "16777219": "Backtab", "16777216": "Backspace",
        "16777223": "Delete", "16777222": "Insert", "16777220": "Home",
        "16777221": "End", "16777225": "PageUp", "16777226": "PageDown",
        "16777234": "Left", "16777236": "Up", "16777237": "Right",
        "16777239": "Down", "16777243": "Minus", "16777244": "Equal",
        "42": "*", "43": "+"
    })

    function keyText(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return "" + (key - Qt.Key_0)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
            return "F" + (key - Qt.Key_F1 + 1)
        // printable ASCII punctuation: the Qt key code IS the character
        if (key >= 0x21 && key <= 0x7e)
            return String.fromCharCode(key)
        var n = _names["" + key]
        if (n !== undefined)
            return n
        if (text && text.length === 1 && /\S/.test(text))
            return text
        return ""
    }

    function modsText(mods) {
        var parts = []
        if (mods & Qt.ControlModifier) parts.push("Ctrl")
        if (mods & Qt.AltModifier) parts.push("Alt")
        if (mods & Qt.ShiftModifier) parts.push("Shift")
        if (mods & Qt.MetaModifier) parts.push(Qt.platform.os === "osx" ? "Cmd" : "Meta")
        return parts
    }

    // A shortcut must carry a real modifier (bare keys would eat typing) —
    // function keys are the exception.
    function validCombo(mods, key) {
        var fkey = key >= Qt.Key_F1 && key <= Qt.Key_F12
        var hasMod = (mods & (Qt.ControlModifier | Qt.AltModifier
                              | Qt.MetaModifier)) !== 0
        return fkey || hasMod
    }

    function startCapture() {
        captureItem.forceActiveFocus()
    }

    // bare modifier presses arrive as Key_*_Modifier with empty text —
    // never treat those as the chosen chord
    readonly property var _bareMods: [Qt.Key_Control, Qt.Key_Shift,
                                      Qt.Key_Alt, Qt.Key_Meta,
                                      Qt.Key_AltGr, Qt.Key_Super_L,
                                      Qt.Key_Super_R]

    // ------------------------------------------------------------- layout
    RowLayout {
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 30
            radius: 6
            color: theme.tokens.bg
            border.color: field.capturing ? theme.tokens.accent
                                          : theme.tokens.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                IconImage {
                    name: "zap"
                    px: 12
                    tint: field.capturing ? theme.tokens.accent
                                          : theme.tokens.textMuted
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: field.capturing ? qsTr("press keys…")
                                          : field.display
                    font.family: theme.monoFont
                    font.pixelSize: 12
                    color: field.capturing ? theme.tokens.accent
                                           : theme.tokens.text
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: field.startCapture()
            }
        }

        Button {
            text: field.capturing ? qsTr("Cancel") : qsTr("Change")
            onClicked: field.capturing
                       ? captureItem.clearActiveFocus()
                       : field.startCapture()
        }
        Button {
            text: qsTr("Reset")
            visible: field.hotkey !== "Alt+`"
            onClicked: field.committed("Alt+`")
        }
    }

    Text {
        visible: field.capturing
        text: qsTr("Hold one or more modifiers (Ctrl, Alt, Shift, Cmd) and a key. Escape cancels.")
        font.pixelSize: 11
        color: theme.tokens.textMuted
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    // invisible key sink while capturing — sits on top of nothing, focus only
    Item {
        id: captureItem
        width: 0
        height: 0
        focus: false

        function finish() {
            clearActiveFocus()
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true
                finish()
                return
            }
            if (field._bareMods.indexOf(event.key) >= 0)
                return
            if (!field.validCombo(event.modifiers, event.key)) {
                event.accepted = true
                return
            }
            var name = field.keyText(event.key, event.text)
            if (name === "")
                return
            var combo = field.modsText(event.modifiers)
            // For ASCII punctuation (0x21-0x2f, 0x3a-0x40, 0x5b-0x60,
            // 0x7b-0x7e) the Shift press is folded into the keysym itself —
            // "~" IS shift+`. A stored "Shift+~" would then never match the
            // same event again, so drop the explicit Shift for those keys.
            var shiftedSym = (event.key >= 0x21 && event.key <= 0x2f)
                             || (event.key >= 0x3a && event.key <= 0x40)
                             || (event.key >= 0x5b && event.key <= 0x60)
                             || (event.key >= 0x7b && event.key <= 0x7e)
            if (shiftedSym && (event.modifiers & Qt.ShiftModifier))
                combo = combo.filter(function (p) { return p !== "Shift" })
            combo.push(name)
            event.accepted = true
            finish()
            field.committed(combo.join("+"))
        }
    }
}

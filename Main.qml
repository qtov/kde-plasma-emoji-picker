import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    width: 520
    height: 640
    visible: true
    title: "Emoji"
    flags: Qt.Tool | Qt.FramelessWindowHint
    color: "#111111"
    opacity: 0.98

    readonly property int basePx: Math.max(12, Qt.application.font.pixelSize || 12)
    readonly property int pxSm: Math.round(basePx * 0.95)
    readonly property int pxMd: Math.round(basePx * 1.10)
    readonly property int pxLg: Math.round(basePx * 1.55)
    readonly property int hField: Math.round(basePx * 2.8)
    readonly property int hRow: Math.round(basePx * 2.6)

    readonly property bool haveKdotool: Sys.haveKdotool
    readonly property bool haveWlCopy: Sys.haveWlCopy
    readonly property bool haveYdotool: Sys.haveYdotool

    property string prevWinId: ""
    property string queued: ""
    property bool allowAutoClose: false

    function activatePrevWindowBestEffort() {
        if (haveKdotool && prevWinId) Sys.run("kdotool windowactivate " + prevWinId + " >/dev/null 2>&1 || true")
    }

    function queueEmoji(emoji) {
        if (emoji) queued += emoji
    }

    function popEmoji() {
        if (queued.length > 0) queued = Sys.popLastGrapheme(queued)
    }

    function pasteQueueAndQuit() {
        if (queued.length === 0) { Qt.quit(); return }

        if (haveWlCopy) {
            Sys.run("printf '%s' " + Sys.shellQuote(queued) + " | wl-copy")
        }

        root.visible = false
        activatePrevWindowBestEffort()

        if (haveYdotool) {
            Sys.run("ydotool key 29:1 47:1 47:0 29:0 >/dev/null 2>&1 || true")
        }

        Qt.quit()
    }

    Timer {
        id: focusLostTimer
        interval: 80
        onTriggered: if (root.visible && allowAutoClose && root.activeFocusItem === null) Qt.quit()
    }

    onActiveFocusItemChanged: if (allowAutoClose && root.visible) focusLostTimer.restart()
    onVisibleChanged: if (!root.visible) allowAutoClose = false

    Component.onCompleted: {
        allowAutoClose = true
        search.forceActiveFocus()
        if (haveKdotool) initTimer.start()
    }

    Timer {
        id: initTimer
        interval: 0
        onTriggered: prevWinId = Sys.runCapture("kdotool getactivewindow 2>/dev/null || true")
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(ev) {
            if (ev.key === Qt.Key_Q && (ev.modifiers & Qt.ControlModifier)) Qt.quit()
            if (ev.key === Qt.Key_Escape) {
                if ((ev.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0) Qt.quit()
                else pasteQueueAndQuit()
                ev.accepted = true
            }
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                if (list.currentIndex >= 0) queueEmoji(EmojiModel.data(EmojiModel.index(list.currentIndex, 0), 257))
                ev.accepted = true
            }
            if (ev.key === Qt.Key_Backspace) { popEmoji(); ev.accepted = true }
            if (ev.key === Qt.Key_Down) { list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1); ev.accepted = true }
            if (ev.key === Qt.Key_Up) { list.currentIndex = Math.max(list.currentIndex - 1, 0); ev.accepted = true }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: hField
                radius: 12; color: "#1c1c1c"; border.color: "#2a2a2a"
                TextField {
                    id: search
                    width: parent.width
                    placeholderText: "Search..."
                    font.pixelSize: pxMd; color: "white"
                    leftPadding: 14; rightPadding: 14
                    background: Item {}
                    onTextChanged: { EmojiModel.setFilter(text); list.currentIndex = 0 }
                    Keys.onPressed: function(ev) {
                        if ((ev.modifiers & Qt.ShiftModifier) && ev.key === Qt.Key_Backspace || (ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_W) {
                            popEmoji(); ev.accepted = true
                        }
                        if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_U) {
                            queued = ""; ev.accepted = true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: hField
                radius: 10; color: "#151515"; border.color: "#2a2a2a"
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10
                    Text { text: "Queue:"; color: "#888888"; font.pixelSize: pxSm }
                    Text { text: queued; color: "white"; font.pixelSize: pxLg; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; model: EmojiModel; currentIndex: 0
                delegate: Rectangle {
                    width: list.width; height: hRow; radius: 8
                    color: (index === list.currentIndex) ? "#2a2a2a" : "transparent"
                    property string label: {
                        var parts = ("" + model.line).split(/\s+/)
                        if (parts.length < 2) return ""
                        var sc = parts[1], tags = []
                        for (var i = 2; i < parts.length && tags.length < 2; i++) tags.push(parts[i])
                        return tags.length ? (sc + "  " + tags.join(" ")) : sc
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: list.currentIndex = index
                        onDoubleClicked: queueEmoji(model.emoji)
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10
                        Text { text: model.emoji; font.pixelSize: pxLg; color: "white"; Layout.preferredWidth: pxLg * 2 }
                        Text { text: label; font.pixelSize: pxMd; color: "white"; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Enter = add to queue   Shift+Backspace | Ctrl+w = remove last emoji"
                    color: "#888888"
                    font.pixelSize: pxSm
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "Ctrl+u = clear emoji queue"
                    color: "#888888"
                    font.pixelSize: pxSm
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "Esc = paste & close   Shift+Esc | Ctrl+q = close"
                    color: "#888888"
                    font.pixelSize: pxSm
                    elide: Text.ElideRight
                }
            }
        }
    }
}

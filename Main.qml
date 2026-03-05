// Main.qml
import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: root
    width: 560
    height: 760
    visible: true
    title: "Emoji"
    flags: Qt.Tool | Qt.FramelessWindowHint
    color: "#111111"
    opacity: 0.98

    property bool haveKdotool: Sys.commandExists("kdotool")
    property string prevWinId: ""

    property bool haveWlCopy: Sys.commandExists("wl-copy")
    property bool haveYdotool: Sys.commandExists("ydotool")

    property string listPath: Sys.cacheListPath()

    // Queue: emojis are appended on Enter, pasted on Esc
    property string queued: ""

    ListModel { id: allModel }
    ListModel { id: viewModel }

    function shellQuote(s) {
        // single-quote safe for sh -lc
        return "'" + ("" + s).split("'").join("'\\''") + "'"
    }

    function loadList() {
        allModel.clear()
        viewModel.clear()

        var txt = Sys.readAllText(listPath)
        if (!txt || txt.length === 0) {
            statusText.text = "Cache missing/empty:\n" + listPath + "\n\nBuild it first (your cache script)."
            return
        }

        var lines = txt.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (!l || l.trim().length === 0) continue
            var sp = l.indexOf(" ")
            var e = (sp > 0) ? l.slice(0, sp) : l
            allModel.append({ emoji: e, line: l })
        }

        statusText.text = ""
        rebuildViewModel()
    }

    function rebuildViewModel() {
        viewModel.clear()
        var q = search.text.trim().toLowerCase()

        for (var i = 0; i < allModel.count; i++) {
            var e = allModel.get(i).emoji
            var line = allModel.get(i).line
            if (q.length === 0 || ("" + line).toLowerCase().indexOf(q) !== -1) {
                viewModel.append({ emoji: e, line: line })
            }
        }
        list.currentIndex = viewModel.count > 0 ? 0 : -1
    }

    function activatePrevWindowBestEffort() {
        if (haveKdotool && prevWinId && prevWinId.length > 0) {
            Sys.run("kdotool windowactivate " + prevWinId + " >/dev/null 2>&1 || true")
        }
    }

    function queueEmoji(emoji) {
        if (!emoji || ("" + emoji).length === 0) return
        queued = queued + emoji
        queueText.text = queued
    }

    function popEmoji() {
        if (!queued || queued.length === 0) return

        // NOTE: This removes one UTF-16 code unit; good enough for many emoji,
        // but ZWJ sequences are multi-codepoint and this will truncate them.
        // If you want "remove last emoji cluster" properly, we can do that too.
        queued = queued.slice(0, queued.length - 1)
        queueText.text = queued
    }

    function pasteQueueAndQuit() {
        if (!queued || queued.length === 0) {
            Qt.quit()
            return
        }

        if (haveWlCopy) {
            Sys.run("printf '%s' " + shellQuote(queued) + " | wl-copy")
        }

        root.visible = false
        activatePrevWindowBestEffort()

        if (haveYdotool) {
            Sys.run("ydotool key 29:1 47:1 47:0 29:0 >/dev/null 2>&1 || true")
        }

        Qt.quit()
    }

    Component.onCompleted: {
        if (haveKdotool) {
            prevWinId = Sys.runCapture("kdotool getactivewindow 2>/dev/null || true")
        }
        loadList()
        search.forceActiveFocus()
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(ev) {
            if (ev.key === Qt.Key_Escape) {
                pasteQueueAndQuit()
                ev.accepted = true
                return
            }

            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                if (list.currentIndex >= 0 && list.currentIndex < viewModel.count) {
                    queueEmoji(viewModel.get(list.currentIndex).emoji)
                    ev.accepted = true
                }
                return
            }

            if (ev.key === Qt.Key_Backspace) {
                popEmoji()
                ev.accepted = true
                return
            }

            if (ev.key === Qt.Key_Down) {
                list.currentIndex = Math.min(list.currentIndex + 1, viewModel.count - 1)
                ev.accepted = true
                return
            }

            if (ev.key === Qt.Key_Up) {
                list.currentIndex = Math.max(list.currentIndex - 1, 0)
                ev.accepted = true
                return
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                radius: 12
                height: 44
                width: parent.width
                color: "#1c1c1c"
                border.color: "#2a2a2a"

                TextField {
                    id: search
                    anchors.fill: parent
                    anchors.margins: 10
                    placeholderText: "Search emoji / :shortcode: / keywords…"
                    background: null
                    color: "white"
                    font.pixelSize: 16
                    onTextChanged: rebuildViewModel()
                }
            }

            Rectangle {
                radius: 10
                height: 44
                width: parent.width
                color: "#151515"
                border.color: "#2a2a2a"

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "Queue:"
                        color: "#888888"
                        font.pixelSize: 14
                    }

                    Text {
                        id: queueText
                        text: queued
                        color: "white"
                        font.pixelSize: 20
                        elide: Text.ElideRight
                        width: parent.width - 70
                    }
                }
            }

            Text {
                id: statusText
                text: ""
                color: "#bbbbbb"
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 140
                clip: true
                model: viewModel
                currentIndex: 0

                delegate: Rectangle {
                    width: list.width
                    height: 42
                    radius: 8
                    color: (index === list.currentIndex) ? "#2a2a2a" : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: list.currentIndex = index
                        onDoubleClicked: queueEmoji(model.emoji)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Text {
                            text: model.emoji
                            font.pixelSize: 22
                            color: "white"
                            width: 32
                        }

                        Text {
                            text: ("" + model.line).slice(("" + model.emoji).length + 1)
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            color: "#dddddd"
                            verticalAlignment: Text.AlignVCenter
                            width: list.width - 60
                        }
                    }
                }
            }

            Text {
                text: "Enter = add to queue   Backspace = remove last   Esc = paste & close"
                color: "#888888"
                font.pixelSize: 12
            }
        }
    }
}

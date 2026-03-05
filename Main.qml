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

    // ---- sizing that respects system scaling ----
    // Qt.application.font.pixelSize already tracks your system font scaling.
    readonly property int basePx: Math.max(12, Qt.application.font.pixelSize || 12)
    readonly property int pxSm: Math.round(basePx * 0.95)
    readonly property int pxMd: Math.round(basePx * 1.10)
    readonly property int pxLg: Math.round(basePx * 1.55)

    readonly property int hField: Math.round(basePx * 2.8)
    readonly property int hRow: Math.round(basePx * 2.6)

    property bool haveKdotool: Sys.commandExists("kdotool")
    property string prevWinId: ""

    property bool haveWlCopy: Sys.commandExists("wl-copy")
    property bool haveYdotool: Sys.commandExists("ydotool")

    property string listPath: Sys.cacheListPath()

    // Queue: emojis appended on Enter, pasted on Esc
    property string queued: ""

    ListModel { id: allModel }
    ListModel { id: viewModel }

    function shellQuote(s) {
        return "'" + ("" + s).split("'").join("'\\''") + "'"
    }

    function loadList() {
        allModel.clear()
        viewModel.clear()

        var txt = Sys.readAllText(listPath)
        if (!txt || txt.length === 0) {
            statusText.text = "Cache missing/empty:\n" + listPath + "\n\nBuild it first."
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
    }

    function popEmoji() {
        if (!queued || queued.length === 0) return
        // still naive; good enough for now
        queued = queued.slice(0, queued.length - 1)
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

    // Key handling must be on an Item, not Window
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: hField
                radius: 12
                color: "#1c1c1c"
                border.color: "#2a2a2a"

		TextField {
		    id: search
		    // Layout.fillWidth: true
		    width: parent.width
		    Layout.preferredHeight: hField

		    placeholderText: "Search emoji / :shortcode: / tags…"
		    font.pixelSize: pxMd
		    color: "white"

		    leftPadding: 14
		    rightPadding: 14
		    topPadding: 10
		    bottomPadding: 10

		    background: Rectangle {
			radius: 12
			color: "#1c1c1c"
			border.color: "#2a2a2a"
		    }

		    palette.placeholderText: "#777777"
		    onTextChanged: rebuildViewModel()
		}
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: hField
                radius: 10
                color: "#151515"
                border.color: "#2a2a2a"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "Queue:"
                        color: "#888888"
                        font.pixelSize: pxSm
                    }

                    Text {
                        text: queued
                        color: "white"
                        font.pixelSize: pxLg
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                id: statusText
                Layout.fillWidth: true
                text: ""
                color: "#bbbbbb"
                wrapMode: Text.WordWrap
                visible: text.length > 0
                font.pixelSize: pxSm
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true   // <-- THIS prevents overlap
                clip: true
                model: viewModel
                currentIndex: 0

		delegate: Rectangle {
		    width: list.width
		    height: hRow
		    radius: 8
		    color: (index === list.currentIndex) ? "#2a2a2a" : "transparent"

		    // Build one clean label: ":rofl: lol laughing"
		    property string label: {
			var parts = ("" + model.line).split(/\s+/)
			if (parts.length < 2) return ""
			var sc = parts[1]              // :rofl:
			var tags = []
			// take up to 2 tags after shortcode
			for (var i = 2; i < parts.length && tags.length < 2; i++) {
			    tags.push(parts[i])
			}
			return tags.length ? (sc + "  " + tags.join(" ")) : sc
		    }

		    MouseArea {
			anchors.fill: parent
			onClicked: list.currentIndex = index
			onDoubleClicked: queueEmoji(model.emoji)
		    }

		    RowLayout {
			anchors.fill: parent
			anchors.margins: 10
			spacing: 10

			Text {
			    text: model.emoji
			    font.pixelSize: pxLg
			    color: "white"
			    Layout.preferredWidth: Math.round(pxLg * 2.0)
			    verticalAlignment: Text.AlignVCenter
			}

			Text {
			    text: label
			    font.pixelSize: pxMd
			    color: "white"
			    elide: Text.ElideRight
			    Layout.fillWidth: true
			    verticalAlignment: Text.AlignVCenter
			}
		    }
		}
            }

            Text {
                Layout.fillWidth: true
                text: "Enter = add to queue   Backspace = remove last   Esc = paste & close"
                color: "#888888"
                font.pixelSize: pxSm
            }
        }
    }
}

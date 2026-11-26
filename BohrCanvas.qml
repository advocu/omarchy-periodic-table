import QtQuick

Item {
    id: root
    property var shells: [2, 4]
    property string symbol: "C"
    property color accentColor: "#3B82F6"
    property color textColor: "#F8FAFC"
    property color ringColor: "#475569"
    property color valenceColor: "#FACC15"
    property bool animateOrbitals: true
    property bool paused: false
    property real phaseAngle: 0.0

    onShellsChanged: bohrCanvas.requestPaint()
    onSymbolChanged: bohrCanvas.requestPaint()
    onAccentColorChanged: bohrCanvas.requestPaint()
    onTextColorChanged: bohrCanvas.requestPaint()
    onRingColorChanged: bohrCanvas.requestPaint()
    onValenceColorChanged: bohrCanvas.requestPaint()
    onVisibleChanged: if (!visible) paused = false

    Timer {
        interval: 40
        running: root.visible && root.animateOrbitals && !root.paused
        repeat: true
        onTriggered: {
            root.phaseAngle = (root.phaseAngle + 0.025) % (Math.PI * 2)
            bohrCanvas.requestPaint()
        }
    }

    Canvas {
        id: bohrCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = width
            var h = height
            var cx = w / 2
            var cy = h / 2
            var maxRadius = Math.min(w, h) * 0.45
            var count = root.shells ? root.shells.length : 0
            if (count === 0) return

            // Draw nucleus
            ctx.beginPath()
            ctx.arc(cx, cy, 15, 0, Math.PI * 2)
            ctx.fillStyle = root.accentColor
            ctx.fill()

            ctx.fillStyle = "#FFFFFF"
            ctx.font = "bold 11px sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            ctx.fillText(root.symbol, cx, cy)

            var minRing = 24
            var step = count > 1 ? (maxRadius - minRing) / (count - 1) : 0
            if (count === 1) minRing = maxRadius * 0.65

            for (var s = 0; s < count; s++) {
                var r = minRing + s * step
                var isOuter = (s === count - 1)

                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.lineWidth = isOuter ? 1.6 : 1.0
                ctx.strokeStyle = isOuter ? root.accentColor : root.ringColor
                ctx.stroke()

                var eCount = root.shells[s]
                var speedFactor = (s % 2 === 0 ? 1 : -1) * (1.1 / (s + 1))
                for (var e = 0; e < eCount; e++) {
                    var angle = (Math.PI * 2 * e) / eCount + (root.phaseAngle * speedFactor)
                    var ex = cx + r * Math.cos(angle)
                    var ey = cy + r * Math.sin(angle)

                    ctx.beginPath()
                    ctx.arc(ex, ey, isOuter ? 4.2 : 3.0, 0, Math.PI * 2)
                    ctx.fillStyle = isOuter ? root.valenceColor : root.textColor
                    ctx.fill()
                }
            }
        }
    }

    // Click the diagram to pause or resume the orbit animation.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.paused = !root.paused
    }
}

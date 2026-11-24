import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "ElementsData.js" as ElementsDB

Panel {
    id: root
    moduleName: "io.github.advocatus.periodic-table"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null

    // UI State
    property int currentZ: 6
    property bool showMoreDetails: false
    property string activeCategoryFilter: ""
    property string searchQuery: ""
    property int heatmapMode: 0 // 0=Category, 1=Valence, 2=Electronegativity, 3=Radius
    property int tempKelvin: 298
    property bool showTempBar: false
    property bool quizActive: false
    property int quizTargetZ: 26
    property int quizScore: 0
    property string quizFeedback: ""

    readonly property var currentElement: ElementsDB.getByZ(root.currentZ)
    readonly property var currentCatMeta: ElementsDB.categoryMeta(root.currentElement.category)

    function open() {
        root.controller.show()
    }

    function close() {
        root.controller.hide()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    function matchesSearch(el) {
        if (!el) return false
        if (root.activeCategoryFilter !== "" && el.category !== root.activeCategoryFilter)
            return false
        if (root.searchQuery === "")
            return true
        var q = root.searchQuery.toLowerCase()
        return el.name.toLowerCase().indexOf(q) !== -1 ||
               el.symbol.toLowerCase().indexOf(q) !== -1 ||
               String(el.z) === q
    }

    function tileAccentColor(el) {
        if (!el) return "transparent"
        if (root.heatmapMode === 1) {
            // Valence electrons heatmap (1..10)
            var vRatio = Math.min(1.0, el.valence / 8.0)
            return Qt.rgba(0.15 + 0.75 * vRatio, 0.55 - 0.2 * vRatio, 0.95 - 0.65 * vRatio, 1.0)
        }
        if (root.heatmapMode === 2) {
            // Pauling electronegativity (0.7..4.0)
            if (el.electronegativity <= 0) return "#475569"
            var enRatio = Math.min(1.0, Math.max(0.0, (el.electronegativity - 0.7) / 3.3))
            return Qt.rgba(0.1 + 0.85 * enRatio, 0.75 - 0.45 * enRatio, 0.35, 1.0)
        }
        if (root.heatmapMode === 3) {
            // Atomic radius (28..260 pm)
            var rRatio = Math.min(1.0, Math.max(0.0, (el.radius - 28.0) / 232.0))
            return Qt.rgba(0.25 + 0.55 * rRatio, 0.4 + 0.45 * (1.0 - rRatio), 0.9, 1.0)
        }
        return ElementsDB.categoryMeta(el.category).color
    }

    function moveFocusByGrid(dRow, dCol) {
        var el = root.currentElement
        var r = el.gridRow
        var c = el.gridCol
        for (var step = 1; step <= 18; step++) {
            var nr = r + dRow * step
            var nc = c + dCol * step
            if (nr < 1 || nr > 10 || nc < 1 || nc > 18) break
            var candidate = ElementsDB.getByGrid(nr, nc)
            if (candidate) {
                root.currentZ = candidate.z
                return
            }
        }
        // Fallback linear step
        if (dCol !== 0 || dRow !== 0) {
            var delta = dCol !== 0 ? dCol : (dRow * 8)
            var nextZ = Math.max(1, Math.min(118, root.currentZ + delta))
            root.currentZ = nextZ
        }
    }

    function startQuizRound() {
        var next = Math.floor(Math.random() * 118) + 1
        root.quizTargetZ = next
        root.quizFeedback = "Click or navigate + Enter on the element matching the clue!"
    }

    function checkQuizAnswer(selectedZ) {
        if (!root.quizActive) return
        if (selectedZ === root.quizTargetZ) {
            root.quizScore += 1
            var solved = ElementsDB.getByZ(selectedZ)
            root.quizFeedback = "Correct! " + solved.name + " (" + solved.symbol + ") has " + solved.valence + " valence electrons."
            var next = ((selectedZ * 37 + 13) % 118) + 1
            root.quizTargetZ = next
        } else {
            var picked = ElementsDB.getByZ(selectedZ)
            root.quizFeedback = "Not " + picked.symbol + " (Z=" + picked.z + "). Try again!"
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(960))
        contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            onCloseRequested: {
                if (root.showMoreDetails) {
                    root.showMoreDetails = false
                } else {
                    root.close()
                }
            }
            onTabRequested: function(direction) {
                root.switchPanel(direction)
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.moveFocusByGrid(0, -1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.moveFocusByGrid(0, 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.moveFocusByGrid(-1, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.moveFocusByGrid(1, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_M) {
                    if (root.quizActive) {
                        root.checkQuizAnswer(root.currentZ)
                    } else {
                        root.showMoreDetails = !root.showMoreDetails
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_T) {
                    root.showTempBar = !root.showTempBar
                    event.accepted = true
                } else if (event.key === Qt.Key_V) {
                    root.heatmapMode = (root.heatmapMode + 1) % 4
                    event.accepted = true
                } else if (event.key === Qt.Key_Q) {
                    root.quizActive = !root.quizActive
                    if (root.quizActive) root.startQuizRound()
                    event.accepted = true
                } else if (event.key === Qt.Key_Backspace) {
                    if (root.searchQuery.length > 0) {
                        root.searchQuery = root.searchQuery.slice(0, -1)
                        event.accepted = true
                    } else if (root.activeCategoryFilter !== "") {
                        root.activeCategoryFilter = ""
                        event.accepted = true
                    }
                }
            }

            Column {
                id: mainColumn
                width: parent.width
                spacing: Style.space(8)

                // Top Header & Controls Strip
                Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                        text: "⚛ Periodic Table of the Elements"
                        color: root.barForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                    }

                    // Mode toggle pills
                    Rectangle {
                        height: Style.space(24)
                        width: heatmapText.implicitWidth + Style.space(16)
                        radius: Style.space(4)
                        color: Qt.rgba(0.12, 0.25, 0.55, 0.45)
                        border.width: 1
                        border.color: "#3B82F6"

                        Text {
                            id: heatmapText
                            anchors.centerIn: parent
                            text: root.heatmapMode === 0 ? "Color: Family (V)" :
                                  root.heatmapMode === 1 ? "Color: Valence e⁻ (V)" :
                                  root.heatmapMode === 2 ? "Color: Electronegativity (V)" :
                                                           "Color: Atomic Radius (V)"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.heatmapMode = (root.heatmapMode + 1) % 4
                        }
                    }

                    Rectangle {
                        height: Style.space(24)
                        width: tempToggleText.implicitWidth + Style.space(16)
                        radius: Style.space(4)
                        color: root.showTempBar ? Qt.rgba(0.06, 0.46, 0.43, 0.55) : Qt.rgba(0.2, 0.25, 0.33, 0.35)
                        border.width: 1
                        border.color: root.showTempBar ? "#14B8A6" : "#475569"

                        Text {
                            id: tempToggleText
                            anchors.centerIn: parent
                            text: "Phase Temp: " + root.tempKelvin + " K (T)"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showTempBar = !root.showTempBar
                        }
                    }

                    Rectangle {
                        height: Style.space(24)
                        width: quizToggleText.implicitWidth + Style.space(16)
                        radius: Style.space(4)
                        color: root.quizActive ? Qt.rgba(0.85, 0.55, 0.05, 0.5) : Qt.rgba(0.2, 0.25, 0.33, 0.35)
                        border.width: 1
                        border.color: root.quizActive ? "#F59E0B" : "#475569"

                        Text {
                            id: quizToggleText
                            anchors.centerIn: parent
                            text: root.quizActive ? "Quiz Active · Score: " + root.quizScore + " (Q)" : "Flash Quiz (Q)"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.quizActive = !root.quizActive
                                if (root.quizActive) root.startQuizRound()
                            }
                        }
                    }
                }

                // Optional Temperature Phase Presets Bar
                Row {
                    visible: root.showTempBar
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                        text: "Temperature Presets:"
                        color: root.barForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: [
                            { label: "Absolute Zero (4 K)", k: 4 },
                            { label: "Liquid N₂ (77 K)", k: 77 },
                            { label: "Room Temp (298 K)", k: 298 },
                            { label: "Hand Warmth (305 K)", k: 305 },
                            { label: "Red Heat (1000 K)", k: 1000 },
                            { label: "Steel Melt (1850 K)", k: 1850 },
                            { label: "Solar Surface (5800 K)", k: 5800 }
                        ]
                        delegate: Rectangle {
                            height: Style.space(22)
                            width: presetLbl.implicitWidth + Style.space(12)
                            radius: Style.space(3)
                            color: root.tempKelvin === modelData.k ? "#0F766E" : Qt.rgba(0.15, 0.2, 0.28, 0.45)
                            border.width: 1
                            border.color: root.tempKelvin === modelData.k ? "#2DD4BF" : "#475569"

                            Text {
                                id: presetLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tempKelvin = modelData.k
                            }
                        }
                    }
                }

                // Optional Flash Quiz Prompt Bar
                Rectangle {
                    visible: root.quizActive
                    width: parent.width
                    height: Style.space(36)
                    radius: Style.space(4)
                    color: Qt.rgba(0.25, 0.18, 0.04, 0.65)
                    border.width: 1
                    border.color: "#F59E0B"

                    Row {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(12)

                        Text {
                            property var qEl: ElementsDB.getByZ(root.quizTargetZ)
                            text: "CLUE: Atomic #" + qEl.z + " · " + qEl.valence + " valence e⁻ · Config " + qEl.config + " · " + ElementsDB.categoryMeta(qEl.category).label
                            color: "#FDE68A"
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: root.quizFeedback
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: 11
                        }
                    }
                }

                // Category Filter Chips Row
                Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Rectangle {
                        height: Style.space(20)
                        width: allCatTxt.implicitWidth + Style.space(10)
                        radius: Style.space(3)
                        color: root.activeCategoryFilter === "" ? "#1D4ED8" : Qt.rgba(0.2, 0.25, 0.33, 0.35)

                        Text {
                            id: allCatTxt
                            anchors.centerIn: parent
                            text: "All (118)"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: 10
                            font.bold: root.activeCategoryFilter === ""
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeCategoryFilter = ""
                        }
                    }

                    Repeater {
                        model: [
                            "alkali-metal", "alkaline-earth", "transition-metal", "post-transition",
                            "metalloid", "reactive-nonmetal", "halogen", "noble-gas", "lanthanide", "actinide"
                        ]
                        delegate: Rectangle {
                            property var meta: ElementsDB.categoryMeta(modelData)
                            height: Style.space(20)
                            width: catChipTxt.implicitWidth + Style.space(10)
                            radius: Style.space(3)
                            color: root.activeCategoryFilter === modelData ? meta.color : Qt.rgba(0.15, 0.2, 0.28, 0.4)
                            border.width: 1
                            border.color: meta.color

                            Text {
                                id: catChipTxt
                                anchors.centerIn: parent
                                text: meta.label
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: 10
                                font.bold: root.activeCategoryFilter === modelData
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activeCategoryFilter === modelData)
                                        root.activeCategoryFilter = ""
                                    else
                                        root.activeCategoryFilter = modelData
                                }
                            }
                        }
                    }
                }

                // 18x10 Interactive Periodic Table Grid (Visible when Stage 2 drawer is collapsed, or compact above)
                Grid {
                    id: periodicGrid
                    visible: !root.showMoreDetails
                    width: parent.width
                    columns: 18
                    rows: 10
                    spacing: 2

                    Repeater {
                        model: 180
                        delegate: Item {
                            readonly property int gRow: Math.floor(index / 18) + 1
                            readonly property int gCol: (index % 18) + 1
                            readonly property var el: ElementsDB.getByGrid(gRow, gCol)
                            readonly property bool hasElement: el !== null
                            readonly property bool isFocused: hasElement && (el.z === root.currentZ)
                            readonly property bool isMatched: hasElement && root.matchesSearch(el)

                            width: Math.floor((periodicGrid.width - 34) / 18)
                            height: 38

                            Rectangle {
                                anchors.fill: parent
                                visible: parent.hasElement
                                radius: 3
                                opacity: parent.isMatched ? 1.0 : 0.22
                                color: parent.isFocused
                                       ? root.tileAccentColor(parent.el)
                                       : Qt.rgba(0.09, 0.13, 0.2, 0.85)
                                border.width: parent.isFocused ? 2 : 1
                                border.color: parent.isFocused ? "#FACC15" : root.tileAccentColor(parent.el)

                                // Top row: Atomic Number (left) and Valence Count (right)
                                Text {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 2
                                    text: parent.parent.hasElement ? String(parent.parent.el.z) : ""
                                    color: parent.parent.isFocused ? "#FFFFFF" : "#94A3B8"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 8
                                }

                                Text {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 2
                                    text: parent.parent.hasElement ? (parent.parent.el.valence + "e⁻") : ""
                                    color: parent.parent.isFocused ? "#FEF08A" : "#38BDF8"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 8
                                }

                                // Center Symbol
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: parent.parent.hasElement
                                          ? (root.quizActive && parent.parent.el.z === root.quizTargetZ ? "?" : parent.parent.el.symbol)
                                          : ""
                                    color: "#FFFFFF"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                // Bottom Element Name
                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 1
                                    width: parent.width - 2
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: parent.parent.hasElement
                                          ? (root.quizActive && parent.parent.el.z === root.quizTargetZ ? "???" : parent.parent.el.name)
                                          : ""
                                    color: parent.parent.isFocused ? "#FFFFFF" : "#CBD5E1"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 7
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        if (parent.parent.hasElement) {
                                            root.currentZ = parent.parent.el.z
                                        }
                                    }
                                    onClicked: {
                                        if (parent.parent.hasElement) {
                                            root.currentZ = parent.parent.el.z
                                            if (root.quizActive) {
                                                root.checkQuizAnswer(parent.parent.el.z)
                                            }
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (parent.parent.hasElement && !root.quizActive) {
                                            root.currentZ = parent.parent.el.z
                                            root.showMoreDetails = true
                                        }
                                    }
                                }
                            }

                            // Lanthanide / Actinide series callout markers in main grid (row 6 col 3 & row 7 col 3)
                            Text {
                                anchors.centerIn: parent
                                visible: !parent.hasElement && parent.gCol === 3 && (parent.gRow === 6 || parent.gRow === 7)
                                text: parent.gRow === 6 ? "57-71
La-Lu" : "89-103
Ac-Lr"
                                horizontalAlignment: Text.AlignHCenter
                                color: "#94A3B8"
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                // =========================================================================
                // STAGE 1: LIVE ELEMENT INSPECTOR CARD (Always visible; updates on hover/keys)
                // Includes the bottom "More Details" option for every element card
                // =========================================================================
                Rectangle {
                    id: inspectorCard
                    width: parent.width
                    height: cardCol.implicitHeight + Style.space(20)
                    radius: Style.space(6)
                    color: Qt.rgba(0.06, 0.09, 0.16, 0.92)
                    border.width: 1.5
                    border.color: root.currentCatMeta.color

                    Column {
                        id: cardCol
                        width: parent.width - Style.space(20)
                        anchors.centerIn: parent
                        spacing: Style.space(8)

                        Row {
                            width: parent.width
                            spacing: Style.space(14)

                            // Big Element Badge
                            Rectangle {
                                width: 72
                                height: 72
                                radius: 6
                                color: root.currentCatMeta.color

                                Text {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 4
                                    text: String(root.currentElement.z)
                                    color: "#FFFFFF"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.currentElement.symbol
                                    color: "#FFFFFF"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 26
                                    font.bold: true
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 3
                                    text: root.currentElement.mass + " u"
                                    color: "#F8FAFC"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 9
                                }
                            }

                            // Core Element Identity & Metrics
                            Column {
                                width: parent.width - 86
                                spacing: 4

                                Row {
                                    spacing: Style.space(10)

                                    Text {
                                        text: root.currentElement.name + " (" + root.currentElement.symbol + ")"
                                        color: "#FFFFFF"
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    Rectangle {
                                        height: 22
                                        width: valBadgeTxt.implicitWidth + 14
                                        radius: 4
                                        color: "#1E3A8A"
                                        border.width: 1
                                        border.color: "#60A5FA"

                                        Text {
                                            id: valBadgeTxt
                                            anchors.centerIn: parent
                                            text: "Valence Electrons: " + root.currentElement.valence + " e⁻"
                                            color: "#FEF08A"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        height: 22
                                        width: catBadgeTxt.implicitWidth + 12
                                        radius: 4
                                        color: Qt.rgba(0.15, 0.2, 0.3, 0.7)
                                        border.width: 1
                                        border.color: root.currentCatMeta.color

                                        Text {
                                            id: catBadgeTxt
                                            anchors.centerIn: parent
                                            text: root.currentCatMeta.label + " · " + root.currentElement.block + "-block"
                                            color: "#E2E8F0"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: "Atomic #: " + root.currentElement.z +
                                          "   |   Config: " + root.currentElement.config +
                                          "   |   Shells: [" + root.currentElement.shells.join(", ") + "]" +
                                          "   |   Period " + root.currentElement.period + ", Group " + root.currentElement.group +
                                          "   |   State @ " + root.tempKelvin + " K: " + ElementsDB.getPhaseAtTemp(root.currentElement, root.tempKelvin)
                                    color: "#93C5FD"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    text: root.currentElement.summary
                                    color: "#E2E8F0"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // =========================================================================
                        // STAGE 2: EXPANDABLE "MORE DETAILS" DEEP CHEMISTRY DRAWER
                        // =========================================================================
                        Rectangle {
                            visible: root.showMoreDetails
                            width: parent.width
                            height: deepDrawerRow.implicitHeight + Style.space(18)
                            radius: Style.space(5)
                            color: Qt.rgba(0.03, 0.06, 0.11, 0.96)
                            border.width: 1
                            border.color: "#0F766E"

                            Row {
                                id: deepDrawerRow
                                width: parent.width - Style.space(18)
                                anchors.centerIn: parent
                                spacing: Style.space(16)

                                // Left: Animated 2D Bohr Orbital Visualizer
                                Column {
                                    width: 190
                                    spacing: 4

                                    BohrCanvas {
                                        width: 180
                                        height: 180
                                        shells: root.currentElement.shells
                                        symbol: root.currentElement.symbol
                                        accentColor: root.currentCatMeta.color
                                    }

                                    Text {
                                        width: 180
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "Outer yellow dots = " + root.currentElement.valence + " valence e⁻"
                                        color: "#FDE047"
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 10
                                    }
                                }

                                // Right: Comprehensive Chemistry & Physical Properties Breakdown
                                Column {
                                    width: parent.width - 210
                                    spacing: Style.space(8)

                                    Text {
                                        text: "Deep Chemistry & Atomic Structure of " + root.currentElement.name + " (Z=" + root.currentElement.z + ")"
                                        color: "#2DD4BF"
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.currentElement.chemistry
                                        color: "#F1F5F9"
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                    }

                                    // Quantitative Chemistry Specs Grid
                                    Grid {
                                        width: parent.width
                                        columns: 3
                                        columnSpacing: Style.space(16)
                                        rowSpacing: Style.space(6)

                                        Text {
                                            text: "• Oxidation States: " + root.currentElement.oxidation
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Electronegativity: " + (root.currentElement.electronegativity > 0 ? root.currentElement.electronegativity + " (Pauling)" : "N/A")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• 1st Ionization Energy: " + root.currentElement.ionization + " kJ/mol"
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Covalent Radius: " + root.currentElement.radius + " pm"
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Melting Point: " + (root.currentElement.meltK > 0 ? root.currentElement.meltK + " K" : "Synthetic")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Boiling Point: " + (root.currentElement.boilK > 0 ? root.currentElement.boilK + " K" : "Synthetic")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Crystal Lattice: " + root.currentElement.crystal
                                            color: "#93C5FD"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Bohr Shells (K..Q): " + root.currentElement.shells.join(" · ")
                                            color: "#93C5FD"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Electron Config: " + root.currentElement.config
                                            color: "#93C5FD"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                    }

                                    // Quick Prev / Next Element Navigation inside Deep Chemistry View
                                    Row {
                                        spacing: Style.space(10)

                                        Rectangle {
                                            height: 24
                                            width: 135
                                            radius: 4
                                            color: "#1E293B"
                                            border.width: 1
                                            border.color: "#475569"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "← Prev Element (H)"
                                                color: "#E2E8F0"
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.currentZ = Math.max(1, root.currentZ - 1)
                                            }
                                        }

                                        Rectangle {
                                            height: 24
                                            width: 135
                                            radius: 4
                                            color: "#1E293B"
                                            border.width: 1
                                            border.color: "#475569"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Next Element (L) →"
                                                color: "#E2E8F0"
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.currentZ = Math.min(118, root.currentZ + 1)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Bottom "More Details" Action Bar on Every Element Card
                        Rectangle {
                            id: moreDetailsBtn
                            width: parent.width
                            height: 30
                            radius: 4
                            color: root.showMoreDetails ? "#115E59" : "#0F766E"
                            border.width: 1
                            border.color: "#2DD4BF"

                            Text {
                                anchors.centerIn: parent
                                text: root.showMoreDetails
                                      ? "▴ Hide More Details & Return to Full 18×10 Periodic Table Grid (Enter / M / Esc)"
                                      : "▾ More Details — View Deep Chemistry, Reactions, Crystal Lattice & Animated Bohr Orbitals for " + root.currentElement.name + " (Enter / M)"
                                color: "#FFFFFF"
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showMoreDetails = !root.showMoreDetails
                            }
                        }
                    }
                }
            }
        }
    }
}

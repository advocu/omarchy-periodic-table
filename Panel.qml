import QtQuick
import qs.Commons
import qs.Ui
import "ElementsData.js" as ElementsDB

Panel {
    id: root
    moduleName: "io.github.advocu.periodic-table"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null

    // UI State
    property int currentZ: 6
    property bool showMoreDetails: false
    property string activeCategoryFilter: ""
    property int heatmapMode: 0 // 0=Category, 1=Valence, 2=Electronegativity, 3=Van der Waals radius
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

    function matchesFilter(el) {
        if (!el) return false
        return root.activeCategoryFilter === "" || el.category === root.activeCategoryFilter
    }

    // Missing data. A blank, null, or non-positive number means the dataset has
    // no value for that field (0 is the bundle's sentinel for "unknown"). The UI
    // says "no data" instead of printing a number or guessing a reason.
    readonly property string noData: "no data"

    function hasValue(v) {
        if (v === undefined || v === null || v === "") return false
        if (typeof v === "number") return !isNaN(v) && v > 0
        return true
    }

    function fmt(v, unit) {
        return root.hasValue(v) ? (unit ? v + " " + unit : String(v)) : root.noData
    }

    function shellsText(el, sep) {
        return el && el.shells && el.shells.length ? el.shells.join(sep) : root.noData
    }

    // Mass is shown exactly as stored: a decimal string, or "[A]" (mass number)
    // for elements without a standard atomic weight. Only decimals get "u".
    function massText(el) {
        if (!el || !root.hasValue(el.mass)) return root.noData
        var m = String(el.mass)
        return m.charAt(0) === "[" ? m : m + " u"
    }

    // Heatmap scales come from the elements that have a value; missing values
    // are excluded from min/max and drawn in the no-data grey.
    readonly property color noDataColor: "#475569"

    function fieldRange(key) {
        var lo = Infinity, hi = -Infinity
        for (var i = 0; i < ElementsDB.ELEMENTS.length; i++) {
            var v = ElementsDB.ELEMENTS[i][key]
            if (!root.hasValue(v)) continue
            if (v < lo) lo = v
            if (v > hi) hi = v
        }
        return { lo: lo, hi: hi }
    }

    readonly property var valenceRange: fieldRange("valence")
    readonly property var enRange: fieldRange("electronegativity")
    readonly property var radiusRange: fieldRange("radius")

    function scaled(v, range) {
        if (range.hi <= range.lo) return 0.5
        return Math.min(1.0, Math.max(0.0, (v - range.lo) / (range.hi - range.lo)))
    }

    function tileAccentColor(el) {
        if (!el) return "transparent"
        if (root.heatmapMode === 1) {
            // Valence electrons heatmap
            if (!root.hasValue(el.valence)) return root.noDataColor
            var vRatio = root.scaled(el.valence, root.valenceRange)
            return Qt.rgba(0.15 + 0.75 * vRatio, 0.55 - 0.2 * vRatio, 0.95 - 0.65 * vRatio, 1.0)
        }
        if (root.heatmapMode === 2) {
            // Pauling electronegativity
            if (!root.hasValue(el.electronegativity)) return root.noDataColor
            var enRatio = root.scaled(el.electronegativity, root.enRange)
            return Qt.rgba(0.1 + 0.85 * enRatio, 0.75 - 0.45 * enRatio, 0.35, 1.0)
        }
        if (root.heatmapMode === 3) {
            // Van der Waals radius
            if (!root.hasValue(el.radius)) return root.noDataColor
            var rRatio = root.scaled(el.radius, root.radiusRange)
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
        // Past the end of a row, step to the previous/next atomic number.
        // Past the end of a column, stay put.
        if (dCol !== 0)
            root.currentZ = Math.max(1, Math.min(118, root.currentZ + dCol))
    }

    // A quiz target must have every field the clue shows.
    function quizReady(z) {
        var el = ElementsDB.getByZ(z)
        return root.hasValue(el.valence) && root.hasValue(el.config) && root.hasValue(el.category)
    }

    function nextQuizTarget(z) {
        for (var i = 0; i < 118; i++) {
            z = (z % 118) + 1
            if (root.quizReady(z)) return z
        }
        return z
    }

    function startQuizRound() {
        root.quizTargetZ = root.nextQuizTarget(Math.floor(Math.random() * 118))
        root.quizFeedback = "Click or navigate + Enter on the element matching the clue!"
    }

    function checkQuizAnswer(selectedZ) {
        if (!root.quizActive) return
        if (selectedZ === root.quizTargetZ) {
            root.quizScore += 1
            var solved = ElementsDB.getByZ(selectedZ)
            root.quizFeedback = "Correct! " + solved.name + " (" + solved.symbol + ") has " + root.fmt(solved.valence, "valence electrons") + "."
            root.quizTargetZ = root.nextQuizTarget((selectedZ * 37 + 13) % 118)
        } else {
            var picked = ElementsDB.getByZ(selectedZ)
            root.quizFeedback = "Not " + picked.symbol + " (Z=" + picked.z + "). Try again!"
        }
    }

    function activateCurrent() {
        if (root.quizActive) root.checkQuizAnswer(root.currentZ)
        else root.showMoreDetails = !root.showMoreDetails
    }

    function toggleQuiz() {
        root.quizActive = !root.quizActive
        if (root.quizActive) root.startQuizRound()
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

            onMoveRequested: function(dx, dy) {
                root.moveFocusByGrid(dy, dx)
            }
            onReturnRequested: root.activateCurrent()
            onTextKey: function(text, modifiers) {
                if (modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
                if (text === "m" || text === "M") root.activateCurrent()
                else if (text === "t" || text === "T") root.showTempBar = !root.showTempBar
                else if (text === "v" || text === "V") root.heatmapMode = (root.heatmapMode + 1) % 4
                else if (text === "q" || text === "Q") root.toggleQuiz()
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
                            text: (root.heatmapMode === 0 ? "Color: Family (V)" :
                                   root.heatmapMode === 1 ? "Color: Valence e⁻ (V)" :
                                   root.heatmapMode === 2 ? "Color: Electronegativity (V)" :
                                                            "Color: Van der Waals Radius (V)")
                                  + (root.heatmapMode === 0 ? "" : " · grey = no data")
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
                            onClicked: root.toggleQuiz()
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
                            { label: "Liquid Helium (4 K)", k: 4 },
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
                            text: "CLUE: Atomic #" + qEl.z + " · Valence e⁻: " + root.fmt(qEl.valence) + " · Config " + root.fmt(qEl.config) + " · " + ElementsDB.categoryMeta(qEl.category).label
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
                            readonly property bool isMatched: hasElement && root.matchesFilter(el)

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
                                    text: parent.parent.hasElement && root.hasValue(parent.parent.el.valence) ? (parent.parent.el.valence + "e⁻") : ""
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
                                    text: root.massText(root.currentElement)
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
                                            text: "Valence Electrons: " + root.fmt(root.currentElement.valence, "e⁻")
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
                                          "   |   Config: " + root.fmt(root.currentElement.config) +
                                          "   |   Shells: " + root.shellsText(root.currentElement, ", ") +
                                          "   |   Period " + root.currentElement.period + ", Group " + root.currentElement.group
                                    color: "#93C5FD"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }

                                // getPhaseAtTemp() returns "Unknown" when the melting/boiling
                                // data cannot decide; that state gets its own colour and label.
                                Text {
                                    readonly property string phase: ElementsDB.getPhaseAtTemp(root.currentElement, root.tempKelvin)
                                    readonly property bool unknown: phase === "Unknown"
                                    width: parent.width
                                    text: "State @ " + root.tempKelvin + " K: " + (unknown ? "Unknown (no melting/boiling data)" : phase)
                                    color: unknown ? "#FBBF24" : "#93C5FD"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 12
                                    font.italic: unknown
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    visible: root.hasValue(root.currentElement.summary)
                                    text: root.hasValue(root.currentElement.summary) ? root.currentElement.summary : ""
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
                                        animateOrbitals: root.opened
                                    }

                                    Text {
                                        width: 180
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "Outer yellow dots = " + root.fmt(root.currentElement.valence, "valence e⁻")
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
                                        text: "More Details: " + root.currentElement.name + " (Z=" + root.currentElement.z + ")"
                                        color: "#2DD4BF"
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        visible: root.hasValue(root.currentElement.chemistry)
                                        text: root.hasValue(root.currentElement.chemistry) ? root.currentElement.chemistry : ""
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
                                            text: "• Oxidation States: " + root.fmt(root.currentElement.oxidation)
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Electronegativity: " + root.fmt(root.currentElement.electronegativity, "(Pauling)")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• 1st Ionization Energy: " + root.fmt(root.currentElement.ionization, "kJ/mol")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Van der Waals Radius: " + root.fmt(root.currentElement.radius, "pm")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Melting Point: " + root.fmt(root.currentElement.meltK, "K")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Boiling Point: " + root.fmt(root.currentElement.boilK, "K")
                                            color: "#CBD5E1"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Bohr Shells (K..Q): " + root.shellsText(root.currentElement, " · ")
                                            color: "#93C5FD"
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "• Electron Config: " + root.fmt(root.currentElement.config)
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
                                      : "▾ More Details — properties and animated Bohr shells for " + root.currentElement.name + " (Enter / M)"
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

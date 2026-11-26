import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ElementsData.js" as ElementsDB

Panel {
    id: root
    moduleName: "io.github.advocu.periodic-table"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null

    // Theme colours: text matches the header (bar foreground), surfaces use the
    // shell's own state fills, so cards keep their contrast on light themes.
    // Family/heatmap colours stay fixed because they encode data.
    readonly property color textColor: root.barForeground
    readonly property color mutedText: Commons.Color.muted
    readonly property color accentColor: Commons.Color.accent
    readonly property color warnColor: Commons.Color.warning

    // UI State
    property int currentZ: 6
    property bool showMoreDetails: false
    property string activeCategoryFilter: ""
    property int heatmapMode: 0 // 0=Category, 1=Valence, 2=Electronegativity, 3=Van der Waals radius
    property int tempKelvin: 298
    property bool showTempBar: false
    property int pinnedZ: 0 // 0 = unpinned; while pinned, hovering other tiles does not change the selection

    onOpenedChanged: if (!root.opened) root.pinnedZ = 0

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

    // Top-right tile slot: phase letter in temperature mode, otherwise the value the heatmap shows.
    function tileMetricText(el) {
        if (!el) return ""
        if (root.showTempBar) {
            var phase = ElementsDB.getPhaseAtTemp(el, root.tempKelvin)
            return phase === "Solid" ? "S" : phase === "Liquid" ? "L" : phase === "Gas" ? "G" : "?"
        }
        if (root.heatmapMode === 2) return root.hasValue(el.electronegativity) ? String(el.electronegativity) : ""
        if (root.heatmapMode === 3) return root.hasValue(el.radius) ? String(el.radius) : ""
        return root.hasValue(el.valence) ? (el.valence + "e⁻") : ""
    }

    // Density as plain decimals: gas values such as 0.00008988 never print in exponent form.
    function densityText(el) {
        if (!el || !root.hasValue(el.density)) return root.noData
        var v = Number(el.density)
        return (v < 0.001 ? v.toFixed(8).replace(/\.?0+$/, "") : String(v)) + " g/cm³"
    }

    // More Details facts, in display order, keeping only fields the dataset has a value for.
    function detailSpecs(el) {
        var out = []
        if (!el) return out
        if (root.hasValue(el.oxidation)) out.push("• Oxidation States: " + el.oxidation)
        if (root.hasValue(el.electronegativity)) out.push("• Electronegativity: " + el.electronegativity + " (Pauling)")
        if (root.hasValue(el.ionization)) out.push("• 1st Ionization Energy: " + el.ionization + " kJ/mol")
        if (root.hasValue(el.radius)) out.push("• Van der Waals Radius: " + el.radius + " pm")
        if (root.hasValue(el.meltK)) out.push("• Melting Point: " + el.meltK + " K")
        if (root.hasValue(el.boilK)) out.push("• Boiling Point: " + el.boilK + " K")
        if (el.shells && el.shells.length > 0) out.push("• Bohr Shells (K..Q): " + root.shellsText(el, " · "))
        if (root.hasValue(el.config)) out.push("• Electron Config: " + el.config)
        if (root.hasValue(el.density)) out.push("• Density: " + root.densityText(el))
        if (root.hasValue(el.yearDiscovered)) out.push("• Discovered: " + el.yearDiscovered)
        return out
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
    readonly property color noDataColor: Commons.Color.muted

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

    function stepZ(delta) {
        root.currentZ = Math.max(1, Math.min(118, root.currentZ + delta))
    }

    function toggleMoreDetails() {
        root.showMoreDetails = !root.showMoreDetails
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
                } else if (root.pinnedZ !== 0) {
                    root.pinnedZ = 0
                } else {
                    root.close()
                }
            }
            onTabRequested: function(direction) {
                root.switchPanel(direction)
            }

            onMoveRequested: function(dx, dy) {
                root.pinnedZ = 0
                // In More Details the grid is hidden, and Left/Right (h/l) match the
                // Prev/Next buttons: one atomic number back or forward.
                if (root.showMoreDetails && dy === 0) root.stepZ(dx)
                else root.moveFocusByGrid(dy, dx)
            }
            onReturnRequested: root.toggleMoreDetails()
            onTextKey: function(text, modifiers) {
                if (modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
                if (text === "m" || text === "M") root.toggleMoreDetails()
                else if (text === "t" || text === "T") root.showTempBar = !root.showTempBar
                else if (text === "v" || text === "V") root.heatmapMode = (root.heatmapMode + 1) % 4
            }

            Column {
                id: mainColumn
                width: parent.width
                spacing: Style.space(8)

                // Top Header & Controls Strip (wraps the pills under the title if the fonts are too wide)
                Flow {
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
                        color: Style.normalFill
                        border.width: 1
                        border.color: root.accentColor

                        Text {
                            id: heatmapText
                            anchors.centerIn: parent
                            text: (root.heatmapMode === 0 ? "Color: Family (V)" :
                                   root.heatmapMode === 1 ? "Color: Valence e⁻ (V)" :
                                   root.heatmapMode === 2 ? "Color: Electronegativity (V)" :
                                                            "Color: Van der Waals Radius (V)")
                                  + (root.heatmapMode === 2 || root.heatmapMode === 3 ? " · grey = no data" : "")
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
                        color: root.showTempBar ? Style.selectedFill : Style.normalFill
                        border.width: 1
                        border.color: root.showTempBar ? root.accentColor : Style.normalBorderColor

                        Text {
                            id: tempToggleText
                            anchors.centerIn: parent
                            text: "Phase Temp: " + root.tempKelvin + " K · " + (root.tempKelvin - 273) + " °C (T)"
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
                }

                // Optional Temperature Phase Presets Bar
                Flow {
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
                            color: root.tempKelvin === modelData.k ? Style.selectedFill : Style.normalFill
                            border.width: 1
                            border.color: root.tempKelvin === modelData.k ? root.accentColor : Style.normalBorderColor

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

                // Category Filter Chips Row
                Flow {
                    width: parent.width
                    spacing: Style.space(4)

                    Rectangle {
                        height: Style.space(20)
                        width: allCatTxt.implicitWidth + Style.space(10)
                        radius: Style.space(3)
                        color: root.activeCategoryFilter === "" ? Style.selectedFill : Style.normalFill

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
                            color: root.activeCategoryFilter === modelData ? Style.selectedFill : Style.normalFill
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
                                       : Style.normalFill
                                border.width: parent.isFocused ? 2 : 1
                                border.color: parent.isFocused ? root.warnColor : root.tileAccentColor(parent.el)

                                // Top row: Atomic Number (left) and Valence Count (right)
                                Text {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 2
                                    text: parent.parent.hasElement ? String(parent.parent.el.z) : ""
                                    color: parent.parent.isFocused ? "#FFFFFF" : root.mutedText
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 9
                                }

                                Text {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 2
                                    text: parent.parent.hasElement ? root.tileMetricText(parent.parent.el) : ""
                                    color: parent.parent.isFocused ? "#FEF08A" : root.accentColor
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 8
                                }

                                // Center Symbol
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.parent.hasElement
                                          ? parent.parent.el.symbol
                                          : ""
                                    color: parent.parent.isFocused ? "#FFFFFF" : root.textColor
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 18
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
                                          ? parent.parent.el.name
                                          : ""
                                    color: parent.parent.isFocused ? "#FFFFFF" : root.textColor
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 7
                                }

                                // Pinned tile: tiny dot in the bottom-right corner
                                Rectangle {
                                    visible: parent.parent.hasElement && parent.parent.el.z === root.pinnedZ
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 2
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: "#FFFFFF"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        if (parent.parent.hasElement && root.pinnedZ === 0) {
                                            root.currentZ = parent.parent.el.z
                                        }
                                    }
                                    // Left or right click pins the tile; clicking the pinned tile again unpins it.
                                    onClicked: function(mouse) {
                                        if (!parent.parent.hasElement) return
                                        var z = parent.parent.el.z
                                        if (root.pinnedZ === z) {
                                            root.pinnedZ = 0
                                        } else {
                                            root.currentZ = z
                                            root.pinnedZ = z
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (parent.parent.hasElement) {
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
                                color: root.mutedText
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
                    color: Style.normalFill
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

                                Text {
                                    visible: root.pinnedZ !== 0 && root.pinnedZ === root.currentElement.z
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    text: "PIN"
                                    color: "#FFFFFF"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 9
                                    font.bold: true
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
                                        color: root.textColor
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    Rectangle {
                                        height: 22
                                        width: valBadgeTxt.implicitWidth + 14
                                        radius: 4
                                        color: Style.selectedFill
                                        border.width: 1
                                        border.color: root.accentColor

                                        Text {
                                            id: valBadgeTxt
                                            anchors.centerIn: parent
                                            text: "Valence Electrons: " + root.fmt(root.currentElement.valence, "e⁻")
                                            color: root.textColor
                                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        height: 22
                                        width: catBadgeTxt.implicitWidth + 12
                                        radius: 4
                                        color: Style.normalFill
                                        border.width: 1
                                        border.color: root.currentCatMeta.color

                                        Text {
                                            id: catBadgeTxt
                                            anchors.centerIn: parent
                                            text: root.currentCatMeta.label + " · " + root.currentElement.block + "-block"
                                            color: root.textColor
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
                                    color: root.textColor
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
                                    color: unknown ? root.warnColor : root.textColor
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: 12
                                    font.italic: unknown
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    visible: root.hasValue(root.currentElement.summary)
                                    text: root.hasValue(root.currentElement.summary) ? root.currentElement.summary : ""
                                    color: root.textColor
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
                            color: Style.normalFill
                            border.width: 1
                            border.color: root.accentColor

                            Row {
                                id: deepDrawerRow
                                width: parent.width - Style.space(18)
                                anchors.centerIn: parent
                                spacing: Style.space(16)

                                // Left: Animated 2D Bohr Orbital Visualizer
                                Column {
                                    id: bohrColumn
                                    width: 190
                                    spacing: 4

                                    BohrCanvas {
                                        width: 180
                                        height: 180
                                        shells: root.currentElement.shells
                                        symbol: root.currentElement.symbol
                                        accentColor: root.currentCatMeta.color
                                        textColor: root.textColor
                                        ringColor: root.mutedText
                                        valenceColor: root.warnColor
                                        animateOrbitals: root.opened
                                    }
                                }

                                // Right: Comprehensive Chemistry & Physical Properties Breakdown
                                Column {
                                    width: parent.width - bohrColumn.width - parent.spacing
                                    spacing: Style.space(8)

                                    Text {
                                        text: "More Details: " + root.currentElement.name + " (Z=" + root.currentElement.z + ")"
                                        color: root.accentColor
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        visible: root.hasValue(root.currentElement.chemistry)
                                        text: root.hasValue(root.currentElement.chemistry) ? root.currentElement.chemistry : ""
                                        color: root.textColor
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                    }

                                    // Quantitative Chemistry Specs Grid (measured fields only)
                                    Grid {
                                        id: specsGrid
                                        width: parent.width
                                        columns: 3
                                        columnSpacing: Style.space(16)
                                        rowSpacing: Style.space(6)

                                        Repeater {
                                            model: root.detailSpecs(root.currentElement)
                                            delegate: Text {
                                                width: Math.floor((specsGrid.width - 2 * specsGrid.columnSpacing) / 3)
                                                wrapMode: Text.Wrap
                                                text: modelData
                                                color: root.textColor
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: 12
                                            }
                                        }
                                    }

                                    // Quick Prev / Next Element Navigation inside Deep Chemistry View
                                    Row {
                                        spacing: Style.space(10)

                                        Rectangle {
                                            height: 24
                                            width: Math.max(135, prevLbl.implicitWidth + Style.space(16))
                                            radius: 4
                                            color: Style.normalFill
                                            border.width: 1
                                            border.color: Style.normalBorderColor

                                            Text {
                                                id: prevLbl
                                                anchors.centerIn: parent
                                                text: "← Prev Element (H)"
                                                color: root.textColor
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.stepZ(-1)
                                            }
                                        }

                                        Rectangle {
                                            height: 24
                                            width: Math.max(135, nextLbl.implicitWidth + Style.space(16))
                                            radius: 4
                                            color: Style.normalFill
                                            border.width: 1
                                            border.color: Style.normalBorderColor

                                            Text {
                                                id: nextLbl
                                                anchors.centerIn: parent
                                                text: "Next Element (L) →"
                                                color: root.textColor
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.stepZ(1)
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: (root.detailSpecs(root.currentElement).length < 10 ? "Unmeasured properties omitted · " : "")
                                              + "Sources: IUPAC 2024 · PubChem · NIST"
                                        color: root.mutedText
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: 10
                                        wrapMode: Text.WordWrap
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
                            color: root.showMoreDetails ? Style.normalFill : Style.selectedFill
                            border.width: 1
                            border.color: root.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: root.showMoreDetails
                                      ? "▴ Hide More Details & Return to Full 18×10 Periodic Table Grid (Enter / M / Esc)"
                                      : "▾ More Details — properties and animated Bohr shells for " + root.currentElement.name + " (Enter / M)"
                                color: root.textColor
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

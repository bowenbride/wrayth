import QtQuick
import qs.components
import qs.config
import qs.services

// One profile's pool, and how to play it.
Item {
    id: root

    required property string name
    required property var pool
    // The row the pointer is over with something in hand.
    required property bool highlighted
    // True when the profile's own net-<name>.png is no longer on disk.
    required property bool missingOwn
    required property bool canRestore

    signal modeRequested(string mode)
    signal everyChanged(int minutes)
    signal fadeChanged(real seconds)
    signal chipToggled(int index)
    signal chipStarred(int index)
    signal chipRemoved(int index)
    signal restoreRequested
    signal chipDragStarted(var payload, real x, real y)
    signal chipDragMoved(real x, real y)
    signal chipDragEnded

    // The index of the chip the keyboard is on, or -1. The screen owns the
    // position; a row only knows whether it holds it.
    property int focusedChip: -1

    readonly property color tone: Theme.accentOf(root.name)
    readonly property color ink: Theme.groundOf(root.name)
    readonly property bool custom: Profiles.isCustom(root.name)
    readonly property int tickedCount: (pool.items ?? []).filter(item => item.on).length
    // CYCLE and SHUFFLE need something to move between.
    readonly property bool rotatable: tickedCount >= 2

    readonly property int padding: 12

    // The chips decide the height, with the same air above and below them, so
    // a pool that wraps onto a second row grows the row rather than crowding
    // it. `controls` is the floor, for a profile with an empty pool.
    implicitHeight: Math.max(controls.implicitHeight + padding * 2, chips.implicitHeight + padding * 2)

    Rectangle {
        anchors.fill: parent
        color: root.highlighted ? Theme.alpha(Theme.accent, 0.12) : Theme.alpha(Theme.hair, 0.16)
        border.width: Appearance.metrics.hairline
        border.color: root.highlighted ? Theme.accent : Theme.hair

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // --- Who ----------------------------------------------------------------
    Column {
        id: who

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: root.padding
        width: 130
        spacing: 4

        Row {
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                color: root.tone
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.name.toUpperCase()
                color: Theme.bright
                font.family: Appearance.font.display
                font.pixelSize: 13
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }
        }

        NrLabel {
            pixelSize: 10
            color: Theme.dim
            text: root.custom ? "CUSTOM" : "PRESET"
        }

        // Only when the profile's own wallpaper is gone. The mapping needs a
        // source, so with no wrayth wallpaper left anywhere there is
        // nothing to restore from and the button says so instead of failing.
        Rectangle {
            visible: opacity > 0
            opacity: root.missingOwn ? 1 : 0
            width: who.width
            height: 26

            Behavior on opacity {
                NumberAnimation {
                    duration: root.missingOwn ? Appearance.duration.enter : Appearance.duration.exit
                    easing.type: root.missingOwn ? Easing.OutCubic : Easing.InCubic
                }
            }
            color: "transparent"
            border.width: Appearance.metrics.hairline
            border.color: root.canRestore ? Theme.accent : Theme.hair

            NrLabel {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                centred: true
                pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: root.canRestore ? Theme.accent : Theme.mute
                text: root.canRestore ? `RESTORE ${Wallpapers.generatedName(root.name)}` : "NO BASE LEFT TO RESTORE FROM"
            }

            HoverHandler {
                enabled: root.canRestore
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.canRestore
                onTapped: root.restoreRequested()
            }
        }
    }

    // --- The pool -------------------------------------------------------------
    Flow {
        id: chips

        anchors.left: who.right
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: root.padding
        width: 574
        spacing: 8

        Repeater {
            model: root.pool.items ?? []

            PoolChip {
                required property var modelData
                required property int index

                item: modelData
                starred: modelData.star === true
                tone: root.tone
                ink: root.ink
                focused: root.focusedChip === index

                onToggled: root.chipToggled(index)
                onStarRequested: root.chipStarred(index)
                onRemoveRequested: root.chipRemoved(index)
                onDragStarted: (payload, x, y) => root.chipDragStarted(payload, x, y)
                onDragMoved: (x, y) => root.chipDragMoved(x, y)
                onDragEnded: root.chipDragEnded()
            }
        }

        // An empty pool is a state worth naming: with nothing in it the
        // profile falls back to its own generated wallpaper.
        NrLabel {
            visible: (root.pool.items ?? []).length === 0
            height: 60
            pixelSize: 10
            color: Theme.dim
            text: "EMPTY    FALLS BACK TO ITS OWN WALLPAPER"
        }
    }

    // --- How ------------------------------------------------------------------
    Column {
        id: controls

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        width: 300
        spacing: 8

        Row {
            spacing: 8

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                text: "MODE"
            }

            Repeater {
                model: Wallpapers.modes

                Rectangle {
                    required property string modelData

                    readonly property bool current: (root.pool.mode ?? "SINGLE") === modelData
                    // SINGLE is always available; the other two need two
                    // ticked wallpapers to have anything to move between.
                    readonly property bool usable: modelData === "SINGLE" || root.rotatable

                    width: label.implicitWidth + 14
                    height: 20
                    color: current ? Theme.alpha(Theme.accent, 0.18) : "transparent"
                    border.width: Appearance.metrics.hairline
                    border.color: current ? Theme.accent : usable ? Theme.hair : Theme.alpha(Theme.hair, 0.5)

                    NrLabel {
                        id: label

                        anchors.centerIn: parent
                        centred: true
                        pixelSize: 10
                        color: parent.current ? Theme.accent : parent.usable ? Theme.text : Theme.mute
                        text: parent.modelData
                    }

                    HoverHandler {
                        enabled: parent.usable
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: parent.usable
                        onTapped: root.modeRequested(parent.modelData)
                    }
                }
            }
        }

        Row {
            spacing: 8
            // EVERY and FADE mean nothing to a single wallpaper.
            opacity: root.rotatable && (root.pool.mode ?? "SINGLE") !== "SINGLE" ? 1 : 0.4
            enabled: opacity === 1

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                text: "EVERY"
            }

            InputField {
                anchors.verticalCenter: parent.verticalCenter
                width: 54
                pixelSize: 10
                text: `${root.pool.every ?? 15}`
                validator: IntValidator {
                    bottom: 1
                    top: 1440
                }

                onEdited: value => root.everyChanged(parseInt(value) || 1)
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                pixelSize: 10
                text: "MIN"
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                text: "FADE"
            }

            InputField {
                anchors.verticalCenter: parent.verticalCenter
                width: 54
                pixelSize: 10
                text: `${root.pool.fade ?? 1.5}`
                validator: DoubleValidator {
                    bottom: 0.1
                    top: 30
                    decimals: 1
                    notation: DoubleValidator.StandardNotation
                }

                onEdited: value => root.fadeChanged(parseFloat(value) || 1.5)
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                pixelSize: 10
                text: "SEC"
            }
        }
    }
}

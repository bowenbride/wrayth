import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.utils

Row {
    id: root

    // Clicking the clock opens CALENDAR under it.
    readonly property string dropdownName: "calendar"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }

    // The seconds sit this far right of the minutes, with no colon between.
    readonly property int secondsGap: 4

    spacing: 10

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // HH:MM and the seconds, each in a cell of its own. TabularText gives every
    // digit the widest digit's width, so both cells are fixed-width by
    // construction and nothing moves as either ticks over.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        // Chakra Petch sits high in its em box, so nudge the clock down to
        // look optically centred next to the date.
        anchors.verticalCenterOffset: 3

        implicitWidth: time.implicitWidth + root.secondsGap + seconds.implicitWidth
        implicitHeight: time.implicitHeight

        TabularText {
            id: time

            text: Fmt.clockHM(clock.date)
            color: Tokens.color.bright
            font.family: Tokens.font.display
            font.pixelSize: Tokens.type.clock.size
            font.weight: Appearance.font.weightBold
        }

        // The lockscreen's treatment, shrunk to the bar: smaller, accented, and
        // raised to sit like a superscript against the HH:MM digits.
        TabularText {
            id: seconds

            // Top-aligned to the HH:MM digits. Both ink tops are measured off
            // the font -- ascent to the top of a digit's drawn pixels -- rather
            // than nudged by a constant, so the alignment survives a change of
            // font or size.
            x: time.implicitWidth + root.secondsGap
            y: (big.ascent + bigInk.tightBoundingRect.y) - (small.ascent + smallInk.tightBoundingRect.y)

            text: Fmt.pad2(clock.date.getSeconds())
            color: Tokens.color.accent
            font.family: Tokens.font.display
            font.pixelSize: Tokens.type.clockSeconds.size
            font.weight: Appearance.font.weightBold
        }

        FontMetrics {
            id: big

            font: time.font
        }

        TextMetrics {
            id: bigInk

            font: time.font
            text: "8"
        }

        FontMetrics {
            id: small

            font: seconds.font
        }

        TextMetrics {
            id: smallInk

            font: seconds.font
            text: "8"
        }
    }

    NrLabel {
        anchors.verticalCenter: parent.verticalCenter
        pixelSize: Appearance.size.date
        text: Fmt.barDate(clock.date)
        font.features: Appearance.tabularFigures
    }
}

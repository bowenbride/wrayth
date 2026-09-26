import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

// What one screen shows while locked.
Item {
    id: root

    property date now: new Date()
    // Driven by the exit animation in LockScreen.
    property real fade: 1

    opacity: fade
    // A layer only while fading. An opacity binding on a plain parent puts the
    // subtree into Qt's implicit opacity path, where the backdrop's blurred
    // Wallpaper composites to nothing -- the same trap the power menu hit.
    layer.enabled: fade < 1

    LockBackdrop {
        anchors.fill: parent
    }

    // --- Top left ----------------------------------------------------------
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 36
        spacing: 10

        HazardStripes {
            implicitWidth: 96
            height: 11
        }

        Row {
            spacing: 10

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                pixelSize: Appearance.size.katakana
                color: Theme.bright
                text: "SESSION SUSPENDED"
            }

            Text {
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                text: "    ICE ACTIVE"
                color: Theme.accent
                font.family: Appearance.font.data
                font.pixelSize: Appearance.size.katakana
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: Appearance.tracking(Appearance.size.katakana)
            }
        }

        KanaTag {
            text: "セッション停止 // 防壁稼働中"
        }
    }

    // --- Top right ---------------------------------------------------------
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 36
        spacing: 6

        // Space and colour divide the two readings; the labels dim, the values
        // in the text colour.
        Row {
            anchors.right: parent.right
            spacing: 16

            Row {
                spacing: 6
                NrLabel { text: "HOST" }
                NrLabel { color: Theme.text; text: Demo.host(Machine.hostname) }
            }

            Row {
                spacing: 6
                NrLabel { text: "UPLINK" }
                NrLabel { color: Theme.text; text: SystemStatus.ssid ? Demo.ssid(SystemStatus.ssid).toUpperCase() : "OFFLINE" }
            }
        }

        NrLabel {
            anchors.right: parent.right
            color: Theme.mute
            text: `PROFILE${Appearance.separator}${Theme.profile.toUpperCase()}`
        }
    }

    // --- Centre ------------------------------------------------------------
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 30

        // **The clock, the operator line and the date, evenly spaced.** They
        // are a nested column so the two gaps around the operator line are
        // equal to each other and their sum equals the single gap the clock
        // and date used to have -- the date and the auth panel below it do
        // not move, and the operator line lands in the air that was already
        // between them.
        Column {
            id: clockGroup

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.max(6, (30 - operatorRow.implicitHeight) / 2)

            // **The colon is the fixed point, and the numbers hang off it.**
            //
            // The digits are `ClockDigits`, laid out at their natural glyph
            // widths -- a narrow `1` no longer floats in a wide cell, which is
            // what put false gaps between the digits and before the seconds.
            // The colon's ink centre is the item's centre and the item is
            // centred on screen, so the colon sits exactly on the screen's
            // midline whatever the digits are; the hours are anchored to the
            // colon's left ink edge and the minutes to its right, and the
            // seconds a fixed distance past the minutes' last visible ink.
            // Nothing on one side of the colon can move anything on the other.
            Item {
                id: clockRow

                anchors.horizontalCenter: parent.horizontalCenter

                // The clear air kept either side of the colon's ink, and
                // between the minutes' last ink and the seconds.
                readonly property real colonGap: 12
                readonly property real secondsGap: 20

                // Everything below is relative to the colon's ink centre = 0.
                readonly property real colonHalf: colonInk.tightBoundingRect.width / 2
                readonly property real hoursWidth: hours.inkRight - hours.inkLeft
                readonly property real minutesWidth: minutes.inkRight - minutes.inkLeft
                readonly property real secondsWidth: seconds.inkRight - seconds.inkLeft

                // Left ink of hours, right ink of the seconds, about the colon.
                readonly property real leftEdge0: -(colonHalf + colonGap + hoursWidth)
                readonly property real minutesRight0: colonHalf + colonGap + minutesWidth
                readonly property real rightEdge0: minutesRight0 + secondsGap + secondsWidth

                // Reserve the longer side on both, so the item's own centre and
                // the colon's ink centre are the same point.
                readonly property real half: Math.max(-leftEdge0, rightEdge0)
                readonly property real shift: half

                implicitWidth: half * 2
                implicitHeight: hours.implicitHeight

                TextMetrics {
                    id: colonInk

                    font: colonText.font
                    text: ":"
                }

                ClockDigits {
                    id: hours

                    // Right ink lands one gap left of the colon's left ink.
                    x: clockRow.shift - clockRow.colonHalf - clockRow.colonGap - inkRight
                    anchors.bottom: parent.bottom

                    text: Fmt.pad2(root.now.getHours())
                    color: Theme.bright
                    pixelSize: 168
                }

                Text {
                    id: colonText

                    renderType: Text.NativeRendering
                    // Ink centre on the item centre: x + inkX + inkW/2 = shift.
                    x: clockRow.shift - colonInk.tightBoundingRect.x - clockRow.colonHalf
                    anchors.bottom: parent.bottom

                    text: ":"
                    color: Theme.bright
                    font.family: Appearance.font.display
                    font.pixelSize: 168
                    font.weight: Appearance.font.weightBold
                }

                ClockDigits {
                    id: minutes

                    // Left ink lands one gap right of the colon's right ink.
                    x: clockRow.shift + clockRow.colonHalf + clockRow.colonGap - inkLeft
                    anchors.bottom: parent.bottom

                    text: Fmt.pad2(root.now.getMinutes())
                    color: Theme.bright
                    pixelSize: 168
                }

                ClockDigits {
                    id: seconds

                    // Left ink a fixed distance past the minutes' last ink.
                    x: minutes.x + minutes.inkRight + clockRow.secondsGap - inkLeft
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 34

                    text: Fmt.pad2(root.now.getSeconds())
                    color: Theme.accent
                    pixelSize: 32
                    gap: 2
                }
            }

            // **The operator line, in the corner labels' style.** It reads the
            // real logged-in user rather than anything demo mode masks: in the
            // demo account that user is `runner`, so it draws `RUNNER` there
            // without a placeholder. `OPERATOR` dim, the `//` in `hair`, the
            // name in `text`.
            Row {
                id: operatorRow

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.dim
                    text: "OPERATOR"
                }

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.hair
                    text: "//"
                }

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    text: Runner.user.toUpperCase()
                }
            }

            // The date, slashes gone so it does not stack a second `//` under
            // the operator line: the numeric date in `text`, the abbreviated
            // day in `dim`, matching the bar's format.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    pixelSize: Appearance.size.katakana
                    color: Theme.text
                    text: Fmt.dateNumeric(root.now)
                }

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    pixelSize: Appearance.size.katakana
                    color: Theme.dim
                    text: Fmt.dayAbbr(root.now)
                }
            }
        }

        AuthPanel {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // --- Bottom strip ------------------------------------------------------
    // The readouts sit straight on the backdrop. A filled bar behind them cut
    // the screen in two and read as a separate surface.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: `QUEUE ${Planner.done}/${Planner.total} CLEARED`
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Vuln.count > 0 ? Theme.text : Theme.dim
                text: `VULN ${Vuln.count} AFFECTED`
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: SystemStatus.breach ? Theme.accent : Theme.dim
                text: SystemStatus.breach ? `ICE BREACH ${SystemStatus.failedUnits}` : "ICE NOMINAL"
            }
        }

        NrLabel {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: Power.onBattery && Power.present ? `PWR ${Math.round(Power.charge)}%` : "PWR AC"
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}

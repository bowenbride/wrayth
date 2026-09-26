import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// CALENDAR: the month, from the bar clock. Weeks start on Monday; today is in
// the accent; the arrows, the scroll wheel and TODAY move the month. No
// events and no accounts -- nothing here reads or sends anything.
DropdownFrame {
    id: root

    title: "CALENDAR"
    katakana: "暦"
    // Read by Dropdowns: this dropdown is 340 px wide.
    readonly property int panelWidth: 340

    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    readonly property var dayNames: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

    // Today, from the clock (minute precision: it ticks once a minute while
    // this is open, and not at all while it is closed -- it is destroyed).
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property date today: clock.date

    // The month shown: its year and month (0-11).
    property int year: today.getFullYear()
    property int month: today.getMonth()
    Component.onCompleted: {
        year = today.getFullYear();
        month = today.getMonth();
    }

    function shift(by: int): void {
        let m = month + by;
        let y = year;
        while (m < 0) {
            m += 12;
            y--;
        }
        while (m > 11) {
            m -= 12;
            y++;
        }
        year = y;
        month = m;
    }
    function goToday(): void {
        year = today.getFullYear();
        month = today.getMonth();
    }

    // The 42 days on the grid: from the Monday on or before the 1st.
    readonly property var days: {
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(year, month, 1 - lead + i));
        return out;
    }

    // ISO 8601 week number.
    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }
    function pad2(n: int): string {
        return n < 10 ? `0${n}` : `${n}`;
    }

    // A 22 x 22 month button: hairline, a drawn chevron.
    component MonthButton: Rectangle {
        id: btn

        property string direction: "right"
        signal activated

        width: 22
        height: 22
        color: tap.pressed ? Theme.alpha(Theme.accent, 0.35) : (hover.hovered ? Theme.cell : "transparent")
        border.width: Appearance.metrics.hairline
        border.color: hover.hovered ? Theme.dim : Theme.hair

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        ChevronGlyph {
            anchors.centerIn: parent
            direction: btn.direction
            color: hover.hovered ? Theme.bright : Theme.text
        }
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: tap
            onTapped: btn.activated()
        }
    }

    headerRight: Row {
        spacing: 6

        MonthButton {
            direction: "left"
            onActivated: root.shift(-1)
        }
        // The month and year in a fixed 132 px slot, so the arrows never move.
        Text {
            width: 132
            height: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: `${root.monthNames[root.month]} ${root.year}`
            color: Theme.bright
            font.family: Appearance.font.data
            font.pixelSize: 11
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: 11 * 0.1
            renderType: Text.NativeRendering
        }
        MonthButton {
            direction: "right"
            onActivated: root.shift(1)
        }
    }

    Column {
        width: parent.width
        spacing: 6

        // The scroll wheel changes month, anywhere over the grid.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real acc: 0
            onWheel: event => {
                acc += event.angleDelta.y;
                if (Math.abs(acc) >= 120) {
                    root.shift(acc > 0 ? -1 : 1);
                    acc = 0;
                }
            }
        }

        Grid {
            id: grid

            columns: 7
            readonly property real cell: 30
            anchors.horizontalCenter: parent.horizontalCenter
            columnSpacing: Math.floor((parent.width - 7 * cell) / 6)
            rowSpacing: 2

            // MO to SU, 9 px dim.
            Repeater {
                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                Text {
                    required property string modelData
                    width: grid.cell
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
            }

            Repeater {
                model: root.days

                Rectangle {
                    id: cellItem

                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === root.month
                    readonly property bool isToday: modelData.getFullYear() === root.today.getFullYear() && modelData.getMonth() === root.today.getMonth() && modelData.getDate() === root.today.getDate()

                    width: grid.cell
                    height: grid.cell
                    color: isToday ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                    border.width: isToday ? 1 : 0
                    border.color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: `${cellItem.modelData.getDate()}`
                        color: cellItem.isToday ? Theme.accent : (cellItem.inMonth ? Theme.text : Theme.mute)
                        font.family: Appearance.font.data
                        font.pixelSize: 11
                        font.weight: cellItem.isToday ? Appearance.font.weightSemi : Appearance.font.weightRegular
                        font.features: Appearance.tabularFigures
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // FRIDAY 09.25.26 · WEEK 39, and TODAY.
        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.dayNames[root.today.getDay()]} ${root.pad2(root.today.getMonth() + 1)}.${root.pad2(root.today.getDate())}.${root.pad2(root.today.getFullYear() % 100)} · WEEK ${root.isoWeek(root.today)}`
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "TODAY"
                font.underline: true
                color: todayHover.hovered ? Theme.text : Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering

                HoverHandler {
                    id: todayHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.goToday()
                }
            }
        }
    }
}

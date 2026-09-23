import QtQuick
import qs.components
import qs.config
import qs.services

// The SYS.DIAG panel at card size: 95 x 104, with the real CPU and memory
// figures in a palette that is not the shell's. The numbers are live because
// they cost nothing -- one binding each, shared across every card -- and a
// panel showing a plausible-looking fiction is the one thing a preview must
// not do.
ChamferPanel {
    id: root

    required property var palette

    // **Authored at the size it is drawn.** It used to be 70 x 77 inside a
    // wrapper scaled up by 1.35, which rasterised 6 and 7 px type and then
    // magnified it. Every figure here is that old one times 1.35, rounded to
    // a whole pixel -- and the panel fits the 135 px thumbnail with 1 px to
    // spare under it, which is what the old compaction to 77 was for.
    implicitWidth: 95
    implicitHeight: 104

    chamfer: 8
    fillColor: palette.panel2
    borderColor: palette.hair

    Column {
        anchors.fill: parent
        anchors.margins: 7
        spacing: 4

        Text {
            text: "SYS.DIAG"
            color: root.palette.bright
            font.family: Appearance.font.display
            font.pixelSize: 9
            font.weight: Appearance.font.weightBold
            renderType: Text.NativeRendering
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.palette.hair
        }

        // CPU: one bar per thread group, rising from the bottom, and accent
        // above 70% -- the HUD's own rule, which is why the panel is worth
        // showing at all.
        Row {
            spacing: 3

            Repeater {
                model: 8

                Item {
                    required property int index

                    // A fixed spread around the live figure, so the bars read
                    // as a load profile rather than eight copies of one
                    // number. The average is the real one.
                    readonly property real value: Math.max(0.04, Math.min(1, SysInfo.cpuPercent / 100 + [0.22, -0.1, 0.05, -0.18, 0.3, -0.05, 0.12, -0.24][index]))

                    width: 7
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        color: root.palette.track
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.round(parent.height * parent.value)
                        color: parent.value > 0.7 ? root.palette.accent : root.palette.signal
                    }
                }
            }
        }

        // **MEM's label and its bar share a line.** Stacked they cost 11 px of
        // a panel that had 26 to give back; side by side they say the same
        // thing, and the real HUD puts its labels beside its readouts too.
        Row {
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MEM"
                color: root.palette.dim
                font.family: Appearance.font.data
                font.pixelSize: 8
                font.weight: Appearance.font.weightSemi
                renderType: Text.NativeRendering
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Repeater {
                    model: 10

                    Rectangle {
                        required property int index

                        width: 4
                        height: 7
                        color: SysInfo.memPercent / 100 * 10 > index ? root.palette.signal : root.palette.track
                    }
                }
            }
        }

        Column {
            spacing: 4

            Row {
                spacing: 5

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    color: SystemStatus.breach ? root.palette.accent : root.palette.signal
                }

                Text {
                    text: SystemStatus.breach ? "ICE BREACH" : "ICE NOMINAL"
                    color: root.palette.text
                    font.family: Appearance.font.data
                    font.pixelSize: 8
                    renderType: Text.NativeRendering
                }
            }

            Row {
                spacing: 5

                Text {
                    text: "VULN"
                    color: root.palette.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 8
                    renderType: Text.NativeRendering
                }

                Text {
                    text: `${Vuln.count}`
                    color: Vuln.count > 0 ? root.palette.accent : root.palette.signal
                    font.family: Appearance.font.data
                    font.pixelSize: 8
                    font.weight: Appearance.font.weightSemi
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}

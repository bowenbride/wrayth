import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The daemon library: everything the HUD could show, grouped by category, with
// a tickbox each. Five at a time; at five the rest dim rather than vanishing,
// because a list that reorders itself under the pointer cannot be read.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        // One screen only: see `ShellState.overlayScreen`.
        readonly property bool shown: Daemons.libraryOpen && ShellState.overlayScreen === modelData.name

        screen: modelData
        color: "transparent"
        // Faded by the compositor, see the layer rule in hypr-wrayth.lua.
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-overlay"
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.55
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Daemons.libraryOpen = false
        }

        // **Above the panel's own top-left corner**, 34 px clear of it, the
        // same place every other full-screen view puts it.
        BackButton {
            x: panel.x
            y: panel.y - 34

            onActivated: Daemons.libraryOpen = false
        }

        ChamferPanel {
            id: panel

            anchors.centerIn: parent

            width: 720
            height: Math.min(parent.height - 120, body.implicitHeight + 92)
            chamfer: Appearance.chamfer.panel
            fillColor: Theme.panel2

            CornerBrackets {
                inset: 6
            }

            // --- Header ----------------------------------------------------
            Row {
                id: head

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 20
                anchors.leftMargin: 22
                spacing: 12

                GlitchFx {
                    group: "overlay"
                    anchors.verticalCenter: parent.verticalCenter
                    fills: true
                    textual: true
                    width: libraryTitle.implicitWidth
                    height: libraryTitle.implicitHeight
                    scrambleItems: [libraryTitle]

                    GlitchText {
                        id: libraryTitle

                        anchors.fill: parent
                        text: `DAEMONS${Appearance.separator}LIBRARY`
                        pixelSize: 20
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "常駐"
                    color: Theme.signal
                    font.family: Appearance.font.accent
                    font.pixelSize: Appearance.size.katakana
                    font.weight: Appearance.font.weightMedium
                    renderType: Text.NativeRendering
                }
            }

            NrLabel {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: head.verticalCenter
                color: Daemons.atCap() ? Theme.accent : Theme.dim
                text: `${Daemons.selected.length}/${Daemons.maxSelected} LOADED`
            }

            // --- The catalogue ---------------------------------------------
            Flickable {
                anchors.top: head.bottom
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 10

                clip: true
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body

                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: Daemons.categories

                        Column {
                            id: group

                            required property string modelData
                            // Named rather than reached for through `parent`:
                            // the inner Repeater's `parent.parent` is the outer
                            // Column, which has no modelData, and the filter
                            // silently matched nothing.
                            readonly property string category: modelData

                            width: body.width
                            spacing: 4

                            NrLabel {
                                color: Theme.mute
                                text: group.category
                            }

                            Rectangle {
                                width: group.width
                                height: Appearance.metrics.hairline
                                color: Theme.hair
                            }

                            Repeater {
                                model: Daemons.catalogue.filter(d => d.category === group.category)

                                DaemonLibraryRow {
                                    required property var modelData

                                    width: group.width
                                    entry: modelData
                                }
                            }
                        }
                    }
                }
            }

            // --- Footer ----------------------------------------------------
            Item {
                id: footer

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Appearance.metrics.hairline
                    color: Theme.hair
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.mute
                        text: "CHANGES APPLY AT ONCE"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ESC"
                        color: Theme.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.mute
                        text: "CLOSE"
                    }
                }
            }
        }

        OverlayKeys {
            anchors.fill: parent
            active: shown

            onEscaped: Daemons.libraryOpen = false
        }
    }
}

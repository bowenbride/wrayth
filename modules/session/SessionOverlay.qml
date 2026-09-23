import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.utils

// SESSION CONTROL: full screen over the profile wallpaper, blurred and darkened.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData

        readonly property bool shown: ShellState.powerOpen

        screen: modelData
        color: "transparent"
        // Faded by the compositor, see the layer rule in hypr-wrayth.lua.
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-overlay"
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onShownChanged: if (shown) keys.take()

        // No opacity binding here any more: the compositor fades the surface.
        // That also removes the need for a layer on this item -- it only existed
        // because an opacity binding on a plain parent composites the
        // Wallpaper's own blur to nothing.
        Item {
            anchors.fill: parent

            Wallpaper {
                anchors.fill: parent
                blurRadius: 16
                dim: 0.58
            }

            // The spec's extra rgba(0,0,0,0.35) over the darkened wallpaper.
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.35
            }

            // A pointer way out. Every full-screen overlay that holds the
            // keyboard needs one: if the keys ever stop answering, a click on
            // bare backdrop is what anybody tries next, and it should work.
            //
            // Bounded, not blanket: the tiles are `TapHandler`s, which take a
            // passive grab and let the press carry on down, so an unbounded
            // dismiss layer would run a power action *and* close the menu.
            MouseArea {
                anchors.fill: parent

                onPressed: mouse => {
                    const inside = content.mapFromItem(null, mouse.x, mouse.y);
                    mouse.accepted = inside.x < 0 || inside.y < 0 || inside.x > content.width || inside.y > content.height;
                }
                // A click off the tiles disarms an armed one rather than
                // closing, and only closes the menu when nothing is armed.
                onClicked: Session.armed !== "" ? Session.disarm() : Session.close()
            }

            Column {
                id: content

                anchors.centerIn: parent
                spacing: 26

                // --- Header ------------------------------------------------
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        GlitchFx {
                            group: "overlay"
                            anchors.verticalCenter: parent.verticalCenter
                            fills: true
                            textual: true
                            width: sessionTitle.implicitWidth
                            height: sessionTitle.implicitHeight
                            scrambleItems: [sessionTitle]

                            GlitchText {
                                id: sessionTitle

                                anchors.fill: parent
                                text: "SESSION CONTROL"
                                pixelSize: 26
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "電源管理"
                            color: Theme.signal
                            font.family: Appearance.font.accent
                            font.pixelSize: Appearance.size.katakana
                            font.weight: Appearance.font.weightMedium
                            renderType: Text.NativeRendering
                        }
                    }

                    // Host and uptime, divided by space and colour: the host in
                    // the text colour, the UPTIME label dim and its value text.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            text: Demo.host(Machine.hostname)
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            NrLabel { text: "UPTIME" }
                            NrLabel { color: Theme.text; text: Fmt.uptime(SysInfo.uptimeSeconds) }
                        }
                    }
                }

                // --- Tiles -------------------------------------------------
                Row {
                    id: tiles

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Repeater {
                        model: Session.tiles

                        SessionTile {
                            // Both are declared: asking for modelData puts the
                            // delegate in required-properties mode, where the
                            // context `index` is no longer visible.
                            required property var modelData
                            required property int index

                            tile: modelData
                            selected: index === Session.selected

                            onActivated: {
                                Session.selected = index;
                                Session.activate();
                            }
                        }
                    }
                }

                // --- Status ------------------------------------------------
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Text {
                        renderType: Text.NativeRendering
                        anchors.horizontalCenter: parent.horizontalCenter

                        text: Session.status
                        color: Session.armed ? Theme.accent : Theme.dim
                        font.family: Appearance.font.data
                        font.pixelSize: Appearance.size.label
                        font.weight: Appearance.font.weightSemi
                        font.letterSpacing: Appearance.tracking(Appearance.size.label)
                        font.capitalization: Font.AllUppercase
                    }

                    Rectangle {
                        width: tiles.width
                        height: 2
                        color: Session.armed ? Theme.accent : Theme.hair

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.duration.state
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Keys in keycaps. Clicking a tile works and is not
                    // advertised -- it is the obvious thing to try, and the
                    // line is better short.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Keycap {
                            anchors.verticalCenter: parent.verticalCenter
                            key: "←→"
                            color: Theme.mute
                        }

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.mute
                            text: "SELECT"
                        }

                        Keycap {
                            anchors.verticalCenter: parent.verticalCenter
                            key: "ENTER"
                            color: Theme.mute
                        }

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.mute
                            text: "EXEC"
                        }

                        Keycap {
                            anchors.verticalCenter: parent.verticalCenter
                            key: "ESC"
                            color: Theme.mute
                        }

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.mute
                            text: "ABORT"
                        }
                    }
                }
            }
        }

        // Arrows move, Enter runs, Escape leaves, and each tile's letter picks
        // it outright -- which is what the key badges are advertising.
        OverlayKeys {
            id: keys

            anchors.fill: parent
            active: overlay.shown

            // Escape stands an armed tile down first; a second Escape closes.
            onEscaped: Session.armed !== "" ? Session.disarm() : Session.close()

            Keys.onLeftPressed: Session.move(-1)
            Keys.onRightPressed: Session.move(1)
            Keys.onReturnPressed: Session.activate()
            Keys.onEnterPressed: Session.activate()
            Keys.onPressed: event => {
                if (event.text.length === 1 && /[a-zA-Z]/.test(event.text)) {
                    Session.selectKey(event.text);
                    event.accepted = true;
                }
            }
        }
    }
}

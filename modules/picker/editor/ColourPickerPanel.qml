import QtQuick
import qs.components
import qs.config

// The colour picker, in the shell's own styling rather than the platform's: a
// saturation/brightness square, a hue bar, a hex field, chips of the palette's
// other colours, and what the contrast will be.
//
// **The contrast is measured against the colour it will actually be read
// against** -- TEXT for the three background tokens, GROUND for the rest --
// and it reports rather than refuses. A palette that fails 4.5:1 somewhere is
// the user's to make; one that fails without saying so is not.
ChamferPanel {
    id: root

    required property string tokenKey
    required property string value
    // The other eight, offered as chips so a palette can be built from itself.
    required property var palette
    required property bool background

    signal changed(string hex)

    readonly property real hue: hsv[0]
    readonly property real saturation: hsv[1]
    readonly property real brightness: hsv[2]

    readonly property var hsv: {
        const c = Qt.color(root.value);
        return [c.hsvHue < 0 ? 0 : c.hsvHue, c.hsvSaturation, c.hsvValue];
    }

    readonly property color against: (root.background ? root.palette.text : root.palette.ground) ?? Tokens.color.ground
    readonly property real ratio: Profiles.contrast(root.value, String(root.against))
    readonly property bool weak: ratio < 4.5

    function emit(h: real, s: real, v: real): void {
        const c = Qt.hsva(Math.max(0, Math.min(1, h)), Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, v)), 1);
        root.changed(Profiles.hexOf([Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)]));
    }

    chamfer: 12
    chamferTopRight: 12
    chamferBottomLeft: 12
    fillColor: Tokens.color.panel2
    borderColor: Tokens.color.accent

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Item {
            width: parent.width
            height: 14

            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.accent
                text: root.tokenKey
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 14
                color: root.value
                border.width: Tokens.measure.hairline
                border.color: Tokens.color.hair
            }
        }

        // --- Saturation and brightness ------------------------------------
        Item {
            id: square

            width: parent.width
            height: 150

            Rectangle {
                anchors.fill: parent
                color: Qt.hsva(root.hue, 1, 1, 1)

                // White on the left, the hue on the right.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: "#ffffff"
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }

                // Black at the bottom.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: "#000000"
                        }
                    }
                }

                border.width: Tokens.measure.hairline
                border.color: Tokens.color.hair
            }

            // The marker is two square rings, light over dark, so it stays
            // visible on both ends of the square (no rounded corners anywhere).
            Item {
                x: root.saturation * square.width - 5
                y: (1 - root.brightness) * square.height - 5
                width: 10
                height: 10

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: "#ffffff"
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.width: 1
                    border.color: "#000000"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor

                function pick(x: real, y: real): void {
                    root.emit(root.hue, x / width, 1 - y / height);
                }

                onPressed: mouse => pick(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    if (pressed)
                        pick(mouse.x, mouse.y);
                }
            }
        }

        // --- Hue -----------------------------------------------------------
        Item {
            id: hueBar

            width: parent.width
            height: 16

            Rectangle {
                anchors.fill: parent
                border.width: Tokens.measure.hairline
                border.color: Tokens.color.hair

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "#ff0000"
                    }
                    GradientStop {
                        position: 0.167
                        color: "#ffff00"
                    }
                    GradientStop {
                        position: 0.333
                        color: "#00ff00"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#00ffff"
                    }
                    GradientStop {
                        position: 0.667
                        color: "#0000ff"
                    }
                    GradientStop {
                        position: 0.833
                        color: "#ff00ff"
                    }
                    GradientStop {
                        position: 1
                        color: "#ff0000"
                    }
                }
            }

            Rectangle {
                x: root.hue * hueBar.width - 1
                width: 3
                height: parent.height
                color: "#ffffff"
                border.width: 1
                border.color: "#000000"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                function pick(x: real): void {
                    // A grey has no hue to keep, so moving the bar on one has
                    // to give it saturation or nothing happens at all.
                    root.emit(x / width, Math.max(root.saturation, 0.05), Math.max(root.brightness, 0.05));
                }

                onPressed: mouse => pick(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        pick(mouse.x);
                }
            }
        }

        // --- Hex -------------------------------------------------------------
        Row {
            width: parent.width
            spacing: 8

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.dim
                text: "HEX"
            }

            InputField {
                id: hexField

                anchors.verticalCenter: parent.verticalCenter
                width: 104
                text: root.value.toUpperCase()
                maximumLength: 7

                onEdited: value => {
                    // Only a complete code is accepted, so the square does not
                    // jump about while the third character is being typed.
                    const t = value.replace("#", "");
                    if (/^[0-9a-fA-F]{6}$/.test(t))
                        root.changed(`#${t.toLowerCase()}`);
                }
                onEscaped: text = root.value.toUpperCase()
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                pixelSize: 10
                color: root.weak ? Tokens.color.alert : Tokens.color.signal
                text: `${root.ratio.toFixed(1)}:1 ON ${root.background ? "TEXT" : "GROUND"}`
            }
        }

        // --- Chips ------------------------------------------------------------
        NrLabel {
            color: Tokens.color.dim
            text: "FROM THIS PALETTE"
        }

        Row {
            spacing: 5

            Repeater {
                model: Customs.roles

                Rectangle {
                    required property var modelData

                    visible: modelData.key !== root.tokenKey
                    width: 20
                    height: 16
                    color: root.palette[modelData.key] ?? Tokens.color.hair
                    border.width: Tokens.measure.hairline
                    border.color: Tokens.color.hair

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        // The stored hex, not the Rectangle's colour: a `color`
                        // stringifies with its alpha in front on some values,
                        // and the palette already holds exactly what to write.
                        onTapped: root.changed(root.palette[parent.modelData.key])
                    }
                }
            }
        }
    }

    // The field follows the square and the chips, but only when the change
    // came from somewhere else -- rebinding it on every keystroke would fight
    // whatever is being typed into it.
    onValueChanged: if (!hexField.activeFocus) hexField.text = root.value.toUpperCase()
}

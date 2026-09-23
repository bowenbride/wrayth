import QtQuick
import qs.components
import qs.config
import qs.services

// The picker's right-hand column: what the wallpaper is, whether it belongs to
// the profile, where the library lives, and the way through to the pools.
ChamferPanel {
    id: root

    signal poolsRequested

    readonly property string currentName: {
        const path = Wallpapers.displayedPath;
        return path ? path.slice(path.lastIndexOf("/") + 1) : "NONE";
    }

    implicitWidth: 390
    // The grid's height exactly, so the two blocks share a top and a bottom
    // edge and the picker reads as two columns rather than two panels.
    implicitHeight: 444

    chamfer: Appearance.chamfer.panel
    fillColor: Theme.panel2
    borderColor: Theme.hair

    Column {
        id: column

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        // 10, not 12. The column, the folder note and the pools button share
        // 412 px of panel and the note was getting 2 px of clear air under it;
        // two pixels off each of the five gaps is what buys the note its own.
        spacing: 10

        // --- Header ---------------------------------------------------------
        Item {
            width: parent.width
            height: 18

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WALLPAPER"
                    color: Theme.bright
                    font.family: Appearance.font.display
                    font.pixelSize: 14
                    font.weight: Appearance.font.weightBold
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "壁紙"
                    color: Theme.signal
                    font.family: Appearance.font.accent
                    font.pixelSize: Appearance.size.katakana
                    font.weight: Appearance.font.weightMedium
                    renderType: Text.NativeRendering
                }
            }

            NrLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                pixelSize: 10
                color: Wallpapers.dynamic ? Theme.signal : Theme.dim
                text: Wallpapers.dynamic ? `DYNAMIC${Appearance.separator}FOLLOWS PROFILE` : `STATIC${Appearance.separator}LOCKED`
            }
        }

        // --- Preview --------------------------------------------------------
        Item {
            width: parent.width
            height: 170

            Rectangle {
                anchors.fill: parent
                color: Theme.deep
                border.width: Appearance.metrics.hairline
                border.color: Theme.hair
            }

            // **`Wallpaper`, not a bare `Image`.** This box shows the same
            // thing the desktop does, and a raw Image blanks while the new
            // file decodes and then cuts to it -- measured as a 100 ms drop to
            // black in a burst, which is exactly the blink the design forbids.
            Wallpaper {
                anchors.fill: parent
                anchors.margins: 1
            }

            // The filename sits on the image rather than under it: it is what
            // the image *is*, and a caption in its own row would push the
            // folder field off the bottom of the column.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 1
                height: 20
                color: Qt.rgba(0, 0, 0, 0.62)

                NrLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    pixelSize: 10
                    color: Theme.bright
                    elide: Text.ElideMiddle
                    text: root.currentName
                }
            }
        }

        // --- Dynamic --------------------------------------------------------
        Item {
            width: parent.width
            height: 22

            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                text: "DYNAMIC"
            }

            ToggleButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                on: Wallpapers.dynamic
                onToggled: Wallpapers.setDynamic(!Wallpapers.dynamic)
            }
        }

        Text {
            width: parent.width
            text: Wallpapers.dynamic ? "Applying a profile switches to its wallpaper. Previewing one shows it." : "The wallpaper stays as it is through every profile change."
            color: Theme.text
            font.family: Appearance.font.data
            font.pixelSize: 10
            wrapMode: Text.Wrap
            renderType: Text.NativeRendering
        }

        // --- Folder ---------------------------------------------------------
        NrLabel {
            color: Theme.text
            text: "FOLDER"
        }

        Row {
            width: parent.width
            spacing: 8

            InputField {
                id: folderField

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - openButton.width - 8
                // Shown with `~`; a typed `~` is expanded back on commit, so
                // the stored path stays absolute.
                text: Paths.display(Wallpapers.folder)
                placeholder: "PATH TO YOUR WALLPAPERS"

                onAccepted: Wallpapers.setFolder(Paths.expand(text))
                onEscaped: text = Paths.display(Wallpapers.folder)
            }

            ActionButton {
                id: openButton

                anchors.verticalCenter: parent.verticalCenter
                text: "OPEN FOLDER"
                usable: folderField.text.length > 0

                onClicked: {
                    // Typing a path and pressing this rather than Enter is the
                    // obvious thing to do, so the field is committed first.
                    if (Paths.expand(folderField.text) !== Wallpapers.folder)
                        Wallpapers.setFolder(Paths.expand(folderField.text));
                    Wallpapers.openFolder();
                }
            }
        }

    }

    // --- The folder note ------------------------------------------------------
    // **Out of the column, with its own air.** In the column it took the
    // column's 12 px above and whatever happened to be left below, which put
    // it hard under the `FOLDER` row at one end and near enough against
    // `MANAGE WALLPAPER POOLS` at the other -- a sentence wedged between two
    // controls. It now has the same 16 px above and below as the panel's own
    // margin, and the space the column does not use falls between it and the
    // button rather than around it.
    // **Centred in the space the column leaves**, so the air above and the air
    // below come out equal by construction rather than by arithmetic on
    // estimated text heights -- which is what got it wrong the first time.
    // Measured: 14 px of clear air above and below the ink at 1920x1080.
    //
    // It is centred in a slot rather than by a `y` binding. A `y` computed
    // from the item's own `implicitHeight` is a loop as far as Qt is
    // concerned -- a `Text` re-measures itself during positioning -- and it
    // said so. An anchor does not ask the question.
    Item {
        id: noteSlot

        anchors.top: column.bottom
        anchors.bottom: poolsButton.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
    }

    Text {
        id: folderNote

        anchors.verticalCenter: noteSlot.verticalCenter
        anchors.left: noteSlot.left
        anchors.right: noteSlot.right

        text: "The wrayth subfolder inside it holds the generated net-*.png wallpapers."
        color: Theme.dim
        font.family: Appearance.font.data
        font.pixelSize: 10
        wrapMode: Text.Wrap
        renderType: Text.NativeRendering
    }

    // --- Pools ---------------------------------------------------------------
    // Bottom-anchored rather than last in the column: it is the way out of this
    // panel, and it belongs on the panel's own edge whatever the column above
    // it does.
    Item {
        id: poolsButton

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        height: 30

        ChamferPanel {
            anchors.fill: parent

            chamfer: 8
            chamferTopRight: 0
            chamferBottomLeft: 8
            // **Opaque, not a tint.** This sits directly under a wallpaper
            // preview, and a translucent accent fill let the image through the
            // label. The tint is blended into `ground` instead of laid over
            // it, which also keeps it inside the cut corner -- a square
            // rectangle on top would have overhung the chamfer.
            fillColor: Theme.blend(Theme.ground, Theme.accent, poolsHover.hovered ? 0.24 : 0.14)
            borderColor: Theme.accent

            Behavior on fillColor {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }

        NrLabel {
            anchors.centerIn: parent
            centred: true
            color: Theme.accent
            text: "MANAGE WALLPAPER POOLS"
        }

        HoverHandler {
            id: poolsHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.poolsRequested()
        }
    }
}

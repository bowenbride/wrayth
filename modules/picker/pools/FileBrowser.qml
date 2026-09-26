import QtQuick
import Qt.labs.folderlistmodel
import qs.components
import qs.config

// Choosing files to add to the library, inside the overlay.
//
// **It is not a `QtQuick.Dialogs.FileDialog`, and it cannot be.** A layer
// surface on the Overlay layer draws above every ordinary window, so the
// portal's file chooser opened *behind* the picker -- invisible, while taking
// the input. That is the trap by another route: the pointer and the keyboard
// both went to a window nobody could see. A chooser reached from an overlay
// has to live inside that overlay.
Item {
    id: root

    property string dir: ""
    // Absolute paths, in the order they were ticked.
    property var selected: []

    signal chosen(var paths)
    signal cancelled

    function open(at: string): void {
        dir = at;
        selected = [];
        root.visible = true;
    }

    function toggle(path: string): void {
        selected = selected.indexOf(path) >= 0 ? selected.filter(p => p !== path) : selected.concat([path]);
    }

    function parentOf(path: string): string {
        const at = path.lastIndexOf("/");
        return at > 0 ? path.slice(0, at) : "/";
    }

    // Everything above is inert while this is hidden, so the model does not
    // sit on a directory nobody is looking at.
    onVisibleChanged: if (!visible) selected = []

    // Nothing behind the panel is clickable while it is up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    ChamferPanel {
        id: panel

        anchors.centerIn: parent
        width: 760
        height: 540

        chamfer: Appearance.chamfer.panel
        fillColor: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.98)
        borderColor: Theme.accent

        // --- Header -----------------------------------------------------
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            height: 26

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    id: taggedTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: `ADD FILES${Appearance.separator}LIBRARY`
                    color: Theme.bright
                    font.family: Appearance.font.display
                    font.pixelSize: 18
                    font.weight: Appearance.font.weightBold
                    renderType: Text.NativeRendering
                }

                KanaTag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "画像"
                    title: taggedTitle
                }
            }

            NrLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                text: `${root.selected.length} SELECTED`
            }
        }

        // --- Where -------------------------------------------------------
        Row {
            id: path

            anchors.top: header.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 10

            ActionButton {
                id: upButton

                anchors.verticalCenter: parent.verticalCenter
                text: "UP"
                usable: root.dir !== "/"
                onClicked: root.dir = root.parentOf(root.dir)
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - upButton.width - 10
                color: Theme.text
                tracked: false
                elide: Text.ElideLeft
                text: Paths.display(root.dir)
            }
        }

        // --- What --------------------------------------------------------
        Flickable {
            id: view

            anchors.top: path.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.leftMargin: 20
            anchors.rightMargin: 30
            anchors.bottomMargin: 12
            clip: true
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rows

                width: parent.width
                spacing: 2

                Repeater {
                    model: FolderListModel {
                        id: listing

                        folder: root.dir ? Paths.url(root.dir) : ""
                        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
                        showDirs: true
                        showDirsFirst: true
                        showDotAndDotDot: false
                        showHidden: false
                        sortField: FolderListModel.Name
                    }

                    Item {
                        required property string fileName
                        required property bool fileIsDir
                        required property string filePath

                        readonly property bool picked: !fileIsDir && root.selected.indexOf(filePath) >= 0

                        width: rows.width
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            color: parent.picked ? Theme.alpha(Theme.accent, 0.16) : rowHover.hovered ? Theme.alpha(Theme.hair, 0.4) : "transparent"
                            border.width: Appearance.metrics.hairline
                            border.color: parent.picked ? Theme.accent : "transparent"
                        }

                        // A folder is named by its trailing slash rather than
                        // an icon; the shell has no icon set and a glyph at
                        // this size would be a smudge.
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter

                            text: parent.fileIsDir ? `${parent.fileName}/` : parent.fileName
                            color: parent.fileIsDir ? Theme.signal : parent.picked ? Theme.accent : Theme.text
                            font.family: Appearance.font.data
                            font.pixelSize: Appearance.size.label
                            font.weight: parent.fileIsDir ? Appearance.font.weightSemi : Appearance.font.weightRegular
                            renderType: Text.NativeRendering
                        }

                        NrLabel {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.picked
                            color: Theme.accent
                            text: "✓ ADDING"
                        }

                        HoverHandler {
                            id: rowHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                if (parent.fileIsDir)
                                    root.dir = parent.filePath;
                                else
                                    root.toggle(parent.filePath);
                            }
                        }
                    }
                }

                NrLabel {
                    visible: listing.count === 0 && listing.status === FolderListModel.Ready
                    height: 40
                    color: Theme.dim
                    text: "NO IMAGES OR FOLDERS HERE"
                }
            }
        }

        ShellScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: view.top
            anchors.bottom: view.bottom
            view: view
        }

        // --- Footer --------------------------------------------------------
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            height: 26

            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                text: "CLICK A FOLDER TO OPEN IT    CLICK AN IMAGE TO TICK IT"
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                ActionButton {
                    text: "CANCEL"
                    onClicked: root.cancelled()
                }

                ActionButton {
                    text: root.selected.length > 1 ? `ADD ${root.selected.length} FILES` : "ADD FILE"
                    accented: root.selected.length > 0
                    usable: root.selected.length > 0
                    onClicked: root.chosen(root.selected)
                }
            }
        }
    }
}

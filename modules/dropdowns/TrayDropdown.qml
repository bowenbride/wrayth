import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.config
import qs.services

// TRAY: every app in the system tray, by name, its icon tinted to the dim
// colour so third-party artwork never breaks the palette. Clicking one slides
// to its menu -- the app's own D-Bus menu, redrawn in the shell's style -- with
// the app's primary action ("OPEN", usually its window) first, and BACK.
// Submenus slide in the same way, one level at a time.
DropdownFrame {
    id: root

    title: "TRAY"
    katakana: "常駐"
    // Read by Dropdowns: this dropdown is 360 px wide.
    readonly property int panelWidth: 360

    // The app whose menu is up, and the path down its submenus: a list of
    // { handle, title }. Empty: the app list.
    property var app: null
    property var path: []
    readonly property bool inMenu: app !== null

    readonly property bool canGoBack: inMenu
    function goBack(): void {
        if (path.length > 1)
            path = path.slice(0, -1);
        else {
            app = null;
            path = [];
        }
    }

    function openApp(item: var): void {
        root.app = item;
        root.path = [{ handle: item.menu, title: Tray.nameOf(item).toUpperCase() }];
    }

    // An app gone from the tray while its menu is up: back to the list.
    Connections {
        target: Tray
        function onItemsChanged(): void {
            if (root.app && Tray.items.indexOf(root.app) < 0) {
                root.app = null;
                root.path = [];
            }
        }
    }

    readonly property int buttonCut: 8
    readonly property real surfaceHeight: implicitHeight - views.height + Math.max(listColumn.implicitHeight, menuColumn.implicitHeight, 120)

    headerRight: NrLabel {
        color: Theme.dim
        text: Tray.items.length === 1 ? "1 APP" : `${Tray.items.length} APPS`
    }

    // An app's icon as a silhouette in the dim colour: a dim square masked by
    // the icon's own alpha, so none of its colours ever show.
    component TintedIcon: Item {
        property string source: ""

        width: 16
        height: 16

        Image {
            id: img

            anchors.fill: parent
            source: parent.source
            sourceSize.width: 32
            sourceSize.height: 32
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
            opacity: 0
        }
        Rectangle {
            id: fill

            anchors.fill: parent
            color: Theme.dim
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: fill
            visible: img.status === Image.Ready
            maskEnabled: true
            maskSource: img
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
        }
        // No icon, or one that will not load: a quiet square in its place, so
        // the name never shifts.
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            color: "transparent"
            border.width: Appearance.metrics.hairline
            border.color: Theme.mute
            visible: img.status !== Image.Ready
        }
    }

    component EntryRow: Item {
        id: entry

        property string text: ""
        property bool usable: true
        property bool chevron: false
        property bool check: false
        property bool checked: false
        property bool accented: false
        property alias icon: iconSlot.source
        property bool showIcon: false
        property string status: ""
        property int pixelSize: 11
        signal activated

        width: parent.width
        height: 32

        Rectangle {
            anchors.fill: parent
            color: hover.hovered && entry.usable ? Theme.cell : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }
        Feedback {
            id: feedback
            anchors.fill: parent
        }

        TintedIcon {
            id: iconSlot

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.showIcon
        }

        Tickbox {
            id: tick

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.check
            checked: entry.checked
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: entry.showIcon || entry.check ? 30 : 8
            anchors.right: arrow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: entry.text
            textFormat: Text.PlainText
            color: !entry.usable ? Theme.dim : (entry.accented ? Theme.accent : Theme.text)
            font.family: Appearance.font.data
            font.pixelSize: entry.pixelSize
            font.weight: entry.accented ? Appearance.font.weightSemi : Appearance.font.weightRegular
            renderType: Text.NativeRendering
        }

        // The app's short status, 9 px dim, when it gives one; else the
        // chevron of an entry that opens further.
        Text {
            id: arrow

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 120)
            elide: Text.ElideRight
            text: entry.status !== "" ? entry.status : ">"
            textFormat: Text.PlainText
            opacity: entry.status !== "" || entry.chevron ? 1 : 0
            color: Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: entry.status !== "" ? 9 : 11
            font.letterSpacing: 9 * 0.1
            renderType: Text.NativeRendering
        }

        HoverHandler {
            id: hover
            cursorShape: entry.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            enabled: entry.usable
            onPressedChanged: if (pressed) feedback.flash()
            onTapped: defer.restart()
        }
        // The acknowledgement paints first; the action runs a frame later.
        Timer {
            id: defer
            interval: 16
            onTriggered: entry.activated()
        }
    }

    Item {
        id: views

        width: parent.width
        height: root.inMenu ? menuColumn.implicitHeight : listColumn.implicitHeight
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Appearance.duration.panel
                easing.type: Easing.OutCubic
            }
        }

        // --- The apps ----------------------------------------------------------
        Column {
            id: listColumn

            width: parent.width
            spacing: 0
            opacity: root.inMenu ? 0 : 1
            visible: opacity > 0

            property real slide: root.inMenu ? -width : 0
            transform: Translate {
                x: listColumn.slide
            }
            Behavior on slide {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }

            NrLabel {
                visible: Tray.items.length === 0
                color: Theme.dim
                text: "NO APPS IN THE TRAY"
                height: 26
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: Tray.items

                // 36 px rows separated by hairlines.
                EntryRow {
                    required property var modelData
                    required property int index

                    height: 36
                    pixelSize: 12
                    showIcon: true
                    icon: modelData.icon ?? ""
                    text: Tray.nameOf(modelData)
                    status: Tray.statusOf(modelData)

                    Rectangle {
                        visible: parent.index > 0
                        width: parent.width
                        height: Appearance.metrics.hairline
                        color: Theme.hair
                    }
                    onActivated: {
                        if (modelData.hasMenu)
                            root.openApp(modelData);
                        else {
                            modelData.activate();
                            ShellState.closeDropdown("a tray app activated");
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: 4
            }
        }

        // --- One app's menu -----------------------------------------------------
        Column {
            id: menuColumn

            width: parent.width
            spacing: 2
            opacity: root.inMenu ? 1 : 0
            visible: opacity > 0

            property real slide: root.inMenu ? 0 : width
            transform: Translate {
                x: menuColumn.slide
            }
            Behavior on slide {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }

            BackButton {
                onActivated: root.goBack()
            }

            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.path.length > 0 ? root.path.map(p => p.title).join(Appearance.separator) : ""
                    color: Theme.bright
                    font.family: Appearance.font.display
                    font.pixelSize: 15
                    font.weight: Appearance.font.weightBold
                    renderType: Text.NativeRendering
                }
            }

            // The primary action first, at the top level only: what clicking
            // the app's icon in any other tray would do.
            EntryRow {
                visible: root.path.length === 1 && root.app && !root.app.onlyMenu
                text: "OPEN"
                accented: true
                onActivated: {
                    root.app.activate();
                    ShellState.closeDropdown("a tray app activated");
                }
            }

            QsMenuOpener {
                id: opener
                menu: root.path.length > 0 ? root.path[root.path.length - 1].handle : null
            }

            Repeater {
                model: opener.children

                Item {
                    id: slot

                    required property var modelData

                    width: parent.width
                    height: modelData.isSeparator ? 9 : row.height

                    Rectangle {
                        visible: slot.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Appearance.metrics.hairline
                        color: Theme.hair
                    }

                    EntryRow {
                        id: row

                        visible: !slot.modelData.isSeparator
                        text: (slot.modelData.text ?? "").replace(/_(?=\S)/g, "")
                        usable: slot.modelData.enabled
                        chevron: slot.modelData.hasChildren
                        check: slot.modelData.buttonType !== QsMenuButtonType.None
                        checked: slot.modelData.checkState === Qt.Checked
                        onActivated: {
                            if (slot.modelData.hasChildren) {
                                root.path = root.path.concat([{ handle: slot.modelData, title: text.toUpperCase() }]);
                                return;
                            }
                            slot.modelData.triggered();
                            ShellState.closeDropdown("a tray menu entry chosen");
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 4
            }
        }
    }
}

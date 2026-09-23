import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The notification stack: top-right, newest on top, one layer surface per card.
// Separate surfaces rather than one column because the blur layer rule ignores
// alpha, and a single surface would frost the gaps between cards too.
Variants {
    model: Notifications.list

    PanelWindow {
        id: card

        required property var modelData

        // Looked up by id rather than by identity: a model entry does not
        // necessarily arrive as the same object it went in as.
        readonly property int index: Math.max(0, Notifications.list.findIndex(entry => entry.id === modelData.id))
        // How far the card starts to the right of where it settles. This is
        // movement inside the surface, not the surface arriving -- the
        // compositor fades the surface itself.
        readonly property real slide: 60

        property real reveal: 0

        screen: ShellState.screens[0] ?? null
        color: "transparent"

        implicitWidth: 400
        implicitHeight: content.implicitHeight

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Ignore rather than Normal: the card is placed at absolute screen
        // coordinates against the active window, so it must not also be pushed
        // below the bar's exclusive zone.
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
            top: true
            right: true
        }

        // Tucked exactly inside the active window's top-right corner. Hyprland
        // reports `at` as the content origin with the border drawn outside it,
        // so sitting on `at` already leaves the window's border visible around
        // the card. With nothing open on the workspace there is no corner to sit
        // in, and it falls back to the screen's top right under the bar.
        readonly property bool inWindow: ActiveWindow.present

        margins.top: (inWindow ? ActiveWindow.y + ActiveWindow.borderSize : Appearance.metrics.barHeight + 16) + Notifications.offsetOf(index)
        margins.right: inWindow ? Math.max(0, (screen?.width ?? 0) - (ActiveWindow.x + ActiveWindow.width) + ActiveWindow.borderSize) : 24

        onImplicitHeightChanged: Notifications.setHeight(modelData.id, implicitHeight)
        Component.onCompleted: {
            Notifications.setHeight(modelData.id, implicitHeight);
            entry.start();
        }

        Behavior on margins.top {
            NumberAnimation {
                duration: Appearance.duration.panel
                easing.type: Easing.OutCubic
            }
        }

        NumberAnimation {
            id: entry

            target: card
            property: "reveal"
            from: 0
            to: 1
            duration: Appearance.duration.enter
            easing.type: Easing.OutCubic
        }

        NotificationCard {
            id: content

            width: parent.width
            notification: card.modelData

            // The same 16 px cut as the window. Both diagonals run at 45
            // degrees whatever their length, so an equal cut on a corner inset
            // by the border width is parallel to the window's and sits just
            // inside it, with an even gap the whole way along.
            chamferTopRight: Appearance.chamfer.panel

            opacity: card.reveal
            // Slides in from the right with a brief shear, settling as it lands.
            transform: [
                Matrix4x4 {
                    property real skew: (1 - card.reveal) * -6
                    matrix: Qt.matrix4x4(1, Math.tan(skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                },
                Translate {
                    x: (1 - card.reveal) * card.slide
                }
            ]

            onDismissed: card.modelData.dismiss()
        }
    }
}

import QtQuick
import qs.config

// One square per page, the current one in accent. Always centred on the grid,
// however many there are.
//
// **No `P1` label.** The bar's page marker labels its pages because they are
// numbered workspaces the user already thinks of by number; a picker page has
// no name, so a label beside the squares would only be counting them again.
Row {
    id: root

    required property int pages
    required property int current

    signal pageRequested(int page)

    spacing: 4

    Repeater {
        model: root.pages

        Item {
            required property int index

            width: 7
            height: 7

            Rectangle {
                anchors.fill: parent
                color: parent.index === root.current ? Theme.accent : Theme.hair

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.duration.state
                        easing.type: Easing.OutCubic
                    }
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.pageRequested(parent.index)
            }
        }
    }
}

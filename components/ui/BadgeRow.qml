import QtQuick
import qs.config

// BadgeRow (DESIGN.md): a ListRow at 38 px with a Badge at the left and a
// 12 px gap to the name. Where an app is listed (tray, launcher).
ListRow {
    id: root

    property string badge: name

    implicitHeight: Tokens.measure.badgeRow
    leading: Tokens.measure.badge + Tokens.space.s12

    Badge {
        x: Tokens.measure.rowPadding
        anchors.verticalCenter: parent.verticalCenter
        name: root.badge
        selected: root.selected
    }
}

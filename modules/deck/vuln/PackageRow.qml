import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// One affected package. Collapsed it is severity, name, what kind of hole it is
// and how many CVEs; the status is not repeated here because the section header
// above already says it. Clicking opens the detail inline.
Item {
    id: root

    // The 8 px the detail rises through as it fades in. A transform, so the
    // rows around it never move: the space is already reserved by the time
    // anything is drawn in it.
    property real detailRise: Tokens.motion.rise

    // Entry only: the detail lifts into place as it fades in, and on the way
    // out it simply fades. The offset is put back while nothing is drawn.
    onExpandedChanged: detailRise = expanded ? 0 : detailRise

    Behavior on detailRise {
        NumberAnimation {
            duration: Tokens.motion.panels
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }


    required property var entry
    property bool expanded: false

    readonly property color tone: {
        if (entry.severity === "HIGH")
            return Tokens.color.accent;
        if (entry.severity === "MED")
            return Tokens.color.alert;
        return Tokens.color.dim;
    }

    readonly property int rowHeight: 20

    // What `pacman -Qi` says requires this package. Looked up only when the
    // row opens, so a list of twelve does not fire twelve processes at start.
    property var requiredBy: []
    property bool requiredKnown: false
    readonly property bool removable: requiredKnown && requiredBy.length === 0

    signal toggled
    // A greyed button was hovered and wants its reason shown somewhere that is
    // not inside this row, which clips.
    signal explain(string text, Item anchorItem)
    signal explainCleared

    // The open row's extra height is rounded up to whole rows, so opening one
    // does not knock the rest of the list off the grid the panel relies on to
    // show only whole rows.
    implicitHeight: rowHeight + (expanded ? Math.ceil((detail.implicitHeight + 8) / rowHeight) * rowHeight : 0)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    clip: true

    // --- The row itself ----------------------------------------------------
    Item {
        id: line

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rowHeight

        Rectangle {
            id: marker

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            color: root.tone
        }

        Text {
            id: name

            anchors.left: marker.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: root.entry.name
            color: root.expanded ? Tokens.color.bright : Tokens.color.text
            font.family: Tokens.font.data
            font.pixelSize: Appearance.size.body
            elide: Text.ElideRight
            maximumLineCount: 1
            renderType: Text.NativeRendering
        }

        NrLabel {
            anchors.left: name.right
            anchors.leftMargin: 10
            anchors.right: cves.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            color: Tokens.color.mute
            elide: Text.ElideRight
            text: root.entry.shortType
        }

        NrLabel {
            id: cves

            anchors.right: fix.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            color: Tokens.color.dim
            text: `${root.entry.cveCount} CVE`
        }

        // Every row carries it. Without a fix in the repos it says `NO FIX` --
        // greyed, unclickable, and explaining itself in the tag above the row.
        // It used to say `FIX` whatever the state was and leave the whole
        // explanation to a hover reading `NOT YET AVAILABLE`, so a row with
        // nothing to do about it looked exactly like a row with something to
        // do about it, and read as a button that had stopped working.
        //
        // **Both labels and the verb reserve one width**, so the buttons line
        // up down the column and none of them changes size when its row does.
        ActionButton {
            id: fix

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: root.entry.fixed ? "FIX" : "NO FIX"
            alsoText: ["FIX", "NO FIX"]
            verbText: "UPDATING"
            accented: root.entry.fixed
            usable: root.entry.fixed
            action: upgradeAction
            onClicked: {
                upgradeAction.begin("UPDATING");
                Vuln.upgrade();
            }
            onHoveredChanged: hovered => {
                if (root.entry.fixed)
                    return;
                if (hovered)
                    root.explain("NO FIX HAS BEEN RELEASED FOR THIS PACKAGE YET", fix);
                else
                    root.explainCleared();
            }
        }

        Feedback {
            id: feedback

            anchors.fill: parent
            flashOpacity: 0.22
        }

        TapHandler {
            // The FIX button sits on this line and takes its own taps.
            exclusiveSignals: TapHandler.NotExclusive
            onPressedChanged: if (pressed) feedback.flash()
            onTapped: root.toggled()
        }
    }

    // --- Expanded detail ---------------------------------------------------
    Column {
        id: detail

        anchors.top: line.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        spacing: 5
        // Appearing: fade in with an 8 px rise, 250 ms, ease-out. Leaving:
        // fade out 180 ms, ease-in, and only then release its space -- which
        // is what `visible: opacity > 0` is for. It used to release the space
        // on the first frame of the fade, so the rows below jumped up while
        // this was still drawing in the gap.
        visible: opacity > 0
        opacity: root.expanded ? 1 : 0

        transform: Translate {
            y: root.detailRise
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.expanded ? Tokens.motion.panels : Tokens.motion.panels
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.expanded ? Tokens.motion.easeIn : Tokens.motion.easeOut
            }
        }

        // Nothing is drawn any more, so the rise is put back without animating
        // -- ready for the next time the row opens.
        onVisibleChanged: if (!visible) root.detailRise = Tokens.motion.rise

        // The full phrase arch-audit gave, not the shortened tag on the row.
        NrLabel {
            width: parent.width
            color: Tokens.color.text
            wrapMode: Text.WordWrap
            font.capitalization: Font.AllUppercase
            text: root.entry.type || "UNKNOWN"
        }

        Text {
            width: parent.width
            text: root.entry.cves.join("   ")
            color: Tokens.color.dim
            font.family: Tokens.font.data
            font.pixelSize: Appearance.size.label
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            renderType: Text.NativeRendering
        }

        NrLabel {
            width: parent.width
            visible: root.entry.fixed
            color: Tokens.color.signal
            text: `FIXED IN ${root.entry.fixedVersion}`
        }

        // What else on the system depends on this package, which is what
        // decides whether removing it is a sane thing to offer.
        NrLabel {
            width: parent.width
            color: Tokens.color.dim
            wrapMode: Text.WordWrap
            text: {
                if (!root.requiredKnown)
                    return "REQUIRED BY  CHECKING";
                if (root.requiredBy.length === 0)
                    return "REQUIRED BY  NOTHING";
                // A core library can be required by forty packages, and the
                // whole list turns the detail into a wall. The count is the
                // answer to "can I remove this"; the names are context.
                const shown = root.requiredBy.slice(0, 8).join(", ").toUpperCase();
                const rest = root.requiredBy.length - 8;
                return `REQUIRED BY  ${root.requiredBy.length} · ${shown}${rest > 0 ? ` +${rest} MORE` : ""}`;
            }
        }

        Row {
            spacing: 6

            ActionButton {
                text: "OPEN ADVISORY"
                onClicked: Deck.launch(["xdg-open", Vuln.advisoryUrl(root.entry.name)])
            }

            // Enabled only when nothing depends on it. `-Rns` would take the
            // dependants with it otherwise, which is not a thing to offer
            // behind a single button.
            ActionButton {
                id: remove

                text: "REMOVE"
                usable: root.removable
                onClicked: Vuln.remove(root.entry.name)
                onHoveredChanged: hovered => {
                    if (root.removable)
                        return;
                    if (hovered)
                        root.explain(root.requiredKnown ? `REQUIRED BY ${root.requiredBy.length} PACKAGE${root.requiredBy.length === 1 ? "" : "S"}` : "CHECKING", remove);
                    else
                        root.explainCleared();
                }
            }
        }
    }

    // `pacman -Qi`'s Required By field, read once per opening. "None" is the
    // word pacman uses when nothing does.
    Process {
        id: requires

        running: root.expanded && !root.requiredKnown
        command: ["pacman", "-Qi", root.entry.name]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("Required By"));
                const value = line ? line.slice(line.indexOf(":") + 1).trim() : "None";
                root.requiredBy = (value === "None" || !value) ? [] : value.split(/\s+/);
                root.requiredKnown = true;
            }
        }
    }

    // The upgrade runs in a terminal the user types a password into, so it can
    // sit there for a long time. No timeout: waiting for a password is not a
    // failure.
    ActionState {
        id: upgradeAction

        timeoutMs: 24 * 60 * 60000
    }

    Connections {
        target: Vuln

        function onUpgradeFinished(ok: bool): void {
            if (!upgradeAction.working)
                return;
            if (ok)
                upgradeAction.succeed();
            else
                upgradeAction.fail("UPGRADE FAILED", "pacman exited non-zero; see the terminal it opened.");
        }
    }
}

import QtQuick
import QtQuick.Effects
import qs.components
import qs.config
import qs.services

// WALLPAPER // POOLS. The library on the left is the folder itself, not a list
// the shell keeps; the rows on the right are what each profile draws from.
//
// Everything is edited in a working copy and committed by SAVE, because a pool
// is several decisions at once -- which files, which are in the rotation, which
// is the card image, how fast -- and half of them applied is not a state
// anybody asked for.
Item {
    id: root

    signal finished

    // One step back, for the overlay's Escape. This screen holds no focus of
    // its own -- the overlay's key owner has it, and routes Escape here first.
    function back(): bool {
        if (chooser.visible) {
            chooser.visible = false;
            return true;
        }
        if (root.confirmingDelete) {
            root.confirmingDelete = "";
            return true;
        }
        return false;
    }

    // name -> pool, deep-copied on the way in.
    property var draft: ({})
    property string confirmingDelete: ""

    // The drag in progress: what is in hand, and where the pointer is in
    // screen coordinates.
    property string dragFile: ""
    property string dragFrom: ""
    property real dragX: 0
    property real dragY: 0
    property int dropRow: -1

    function load(): void {
        const next = {};
        for (const name of Profiles.names)
            next[name] = JSON.parse(JSON.stringify(Wallpapers.poolFor(name)));
        draft = next;
        dropRow = -1;
        Wallpapers.rescan();
    }

    function poolOf(name: string): var {
        return draft[name] ?? Wallpapers.poolFor(name);
    }

    function edit(name: string, change: var): void {
        const next = Object.assign({}, draft);
        const pool = JSON.parse(JSON.stringify(poolOf(name)));
        change(pool);
        // Exactly one card image per profile, always. A pool with no star
        // would have to fall back somewhere, and two would be a question.
        if (pool.items.length && !pool.items.some(item => item.star))
            pool.items[0].star = true;
        next[name] = pool;
        draft = next;
    }

    function addTo(name: string, file: string): void {
        edit(name, pool => {
            if (pool.items.some(item => item.file === file))
                return;
            pool.items.push({
                file,
                on: true,
                star: pool.items.length === 0
            });
        });
    }

    function removeFrom(name: string, file: string): void {
        edit(name, pool => {
            pool.items = pool.items.filter(item => item.file !== file);
        });
    }

    function commit(): void {
        Wallpapers.setPools(draft);
        root.finished();
    }

    onVisibleChanged: {
        clearFocus();
        if (visible)
            load();
    }

    // --- Drag ----------------------------------------------------------------
    function beginDrag(file: string, from: string, x: real, y: real): void {
        dragFile = file;
        dragFrom = from;
        moveDrag(x, y);
    }

    function moveDrag(x: real, y: real): void {
        dragX = x;
        dragY = y;
        dropRow = rowUnder(x, y);
    }

    Connections {
        target: ShellState

        function onPoolsDemoDrag(file: string, profile: string): void {
            if (root.visible)
                root.demoDrag(file, profile);
        }
    }

    // --- The demo drag ---------------------------------------------------------
    // **A hand moving a tile, with no hand.** There is no pointer in a
    // recording, and `beginDrag`/`moveDrag` are driven by one -- so a
    // demonstration of the one gesture this screen is built around had no way
    // to happen at all. This animates it: the tile lifts, travels an eased arc
    // with a tilt that settles on arrival, the target row lights as it comes
    // in, and the drop is the same `addTo` a real release makes.
    //
    // **It ends in the draft, exactly where a real drag ends.** This screen is
    // draft-until-SAVE and a pointer drag writes nothing either; committing
    // here would make the demonstration do something the gesture it is
    // demonstrating does not.
    property real dragT: 0
    property real dragLift: 0
    property real dragFromX: 0
    property real dragFromY: 0
    property real dragToX: 0
    property real dragToY: 0
    property int dragTargetRow: -1
    readonly property bool demoDragging: dragLift > 0 || dragT > 0

    // How high the arc rises at its midpoint, and how far the tile leans into
    // the direction it is travelling. Both are shaped by `sin(pi t)`, which is
    // zero at both ends -- so the tile leaves flat and **arrives flat**, which
    // is the difference between a throw and a drop.
    readonly property real dragArc: -96
    readonly property real dragTilt: 7

    readonly property real dragArcShape: Math.sin(Math.PI * root.dragT)
    readonly property real dragX2: root.dragFromX + (root.dragToX - root.dragFromX) * root.dragT
    readonly property real dragY2: root.dragFromY + (root.dragToY - root.dragFromY) * root.dragT + root.dragArc * root.dragArcShape

    function demoDrag(wanted: string, target: string): bool {
        const row = Profiles.names.indexOf(target);
        if (row < 0)
            return false;
        // **Chosen against the draft, not against the saved pools.** A second
        // drag asked `Wallpapers.poolFor` and got the same answer as the
        // first, because the first one's tile is only in the draft.
        const file = wanted || root.dragCandidateFor(target);
        if (!file)
            return false;
        const tile = libraryTileFor(file);
        const item = rowRepeater.itemAt(row);
        if (!tile || !item)
            return false;

        const from = tile.mapToItem(root, tile.width / 2, tile.height / 2);
        const to = item.mapToItem(root, item.width * 0.62, item.height / 2);
        root.dragFile = file;
        root.dragFrom = "";
        root.dragFromX = from.x;
        root.dragFromY = from.y;
        root.dragToX = to.x;
        root.dragToY = to.y;
        root.dragTargetRow = row;
        root.dropRow = -1;
        demoDragRun.restart();
        return true;
    }

    function dragCandidateFor(target: string): string {
        const held = (root.poolOf(target).items ?? []).map(item => item.file);
        for (const entry of Wallpapers.library ?? []) {
            if (held.indexOf(entry.file) < 0)
                return entry.file;
        }
        return "";
    }

    function libraryTileFor(file: string): var {
        for (let i = 0; i < (Wallpapers.library ?? []).length; i++) {
            if (Wallpapers.library[i].file === file) {
                // The Flow's first child is `+ ADD FILES`, so the tiles are
                // offset by one.
                const item = libraryFlow.children[i + 1];
                if (item && item.width > 0)
                    return item;
            }
        }
        return null;
    }

    SequentialAnimation {
        id: demoDragRun

        // The pick-up. Short, because a hand does not hesitate once it has
        // decided.
        NumberAnimation {
            target: root
            property: "dragLift"
            from: 0
            to: 1
            duration: 170
            easing.type: Easing.OutCubic
        }

        // The travel. **Ease in and out**, so it leaves and lands slowly and
        // covers the middle quickly, which is what a hand does.
        NumberAnimation {
            target: root
            property: "dragT"
            from: 0
            to: 1
            duration: 1320
            easing.type: Easing.InOutCubic
        }

        // The drop: the lift comes off, and the pool gains the wallpaper on
        // the same frame the tile lands.
        NumberAnimation {
            target: root
            property: "dragLift"
            to: 0
            duration: 200
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                const target = Profiles.names[root.dragTargetRow];
                if (target)
                    root.addTo(target, root.dragFile);
                root.dragFile = "";
                root.dragT = 0;
            }
        }

        // The row holds its light a beat after the drop, then lets go.
        PauseAnimation {
            duration: 320
        }

        ScriptAction {
            script: {
                root.dropRow = -1;
                root.dragTargetRow = -1;
            }
        }
    }

    // The row lights as the tile comes in, not when it leaves -- the light is
    // the target answering, and a target that answers before anything is near
    // it is a highlight rather than a reaction.
    onDragTChanged: {
        if (root.dragTargetRow >= 0 && root.dragT > 0.55)
            root.dropRow = root.dragTargetRow;
    }

    function endDrag(): void {
        if (dragFile && dropRow >= 0) {
            const target = Profiles.names[dropRow];
            if (target) {
                // Dragging a chip out of one row and into another *moves* it;
                // dragging a library tile in only adds. The difference is
                // where the drag started, which is why `dragFrom` is carried.
                if (dragFrom && dragFrom !== target)
                    removeFrom(dragFrom, dragFile);
                addTo(target, dragFile);
            }
        }
        dragFile = "";
        dragFrom = "";
        dropRow = -1;
    }

    // --- The keyboard's position in the pools ---------------------------------
    // The chips are reachable without the pointer: Tab walks every chip in
    // every row, Enter makes the one it is on the profile's card image, and
    // Delete takes it out of that profile's pool. The focus is held here as a
    // pair of indices rather than as Qt focus, because the overlay's key owner
    // takes real focus back from anything that is not a text field -- see
    // `OverlayKeys`, and the trap it exists to stop.
    property int focusRow: -1
    property int focusChip: -1
    // The library tile the keyboard is on, or -1. **Tab walks the library
    // first and then the rows**, one order through the screen, so every
    // control that only appears on pointer-over -- a tile's `DELETE`, a chip's
    // `CARD` tag and its minus -- can be reached without the pointer.
    property int focusTile: -1

    readonly property bool chipFocused: focusRow >= 0 && focusChip >= 0
    readonly property bool tileFocused: focusTile >= 0

    function chipCount(row: int): int {
        const name = Profiles.names[row];
        return name ? (root.poolOf(name).items ?? []).length : 0;
    }

    readonly property int tileCount: (Wallpapers.library ?? []).length

    // One position, walked forward or back: the library's tiles, then every
    // chip in every row, then round to the start.
    function stepFocus(delta: int): void {
        if (root.tileFocused) {
            const next = root.focusTile + delta;
            if (next >= 0 && next < root.tileCount) {
                root.focusTile = next;
                return;
            }
            root.focusTile = -1;
            // Off the end of the library goes into the rows; off the front
            // wraps to the last chip.
            if (delta > 0)
                root.stepChip(1);
            else
                root.stepLastChip();
            return;
        }
        if (root.chipFocused) {
            if (root.stepChip(delta))
                return;
            // Out of chips: back into the library at the end it came from.
            root.focusTile = delta > 0 ? (root.tileCount ? 0 : -1) : root.tileCount - 1;
            return;
        }
        // Nothing focused yet.
        if (delta > 0)
            root.focusTile = root.tileCount ? 0 : -1;
        else
            root.focusTile = root.tileCount - 1;
        if (root.focusTile < 0)
            root.stepChip(delta);
    }

    function stepLastChip(): void {
        for (let r = Profiles.names.length - 1; r >= 0; r--) {
            const count = root.chipCount(r);
            if (count) {
                root.focusRow = r;
                root.focusChip = count - 1;
                return;
            }
        }
    }

    // Forward or back through every chip in the screen, rows included, so the
    // end of one row is the start of the next. Returns false when it walks off
    // the end, which is what hands the position back to the library.
    function stepChip(delta: int): bool {
        const rows = Profiles.names.length;
        if (!rows)
            return false;
        let r = root.focusRow;
        let c = root.focusChip;
        if (r < 0) {
            r = delta > 0 ? 0 : rows - 1;
            c = delta > 0 ? -1 : root.chipCount(r);
        }
        // At most one full pass: a screen where every pool is empty has
        // nothing to land on, and this has to stop rather than spin.
        for (let guard = 0; guard < rows; guard++) {
            c += delta;
            const count = root.chipCount(r);
            if (c >= 0 && c < count) {
                root.focusTile = -1;
                root.focusRow = r;
                root.focusChip = c;
                return true;
            }
            // Walking off the last row forward, or the first row back, is the
            // end of the chips rather than a wrap: the library is next.
            if (delta > 0 && r === rows - 1)
                break;
            if (delta < 0 && r === 0)
                break;
            r += delta;
            c = delta > 0 ? -1 : root.chipCount(r);
        }
        root.clearChipFocus();
        return false;
    }

    function clearChipFocus(): void {
        focusRow = -1;
        focusChip = -1;
    }

    function clearFocus(): void {
        clearChipFocus();
        focusTile = -1;
    }

    // Enter and Delete, routed from the overlay. They act on the focused chip
    // and do nothing at all when there is not one, so neither key gains a
    // meaning on this screen that it did not have before.
    function promoteFocused(): bool {
        if (!root.chipFocused)
            return false;
        const name = Profiles.names[root.focusRow];
        const at = root.focusChip;
        root.edit(name, pool => pool.items.forEach((item, i) => item.star = i === at));
        return true;
    }

    function removeFocused(): bool {
        // A focused library tile asks the same question the pointer does.
        if (root.tileFocused) {
            const entry = (Wallpapers.library ?? [])[root.focusTile];
            if (!entry)
                return false;
            root.confirmingDelete = entry.file;
            return true;
        }
        if (!root.chipFocused)
            return false;
        const name = Profiles.names[root.focusRow];
        const at = root.focusChip;
        root.edit(name, pool => pool.items.splice(at, 1));
        // The chip it was on is gone; stay in the row if anything is left.
        if (root.focusChip >= root.chipCount(root.focusRow))
            root.focusChip = root.chipCount(root.focusRow) - 1;
        if (root.focusChip < 0)
            root.clearChipFocus();
        return true;
    }

    // Which row the pointer is over, by asking each row where it is rather
    // than by arithmetic on the scroll position -- the list scrolls, and a
    // computed offset would be wrong the moment it did.
    function rowUnder(x: real, y: real): int {
        for (let i = 0; i < rowRepeater.count; i++) {
            const item = rowRepeater.itemAt(i);
            if (!item)
                continue;
            const local = item.mapFromItem(null, x, y);
            if (local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height) {
                // Off the visible part of the list, so not a drop.
                const inView = rowsView.mapFromItem(null, x, y);
                if (inView.y < 0 || inView.y > rowsView.height)
                    return -1;
                return i;
            }
        }
        return -1;
    }

    // The panel's own bounds plus the `BACK` control above it, for the
    // overlay's backdrop dismissal -- a control outside this rectangle would
    // dismiss the screen on its way to being pressed.
    readonly property rect contentRect: Qt.rect(panel.x, back.y, panel.width, panel.y + panel.height - back.y)

    // **Above the panel's own top-left corner**, 34 px clear of it, so it
    // never overlaps or moves the header inside.
    BackButton {
        id: back

        x: panel.x
        y: panel.y - 34

        onActivated: root.finished()
    }

    ChamferPanel {
        id: panel

        x: 150
        y: 120
        width: 1620
        height: 840

        chamfer: Appearance.chamfer.panel
        fillColor: Theme.panel2
        borderColor: Theme.hair

        // --- Header -----------------------------------------------------------
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            height: 30

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                GlitchFx {
                    group: "overlay"
                    anchors.verticalCenter: parent.verticalCenter
                    fills: true
                    textual: true
                    width: poolsTitle.implicitWidth
                    height: poolsTitle.implicitHeight
                    scrambleItems: [poolsTitle]

                    GlitchText {
                        id: poolsTitle

                        anchors.fill: parent
                        text: `WALLPAPER${Appearance.separator}POOLS`
                        pixelSize: 22
                    }
                }

                KanaTag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "壁紙"
                    title: poolsTitle
                }
            }

            NrLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                tracked: false
                text: Wallpapers.folder ? Paths.display(Wallpapers.folder) : "NO FOLDER SET"
            }
        }

        // --- Library ------------------------------------------------------------
        Item {
            id: library

            anchors.top: header.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.bottom: footer.top
            anchors.bottomMargin: 16
            width: 440

            NrLabel {
                id: libraryTitle

                anchors.top: parent.top
                color: Theme.text
                text: `LIBRARY${Appearance.separator}${Wallpapers.library.length} FILES`
            }

            Flickable {
                id: libraryView

                anchors.top: libraryTitle.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                clip: true
                contentHeight: libraryFlow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: libraryFlow

                    width: parent.width
                    spacing: 12

                    // The way in. A file chooser rather than a path field: the
                    // files being added are ones the user already has open
                    // somewhere, and typing their paths is not how anybody
                    // does that.
                    Item {
                        width: 190
                        height: 110

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.alpha(Theme.accent, addHover.hovered ? 0.16 : 0.07)
                            border.width: Appearance.metrics.hairline
                            border.color: Theme.accent
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "+"
                                color: Theme.accent
                                font.family: Appearance.font.display
                                font.pixelSize: 24
                                font.weight: Appearance.font.weightBold
                                renderType: Text.NativeRendering
                            }

                            NrLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                centred: true
                                color: Theme.accent
                                text: "ADD FILES"
                            }
                        }

                        HoverHandler {
                            id: addHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: chooser.open(Wallpapers.folder || Paths.home)
                        }
                    }

                    Repeater {
                        model: Wallpapers.library

                        LibraryTile {
                            required property var modelData
                            required property int index

                            entry: modelData
                            focused: root.focusTile === index

                            onDeleteRequested: root.confirmingDelete = modelData.file
                            onDragStarted: (payload, x, y) => root.beginDrag(payload, "", x, y)
                            onDragMoved: (x, y) => root.moveDrag(x, y)
                            onDragEnded: root.endDrag()
                        }
                    }
                }
            }

            ShellScrollBar {
                anchors.right: parent.right
                anchors.top: libraryView.top
                anchors.bottom: libraryView.bottom
                view: libraryView
            }
        }

        // --- Rows -----------------------------------------------------------------
        Item {
            id: rowsPane

            anchors.top: header.bottom
            anchors.topMargin: 16
            anchors.left: library.right
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: footer.top
            anchors.bottomMargin: 16

            NrLabel {
                id: rowsTitle

                anchors.top: parent.top
                color: Theme.text
                text: `PROFILES${Appearance.separator}${Profiles.names.length}`
            }

            Flickable {
                id: rowsView

                anchors.top: rowsTitle.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                clip: true
                contentHeight: rowsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rowsColumn

                    width: parent.width
                    spacing: 10

                    Repeater {
                        id: rowRepeater

                        model: Profiles.names

                        PoolRow {
                            required property string modelData
                            required property int index

                            width: rowsColumn.width
                            name: modelData
                            pool: root.poolOf(modelData)
                            highlighted: root.dropRow === index && root.dragFile !== ""
                            missingOwn: !Wallpapers.hasFile(Wallpapers.ownFile(modelData))
                            canRestore: Wallpapers.restoreSource() !== null
                            focusedChip: root.focusRow === index ? root.focusChip : -1

                            onModeRequested: mode => root.edit(modelData, pool => pool.mode = mode)
                            onEveryChanged: minutes => root.edit(modelData, pool => pool.every = minutes)
                            onFadeChanged: seconds => root.edit(modelData, pool => pool.fade = seconds)
                            onChipToggled: at => root.edit(modelData, pool => pool.items[at].on = !pool.items[at].on)
                            onChipStarred: at => root.edit(modelData, pool => pool.items.forEach((item, i) => item.star = i === at))
                            onChipRemoved: at => root.edit(modelData, pool => pool.items.splice(at, 1))
                            onRestoreRequested: Wallpapers.restore(modelData)
                            onChipDragStarted: (payload, x, y) => root.beginDrag(payload, modelData, x, y)
                            onChipDragMoved: (x, y) => root.moveDrag(x, y)
                            onChipDragEnded: root.endDrag()
                        }
                    }
                }
            }

            ShellScrollBar {
                anchors.right: parent.right
                anchors.top: rowsView.top
                anchors.bottom: rowsView.bottom
                view: rowsView
            }
        }

        // --- Footer ---------------------------------------------------------------
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            height: 28

            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                // **Bounded by the buttons, not by its own length.** The
                // legend names five controls now and the first draft of it
                // ran straight through CANCEL; a line that sets its own width
                // will do that again the next time a control is renamed.
                anchors.right: footerButtons.left
                anchors.rightMargin: 24
                elide: Text.ElideRight
                pixelSize: Appearance.size.label
                // **Untracked, because it is a sentence.** 0.14em over 180
                // characters is 260 px of letter-spacing, which is what put it
                // through the buttons; the header's folder path is untracked
                // for the same reason. Tracking is for labels.
                tracked: false
                color: Theme.dim
                // **Every control is named exactly as it appears.** The
                // legend used to describe two marks -- a star and a cross --
                // that said nothing about themselves; now it names the words
                // that are on the screen.
                text: "DRAG A WALLPAPER ONTO A ROW    TICK TO INCLUDE IT IN THE ROTATION    CARD MARKS THE IMAGE SHOWN ON THE PROFILE    MINUS TAKES IT OUT OF THIS PROFILE    DELETE REMOVES THE FILE FROM DISK"
            }

            Row {
                id: footerButtons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                ActionButton {
                    text: "CANCEL"
                    onClicked: root.finished()
                }

                ActionButton {
                    text: "SAVE"
                    accented: true
                    onClicked: root.commit()
                }
            }
        }
    }

    // While something is in hand, nothing underneath reacts to the pointer.
    // The originating MouseArea holds the grab, so the drag itself is
    // unaffected; what this stops is every hover and every control the ghost
    // is dragged across lighting up under it, and a stray release landing on
    // a chip's tickbox instead of the row.
    MouseArea {
        anchors.fill: parent
        visible: root.dragFile !== ""
        enabled: visible
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        z: 9
    }

    // --- The drag's ghost --------------------------------------------------------
    // Drawn at the top of the screen rather than by reparenting the chip: the
    // rows and the library both clip, and a dragged item that stays inside its
    // own list disappears the moment it leaves it.
    Item {
        id: ghost

        // Under the pointer for a real drag; on the arc for a demo one.
        x: (root.demoDragging ? root.dragX2 : root.dragX) - width / 2
        y: (root.demoDragging ? root.dragY2 : root.dragY) - height / 2
        width: 108
        height: 60
        z: 10

        // **The lift is scale and shadow together.** Either on its own reads
        // as a rendering change; the pair reads as the tile coming off the
        // surface. The tilt leans into the direction of travel and is shaped
        // so it is zero at both ends of the arc.
        transform: [
            Rotation {
                origin.x: ghost.width / 2
                origin.y: ghost.height / 2
                angle: root.demoDragging ? root.dragTilt * root.dragArcShape * (root.dragToX >= root.dragFromX ? 1 : -1) : 0
            },
            Scale {
                origin.x: ghost.width / 2
                origin.y: ghost.height / 2
                xScale: 1 + 0.05 * root.dragLift
                yScale: 1 + 0.05 * root.dragLift
            }
        ]

        layer.enabled: root.dragLift > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1.0
            shadowVerticalOffset: 10 * root.dragLift
            shadowOpacity: 0.65 * root.dragLift
        }

        // The ghost is in hand or it is not; it fades rather than blinking on
        // and off under the pointer. It does not rise -- it is following the
        // cursor, and a rise would fight the thing that is moving it.
        visible: opacity > 0
        // A demo drag is opaque: it is standing in for a hand, and a
        // half-transparent tile reads as a preview of a drop rather than as
        // the thing itself being carried.
        opacity: root.dragFile === "" ? 0 : (root.demoDragging ? 1 : 0.85)

        Behavior on opacity {
            NumberAnimation {
                duration: root.dragFile !== "" ? Appearance.duration.state : Appearance.duration.exit
                easing.type: root.dragFile !== "" ? Easing.OutCubic : Easing.InCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.deep
            border.width: Appearance.metrics.hairline
            border.color: Theme.accent
        }

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: Wallpapers.imageOf(root.dragFile)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(220, 120)
            asynchronous: true
            cache: true
        }
    }

    // --- Deleting a file ------------------------------------------------------------
    // **The scrim and the panel are one object**, so they arrive and leave
    // together rather than as two things on two clocks.
    Appear {
        anchors.fill: parent
        fills: true
        shown: root.confirmingDelete !== ""

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
    }

    ChamferPanel {
        anchors.centerIn: parent
        width: 460
        height: 190

        chamfer: Appearance.chamfer.panel
        fillColor: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.97)
        borderColor: Theme.alert

        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 12

            Text {
                width: parent.width
                text: "DELETE FROM DISK?"
                color: Theme.alert
                font.family: Appearance.font.display
                font.pixelSize: 18
                font.weight: Appearance.font.weightBold
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: `${root.confirmingDelete} is removed from your wallpapers folder. Every pool holding it loses it.`
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                renderType: Text.NativeRendering
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                ActionButton {
                    text: "DELETE"
                    accented: true
                    textColor: Theme.alert
                    onClicked: {
                        const file = root.confirmingDelete;
                        Wallpapers.deleteFile(file);
                        for (const name of Profiles.names)
                            root.removeFrom(name, file);
                        root.confirmingDelete = "";
                    }
                }

                ActionButton {
                    text: "KEEP"
                    onClicked: root.confirmingDelete = ""
                }
            }
        }
    }
    }

    // The chooser lives inside the overlay. See FileBrowser for why a
    // `FileDialog` cannot: it opens behind a layer surface and takes the
    // input with it.
    FileBrowser {
        id: chooser

        anchors.fill: parent
        visible: false

        onChosen: paths => {
            Wallpapers.importFiles(paths);
            visible = false;
        }
        onCancelled: visible = false
    }

}

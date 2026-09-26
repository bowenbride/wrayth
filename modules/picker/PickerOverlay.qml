import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.modules.picker.editor
import qs.modules.picker.effects
import qs.modules.picker.privacy
import qs.modules.picker.pools
import qs.modules.picker.system

// PROFILE // SELECT, and the two screens it leads to. Moving the selection
// recolours the whole shell at once; Enter keeps it, Escape puts the old one
// back.
//
// One layer surface holds all three screens. The editor and the pools are not
// separate overlays -- they are reached from here, return to here, and share
// the backdrop, so a second surface would only mean a second fade.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData

        // One screen only: see `ShellState.overlayScreen`.
        readonly property bool shown: ShellState.pickerOpen && ShellState.overlayScreen === modelData?.name

        // "grid", "editor" or "pools". Held on `ShellState` rather than here so
        // the IPC can drive it; **not called `screen`**, because `PanelWindow`
        // already has one and it is the monitor this surface is on.
        property string view: ShellState.pickerView
        // The custom profile being edited, or "" for a new one.
        property string editing: ShellState.pickerEditing

        function show(next: string): void {
            ShellState.pickerView = next;
        }

        // --- The grid's contents ---------------------------------------------
        // Every profile, then the card that makes a new one. The `+ NEW
        // CUSTOM` tile is part of the grid rather than a button beside it, so
        // the arrow keys reach it like anything else.
        readonly property var entries: {
            const out = Profiles.names.map(name => ({
                        kind: "profile",
                        name
                    }));
            out.push({
                kind: "new",
                name: ""
            });
            return out;
        }

        readonly property int columns: 4
        readonly property int rows: 2
        readonly property int perPage: columns * rows

        property int selected: 0
        property string applied: ""
        property string confirming: ""

        readonly property int pages: Math.max(1, Math.ceil(entries.length / perPage))
        readonly property int page: Math.floor(selected / perPage)

        // The profile the shell is painted with. Landing on `+ NEW CUSTOM`
        // leaves it where it was: there is nothing there to preview, and
        // snapping the shell back to the active profile would read as the
        // preview breaking.
        property string previewed: Theme.activeProfile

        function select(index: int): void {
            const count = entries.length;
            selected = (index + count) % count;
            applied = "";
            const entry = entries[selected];
            if (entry.kind === "profile") {
                previewed = entry.name;
                Theme.preview(entry.name);
            }
        }

        function move(delta: int): void {
            select(selected + delta);
        }

        function goToPage(target: int): void {
            select(Math.min(entries.length - 1, target * perPage));
        }

        // Enter, routed to whatever is up. The editor saves; the pools screen
        // does not commit on Enter, because SAVE there writes every row at
        // once and a stray keystroke should not.
        function accept(): void {
            if (view === "editor") {
                editorScreen.save();
                return;
            }
            // The pools screen does not commit on Enter -- SAVE there writes
            // every row at once and a stray keystroke should not. Enter on a
            // focused chip is a different question, and it answers that one.
            if (view === "pools") {
                poolsScreen.promoteFocused();
                return;
            }
            // Nothing on the effects page waits for Enter: every control there
            // applies itself the moment it is pressed.
            if (view === "effects" || view === "privacy" || view === "system")
                return;
            confirm();
        }

        // Enter means "the obvious next thing": answer the question if one is
        // up, otherwise act on the card.
        function confirm(): void {
            if (confirming) {
                removeProfile(confirming);
                return;
            }
            activate();
        }

        function askToRemove(): void {
            const entry = entries[selected];
            if (entry?.kind === "profile" && Profiles.isCustom(entry.name))
                confirming = entry.name;
        }

        function activate(): void {
            const entry = entries[selected];
            if (!entry)
                return;
            if (entry.kind === "new") {
                ShellState.pickerEditing = "";
                overlay.show("editor");
                return;
            }
            apply(entry.name);
        }

        function apply(name: string): void {
            applied = name;
            // The card says APPLYING until the profile has actually landed,
            // rather than for a fixed moment: `Theme.apply` writes the file and
            // bumps activeProfile, and that is what runs the helper script for
            // kitty and the Hyprland borders. Re-applying the profile already
            // in force changes nothing, so it is settled here instead of
            // waiting for a signal that will never come.
            if (Theme.activeProfile === name) {
                close.restart();
                return;
            }
            applyAction.begin("APPLYING");
            Theme.apply(name);
        }

        function removeProfile(name: string): void {
            confirming = "";
            // The shell must always be painted with something, and Circuit is
            // the balanced default.
            const fallback = "Circuit";
            if (Theme.activeProfile === name)
                Theme.apply(fallback);
            if (previewed === name) {
                previewed = fallback;
                Theme.preview(fallback);
            }
            Wallpapers.forget(name);
            Customs.remove(name);
            selected = Math.min(selected, entries.length - 2);
        }

        Connections {
            target: ShellState

            function onPickerSelect(name: string): void {
                if (!overlay.shown)
                    return;
                const at = name === "new"
                    ? overlay.entries.length - 1
                    : overlay.entries.findIndex(entry => entry.kind === "profile" && entry.name.toLowerCase() === name.toLowerCase());
                if (at >= 0)
                    overlay.select(at);
            }
        }

        ActionState {
            id: applyAction
        }

        Connections {
            target: Theme

            function onActiveProfileChanged(): void {
                if (!applyAction.working)
                    return;
                if (Theme.activeProfile === overlay.applied) {
                    applyAction.succeed();
                    close.restart();
                }
            }
        }

        // One step back, whatever is up: the screen's own question, then the
        // screen, then the picker. **Every branch of this has to end
        // somewhere** -- the version that did not is what trapped the
        // keyboard.
        function dismiss(): void {
            if (view === "editor" && editorScreen.back())
                return;
            if (view === "pools" && poolsScreen.back())
                return;
            if (view === "privacy" && privacyScreen.back())
                return;
            if (view === "system" && systemScreen.back())
                return;
            if (view === "effects" && effectsScreen.back())
                return;
            if (confirming) {
                confirming = "";
                return;
            }
            if (view !== "grid") {
                show("grid");
                return;
            }
            Theme.clearPreview();
            applied = "";
            ShellState.pickerOpen = false;
        }

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

        onShownChanged: {
            if (shown) {
                overlay.show("grid");
                confirming = "";
                applied = "";
                selected = Math.max(0, Profiles.names.indexOf(Theme.profile));
                previewed = Theme.profile;
                Theme.preview(Theme.profile);
                keys.take();
            } else {
                Theme.clearPreview();
            }
        }

        // A beat on APPLIED before the overlay goes.
        Timer {
            id: close

            interval: 420
            onTriggered: ShellState.pickerOpen = false
        }

        Item {
            anchors.fill: parent

            // Whatever the shell is showing: with DYNAMIC on that is the
            // previewed profile's wallpaper, because previewing moves
            // `Theme.profile` and the wallpaper follows it. With DYNAMIC off
            // it does not move, which is what the switch promises.
            Wallpaper {
                anchors.fill: parent
                blurRadius: 16
                dim: 0.62
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.3
            }

            // **A click on bare backdrop goes back one step**, the same as
            // Escape. The grid had no pointer way out at all -- the only click
            // that closed the picker was a second click on the card already
            // previewed -- so a keyboard that had stopped answering left
            // nothing left to try.
            //
            // **It tests the pointer against the composition's own bounds
            // rather than relying on the panels to swallow their clicks.** A
            // `TapHandler` takes a *passive* grab, so a press on a card does
            // not stop propagating: a plain dismiss layer underneath would
            // have previewed the card and closed the picker in one click. The
            // rectangles below are the same figures the screens are laid out
            // from, so the two cannot drift apart.
            MouseArea {
                anchors.fill: parent

                readonly property rect content: {
                    if (overlay.view === "editor")
                        return editorScreen.contentRect;
                    if (overlay.view === "pools")
                        return poolsScreen.contentRect;
                    if (overlay.view === "effects")
                        return effectsScreen.contentRect;
                    if (overlay.view === "privacy")
                        return privacyScreen.contentRect;
                    if (overlay.view === "system")
                        return systemScreen.contentRect;
                    return gridScreen.contentRect;
                }

                onPressed: mouse => {
                    // Inside the composition the press is not ours: reject it
                    // and it carries on down to whatever is under it.
                    mouse.accepted = !(mouse.x >= content.x && mouse.x <= content.x + content.width && mouse.y >= content.y && mouse.y <= content.y + content.height);
                }
                onClicked: overlay.dismiss()
            }

            // --- The grid screen ---------------------------------------------
            // Laid out at the spec's own coordinates rather than centred: the
            // grid, the arrows either side of it, the indicator under it and
            // the wallpaper column beside it are one composition, and centring
            // each piece separately is what lets them drift apart.
            // **Each screen fades as one object.** Switching between the
            // grid, the editor and the pools used to cut: one `visible` went
            // false and the next went true in the same frame. A section
            // animates as a single opacity on its container, never one child
            // after another, which is exactly what `Appear` is.
            Appear {
                id: gridAppear

                anchors.fill: parent
                fills: true
                shown: overlay.view === "grid"

            Item {
                id: gridScreen

                anchors.fill: parent

                readonly property int gridLeft: 250
                readonly property int gridTop: 262
                readonly property int gridWidth: 1008
                readonly property int gridHeight: 444

                // Everything the screen actually draws, from the left arrow to
                // the wallpaper column and from the header to the bottom of
                // the EFFECTS section. The backdrop dismisses outside this and
                // nowhere else -- **which is why the section has to be inside
                // it**: a control outside this rectangle closes the picker
                // whenever it is used.
                readonly property rect contentRect: Qt.rect(212, 90, 1710 - 212, 800 - 90)

                // **`BACK` above the header, at the composition's own left
                // edge.** Escape is not discoverable and it was the only way
                // out of this screen; the button does exactly what Escape
                // does, by calling the same function.
                // The full-screen header row: BackControl, title, status.
                BackButton {
                    id: pickerBack
                    x: gridScreen.gridLeft
                    y: 151 + Math.round((46 - height) / 2)

                    onActivated: overlay.dismiss()
                }

                // Header, above the grid, spanning to the wallpaper column's
                // right edge so the status sits at the composition's own edge.
                Item {
                    x: gridScreen.gridLeft
                    y: 151
                    width: 1710 - gridScreen.gridLeft
                    height: 46

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: pickerBack.width + Tokens.space.s16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        GlitchFx {
                            group: "overlay"
                            anchors.verticalCenter: parent.verticalCenter
                            fills: true
                            textual: true
                            width: pickerTitle.implicitWidth
                            height: pickerTitle.implicitHeight
                            scrambleItems: [pickerTitle]

                            GlitchText {
                                id: pickerTitle

                                anchors.fill: parent
                                text: "PROFILES"
                                // The full-screen view title role (DESIGN.md): 22 px, 0.12em.
                                pixelSize: Tokens.type.viewTitle.size
                                tracking: Tokens.type.viewTitle.tracking
                            }
                        }

                        KanaTag {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "配色"
                            title: pickerTitle
                        }
                    }

                    Row {
                        id: status

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        readonly property bool creating: overlay.entries[overlay.selected]?.kind === "new"
                        readonly property bool previewing: !overlay.applied

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Tokens.color.accent
                            text: {
                                if (!status.previewing)
                                    return `APPLIED ${overlay.applied.toUpperCase()}`;
                                if (status.creating)
                                    return "NEW CUSTOM";
                                return `PREVIEW ${overlay.previewed.toUpperCase()}`;
                            }
                        }

                        Keycap {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: status.previewing
                            key: "ENTER"
                            color: Tokens.color.accent
                        }

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: status.previewing
                            color: Tokens.color.accent
                            text: status.creating ? "TO CREATE" : "OR CLICK AGAIN TO APPLY"
                        }
                    }
                }

                NrLabel {
                    x: gridScreen.gridLeft
                    y: 223
                    color: Tokens.color.dim
                    text: "SAME DECK, DIFFERENT OWNER    LIVE PREVIEW"
                }

                // --- Arrows ---------------------------------------------------
                PageArrow {
                    x: 212
                    y: gridScreen.gridTop
                    leading: true
                    available: overlay.page > 0
                    onActivated: overlay.goToPage(overlay.page - 1)
                }

                PageArrow {
                    x: 1270
                    y: gridScreen.gridTop
                    leading: false
                    available: overlay.page < overlay.pages - 1
                    onActivated: overlay.goToPage(overlay.page + 1)
                }

                // --- Cards ----------------------------------------------------
                Grid {
                    id: grid

                    x: gridScreen.gridLeft
                    y: gridScreen.gridTop
                    width: gridScreen.gridWidth
                    height: gridScreen.gridHeight

                    columns: overlay.columns
                    columnSpacing: 16
                    rowSpacing: 16

                    Repeater {
                        // Only this page's entries are built. The grid is a
                        // fixed 4x2 and paging is what the arrows are for, so
                        // an off-page card would be an item with nowhere to go.
                        model: overlay.entries.slice(overlay.page * overlay.perPage, (overlay.page + 1) * overlay.perPage)

                        Loader {
                            required property var modelData
                            required property int index

                            readonly property int absolute: overlay.page * overlay.perPage + index

                            sourceComponent: modelData.kind === "new" ? newCard : profileCard
                        }
                    }
                }

                Component {
                    id: profileCard

                    ProfileCard {
                        name: parent.modelData.name
                        selected: parent.absolute === overlay.selected
                        active: name === Theme.activeProfile
                        confirming: overlay.confirming === name

                        working: applyAction.working && name === overlay.applied
                        succeeded: applyAction.succeeded && name === overlay.applied

                        onPicked: {
                            if (overlay.selected === parent.absolute)
                                overlay.apply(name);
                            else
                                overlay.select(parent.absolute);
                        }
                        onEditRequested: {
                            ShellState.pickerEditing = name;
                            overlay.show("editor");
                        }
                        onDeleteRequested: overlay.confirming = name
                        onDeleteConfirmed: overlay.removeProfile(name)
                        onDeleteCancelled: overlay.confirming = ""
                    }
                }

                Component {
                    id: newCard

                    NewCustomCard {
                        selected: parent.absolute === overlay.selected

                        onPicked: {
                            if (overlay.selected === parent.absolute)
                                overlay.activate();
                            else
                                overlay.select(parent.absolute);
                        }
                    }
                }

                // --- Page indicator -------------------------------------------
                PageDots {
                    x: gridScreen.gridLeft + (gridScreen.gridWidth - width) / 2
                    y: 724
                    pages: overlay.pages
                    current: overlay.page
                    onPageRequested: target => overlay.goToPage(target)
                }

                // --- Key hints -------------------------------------------------
                Row {
                    x: gridScreen.gridLeft
                    y: 760
                    spacing: 6

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "←→↑↓"
                        color: Tokens.color.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.mute
                        text: "PREVIEW"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ENTER"
                        color: Tokens.color.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.mute
                        text: "APPLY"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ESC"
                        color: Tokens.color.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.mute
                        text: "REVERT AND CLOSE"
                    }
                }

                // --- Wallpaper column -------------------------------------------
                WallpaperColumn {
                    x: 1320
                    y: gridScreen.gridTop

                    onPoolsRequested: overlay.show("pools")
                }

                // --- The way to the effects page --------------------------------
                // On the key hints' line and at the composition's right edge,
                // so it reads as a way out of this screen rather than as one
                // more thing on it. The wallpaper column's own `MANAGE
                // WALLPAPER POOLS` is the same button in the same role.
                Item {
                    id: effectsButton

                    x: 1710 - width
                    y: 756
                    // **The whole row, not just the word.** It was sized from
                    // the label alone while it holds the label *and* its
                    // katakana, so the tag was pressed against the chamfer and
                    // the word against the left edge.
                    width: effectsRow.implicitWidth + 40
                    height: 30

                    ChamferPanel {
                        anchors.fill: parent

                        chamfer: 8
                        chamferTopRight: 0
                        chamferBottomLeft: 8
                        // Opaque, blended rather than laid over: it sits on a
                        // wallpaper, and a translucent accent fill lets the
                        // image through the label.
                        fillColor: Theme.blend(Tokens.color.ground, Tokens.color.accent, effectsHover.hovered ? 0.24 : 0.14)
                        borderColor: Tokens.color.accent

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: Tokens.motion.feedback
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.motion.easeIn
                            }
                        }
                    }

                    Row {
                        id: effectsRow

                        anchors.centerIn: parent
                        spacing: 8

                        NrLabel {
                            id: effectsLabel

                            anchors.verticalCenter: parent.verticalCenter
                            centred: true
                            color: Tokens.color.accent
                            text: "EFFECTS"
                        }

                        KanaTag {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "演出"
                            title: effectsLabel
                        }
                    }

                    HoverHandler {
                        id: effectsHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    Feedback {
                        id: effectsFeedback

                        anchors.fill: parent
                        flashOpacity: 0.3
                    }

                    TapHandler {
                        onPressedChanged: if (pressed) effectsFeedback.flash()
                        onTapped: overlay.show("effects")
                    }
                }

                // --- The way to the privacy page, beside EFFECTS -------------------------
                // On the key hints' line and at the composition's right edge,
                // so it reads as a way out of this screen rather than as one
                // more thing on it. The wallpaper column's own `MANAGE
                // WALLPAPER POOLS` is the same button in the same role.
                Item {
                    id: privacyButton

                    x: effectsButton.x - width - 12
                    y: 756
                    // **The whole row, not just the word.** It was sized from
                    // the label alone while it holds the label *and* its
                    // katakana, so the tag was pressed against the chamfer and
                    // the word against the left edge.
                    width: privacyRow.implicitWidth + 40
                    height: 30

                    ChamferPanel {
                        anchors.fill: parent

                        chamfer: 8
                        chamferTopRight: 0
                        chamferBottomLeft: 8
                        // Opaque, blended rather than laid over: it sits on a
                        // wallpaper, and a translucent accent fill lets the
                        // image through the label.
                        fillColor: Theme.blend(Tokens.color.ground, Tokens.color.accent, privacyHover.hovered ? 0.24 : 0.14)
                        borderColor: Tokens.color.accent

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: Tokens.motion.feedback
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.motion.easeIn
                            }
                        }
                    }

                    Row {
                        id: privacyRow

                        anchors.centerIn: parent
                        spacing: 8

                        NrLabel {
                            id: privacyLabel

                            anchors.verticalCenter: parent.verticalCenter
                            centred: true
                            color: Tokens.color.accent
                            text: "PRIVACY"
                        }

                        KanaTag {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "秘匿"
                            title: privacyLabel
                        }
                    }

                    HoverHandler {
                        id: privacyHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    Feedback {
                        id: privacyFeedback

                        anchors.fill: parent
                        flashOpacity: 0.3
                    }

                    TapHandler {
                        onPressedChanged: if (pressed) privacyFeedback.flash()
                        onTapped: overlay.show("privacy")
                    }
                }

                // --- The way to the system page, beside PRIVACY -------------------------
                // On the key hints' line and at the composition's right edge,
                // so it reads as a way out of this screen rather than as one
                // more thing on it. The wallpaper column's own `MANAGE
                // WALLPAPER POOLS` is the same button in the same role.
                Item {
                    id: systemButton

                    x: privacyButton.x - width - 12
                    y: 756
                    // **The whole row, not just the word.** It was sized from
                    // the label alone while it holds the label *and* its
                    // katakana, so the tag was pressed against the chamfer and
                    // the word against the left edge.
                    width: systemRow.implicitWidth + 40
                    height: 30

                    ChamferPanel {
                        anchors.fill: parent

                        chamfer: 8
                        chamferTopRight: 0
                        chamferBottomLeft: 8
                        // Opaque, blended rather than laid over: it sits on a
                        // wallpaper, and a translucent accent fill lets the
                        // image through the label.
                        fillColor: Theme.blend(Tokens.color.ground, Tokens.color.accent, systemHover.hovered ? 0.24 : 0.14)
                        borderColor: Tokens.color.accent

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: Tokens.motion.feedback
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.motion.easeIn
                            }
                        }
                    }

                    Row {
                        id: systemRow

                        anchors.centerIn: parent
                        spacing: 8

                        NrLabel {
                            id: systemLabel

                            anchors.verticalCenter: parent.verticalCenter
                            centred: true
                            color: Tokens.color.accent
                            text: "SYSTEM"
                        }

                        KanaTag {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "設定"
                            title: systemLabel
                        }
                    }

                    HoverHandler {
                        id: systemHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    Feedback {
                        id: systemFeedback

                        anchors.fill: parent
                        flashOpacity: 0.3
                    }

                    TapHandler {
                        onPressedChanged: if (pressed) systemFeedback.flash()
                        onTapped: overlay.show("system")
                    }
                }
            }
            }

            // --- The custom editor ---------------------------------------------
            Appear {
                anchors.fill: parent
                fills: true
                shown: overlay.view === "editor"

            CustomEditor {
                id: editorScreen

                anchors.fill: parent
                editing: overlay.editing

                onFinished: name => {
                    overlay.show("grid");
                    if (name) {
                        const at = overlay.entries.findIndex(entry => entry.name === name);
                        if (at >= 0)
                            overlay.select(at);
                    }
                }
                onCancelled: overlay.show("grid")
            }
            }

            // --- The system page -------------------------------------------------
            Appear {
                anchors.fill: parent
                fills: true
                shown: overlay.view === "system"

            SystemPage {
                id: systemScreen

                anchors.fill: parent

                onFinished: overlay.show("grid")
            }
            }

            // --- The privacy page ------------------------------------------------
            Appear {
                anchors.fill: parent
                fills: true
                shown: overlay.view === "privacy"

            PrivacyPage {
                id: privacyScreen

                anchors.fill: parent

                onFinished: overlay.show("grid")
            }
            }

            // --- The pools screen ------------------------------------------------
            Appear {
                anchors.fill: parent
                fills: true
                shown: overlay.view === "effects"

            EffectsPage {
                id: effectsScreen

                anchors.fill: parent

                onFinished: overlay.show("grid")
            }
            }

            Appear {
                anchors.fill: parent
                fills: true
                shown: overlay.view === "pools"

            PoolsScreen {
                id: poolsScreen

                anchors.fill: parent

                onFinished: overlay.show("grid")
            }
            }
        }

        // Left and right by one, up and down by a row, across page boundaries
        // by themselves -- the selection is an index into every profile, and
        // the page follows it rather than bounding it.
        //
        // **The grid's keys are gated inside each handler, not by disabling
        // this item.** It used to carry `enabled: overlay.view === "grid"`;
        // disabling an item drops its active focus and re-enabling does not
        // give it back, so coming out of the editor or the pools left the
        // surface holding the keyboard with no item to deliver it to, and
        // Escape did nothing at all.
        OverlayKeys {
            id: keys

            anchors.fill: parent
            active: overlay.shown

            onEscaped: overlay.dismiss()

            readonly property bool onGrid: overlay.view === "grid"
            readonly property bool onPools: overlay.view === "pools"

            Keys.onLeftPressed: if (onGrid) overlay.move(-1)
            Keys.onRightPressed: if (onGrid) overlay.move(1)
            Keys.onUpPressed: if (onGrid) overlay.move(-overlay.columns)
            Keys.onDownPressed: if (onGrid) overlay.move(overlay.columns)
            Keys.onReturnPressed: overlay.accept()
            Keys.onEnterPressed: overlay.accept()
            // Delete asks about the selected custom profile, and Enter answers
            // it. The picker is arrow-driven; a card that can only be removed
            // with the pointer would be the one thing in it that is not. On
            // the pools screen the same two keys act on the focused chip, and
            // do nothing when there is not one.
            Keys.onDeletePressed: {
                if (onGrid)
                    overlay.askToRemove();
                else if (onPools)
                    poolsScreen.removeFocused();
            }

            // Tab walks the pools screen's chips. It is the only screen with
            // a keyboard position of its own, so this is gated on it rather
            // than being a general affordance.
            Keys.onTabPressed: event => {
                if (!onPools)
                    return;
                poolsScreen.stepFocus(1);
                event.accepted = true;
            }
            Keys.onBacktabPressed: event => {
                if (!onPools)
                    return;
                poolsScreen.stepFocus(-1);
                event.accepted = true;
            }
        }
    }
}

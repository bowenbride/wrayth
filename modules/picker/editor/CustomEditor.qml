import QtQuick
import qs.components
import qs.config
import qs.services

// CUSTOM // EDIT. Nine colours, a picker for whichever one is selected, and a
// live preview of what they make. The other seven tokens of a palette are
// relationships between these nine and are derived on save, so this asks for
// colours rather than for a colour system.
Item {
    id: root

    // The custom profile being edited, or "" for a new one.
    property string editing: ""

    signal finished(string name)
    signal cancelled

    // One step back, for the overlay's Escape. False means "nothing of mine
    // was up", and the overlay leaves the screen instead.
    function back(): bool {
        if (root.naming) {
            root.naming = false;
            return true;
        }
        return false;
    }

    readonly property bool creating: !editing

    // The nine being edited. Seeded from the profile on the way in, or from
    // Circuit for a new one -- a blank palette would be nine blacks, and the
    // first thing anyone would do with it is pick a preset anyway. It holds
    // Circuit's from the moment it is built rather than from the moment it is
    // shown, so nothing downstream ever binds to an empty palette.
    property var colors: Profiles.nineOf("Circuit")
    property string activeKey: "accent"
    property bool naming: false
    property string pendingName: ""

    // Everything downstream of the nine. The preview paints from this, so what
    // is on screen is exactly what a save would store.
    readonly property var palette: Profiles.derive(root.colors)

    function seed(from: string): void {
        colors = Profiles.nineOf(from);
    }

    // Driven by `picker colour <key> <hex>`. It goes through `set` like the
    // colour picker does, so the live preview and the derived tokens follow
    // exactly as they would under a pointer.
    Connections {
        target: ShellState

        function onEditorSave(name: string): void {
            if (!root.visible)
                return;
            root.naming = false;
            root.store(name);
        }

        function onEditorColour(key: string, hex: string): void {
            if (!root.visible)
                return;
            root.activeKey = key;
            root.set(key, hex);
        }
    }

    function set(key: string, hex: string): void {
        const next = Object.assign({}, root.colors);
        next[key] = hex;
        colors = next;
    }

    // Enter saves, the way it does everywhere else in the shell. The editor is
    // a form and the pointer is not the only way through it.
    function save(): void {
        if (root.creating)
            root.naming = true;
        else
            root.store(root.editing);
    }

    function store(name: string): void {
        Customs.store(name, root.colors);
        // The wallpaper is generated from the palette that was just stored --
        // for a new profile and for an edited one alike, since editing the
        // accent is exactly the case where the old wallpaper stops matching.
        wallpaper.restart();
        pendingName = name;
    }

    // One beat, so `Profiles.palettes` has the new entry before the generator
    // is asked for its accent and signal.
    Timer {
        id: wallpaper

        interval: 50
        onTriggered: {
            Wallpapers.generate(root.pendingName, null);
            Wallpapers.seed(root.pendingName);
            root.finished(root.pendingName);
        }
    }

    onVisibleChanged: {
        if (!visible)
            return;
        naming = false;
        activeKey = "accent";
        seed(editing || Theme.activeProfile);
    }

    // The panel's own bounds plus the `BACK` control above it.
    readonly property rect contentRect: Qt.rect(panel.x, back.y, panel.width, panel.y + panel.height - back.y)

    BackButton {
        id: back

        x: panel.x
        y: panel.y - 34

        onActivated: root.cancelled()
    }

    ChamferPanel {
        id: panel

        // **The panel ends where its content ends.** It was a fixed 760 px
        // with the buttons anchored to its bottom edge, which left about
        // 200 px of nothing between the colour list and `DISCARD` /
        // `SAVE PROFILE` -- a panel that looked as though something had failed
        // to load into it. The height is the header, the tallest of the three
        // columns, and the buttons.
        //
        // It is re-centred vertically rather than kept at its old top: a panel
        // that shrinks from a fixed `y` reads as having fallen upwards.
        readonly property real gutter: 24
        readonly property real body: Math.max(rows.height + 22 + startFrom.height, picker.height, preview.height)

        x: 250
        y: Math.round((parent.height - height) / 2)
        width: 1420
        height: gutter + header.height + 18 + body + 20 + buttons.height + gutter

        chamfer: Appearance.chamfer.panel
        fillColor: Theme.panel2
        borderColor: Theme.hair

        // --- Header -------------------------------------------------------
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                GlitchFx {
                    group: "overlay"
                    anchors.verticalCenter: parent.verticalCenter
                    fills: true
                    textual: true
                    width: editorTitle.implicitWidth
                    height: editorTitle.implicitHeight
                    scrambleItems: [editorTitle]

                    GlitchText {
                        id: editorTitle

                        anchors.fill: parent
                        text: `CUSTOM${Appearance.separator}EDIT`
                        pixelSize: 22
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "調整"
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
                color: Theme.dim
                text: root.creating ? "NEW PROFILE" : `EDITING${Appearance.separator}${root.editing.toUpperCase()}`
            }
        }

        // --- The nine ------------------------------------------------------
        Column {
            id: rows

            anchors.top: header.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.leftMargin: 24
            width: 520
            spacing: 2

            Repeater {
                model: Customs.roles

                SwatchRow {
                    required property var modelData

                    width: rows.width
                    tokenKey: modelData.key
                    role: modelData.role
                    value: root.colors[modelData.key] ?? "#000000"
                    selected: root.activeKey === modelData.key

                    onPicked: root.activeKey = modelData.key
                }
            }
        }

        // --- Start from ------------------------------------------------------
        Column {
            id: startFrom

            anchors.top: rows.bottom
            anchors.topMargin: 22
            anchors.left: rows.left
            width: rows.width
            spacing: 8

            NrLabel {
                color: Theme.dim
                text: "START FROM"
            }

            Row {
                spacing: 8

                Repeater {
                    model: Profiles.presetNames

                    Rectangle {
                        required property string modelData

                        readonly property var preset: Profiles.presets[modelData]

                        width: 78
                        height: 26
                        color: preset.ground
                        border.width: Appearance.metrics.hairline
                        border.color: chipHover.hovered ? preset.accent : Theme.hair

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                color: parent.parent.preset.accent
                            }

                            NrLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                pixelSize: 10
                                color: parent.parent.preset.text
                                text: parent.parent.modelData
                            }
                        }

                        HoverHandler {
                            id: chipHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.seed(parent.modelData)
                        }
                    }
                }
            }
        }

        // --- Picker ------------------------------------------------------------
        ColourPickerPanel {
            id: picker

            anchors.top: rows.top
            anchors.left: rows.right
            anchors.leftMargin: 20
            width: 330
            height: 420

            tokenKey: root.activeKey
            value: root.colors[root.activeKey] ?? "#000000"
            palette: root.colors
            background: Customs.backgroundKeys.indexOf(root.activeKey) >= 0

            onChanged: hex => root.set(root.activeKey, hex)
        }

        // --- Preview -------------------------------------------------------------
        Column {
            id: preview

            anchors.top: rows.top
            anchors.left: picker.right
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 24
            spacing: 10

            NrLabel {
                color: Theme.dim
                text: `LIVE PREVIEW${Appearance.separator}NOT APPLIED YET`
            }

            LivePreview {
                width: parent.width
                palette: root.palette
            }

            Text {
                width: parent.width
                text: "deep, track, mute, cell and the translucent panel fills are derived from these nine."
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 10
                wrapMode: Text.Wrap
                renderType: Text.NativeRendering
            }
        }

        // --- Buttons ---------------------------------------------------------------
        Row {
            id: buttons

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: panel.gutter
            spacing: 12

            ActionButton {
                text: "DISCARD"
                onClicked: root.cancelled()
            }

            ActionButton {
                text: "SAVE PROFILE"
                accented: true
                onClicked: root.save()
            }
        }
    }

    // --- The name prompt -----------------------------------------------------------
    // Scrim and prompt as one object, on one opacity.
    Appear {
        anchors.fill: parent
        fills: true
        shown: root.naming

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
    }

    NamePrompt {
        id: prompt

        anchors.centerIn: parent

        onAccepted: name => {
            root.naming = false;
            root.store(name);
        }
        onCancelled: root.naming = false
    }
    }

    // The prompt takes the keyboard while it is up and gives it back by
    // clearing its own field's focus, which the overlay's key owner notices --
    // this screen holds no focus of its own. **It used to**, and a screen that
    // grabs focus and then hides is half of how the picker trapped the
    // keyboard.
    //
    // The focus is taken a tick later: the handler runs before the prompt's
    // `Appear` wrapper has become visible, and focusing into a hidden subtree
    // is the same stale-order trap that left the Wi-Fi passphrase field deaf
    // on its first use.
    onNamingChanged: if (naming) {
        prompt.value = "";
        Qt.callLater(prompt.take);
    }

}

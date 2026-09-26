import QtQuick
import qs.components
import qs.config
import qs.services
import qs.modules.picker

// EFFECTS // 演出: the picker's fourth view, beside the custom editor and the
// wallpaper pools.
//
// **It used to be a strip of chips under the profile screen's key hints.** Six
// scanline treatments cannot be chosen from three-letter labels -- a rolling
// band and a vignette are not more of the same thing, they are different
// looks -- so each one is a tile that renders the sample it describes.
//
// Everything here applies live and saves itself. There is no apply button:
// `Effects` writes `~/.config/wrayth/effects.json` on every change and the
// shell is bound to it, so a press lands on the shell before the finger is off
// the button.
Item {
    id: root

    signal finished

    // One step back, for the overlay's Escape. Nothing on this page opens a
    // question of its own, so there is never a step to take before leaving.
    function back(): bool {
        return false;
    }

    // Laid out at the composition's own coordinates, like the grid screen: the
    // header, the tiles and the rows below them are one thing, and centring
    // each piece separately is what lets them drift apart.
    // **Not `left` and `right`.** An `Item` already has both, as anchor
    // lines, and overriding them is a FINAL property collision that will not
    // load at all.
    readonly property int originX: 250
    readonly property int endX: 1710
    readonly property int span: endX - originX

    // Everything the page draws. The backdrop dismisses outside this and
    // nowhere else -- **a control outside this rectangle would close the
    // picker whenever it was used.**
    readonly property rect contentRect: Qt.rect(originX - 38, 145, span + 76, 946 - 145)

    // --- Back ---------------------------------------------------------------
    // Top-left of the composition, above the header, at the same coordinates
    // on every view that takes the screen.
    // The full-screen header row (DESIGN.md): BackControl, title, status.
    BackButton {
        id: back
        x: root.originX
        y: 151 + Math.round((46 - height) / 2)

        onActivated: root.finished()
    }

    // --- Header -----------------------------------------------------------------
    Item {
        id: header

        x: root.originX
        y: 151
        width: root.span
        height: 46

        Row {
            anchors.left: parent.left
            anchors.leftMargin: back.width + Tokens.space.s16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            GlitchFx {
                group: "overlay"
                anchors.verticalCenter: parent.verticalCenter
                fills: true
                textual: true
                width: effectsTitle.implicitWidth
                height: effectsTitle.implicitHeight
                scrambleItems: [effectsTitle]

                GlitchText {
                    id: effectsTitle

                    anchors.fill: parent
                    text: "EFFECTS"
                    // The full-screen view title role (DESIGN.md): 22 px, 0.12em.
                    pixelSize: Tokens.type.viewTitle.size
                    tracking: Tokens.type.viewTitle.tracking
                }
            }

            KanaTag {
                anchors.verticalCenter: parent.verticalCenter
                text: "演出"
                title: effectsTitle
            }
        }

        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.color.accent
            text: "SAVED WITH THE PROFILE SETTINGS    APPLIED LIVE"
        }
    }

    NrLabel {
        x: root.originX
        y: 223
        color: Tokens.color.dim
        text: "HOW THE SHELL WEARS ITS AGE    THE SCANLINE OVERLAY AND THE GLITCH SCHEDULE"
    }

    // --- Treatments ---------------------------------------------------------------
    NrLabel {
        id: treatmentsLabel

        x: root.originX
        y: 262
        color: Tokens.color.text
        text: `SCANLINE TREATMENTS · ${Effects.treatment.name}`
    }

    Row {
        id: tiles

        x: root.originX
        y: 286
        width: root.span
        spacing: 16

        Repeater {
            model: Effects.treatments

            TreatmentTile {
                required property var modelData

                treatment: modelData
                selected: Effects.scanlines === modelData.key

                onPicked: Effects.setScanlines(modelData.key)
            }
        }
    }

    // --- Coverage -------------------------------------------------------------------
    Row {
        id: coverage

        x: root.originX
        y: 550
        spacing: 34

        EffectsChips {
            anchors.verticalCenter: parent.verticalCenter
            label: "COVERAGE"
            options: ["PANELS ONLY", "EVERYTHING"]
            // The stored value is `PANELS`; the label says `PANELS ONLY`,
            // because "panels" on its own reads as a category rather than as
            // "and nothing else".
            current: Effects.scanlinesOver === "PANELS" ? "PANELS ONLY" : "EVERYTHING"

            onChosen: mode => Effects.setScanlinesOver(mode === "EVERYTHING" ? "EVERYTHING" : "PANELS")
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Tickbox {
                anchors.verticalCenter: parent.verticalCenter
                checked: Effects.excludeWindowContent

                onToggled: Effects.setExcludeWindowContent(!Effects.excludeWindowContent)
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.text
                text: "EXCLUDE WINDOW CONTENT"
            }
        }

        // **Greyed and forced on while the one beside it is.** A fullscreen
        // window is window content, so with that excluded this cannot be
        // anything but true -- and a checkbox that can only be true should say
        // so rather than pretend to be a choice.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            opacity: Effects.fullscreenLocked ? 0.45 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            Tickbox {
                anchors.verticalCenter: parent.verticalCenter
                checked: Effects.excludeFullscreen
                enabled: !Effects.fullscreenLocked

                onToggled: Effects.setExcludeFullscreen(!Effects.excludeFullscreen)
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Effects.fullscreenLocked ? Tokens.color.mute : Tokens.color.text
                text: "EXCLUDE FULLSCREEN"
            }
        }
    }

    // --- Glitch ----------------------------------------------------------------------
    EffectsChips {
        id: glitchChips

        x: root.originX
        y: 600
        label: "GLITCH"
        options: Effects.glitchModes
        current: Effects.glitch

        onChosen: mode => Effects.setGlitch(mode)
    }

    // The timing, which is what OFF / RARE / NORMAL are shorthand for. It is
    // dimmed rather than hidden while the schedule is off: the numbers are
    // still what it will do when it is switched back on.
    //
    // **Typing stages; APPLY commits.** Validation happens on the whole set at
    // once, because FROM and TO are only right or wrong together, and it says
    // what is wrong rather than silently correcting the number under the
    // user's hands -- which is what the old per-keystroke clamp did.
    property string timingError: ""

    readonly property bool timingDirty: Effects.glitchRange ? (fromField.dirty || toField.dirty) : everyField.dirty

    function applyTiming(): void {
        const whole = value => /^[0-9]+$/.test(value.trim()) ? parseInt(value.trim()) : NaN;
        if (Effects.glitchRange) {
            const from = whole(fromField.text);
            const to = whole(toField.text);
            if (isNaN(from) || isNaN(to)) {
                root.timingError = "WHOLE SECONDS ONLY";
                return;
            }
            if (from < Effects.minSeconds || to < Effects.minSeconds || from > Effects.maxSeconds || to > Effects.maxSeconds) {
                root.timingError = `${Effects.minSeconds} TO ${Effects.maxSeconds} SECONDS`;
                return;
            }
            if (from > to) {
                root.timingError = "FROM CANNOT BE ABOVE TO";
                return;
            }
            root.timingError = "";
            Effects.commitRange(from, to);
        } else {
            const every = whole(everyField.text);
            if (isNaN(every)) {
                root.timingError = "WHOLE SECONDS ONLY";
                return;
            }
            if (every < Effects.minSeconds || every > Effects.maxSeconds) {
                root.timingError = `${Effects.minSeconds} TO ${Effects.maxSeconds} SECONDS`;
                return;
            }
            root.timingError = "";
            Effects.commitEvery(every);
        }
        fromField.release();
        toField.release();
        everyField.release();
    }

    // A staged value stops being wrong the moment it is edited again.
    onTimingDirtyChanged: if (!timingDirty) timingError = ""

    Row {
        id: timing

        x: root.originX
        y: 646
        spacing: 12
        opacity: Effects.glitch === "OFF" ? 0.45 : 1
        enabled: Effects.glitch !== "OFF"

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            // The same slot the GLITCH label above it takes, so the two rows
            // line up at their controls rather than at their words.
            width: glitchChips.labelWidth
            color: Tokens.color.dim
            text: "RANGE"
        }

        ToggleButton {
            anchors.verticalCenter: parent.verticalCenter
            on: Effects.glitchRange

            onToggled: Effects.setGlitchRange(!Effects.glitchRange)
        }

        // **Both sets of fields are always here.** Swapping one row for
        // another would move everything after it every time the toggle was
        // pressed; the set that is not in use is simply not drawn, and its
        // space is the other set's.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(rangeFields.implicitWidth, everyFields.implicitWidth)
            height: Math.max(rangeFields.implicitHeight, everyFields.implicitHeight)

            Row {
                id: rangeFields

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: Effects.glitchRange

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.dim
                    text: "FROM"
                }

                SecondsField {
                    id: fromField

                    anchors.verticalCenter: parent.verticalCenter
                    committed: Effects.glitchFrom

                    onAccepted: root.applyTiming()
                }

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.dim
                    text: "TO"
                }

                SecondsField {
                    id: toField

                    anchors.verticalCenter: parent.verticalCenter
                    committed: Effects.glitchTo

                    onAccepted: root.applyTiming()
                }

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.dim
                    text: "SEC"
                }
            }

            Row {
                id: everyFields

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: !Effects.glitchRange

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.dim
                    text: "EVERY"
                }

                SecondsField {
                    id: everyField

                    anchors.verticalCenter: parent.verticalCenter
                    committed: Effects.glitchEvery

                    onAccepted: root.applyTiming()
                }

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.dim
                    text: "SEC"
                }
            }
        }

        ActionButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "APPLY"
            accented: root.timingDirty
            usable: root.timingDirty

            onClicked: root.applyTiming()
        }

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            // A fixed slot, so a message appearing moves nothing.
            width: 260
            color: Tokens.color.alert
            elide: Text.ElideRight
            text: root.timingError
        }
    }

    // --- What a glitch is made of ---------------------------------------------
    EffectsToggles {
        id: poolRow

        x: root.originX
        y: 690
        label: "EFFECTS IN THE POOL"
        options: Effects.allEffects.map(name => ({
                    key: name,
                    text: name,
                    on: Effects.effectOn(name)
                }))

        onToggled: name => Effects.toggleEffect(name)
    }

    Row {
        x: root.originX
        y: 730
        spacing: 34

        EffectsChips {
            anchors.verticalCenter: parent.verticalCenter
            label: "EFFECTS PER GLITCH"
            options: Effects.countModes.map(mode => Effects.countLabels[mode])
            current: Effects.countLabels[Effects.glitchCount]

            onChosen: label => Effects.setGlitchCount(Effects.countModes.find(mode => Effects.countLabels[mode] === label))
        }

        EffectsChips {
            anchors.verticalCenter: parent.verticalCenter
            label: "OVERLAP"
            options: Effects.overlapModes.map(mode => Effects.overlapLabels[mode])
            current: Effects.overlapLabels[Effects.glitchOverlap]

            onChosen: label => Effects.setGlitchOverlap(Effects.overlapModes.find(mode => Effects.overlapLabels[mode] === label))
        }
    }

    Row {
        x: root.originX
        y: 770
        spacing: 24

        EffectsToggles {
            anchors.verticalCenter: parent.verticalCenter
            label: "TARGETS"
            options: Effects.allGroups.map(name => ({
                        key: name,
                        text: Effects.groupLabels[name],
                        on: Effects.groupOn(name)
                    }))

            onToggled: name => Effects.toggleGroup(name)
        }

        // **Fires one now, on a visible element, with the settings as they
        // stand.** A change to the pool or the count cannot be judged by
        // waiting out an interval.
        ActionButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "PREVIEW"
            accented: true

            onClicked: {
                const result = Glitch.preview();
                previewNote.text = result === "nothing visible to glitch" ? "NOTHING VISIBLE TO GLITCH" : "";
                previewClear.restart();
            }
        }

        NrLabel {
            id: previewNote

            anchors.verticalCenter: parent.verticalCenter
            width: 220
            color: Tokens.color.alert
            elide: Text.ElideRight
        }
    }

    Timer {
        id: previewClear

        interval: 2600
        onTriggered: previewNote.text = ""
    }

    // --- What it costs -------------------------------------------------------------
    Column {
        x: root.originX
        y: 818
        width: root.span
        spacing: 4

        NrLabel {
            color: Tokens.color.dim
            text: "COST"
        }

        Text {
            width: parent.width
            text: "The lines are one tiled texture per surface and measured inside the run-to-run spread on a test laptop: 15.6% of a core with them off against 16.1% with them on everything. The rolling band adds a second layer with an animation behind it, and the vignette a third, and both are paid on every surface they are drawn on -- so FINE + ROLLING BAND and FULL CRT cost more than the three above them, and EVERYTHING costs more than PANELS ONLY."
            color: Tokens.color.text
            font.family: Tokens.font.data
            font.pixelSize: 11
            wrapMode: Text.Wrap
            renderType: Text.NativeRendering
        }
    }

    // --- Key hints -------------------------------------------------------------------
    Row {
        x: root.originX
        y: 906
        spacing: 6

        Keycap {
            anchors.verticalCenter: parent.verticalCenter
            key: "ESC"
            color: Tokens.color.mute
        }

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.color.mute
            text: "BACK TO THE PROFILES    EVERY CHANGE HERE IS ALREADY SAVED"
        }
    }
}

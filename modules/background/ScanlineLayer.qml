import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.services

// The one surface in the shell that draws over application windows, and it
// exists only when the user has asked for that.
//
// **`EXCLUDE WINDOW CONTENT` is what decides whether this surface exists at
// all.** Every other scanline overlay is a child of a shell surface, and a
// shell surface never draws over a window -- the bar is above the desktop and
// the wallpaper is below every window. So lines can reach an application
// window, a video or the terminal's contents by exactly one route: a
// deliberate full-screen layer, this one. With the exclusion on there is no
// such surface, which is a stronger guarantee than a filter.
//
// **`EXCLUDE FULLSCREEN` takes the surface away over a fullscreen window**, and
// is forced on while the window-content exclusion is -- a fullscreen window is
// window content, so a checkbox that could disagree would be lying.
//
// It takes no input at all: an empty mask means every click, hover and scroll
// goes through it to whatever is underneath.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: layer

        required property ShellScreen modelData

        // **Hyprland's cached workspace object does not update on a
        // fullscreen change.** `hasfullscreen` read straight off
        // `activeWorkspace.lastIpcObject` stayed false through a real
        // fullscreen -- measured, with `hyprctl workspaces` saying true at the
        // same moment. The workspaces have to be refreshed first, and the
        // `fullscreen` event is what says to.
        // **Read, not bound.** `Hyprland.monitorFor()` is a function call, so a
        // binding through it captures whatever it returned when the binding
        // was first evaluated and never runs again -- the flag sat at false
        // through a real fullscreen while `hyprctl workspaces` said true.
        // And the cached workspace object does not update on a fullscreen
        // change by itself, so the refresh has to be asked for and then read
        // a beat later, because it is asynchronous.
        property bool fullscreen: false

        function syncFullscreen(): void {
            const workspace = Hyprland.monitorFor(layer.screen)?.activeWorkspace?.lastIpcObject ?? null;
            layer.fullscreen = (workspace?.hasfullscreen ?? false) === true;
        }

        Timer {
            id: settle

            interval: 60
            onTriggered: layer.syncFullscreen()
        }

        Connections {
            target: Hyprland

            function onRawEvent(event: HyprlandEvent): void {
                // `fullscreen` fires on the change itself; the others are the
                // ways a fullscreen window can arrive on or leave this monitor
                // without one.
                if (!["fullscreen", "workspace", "focusedmon", "closewindow", "openwindow", "activespecial"].includes(event.name))
                    return;
                Hyprland.refreshWorkspaces();
                settle.restart();
            }
        }

        // The shell can start with a window already fullscreen, and no event
        // will be along to say so.
        Component.onCompleted: {
            Hyprland.refreshWorkspaces();
            settle.restart();
        }

        screen: modelData
        color: "transparent"
        visible: Effects.scanlinesOverWindows && !(Effects.excludeFullscreen && layer.fullscreen)

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-scanlines"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Nothing here is clickable, and everything under it is. An empty
        // region is the whole surface passed through.
        mask: Region {}

        Scanlines {
            surface: "windows"
        }
    }
}

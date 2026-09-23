import QtQuick
import qs.config
import qs.services

// The interaction state machine behind every action in the shell that takes
// time. It is not visual: `ActionButton` and the other clickables read `phase`
// and render it. Keeping it separate is what lets a row, a tile, a toggle and a
// panel all show the same five states without repeating the logic.
//
//   idle -> working -> success -> idle
//                   -> failure -> idle
//
// A caller does `begin("LINKING")`, then `succeed()` or `fail("WRONG
// PASSPHRASE")`. Nothing else has to be tracked: the timeout, the hold before
// returning to idle, and the notification on a system error are all here.
QtObject {
    id: root

    // idle | working | success | failure
    property string phase: "idle"
    // The verb shown in place of the label while working: LINKING, CONNECTING,
    // SCANNING, FORGETTING, UNLINKING, APPLYING, VERIFYING.
    property string verb: ""
    // The short reason shown on failure, without the `FAILED // ` prefix.
    property string reason: ""

    readonly property bool working: phase === "working"
    readonly property bool succeeded: phase === "success"
    readonly property bool failed: phase === "failure"

    // How long a working state may run before it is called a failure.
    property int timeoutMs: 20000
    // How long the failure reason stays up before the element returns to normal.
    property int failureMs: 3000
    // The success flash is brief: the element's new state is the real feedback.
    property int successMs: 400

    signal finished(bool ok)

    function begin(actionVerb: string): void {
        verb = actionVerb;
        reason = "";
        phase = "working";
        settle.stop();
        limit.restart();
    }

    function succeed(): void {
        if (phase !== "working")
            return;
        limit.stop();
        phase = "success";
        settle.interval = successMs;
        settle.restart();
        finished(true);
    }

    // `detail` is the system's own error text, if there was one. It is not shown
    // on the element -- there is no room for it -- so it goes out as a normal
    // notification instead, which is also what leaves a record of it.
    function fail(why: string, detail: string): void {
        limit.stop();
        reason = why;
        phase = "failure";
        settle.interval = failureMs;
        settle.restart();
        if (detail)
            Notifications.send(`${verb || "ACTION"} FAILED`, detail);
        finished(false);
    }

    // Drop straight back to idle without showing an outcome, for a caller that
    // has been superseded -- a dropdown closing mid-action, say.
    function reset(): void {
        limit.stop();
        settle.stop();
        phase = "idle";
        verb = "";
        reason = "";
    }

    property Timer limit: Timer {
        interval: root.timeoutMs
        onTriggered: root.fail("TIMEOUT", "")
    }

    property Timer settle: Timer {
        interval: root.failureMs
        onTriggered: {
            root.phase = "idle";
            root.verb = "";
            root.reason = "";
        }
    }
}

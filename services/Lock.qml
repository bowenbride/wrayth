pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.services

// The lockscreen's authentication. PAM reads wrayth's own stack from
// assets/pam.d, so nothing has to be installed under /etc and no root is
// needed -- see DESIGN.md.
//
// **Nothing here can block the interface.** Quickshell runs the PAM
// conversation in a forked child and talks to it over a pipe watched by the
// event loop, so the clock and the input keep running whatever PAM is doing.
// What this file adds is that a conversation which never finishes cannot hold
// the panel in VERIFYING for ever either: `authWatchdog` aborts it.
Singleton {
    id: root

    // "", "checking", "denied" or "granted".
    property string state: ""
    property int attempts: 0
    property string buffer: ""
    // What PAM will actually be handed, captured the moment a submit is
    // accepted. Keeping it apart from `buffer` means nothing typed afterwards
    // can leak into an attempt already in flight.
    property string pending: ""
    // Every PAM attempt counts against pam_faillock, so a stray repeat must not
    // be able to stack them up.
    property real lastSubmit: 0
    readonly property int submitCooldownMs: 500

    readonly property bool busy: state === "checking"
    readonly property bool granted: state === "granted"

    readonly property int maxLength: 16

    // A one-line reason for the last attempt ending without a verdict, shown
    // in place of the usual message ("timeout"), or "".
    property string notice: ""

    // --- faillock lockout ---------------------------------------------------
    // True while pam_faillock is refusing every attempt, correct or not.
    property bool lockedOut: false
    // When the lockout ends (ms since the epoch), or 0 when that is not known.
    // Known from the tally file when it is readable (it normally is: the tally
    // is the user's own file); otherwise from PAM's "(N minutes left to
    // unlock)" line, which is only a whole-minute ceiling.
    property real lockoutUntil: 0
    // "tally" (exact), "pam" (PAM's minute ceiling) or "" (no time given).
    property string lockoutSource: ""
    // Seconds left, refreshed by `lockoutTick`.
    property int lockoutLeft: 0

    // Set by LockScreen when the lock cannot get the keyboard back by itself:
    // the panel then points to the console recovery.
    property bool keyboardLost: false

    signal unlockRequested

    function type(character: string): void {
        if (busy || granted || buffer.length >= 64)
            return;
        buffer += character;
        if (state === "denied")
            state = "";
    }

    function backspace(): void {
        if (busy || granted)
            return;
        buffer = buffer.slice(0, -1);
    }

    function clear(): void {
        buffer = "";
    }

    function submit(): void {
        if (busy || granted || !buffer)
            return;
        const now = Date.now();
        if (now - lastSubmit < submitCooldownMs)
            return;
        lastSubmit = now;

        // **A lockout with an exact end is waited out, not tried against.**
        // pam_faillock records a wrong password typed during a lockout as a
        // fresh failure, which restarts the lockout -- so a typo while locked
        // out would make the wait longer. The attempt is dropped here, before
        // PAM, with the countdown still showing; the tally is re-read so a
        // lockout an administrator has reset lifts at once. Stricter, never
        // looser: nothing reaches PAM that would not have.
        if (lockedOut && lockoutSource === "tally" && lockoutUntil > now) {
            buffer = "";
            tally.refresh();
            return;
        }

        pending = buffer;
        buffer = "";
        notice = "";
        state = "checking";
        pam.start();
    }

    // Called when the lock engages, so a second lock starts clean. The lockout
    // is not cleared: it belongs to the account, not to this lock, and the
    // tally is read again at once.
    function reset(): void {
        state = "";
        buffer = "";
        pending = "";
        notice = "";
        attempts = 0;
        tally.refresh();
    }

    function _finish(verdict: string): void {
        authWatchdog.stop();
        pending = "";
        buffer = "";
        state = verdict;
        if (verdict === "denied") {
            attempts += 1;
            tally.refresh();
        }
    }

    PamContext {
        id: pam

        config: "passwd"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onActiveChanged: {
            if (active)
                authWatchdog.restart();
        }

        // Every message, not only a change of `responseRequired`: that
        // property only signals when it *changes*, so a module prompting twice
        // in a row would never be answered and the child would wait on the
        // pipe for ever. The passphrase is handed over once; a second prompt
        // has no answer and ends the attempt.
        onPamMessage: {
            root._readLockoutMessage(message);
            if (!responseRequired)
                return;
            if (!root.pending) {
                // An empty answer is never sent: it could only mean this
                // context was started by something other than a deliberate
                // submit, and pam_faillock would count the failure all the
                // same.
                abort();
                authWatchdog.stop();
                root.state = "";
                return;
            }
            respond(root.pending);
            root.pending = "";
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                authWatchdog.stop();
                root.pending = "";
                root.lockedOut = false;
                root.lockoutUntil = 0;
                root.lockoutSource = "";
                root.state = "granted";
                root.unlockRequested();
                return;
            }
            root._finish("denied");
        }

        // `completed(Error)` follows every error, so the verdict is left to
        // onCompleted; nothing is counted twice.
        onError: error => {}
    }

    // PAM gave no verdict in time. Aborting kills the forked child; the attempt
    // ends without a verdict and is not counted here (pam_faillock may or may
    // not have recorded it, depending on where the child was).
    Timer {
        id: authWatchdog

        interval: 20000
        onTriggered: {
            if (!root.busy)
                return;
            pam.abort();
            root.pending = "";
            root.notice = "timeout";
            root.state = "";
        }
    }

    // --- Reading the lockout ------------------------------------------------

    // pam_faillock's own lines, as PAM relays them during `preauth`. English
    // only; in another locale the tally below still finds the lockout.
    function _readLockoutMessage(message: string): void {
        if (/account is locked/i.test(message)) {
            lockedOut = true;
        }
        const m = /\((\d+) minutes? left to unlock\)/i.exec(message);
        if (m) {
            lockedOut = true;
            if (lockoutSource !== "tally") {
                lockoutSource = "pam";
                lockoutUntil = Date.now() + Number(m[1]) * 60000;
            }
        }
    }

    // The same rule pam_faillock applies (check_tally in pam_faillock.c): the
    // valid failures within `fail_interval` of the latest one; locked when
    // there are at least `deny` of them and the latest is under `unlock_time`
    // old. `unlock_time = 0` never unlocks by itself.
    function _applyTally(lines: list<string>): void {
        const times = [];
        for (const line of lines) {
            const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\s.*\sV\s*$/.exec(line);
            if (m)
                times.push(new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6])).getTime());
        }
        const now = Date.now();
        if (times.length === 0) {
            _clearLockout();
            return;
        }
        const latest = Math.max(...times);
        const failures = times.filter(t => latest - t < conf.failInterval * 1000).length;
        const locked = conf.deny > 0 && failures >= conf.deny && (conf.unlockTime === 0 || latest + conf.unlockTime * 1000 >= now);
        if (!locked) {
            _clearLockout();
            return;
        }
        lockedOut = true;
        lockoutSource = conf.unlockTime === 0 ? "" : "tally";
        lockoutUntil = conf.unlockTime === 0 ? 0 : latest + conf.unlockTime * 1000;
        _tick();
    }

    function _clearLockout(): void {
        // Only a reading of the tally clears a lockout PAM reported; a PAM
        // estimate with no tally behind it runs out on its own clock.
        if (lockoutSource === "pam" && lockoutUntil > Date.now())
            return;
        lockedOut = false;
        lockoutUntil = 0;
        lockoutSource = "";
        lockoutLeft = 0;
    }

    function _tick(): void {
        if (!lockedOut)
            return;
        if (lockoutUntil > 0) {
            lockoutLeft = Math.max(0, Math.ceil((lockoutUntil - Date.now()) / 1000));
            if (lockoutLeft === 0) {
                lockedOut = false;
                lockoutUntil = 0;
                lockoutSource = "";
                tally.refresh();
            }
        }
    }

    // /etc/security/faillock.conf, which the shell's stack uses unmodified
    // (it passes pam_faillock no options). World-readable; defaults as
    // documented in faillock.conf(5).
    QtObject {
        id: conf

        property int deny: 3
        property int unlockTime: 600
        property int failInterval: 900
        property string dir: "/var/run/faillock"
    }

    FileView {
        path: "/etc/security/faillock.conf"
        printErrors: false

        onLoaded: {
            for (const raw of text().split("\n")) {
                const line = raw.replace(/#.*/, "").trim();
                const m = /^(\w+)\s*=\s*(\S+)$/.exec(line);
                if (!m)
                    continue;
                const value = m[2] === "never" ? 0 : Number(m[2]);
                if (m[1] === "deny" && !isNaN(value))
                    conf.deny = value;
                else if (m[1] === "unlock_time" && !isNaN(value))
                    conf.unlockTime = value;
                else if (m[1] === "fail_interval" && !isNaN(value))
                    conf.failInterval = value;
                else if (m[1] === "dir")
                    conf.dir = m[2];
            }
            tally.refresh();
        }
    }

    // `faillock --user <me>` reads the user's own tally file, which pam_faillock
    // creates owned by that user -- no privilege needed. An argument list, no
    // shell. If the file is unreadable the command prints nothing useful and
    // the lockout falls back to PAM's own message.
    Process {
        id: tally

        function refresh(): void {
            if (!running)
                running = true;
        }

        command: ["faillock", "--dir", conf.dir, "--user", Quickshell.env("USER") || ""]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: root._applyTally(text.split("\n"))
        }
    }

    Timer {
        id: lockoutTick

        interval: 1000
        repeat: true
        running: root.lockedOut
        onTriggered: {
            root._tick();
            // Re-read now and then, so a lockout reset by an administrator
            // (`faillock --reset`) lifts without waiting it out.
            if (++count % 5 === 0)
                tally.refresh();
        }

        property int count: 0
    }
}

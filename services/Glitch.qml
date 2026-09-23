pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The glitch scheduler. One of these, for the whole shell.
//
// The design system's glitch used to be a property of `GlitchText`: every
// display title ran its own 140 ms burst every 4 to 5 seconds, on its own
// clock, and nothing else in the shell ever glitched at all. That made the
// glitch a decoration on one component rather than a texture the shell has.
//
// Now: anything that may glitch wraps itself in a `components/GlitchFx.qml`
// and registers here. This picks **one** target at a time, a random set of
// effects, and a random duration, on a random interval that is never the same
// twice -- and it is also where events fire one deliberately.
//
// **Nothing registers that is not the shell's own interface.** The scope rule
// -- never over an application window, video, or the terminal's contents -- is
// a property of where `GlitchFx` is placed, not a filter here, because the
// shell does not draw over those surfaces in the first place.
Singleton {
    id: root

    // --- Registry -----------------------------------------------------------
    // The `GlitchFx` items currently alive. They add and remove themselves.
    property var targets: []

    function register(fx: var): void {
        if (root.targets.indexOf(fx) >= 0)
            return;
        root.targets = root.targets.concat([fx]);
    }

    function unregister(fx: var): void {
        root.release(fx);
        root.targets = root.targets.filter(other => other !== fx);
    }

    // --- Mode ---------------------------------------------------------------
    // **How often is entirely the user's**, and it is read fresh on every tick
    // rather than held here: see `Effects.nextInterval`. `RARE` and `NORMAL`
    // are presets that fill the same two fields, so there is one mechanism
    // and three ways to drive it.
    // **Silenced without changing the user's setting.** A recording wants
    // glitches it asked for and no others, and a demo that wrote `OFF` into
    // `effects.json` would be editing the user's configuration to take a
    // video. This is a runtime veto that leaves the setting alone, and a
    // config reload drops it -- which is the safe direction.
    property bool suppressed: false

    readonly property bool enabled: Effects.glitch !== "OFF" && !root.suppressed

    // --- What is running ----------------------------------------------------
    // **One element at a time.** Two at once reads as a rendering fault rather
    // than as the shell's own texture, so a glitch fired while one is running
    // waits for it.
    // **Everything running right now**, because the overlap setting can allow
    // more than one. It was a single `current`; `busy` is now a count against
    // the limit rather than a flag.
    property var running: []

    readonly property var current: root.running.length ? root.running[root.running.length - 1] : null
    readonly property bool busy: root.running.length >= Effects.overlapLimit

    // Event triggers that arrived while something was running, each with the
    // options they were fired with. The idle schedule does not queue -- it
    // simply rolls again.
    property var queue: []

    // **Only the target that is running may release the scheduler.** A target
    // going off screen mid-glitch stops itself, and if that call cleared
    // `current` unconditionally it would end somebody else's glitch and let a
    // second one start on top of the first.
    function release(fx: var): void {
        root.running = root.running.filter(other => other !== fx);
        drain.restart();
    }

    Timer {
        id: drain

        interval: 40
        onTriggered: root.next()
    }

    function next(): void {
        if (root.busy || !root.queue.length)
            return;
        const item = root.queue[0];
        root.queue = root.queue.slice(1);
        root.run(item.fx, item.options);
    }

    // --- Rolling a glitch ---------------------------------------------------
    readonly property var effectNames: ["SPLIT", "SLICE", "SCRAMBLE"]

    // **`WEIGHTED` is 70% one effect, 24% two, 6% all three.** An even split
    // made three effects feel like one noisy effect; the point of having three
    // is that two together is uncommon and three is something you notice. The
    // other three modes are flat: exactly one, one or two, one to three.
    function rollCount(): int {
        const mode = Effects.glitchCount;
        if (mode === "ONE")
            return 1;
        if (mode === "TWO")
            return 1 + Math.floor(Math.random() * 2);
        if (mode === "THREE")
            return 1 + Math.floor(Math.random() * 3);
        const r = Math.random();
        if (r < 0.7)
            return 1;
        if (r < 0.94)
            return 2;
        return 3;
    }

    // A random set of that many, drawn without replacement **from the pool the
    // user left switched on**.
    function rollEffects(count: int): var {
        const pool = Effects.glitchEffects.slice();
        const out = [];
        for (let i = 0; i < count && pool.length; i++)
            out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
        return out.length ? out : ["SPLIT"];
    }

    // 110 to 170 ms.
    function rollDuration(): int {
        return 110 + Math.floor(Math.random() * 61);
    }

    // **SCRAMBLE is dropped rather than the target being dropped.** A number
    // may split and slice; it may not flicker through junk, because a
    // scrambled figure is a lie for 150 ms and 150 ms is long enough to read
    // one. A target that cannot scramble still glitches, with what is left.
    function allowed(fx: var, effects: var): var {
        const out = effects.filter(name => name !== "SCRAMBLE" || fx.canScramble);
        // Everything was SCRAMBLE and the target is a number: give it SPLIT,
        // rather than a glitch that does nothing.
        return out.length ? out : ["SPLIT"];
    }

    function run(fx: var, options: var): void {
        if (!fx || !fx.eligible || root.running.indexOf(fx) >= 0)
            return;
        const opts = options ?? ({});
        const effects = root.allowed(fx, opts.effects ?? root.rollEffects(opts.count ?? root.rollCount()));
        const duration = opts.duration ?? root.rollDuration();
        root.running = root.running.concat([fx]);
        root.lastTarget = fx;
        fx.play(effects, duration);
    }

    // --- The idle schedule --------------------------------------------------
    // **Only a visible element in a switched-on group.** `eligible` is the
    // target's own business -- it is on screen and its host is not mid-edit --
    // and the group filter is the user's.
    function eligible(): var {
        return root.targets.filter(fx => fx.eligible && Effects.groupOn(fx.group));
    }

    // The target the last glitch ran on. **Never twice running**: with seven
    // eligible targets a uniform draw repeats one about one time in seven, and
    // a repeat reads as the shell being stuck rather than as its texture.
    property var lastTarget: null

    // **Weighted by the square root of the element's area.** A uniform draw
    // put as many glitches on a 40 px readout as on the deck's spectrum, and a
    // 160 ms glitch on a 40 px readout is not something anybody notices --
    // which is why the schedule looked broken when it was firing on time.
    // Square root rather than area, because area alone would mean the bar
    // never glitched while the deck was open.
    function pick(pool: var): var {
        const usable = pool.length > 1 ? pool.filter(fx => fx !== root.lastTarget) : pool;
        let total = 0;
        const weights = usable.map(fx => {
            const w = Math.sqrt(Math.max(1, fx.width * fx.height));
            total += w;
            return w;
        });
        let roll = Math.random() * total;
        for (let i = 0; i < usable.length; i++) {
            roll -= weights[i];
            if (roll <= 0)
                return usable[i];
        }
        return usable[usable.length - 1];
    }

    // **The schedule runs to a timestamp, not to a timer's own period.**
    // QML's `Timer` is a coarse timer: measured here, an interval of 10000 ms
    // fired at 9600 and one of 3000 at 2880 -- a consistent 4% early, which is
    // inside Qt's tolerance and nowhere near good enough for a setting that
    // says "exactly every N seconds". So the timer is only a way of waking up:
    // each wake checks the clock, and an early one just asks for the
    // remainder. That converges in two or three wakes a period and is exact to
    // the last of them.
    property real dueAt: 0

    function schedule_(): void {
        root.dueAt = Date.now() + root.roll();
        schedule.interval = Math.max(16, root.dueAt - Date.now());
        schedule.restart();
    }

    // `force` skips the clock, for the `qa tick` handler: the timestamp
    // schedule made that return early like any other wake, which took away the
    // one thing a test session had for driving the idle path.
    function tick(force: bool): void {
        const now = Date.now();
        const remaining = root.dueAt - now;
        if (!force && remaining > 20) {
            // Woken early by the coarse timer: go back for the rest of it.
            schedule.interval = remaining;
            return;
        }
        root.schedule_();
        if (!root.enabled || root.busy)
            return;
        const pool = root.eligible();
        if (!pool.length)
            return;
        root.run(root.pick(pool), null);
    }

    // **Re-rolled every time** while `RANGE` is on, so the schedule has no beat
    // to find. With `RANGE` off it is exactly the interval the user set, which
    // is metronomic on purpose and is the whole point of offering it.
    function roll(): int {
        return Effects.nextInterval();
    }

    Timer {
        id: schedule

        interval: 1000
        running: root.enabled
        repeat: true
        onTriggered: root.tick(false)
    }

    // A change to the interval, the mode or the range takes effect on the next
    // glitch rather than on the next restart of the shell -- and turning the
    // schedule back on starts a fresh period rather than resuming an old one.
    Connections {
        target: Effects

        function onGlitchChanged(): void {
            root.schedule_();
        }

        function onGlitchRangeChanged(): void {
            root.schedule_();
        }

        function onGlitchEveryChanged(): void {
            root.schedule_();
        }

        function onGlitchFromChanged(): void {
            root.schedule_();
        }

        function onGlitchToChanged(): void {
            root.schedule_();
        }
    }

    Component.onCompleted: root.schedule_()

    // --- Event triggers -----------------------------------------------------
    // Fired by name rather than by item, so a caller does not have to hold a
    // reference to a widget three modules away. A name with nothing registered
    // under it is a no-op, which is what makes it safe to fire from a service
    // that does not know whether the deck is even built.
    // **`fire` ignores the veto; the schedule does not.** Suppression is
    // about the shell glitching on its own, and an event trigger is the
    // caller saying exactly what it wants -- which is the whole point of the
    // `glitch fire` handler during a recording.
    function fire(key: string, options: var): void {
        if (Effects.glitch === "OFF")
            return;
        const fx = root.targets.find(target => target.key === key && target.eligible);
        if (!fx)
            return;
        if (root.busy) {
            root.queue = root.queue.concat([({
                        fx,
                        options
                    })]);
            return;
        }
        root.run(fx, options);
    }

    // A run of keys, one after another, each waiting for the last. This is the
    // deck's staggered opening: the `SYS.DIAG` header first, then the panel
    // headers. **Staggering between sibling panels is the one place the
    // animation rules allow it** -- never between children of one panel.
    function fireSequence(keys: var, options: var): void {
        for (const key of keys)
            root.fire(key, options);
    }

    // **Fires one now, on a visible element, with the settings as they stand.**
    // It ignores the overlap limit, because it is an answer to a press: a
    // preview that silently did nothing because something else was glitching
    // would be worse than no preview.
    function preview(): string {
        const pool = root.eligible();
        if (!pool.length)
            return "nothing visible to glitch";
        const fx = root.pick(pool);
        const effects = root.allowed(fx, root.rollEffects(root.rollCount()));
        const duration = root.rollDuration();
        root.running = root.running.concat([fx]);
        root.lastTarget = fx;
        fx.play(effects, duration);
        return `${fx.key || "-"} ${effects.join("+")}`;
    }

    // The strongest combination there is: all three effects at the top of the
    // duration band. The failed unlock uses it, and nothing else should.
    function fireHard(key: string): void {
        root.fire(key, {
            effects: root.effectNames.slice(),
            duration: 170
        });
    }
}

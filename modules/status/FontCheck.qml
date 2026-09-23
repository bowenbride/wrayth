import Quickshell
import Quickshell.Io
import qs.services

// **Warn, don't render boxes.** The shell asks for four specific font families
// by name (see config/Appearance.qml); if one is not installed Qt silently
// substitutes a default face, which for the katakana tags and the Nerd-Font bar
// icons means tofu. This checks the families at start and, if any is missing,
// raises a notification naming them and pointing at the README. The shell keeps
// working either way -- this only tells the user what to install.
Scope {
    Process {
        running: true
        // fc-list may itself be absent (fontconfig not installed); then skip
        // quietly rather than warning about a tool we cannot use.
        command: ["sh", "-c", "command -v fc-list >/dev/null 2>&1 || exit 0; miss=''; for f in 'Chakra Petch' 'JetBrains Mono' 'Noto Sans CJK JP' 'JetBrainsMono Nerd Font'; do fc-list : family 2>/dev/null | grep -qiF \"$f\" || miss=\"${miss:+$miss, }$f\"; done; printf '%s' \"$miss\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const missing = text.trim();
                if (missing)
                    Notifications.send("Wrayth: fonts missing", `${missing} -- install these for correct rendering (see the README).`);
            }
        }
    }
}

#!/usr/bin/env python3
"""cava-link.py <cava pid> -- link SIGNAL's capture to the default sink's monitor.

cava runs with node.autoconnect=false (services/Cava.qml), so nothing links
it but this. It is linked to the monitor ports of the current default sink
(monitor_FL to FL, monitor_FR to FR, a mono monitor to both) and to nothing
else: every other link into cava -- an old sink's monitor, or anything
else -- is removed. **Never an app's output ports**: a capture linked into an
app's stream takes part in that stream's format negotiation, and when the
capture cannot answer (a stopped process, a stuck link) the app's stream
never starts, and its playback hangs. Run again at any time:
it only changes what differs.
"""
import json
import subprocess
import sys

pid = sys.argv[1]
graph = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, check=True).stdout)

props = lambda o: (o.get("info") or {}).get("props") or {}
clients = {o["id"] for o in graph if o["type"].endswith(":Client")
           and str(props(o).get("application.process.id")) == pid}
cava = next((o["id"] for o in graph if o["type"].endswith(":Node")
             and props(o).get("client.id") in clients), None)
if cava is None:
    sys.exit("cava-link: no cava node for pid " + pid)

ports = [o for o in graph if o["type"].endswith(":Port")]
inputs = {props(p).get("audio.channel"): p["id"] for p in ports
          if props(p).get("node.id") == cava and props(p).get("port.direction") == "in"}

sink = None
for o in graph:
    # A metadata object's name is in its top-level props, not info.props.
    if o["type"].endswith(":Metadata") and (o.get("props") or {}).get("metadata.name", props(o).get("metadata.name")) == "default":
        for m in o.get("metadata") or []:
            if m.get("key") == "default.audio.sink":
                value = m.get("value")
                if isinstance(value, str):
                    value = json.loads(value)
                sink = (value or {}).get("name")
sinks = {o["id"] for o in graph if o["type"].endswith(":Node")
         and props(o).get("node.name") == sink and props(o).get("media.class") == "Audio/Sink"}
monitors = [p for p in ports if props(p).get("node.id") in sinks
            and props(p).get("port.direction") == "out" and props(p).get("port.monitor")]

want = set()
for p in monitors:
    ch = props(p).get("audio.channel")
    for dest in (["FL", "FR"] if ch in ("MONO", None) else [ch]):
        if dest in inputs:
            want.add((p["id"], inputs[dest]))

have = {}
for o in graph:
    if o["type"].endswith(":Link"):
        info = o.get("info") or {}
        if info.get("input-node-id") == cava:
            have[(info.get("output-port-id"), info.get("input-port-id"))] = o["id"]

for pair, link in have.items():
    if pair not in want:
        subprocess.run(["pw-link", "-d", str(link)], capture_output=True)
for out, inp in want - set(have):
    subprocess.run(["pw-link", str(out), str(inp)], capture_output=True)

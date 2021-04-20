#!/usr/bin/env python3

from contextlib import contextmanager
from pulsectl.pulsectl import Pulse, PulseClientInfo, PulseCardInfo
from pathlib import Path
import os
import subprocess
import tempfile


@contextmanager
def tmp_file_pair():
    """Context Manager for creating two temporary files."""
    tmpdir = tempfile.mkdtemp()
    f1 = os.path.join(tmpdir, "f1")
    f2 = os.path.join(tmpdir, "f2")
    Path(f1).touch()
    Path(f2).touch()
    try:
        yield f1, f2
    finally:
        os.unlink(f1)
        os.unlink(f2)
        os.rmdir(tmpdir)


def displaySwitcherAndRedirect(pa: Pulse, pid: int) -> str:
    """Display a window for the user to pick an audio sink to move the pid to.

    All the sink inputs belonging to the specified pid will be moved to the
    selected sink.

    If the user aborts, no actions will be performed

    Returns a string describing an error or a None value if no error occurred.
    """

    def filter_client_with_pid(clt: PulseClientInfo):
        if "application.process.id" not in clt.proplist:
            return False
        return clt.proplist["application.process.id"] == str(pid)

    filtered = [clt for clt in pa.client_list() if filter_client_with_pid(clt)]
    if not filtered:
        return "Could not find the sink input to move."
    target_client_id = filtered[0].index

    sinks_lines  = [str(s.index) + " " + s.description for s in pa.sink_list()]
    sinks_lines.reverse()  # Empirically more useful...

    with tmp_file_pair() as (f1, f2):
        print(sinks_lines)
        Path(f1).write_text("\n".join(sinks_lines))
        cmd = [
            "alacritty",
            "--class",
            "launcher",
            "-e",
            "sh",
            "-c",
            "cat " + f1 + " | fzf --reverse > " + f2,
        ]
        subprocess.run(cmd)
        outs = Path(f2).read_text().split(' ')

    if not outs:
        return "The user did not choose any sink."

    target_sink_id = int(outs[0])
    print("Moving to " + str(target_sink_id))

    sink_inputs_to_redirect = [
        c.index for c in pa.sink_input_list() if c.client == target_client_id
    ]

    for s_idx in sink_inputs_to_redirect:
        pa.sink_input_move(s_idx, target_sink_id)


def get_focused_window_pid() -> int:
    sway_cmd = ["swaymsg", "-t", "get_tree"]
    window_tree_str = subprocess.run(sway_cmd, capture_output=True).stdout.decode()
    jq_cmd = ["jq", "-r", ".. | select(.focused? == true) | .pid"]
    cmd_out = subprocess.run(
        jq_cmd, capture_output=True, input=window_tree_str.encode()
    ).stdout.decode()
    return int(cmd_out)


def main():
    focused_window_pid = get_focused_window_pid()
    with Pulse("remap-pa-client") as pulse:
        msg = displaySwitcherAndRedirect(pulse, focused_window_pid)
        if msg:
            print(msg)


if __name__ == "__main__":
    main()

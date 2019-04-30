#!/usr/bin/env nix-shell
#! nix-shell -p "(callPackage /home/roosemberth/dotfiles/nixos-config/pkgs/sandbox.nix {}).python-mpd2" -i python
"""
(C) Roosembert Palacios, 2019

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

--

This program connects to an mpd server and repeats a song within the
provided interval
"""

import argparse
import threading
import signal

from mpd import MPDClient

cli_parser = argparse.ArgumentParser()
cli_parser.add_argument('start', help='Start in seconds', type=float)
cli_parser.add_argument('end', help='End in seconds', type=float)
cli_parser.add_argument('--force-start', action='store_true', help='''
    Seek to start position on boot''')
cli_parser.add_argument('--quiet', help='Do not print state', action='store_true')

def mk_client() -> MPDClient:
    c = MPDClient()
    c.timeout = None
    c.idletimeout = None
    c.connect("localhost", 6600)
    return c

def main(*_, start: float, end: float, quiet=False, force_start=False):
    c = mk_client()

    ctrl = {'run': True}

    def seek_when_elapsed_greated_than_end():
        status = type('MPD_Status', (object,), c.status())  # type: ignore

        if status.state == 'play':
            if float(status.elapsed) > end:
                # Cast to int: Mopidy hangs clients if we pass anything other than an int
                # https://github.com/mopidy/mopidy/issues/1756
                c.seekcur(int(start))

        if ctrl['run']:
            threading.Timer(0.1, seek_when_elapsed_greated_than_end).start()

    # Cast to int: See note in seek_when_elapsed_greated_than_end loop
    if force_start:
        c.seekcur(int(start))

    seek_when_elapsed_greated_than_end()

    def sighandler(sig, frame):
        ctrl['run'] = False

    signal.signal(signal.SIGINT, sighandler)

if __name__ == '__main__':
    main(**vars(cli_parser.parse_args()))

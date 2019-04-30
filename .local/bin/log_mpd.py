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

See the cli_parser description for an overview of this program.

"""
from datetime import datetime
import argparse
import csv
import threading
import signal
import sys

from mpd import MPDClient

cli_parser = argparse.ArgumentParser(description='''
    This program connects to an mpd server and monitors playback history.
    Prints a line to stdout every time it detects a track changes or is repeated.
    Lines are csv-formatted with the following specification: `DATE,PLAYBACK_DURATION,SONG_DURATION,FILE,TITLE,ARTIST`
''')
cli_parser.add_argument('--host', help='Connect to server at host [localhost]', default="localhost")
cli_parser.add_argument('--port', help='Connect to server at port [6600]', type=int, default="6600")

def mk_client(host: str, port: int) -> MPDClient:
    client = MPDClient()
    client.timeout = None
    client.idletimeout = None
    client.connect(host, port)
    return client

def main(*_, host: str, port: int):
    mpd_client = mk_client(host, port)

    class ApplicationState:
        def __init__(self):
            self.run = True
            self.curElapsed = 0    # Elapsed time in the current song
            self.tracking = False  # Whether we're currently tracking a song

            self.curDate = None    # Isoformat date at start of playback
            self.curStart = 0      # Elapsed at start of playback (i.e. seek then play)
            self.curDuration = 0   # Duration of current song
            self.curFile = None    # File resource of current song
            self.curTitle = None
            self.curArtist = None

            self.writer = csv.writer(sys.stdout)

        def stop(self):
            self.run = False

        def printStateLine(self):
            playback_start_date = self.curDate
            playback_duration = self.curElapsed - self.curStart
            song_duration = self.curDuration
            file_str = self.curFile
            title = self.curTitle
            artist = self.curArtist

            self.writer.writerow([playback_start_date, playback_duration, song_duration, file_str, title, artist])
            sys.stdout.flush()

        def refreshFromMpdState(self, status_obj, current_song_obj):
            self.curElapsed = float(status_obj.elapsed)
            self.curDate = datetime.now().isoformat()
            self.curStart = float(status_obj.elapsed)
            self.curDuration = float(current_song_obj.time)
            self.curFile = current_song_obj.file
            self.curTitle = current_song_obj.title
            self.curArtist = current_song_obj.artist

    appState = ApplicationState()

    signal.signal(signal.SIGINT, lambda *_: appState.stop())

    def stop_tracking_and_maybe_report(status_obj, force_report = False):
        if force_report:
            trigger_report()
        elif appState.curElapsed - float(status_obj.elapsed) > appState.curDuration/3:  # Don't log if didn't play at least a third of the song
            trigger_report()
        appState.tracking = False

    def trigger_report():
        if not appState.tracking:
            raise ValueError('Invoked tracking stop when not tracking !: {}'.format(appState.__dict__))
        appState.printStateLine()

    def tracking_loop(status_obj, current_song_obj):
        status_elapsed_secs = float(status_obj.elapsed)
        if status_elapsed_secs > appState.curElapsed:  # Normal time advancement
            appState.curElapsed = float(status_obj.elapsed)
        elif status_elapsed_secs < appState.curElapsed:  # Detect repeat
            stop_tracking_and_maybe_report(status_obj)
            return

        if appState.curFile and appState.curFile != current_song_obj.file:
            stop_tracking_and_maybe_report(status_obj)
            return

        if status_obj.state != 'play':  # Playback stopped and tracking -> Stop tracking and force log
            stop_tracking_and_maybe_report(status_obj, force_report = True)
            mpd_client.idle()

    def monitor_status_and_report():
        status = type('MPD_Status', (object,), mpd_client.status())  # type: ignore
        song = type('MPD_CurrentSong', (object,), mpd_client.currentsong())  # type: ignore

        if appState.tracking:
            tracking_loop(status, song)

        if status.state == 'play' and not appState.tracking:  # Playing and not tracking -> Track
            appState.refreshFromMpdState(status, song)
            appState.tracking = True

        if appState.run:
            threading.Timer(0.1, monitor_status_and_report).start()
        else:  # Maybe log on termination
            stop_tracking_and_maybe_report(status)

    monitor_status_and_report()

if __name__ == '__main__':
    main(**vars(cli_parser.parse_args()))

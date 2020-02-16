#!/usr/bin/env nix-shell
#! nix-shell -p "(callPackage /home/roosemberth/dotfiles/nixos-config/pkgs/sandbox.nix {}).python-mpd2" -i python3
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
import logging
import threading
import time
import signal
import sys

from mpd import ConnectionError, MPDClient

logger = logging.getLogger(__name__)

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

class MpdLoggerState:
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

        # FIXME: Move the out of the state class...
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

class MpdLogger(MpdLoggerState):
    def __init__(self, mpd_client: MPDClient):
        super(MpdLogger, self).__init__()
        self.mpd_client = mpd_client

    def stop_tracking_and_report(self, status_obj, force_report = False):
        # There may not be a current song anymore. => set elapsed = 0
        current_playing_song_elapsed = float(getattr(status_obj, 'elapsed', 0))

        if force_report:
            self.trigger_report()
        # Don't log if didn't play at least a third of the song
        elif self.curElapsed - current_playing_song_elapsed > self.curDuration/3:
            self.trigger_report()
        self.tracking = False

    def trigger_report(self):
        if not self.tracking:
            raise RuntimeError('Invoked tracking stop when not tracking !: {}'.format(self.__dict__))
        self.printStateLine()

    def tracking_loop(self, status_obj, current_song_obj) -> None:
        if not hasattr(status_obj, 'elapsed'):  # Playback ended
            self.stop_tracking_and_report(status_obj)
            return

        status_elapsed_secs = float(status_obj.elapsed)
        if status_elapsed_secs > self.curElapsed:  # Normal time advancement
            self.curElapsed = float(status_obj.elapsed)
        elif status_elapsed_secs < self.curElapsed:  # Detect repeat
            self.stop_tracking_and_report(status_obj)
            return

        if self.curFile and self.curFile != current_song_obj.file:
            self.stop_tracking_and_report(status_obj)
            return

        if status_obj.state != 'play':  # Playback stopped and tracking -> Stop tracking
            self.stop_tracking_and_report(status_obj)
            self.mpd_client.idle()

    def monitor_status_and_report(self):
        mpd_status = type('MPD_Status', (object,), self.mpd_client.status())  # type: ignore
        song = type('MPD_CurrentSong', (object,), self.mpd_client.currentsong())  # type: ignore

        if self.tracking:
            self.tracking_loop(mpd_status, song)

        if mpd_status.state == 'play' and not self.tracking:  # Playing and not tracking -> Track
            self.refreshFromMpdState(mpd_status, song)
            self.tracking = True

    def start(self):
        try:
            while self.run:
                self.monitor_status_and_report()
        except ConnectionResetError:
            logger.info('Disconnected.')

def main(*_, host: str, port: int):
    run = True
    while run:
        try:
            mpd_client = mk_client(host, port)
            logger.info('Connected to %s:%d', host, port)
            mpd_logger = MpdLogger(mpd_client)

            def sigint_handler(*_):
                logger.debug('Caught sigint')
                mpd_logger.stop()
                sys.exit(0)
                run = False

            signal.signal(signal.SIGINT, sigint_handler)
            thread = threading.Thread(target=mpd_logger.start)
            thread.start()
            thread.join()
        except ConnectionRefusedError:
            time.sleep(1)

if __name__ == '__main__':
    main(**vars(cli_parser.parse_args()))

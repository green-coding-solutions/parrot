# Corpus attribution

Every clip in this directory is derived from:

**Big Buck Bunny**, "Sunflower" version
(c) copyright 2008, Blender Foundation / www.bigbuckbunny.org
Licensed under the **Creative Commons Attribution 3.0** licence:
https://creativecommons.org/licenses/by/3.0/

Source file, downloaded once at authoring time and not at measurement time:

    https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_60fps_normal.mp4.zip
    sha256  68c456673409f8df09b80d0afe29ecb38ef110551fa8a93c83e54a96ebdaec78

## Changes made

The clips are modified versions of that film, as CC BY permits and requires to be
stated. [../make-corpus.sh](../make-corpus.sh) is the exact recipe, and it is the
only thing that should ever produce this directory. In summary, each clip is:

* the 60-second stretch beginning 300 s into the film, cut to 30 s (clip 01) or
  15 s (clips 02-06);
* scaled from 1920x1080 to 1440x810 (or 640x360 for clip 06);
* frame rate left at the master's native 60 fps for clip 02 and decimated to
  30 fps for the rest;
* re-encoded to H.264, VP9, H.265 or AV1;
* overlaid with the clip's own name and a running timecode;
* remuxed with two audio tracks (AAC 2.0 `eng`, AAC 5.1 `ger`) and two generated
  SRT subtitle tracks (`eng`, `ger`) that are not part of the original film.

# Video player
#
# One line per block. A block ends in a checkpoint, and a checkpoint is a
# screenshot compared pixel for pixel on replay - so EVERY BLOCK HAS TO END ON A
# FRAME THAT IS THE SAME FRAME EVERY RUN.
#
# That is why so many of these lines end in "and put the position on ...". A
# block shaped "resume, play ten seconds, pause" ends wherever wall-clock timing
# and the decoder's speed on the day happen to leave it, which is not the same
# frame twice: measured, four of the seven entrants failed their first replay on
# exactly that, at RMSE 0.25 to 0.31 against a 0.2 ceiling. Ending on a seek
# instead costs one click and makes the frame a property of the click, not of the
# clock.
#
# The price is that those checkpoints no longer prove that playback HAPPENED -
# a block whose resume was swallowed would seek to the same mark and pass. What
# still proves it is block 21, which can only reach clip 06 by playing off the
# end of clip 05, and the sink-input line that common/verify-app.sh prints.

* Load app: wait for the player to finish starting with the six-clip corpus playlist loaded and `01-h264-1440x900p30.mkv` playing, dismissing any first-run, privacy, update or notification dialog it puts in front of that, then pause and put the position back to the start of the clip, by whichever route the player offers - its position bar or its own restart key
* Play H.264: resume and let the clip play through ten seconds of its own burnt-in timecode, then pause and put the position on the mark two fifths of the way along the position bar
* Seek with the keyboard: from that mark, make eleven short jumps with the player's own seek keys, alternating backwards and forwards so the position stays inside the clip and ending one jump behind where it started, letting each jump finish drawing before the next
* Seek on the bar: click the position bar at three quarters, then at its midpoint, then at a quarter, letting the frame at each position finish drawing before the next click
* Resume: resume playback from that quarter mark and let it play through six seconds of the clip's timecode, then pause and put the position on the mark seven tenths of the way along the bar
* Volume down and up: turn the volume down to about a quarter and back up to full, by whichever route the player offers - its volume slider, its audio menu or its own volume keys
* Mute: mute the player, wait for the muted state to show, then unmute it
* Subtitles on: turn on the German subtitle track and let the clip play through six seconds of its timecode with the subtitles drawing, then pause and put the position on the mark just over a third of the way along the bar, which is inside a subtitle cue and not in the one-second gap between two
* Subtitles off: turn the subtitles off again, wait for the frame to redraw without them, and put the position on the mark just under a sixth of the way along the bar
* Second audio track: switch from the English stereo track to the German 5.1 track and let the clip play through six seconds of the clip's timecode, then pause and put the position on the mark just over half way along the bar
* Aspect ratio 4:3: force the video to a 4:3 aspect ratio, by whichever route the player offers - its aspect menu or its own aspect key - and wait for the frame to redraw pillarboxed
* Aspect ratio back: put the aspect ratio back to the clip's own and wait for the frame to redraw at full width
* Fullscreen: go fullscreen and let the clip play through ten seconds of its timecode scaled to the whole screen, then pause and put the position back to the start of the clip with the player's own seek keys, held down until the seek clamps there, and step forward twice - the position bar is not where it was in the window, so this block ends on the keyboard rather than on a click
* Leave fullscreen: return to the window and wait for the frame to redraw at window size
* Play 60 fps: advance to the next item in the playlist, `02-h264-1440x900p60.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark a fifth of the way along the bar
* Play VP9: advance to `03-vp9-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark three fifths of the way along the bar
* Play HEVC: advance to `04-hevc-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark just under a sixth of the way along the bar
* Play AV1: advance to `05-av1-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark three quarters of the way along the bar
* Play upscaled SD: advance to `06-h264-640x400p30.mkv`, which the player has to scale up to fill the same window, let it play through ten seconds of its timecode, then pause and put the position on the mark three fifths of the way along the bar
* Previous clip: go back one item in the playlist to `05-av1-1440x900p30.mkv`, pause, and put the position on the mark a fifth of the way along the bar
* Play to the end of a clip: click the position bar inside the last five seconds of that clip, resume, and let it run past the end so the playlist advances to `06-h264-640x400p30.mkv` on its own, then pause and put the position on the mark most of the way along that clip's bar
* Idle paused: leave the player paused and untouched for thirty seconds

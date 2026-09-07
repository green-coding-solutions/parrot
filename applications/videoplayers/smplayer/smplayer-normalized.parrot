# Parrot recording v2

startcommand = /usr/local/bin/parrot-smplayer
windowtitle = 
windowclass = smplayer

wait 30.207431
mousemove 720 450
wait 0.000023
keydown space
wait 0.005950
keyup space
wait 0.792082
mousemove 215 849
wait 0.000020
mousedown 1
wait 0.000019
mouseup 1
wait 7.035949
mousemove 1420 400
wait 0.006261
wait 9.901701
log * Load app: wait for the player to finish starting with the six-clip corpus playlist loaded and `01-h264-1440x900p30.mkv` playing, dismissing any first-run, privacy, update or notification dialog it puts in front of that, then pause and put the position back to the start of the clip, by whichever route the player offers - its position bar or its own restart key
check smplayer/smplayer-check-001.png
wait 2.048148
keydown space
wait 0.006109
keyup space
wait 10.047167
keydown space
wait 0.006107
keyup space
wait 0.803489
mousemove 638 849
wait 0.000020
mousedown 1
wait 0.000005
mouseup 1
wait 7.034007
mousemove 1420 400
wait 0.006193
wait 3.812031
log * Play H.264: resume and let the clip play through ten seconds of its own burnt-in timecode, then pause and put the position on the mark two fifths of the way along the position bar
check smplayer/smplayer-check-002.png
wait 2.048974
keydown Left
wait 0.006128
keyup Left
wait 1.046746
keydown Right
wait 0.006118
keyup Right
wait 1.047261
keydown Left
wait 0.006161
keyup Left
wait 1.046686
keydown Right
wait 0.006290
keyup Right
wait 1.048177
keydown Left
wait 0.006194
keyup Left
wait 1.046309
keydown Right
wait 0.006184
keyup Right
wait 1.048901
keydown Left
wait 0.006146
keyup Left
wait 1.047118
keydown Right
wait 0.006189
keyup Right
wait 1.048915
keydown Left
wait 0.006191
keyup Left
wait 1.046449
keydown Right
wait 0.006218
keyup Right
wait 1.048978
keydown Left
wait 0.006106
keyup Left
wait 6.143961
mousemove 1420 400
wait 0.006165
wait 0.131267
log * Seek with the keyboard: from that mark, make eleven short jumps with the player's own seek keys, alternating backwards and forwards so the position stays inside the clip and ending one jump behind where it started, letting each jump finish drawing before the next
check smplayer/smplayer-check-003.png
wait 2.803792
mousemove 972 849
wait 0.000044
mousedown 1
wait 0.000017
mouseup 1
wait 2.699683
mousemove 734 849
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 2.695364
mousemove 495 849
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 7.032650
mousemove 1420 400
wait 0.006187
wait 11.386637
log * Seek on the bar: click the position bar at three quarters, then at its midpoint, then at a quarter, letting the frame at each position finish drawing before the next click
check smplayer/smplayer-check-004.png
wait 2.047562
keydown space
wait 0.006335
keyup space
wait 6.048290
keydown space
wait 0.006408
keyup space
wait 0.804252
mousemove 924 849
wait 0.000020
mousedown 1
wait 0.000012
mouseup 1
wait 7.033853
mousemove 1420 400
wait 0.006165
wait 3.808146
log * Resume: resume playback from that quarter mark and let it play through six seconds of the clip's timecode, then pause and put the position on the mark seven tenths of the way along the bar
check smplayer/smplayer-check-005.png
wait 2.049520
keydown 9
wait 0.006063
keyup 9
wait 0.086570
keydown 9
wait 0.006187
keyup 9
wait 0.086471
keydown 9
wait 0.006049
keyup 9
wait 0.086647
keydown 9
wait 0.006349
keyup 9
wait 0.086817
keydown 9
wait 0.006595
keyup 9
wait 0.086593
keydown 9
wait 0.006230
keyup 9
wait 0.086796
keydown 9
wait 0.006332
keyup 9
wait 0.086966
keydown 9
wait 0.006068
keyup 9
wait 0.086675
keydown 9
wait 0.006502
keyup 9
wait 0.086413
keydown 9
wait 0.006290
keyup 9
wait 0.086523
keydown 9
wait 0.005989
keyup 9
wait 0.086637
keydown 9
wait 0.005994
keyup 9
wait 0.086980
keydown 9
wait 0.006027
keyup 9
wait 0.086552
keydown 9
wait 0.006228
keyup 9
wait 0.086701
keydown 9
wait 0.006193
keyup 9
wait 0.086834
keydown 9
wait 0.006245
keyup 9
wait 0.086734
keydown 9
wait 0.006254
keyup 9
wait 0.086325
keydown 9
wait 0.006250
keyup 9
wait 0.086726
keydown 9
wait 0.006235
keyup 9
wait 2.052557
keydown 0
wait 0.006208
keyup 0
wait 0.086540
keydown 0
wait 0.006547
keyup 0
wait 0.086444
keydown 0
wait 0.006179
keyup 0
wait 0.086669
keydown 0
wait 0.006400
keyup 0
wait 0.086844
keydown 0
wait 0.006488
keyup 0
wait 0.086536
keydown 0
wait 0.006408
keyup 0
wait 0.086613
keydown 0
wait 0.006549
keyup 0
wait 0.086512
keydown 0
wait 0.006391
keyup 0
wait 0.086167
keydown 0
wait 0.006186
keyup 0
wait 0.086643
keydown 0
wait 0.006275
keyup 0
wait 0.086291
keydown 0
wait 0.006755
keyup 0
wait 0.086766
keydown 0
wait 0.006557
keyup 0
wait 0.086526
keydown 0
wait 0.006276
keyup 0
wait 0.086471
keydown 0
wait 0.006465
keyup 0
wait 0.086625
keydown 0
wait 0.006334
keyup 0
wait 0.086707
keydown 0
wait 0.006201
keyup 0
wait 0.086216
keydown 0
wait 0.006067
keyup 0
wait 0.086508
keydown 0
wait 0.005781
keyup 0
wait 0.086483
keydown 0
wait 0.006087
keyup 0
wait 6.140369
mousemove 1420 400
wait 0.006073
wait 2.055024
log * Volume down and up: turn the volume down to about a quarter and back up to full, by whichever route the player offers - its volume slider, its audio menu or its own volume keys
check smplayer/smplayer-check-006.png
wait 2.049885
keydown m
wait 0.006176
keyup m
wait 2.049241
keydown m
wait 0.006139
keyup m
wait 5.143486
mousemove 1420 400
wait 0.006249
wait 0.024696
log * Mute: mute the player, wait for the muted state to show, then unmute it
check smplayer/smplayer-check-007.png
wait 2.048736
keydown j
wait 0.006232
keyup j
wait 1.047492
keydown j
wait 0.006059
keyup j
wait 0.045962
keydown space
wait 0.006532
keyup space
wait 6.048012
keydown space
wait 0.006100
keyup space
wait 0.803615
mousemove 590 849
wait 0.000023
mousedown 1
wait 0.000006
mouseup 1
wait 7.036081
mousemove 1420 400
wait 0.006253
wait 12.016186
log * Subtitles on: turn on the German subtitle track and let the clip play through six seconds of its timecode with the subtitles drawing, then pause and put the position on the mark just over a third of the way along the bar, which is inside a subtitle cue and not in the one-second gap between two
check smplayer/smplayer-check-008.png
wait 2.047503
keydown j
wait 0.006054
keyup j
wait 0.797900
mousemove 400 849
wait 0.000017
mousedown 1
wait 0.000004
mouseup 1
wait 7.036642
mousemove 1420 400
wait 0.006226
wait 11.957756
log * Subtitles off: turn the subtitles off again, wait for the frame to redraw without them, and put the position on the mark just under a sixth of the way along the bar
check smplayer/smplayer-check-009.png
wait 2.046646
keydown k
wait 0.006167
keyup k
wait 0.043310
keydown space
wait 0.006161
keyup space
wait 6.047697
keydown space
wait 0.006175
keyup space
wait 0.803849
mousemove 781 849
wait 0.000027
mousedown 1
wait 0.000006
mouseup 1
wait 7.034271
mousemove 1420 400
wait 0.006125
wait 11.405735
log * Second audio track: switch from the English stereo track to the German 5.1 track and let the clip play through six seconds of the clip's timecode, then pause and put the position on the mark just over half way along the bar
check smplayer/smplayer-check-010.png
wait 2.889651
mousemove 124 10
wait 0.000016
mousedown 1
wait 0.000009
mouseup 1
wait 2.484828
mousemove 210 184
wait 0.000018
mousedown 1
wait 0.000004
mouseup 1
wait 2.485782
mousemove 520 259
wait 0.000024
mousedown 1
wait 0.000007
mouseup 1
wait 7.231337
mousemove 1420 400
wait 0.006071
wait 3.026508
log * Aspect ratio 4:3: force the video to a 4:3 aspect ratio, by whichever route the player offers - its aspect menu or its own aspect key - and wait for the frame to redraw pillarboxed
check smplayer/smplayer-check-011.png
wait 2.892601
mousemove 124 10
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 2.483222
mousemove 210 184
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 2.485103
mousemove 520 184
wait 0.000020
mousedown 1
wait 0.000015
mouseup 1
wait 7.236211
mousemove 1420 400
wait 0.006299
wait 1.893262
log * Aspect ratio back: put the aspect ratio back to the clip's own and wait for the frame to redraw at full width
check smplayer/smplayer-check-012.png
wait 2.048226
keydown f
wait 0.006154
keyup f
wait 0.045041
keydown space
wait 0.006144
keyup space
wait 10.047308
keydown space
wait 0.006151
keyup space
wait 0.047875
keydown Left
wait 0.006425
keyup Left
wait 0.550642
keydown Left
wait 0.006245
keyup Left
wait 0.546480
keydown Left
wait 0.006245
keyup Left
wait 0.548218
keydown Left
wait 0.006122
keyup Left
wait 0.546812
keydown Left
wait 0.005987
keyup Left
wait 0.548223
keydown Left
wait 0.006320
keyup Left
wait 0.549245
keydown Left
wait 0.006071
keyup Left
wait 0.548763
keydown Left
wait 0.006267
keyup Left
wait 0.551059
keydown Left
wait 0.006309
keyup Left
wait 0.547593
keydown Left
wait 0.006234
keyup Left
wait 0.549881
keydown Left
wait 0.006015
keyup Left
wait 0.550523
keydown Left
wait 0.006031
keyup Left
wait 2.047978
keydown Right
wait 0.006224
keyup Right
wait 1.045147
keydown Right
wait 0.006394
keyup Right
wait 7.642083
mousemove 1420 400
wait 0.006068
wait 0.312544
log * Fullscreen: go fullscreen and let the clip play through ten seconds of its timecode scaled to the whole screen, then pause and put the position back to the start of the clip with the player's own seek keys, held down until the seek clamps there, and step forward twice - the position bar is not where it was in the window, so this block ends on the keyboard rather than on a click
check smplayer/smplayer-check-013.png
wait 2.076276
keydown f
wait 0.000016
keyup f
wait 6.114344
mousemove 1420 400
wait 0.006170
wait 0.012893
log * Leave fullscreen: return to the window and wait for the frame to redraw at window size
check smplayer/smplayer-check-014.png
wait 2.048305
keydown Shift_L
wait 0.006309
keydown period
wait 0.006120
keyup Shift_L
wait 0.006170
keyup period
wait 10.052984
keydown space
wait 0.006117
keyup space
wait 0.805949
mousemove 447 849
wait 0.000028
mousedown 1
wait 0.000017
mouseup 1
wait 7.042776
mousemove 1420 400
wait 0.006150
wait 8.980464
log * Play 60 fps: advance to the next item in the playlist, `02-h264-1440x900p60.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark a fifth of the way along the bar
check smplayer/smplayer-check-015.png
wait 2.053306
keydown Shift_L
wait 0.006140
keydown period
wait 0.006207
keyup Shift_L
wait 0.006247
keyup period
wait 10.047689
keydown space
wait 0.006248
keyup space
wait 0.802392
mousemove 829 849
wait 0.000016
mousedown 1
wait 0.000011
mouseup 1
wait 7.031066
mousemove 1420 400
wait 0.006215
wait 8.969956
log * Play VP9: advance to `03-vp9-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark three fifths of the way along the bar
check smplayer/smplayer-check-016.png
wait 2.051097
keydown Shift_L
wait 0.006112
keydown period
wait 0.006206
keyup Shift_L
wait 0.006228
keyup period
wait 10.048530
keydown space
wait 0.006205
keyup space
wait 0.802101
mousemove 400 849
wait 0.000016
mousedown 1
wait 0.000009
mouseup 1
wait 7.033814
mousemove 1420 400
wait 0.006402
wait 8.967085
log * Play HEVC: advance to `04-hevc-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark just under a sixth of the way along the bar
check smplayer/smplayer-check-017.png
wait 2.051478
keydown Shift_L
wait 0.006155
keydown period
wait 0.006396
keyup Shift_L
wait 0.006246
keyup period
wait 10.049495
keydown space
wait 0.006196
keyup space
wait 0.808319
mousemove 972 849
wait 0.000023
mousedown 1
wait 0.000111
mouseup 1
wait 7.036757
mousemove 1420 400
wait 0.006270
wait 8.941818
log * Play AV1: advance to `05-av1-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark three quarters of the way along the bar
check smplayer/smplayer-check-018.png
wait 2.046410
keydown Shift_L
wait 0.006291
keydown period
wait 0.006055
keyup Shift_L
wait 0.006075
keyup period
wait 10.050561
keydown space
wait 0.006067
keyup space
wait 0.806038
mousemove 829 849
wait 0.000021
mousedown 1
wait 0.000015
mouseup 1
wait 7.055088
mousemove 1420 400
wait 0.006038
wait 8.935513
log * Play upscaled SD: advance to `06-h264-640x400p30.mkv`, which the player has to scale up to fill the same window, let it play through ten seconds of its timecode, then pause and put the position on the mark three fifths of the way along the bar
check smplayer/smplayer-check-019.png
wait 2.053421
keydown Shift_L
wait 0.006384
keydown comma
wait 0.006108
keyup Shift_L
wait 0.006120
keyup comma
wait 3.053833
keydown space
wait 0.006247
keyup space
wait 0.815445
mousemove 447 849
wait 0.000018
mousedown 1
wait 0.000009
mouseup 1
wait 7.042700
mousemove 1420 400
wait 0.006339
wait 11.972679
log * Previous clip: go back one item in the playlist to `05-av1-1440x900p30.mkv`, pause, and put the position on the mark a fifth of the way along the bar
check smplayer/smplayer-check-020.png
wait 2.810889
mousemove 1115 849
wait 0.000017
mousedown 1
wait 0.000008
mouseup 1
wait 1.941844
keydown space
wait 0.006255
keyup space
wait 12.048024
keydown space
wait 0.006128
keyup space
wait 0.803078
mousemove 1067 849
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 7.037728
mousemove 1420 400
wait 0.006215
wait 10.720596
log * Play to the end of a clip: click the position bar inside the last five seconds of that clip, resume, and let it run past the end so the playlist advances to `06-h264-640x400p30.mkv` on its own, then pause and put the position on the mark most of the way along that clip's bar
check smplayer/smplayer-check-021.png
wait 36.138424
mousemove 1420 400
wait 0.006343
wait 0.015155
log * Idle paused: leave the player paused and untouched for thirty seconds
check smplayer/smplayer-check-022.png

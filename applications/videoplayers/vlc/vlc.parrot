# Parrot recording v2

startcommand = /usr/local/bin/parrot-vlc
windowtitle = 
windowclass = vlc

wait 28.712626
mousemove 720 450
wait 0.000038
keydown space
wait 0.006156
keyup space
wait 0.804131
mousemove 62 856
wait 0.000051
mousedown 1
wait 0.000022
mouseup 1
wait 6.833101
mousemove 1420 400
wait 0.006140
log * Load app: wait for the player to finish starting with the six-clip corpus playlist loaded and `01-h264-1440x900p30.mkv` playing, dismissing any first-run, privacy, update or notification dialog it puts in front of that, then pause and put the position back to the start of the clip, by whichever route the player offers - its position bar or its own restart key
check vlc/vlc-check-001.png
wait 2.052913
keydown space
wait 0.006673
keyup space
wait 10.049478
keydown space
wait 0.006092
keyup space
wait 0.800897
mousemove 588 856
wait 0.000028
mousedown 1
wait 0.000014
mouseup 1
wait 6.831322
mousemove 1420 400
wait 0.006089
log * Play H.264: resume and let the clip play through ten seconds of its own burnt-in timecode, then pause and put the position on the mark two fifths of the way along the position bar
check vlc/vlc-check-002.png
wait 2.046816
keydown Left
wait 0.006262
keyup Left
wait 1.045317
keydown Right
wait 0.006250
keyup Right
wait 1.047158
keydown Left
wait 0.006261
keyup Left
wait 1.046903
keydown Right
wait 0.006301
keyup Right
wait 1.046478
keydown Left
wait 0.006115
keyup Left
wait 1.046066
keydown Right
wait 0.006269
keyup Right
wait 1.045977
keydown Left
wait 0.006422
keyup Left
wait 1.046899
keydown Right
wait 0.006222
keyup Right
wait 1.047440
keydown Left
wait 0.006251
keyup Left
wait 1.050455
keydown Right
wait 0.006104
keyup Right
wait 1.047035
keydown Left
wait 0.006278
keyup Left
wait 6.144437
mousemove 1420 400
wait 0.006201
log * Seek with the keyboard: from that mark, make eleven short jumps with the player's own seek keys, alternating backwards and forwards so the position stays inside the clip and ending one jump behind where it started, letting each jump finish drawing before the next
check vlc/vlc-check-003.png
wait 2.807405
mousemove 1049 856
wait 0.000022
mousedown 1
wait 0.000017
mouseup 1
wait 2.500384
mousemove 720 856
wait 0.000018
mousedown 1
wait 0.000005
mouseup 1
wait 2.501530
mousemove 391 856
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 6.837247
mousemove 1420 400
wait 0.006144
log * Seek on the bar: click the position bar at three quarters, then at its midpoint, then at a quarter, letting the frame at each position finish drawing before the next click
check vlc/vlc-check-004.png
wait 2.049247
keydown space
wait 0.006250
keyup space
wait 6.048808
keydown space
wait 0.006352
keyup space
wait 0.806735
mousemove 983 856
wait 0.000028
mousedown 1
wait 0.000115
mouseup 1
wait 6.839709
mousemove 1420 400
wait 0.006256
log * Resume: resume playback from that quarter mark and let it play through six seconds of the clip's timecode, then pause and put the position on the mark seven tenths of the way along the bar
check vlc/vlc-check-005.png
wait 2.048836
keydown Control_L
wait 0.006195
keydown Down
wait 0.006288
keyup Control_L
wait 0.006263
keyup Down
wait 0.106863
keydown Control_L
wait 0.006787
keydown Down
wait 0.006297
keyup Control_L
wait 0.006512
keyup Down
wait 0.106624
keydown Control_L
wait 0.005965
keydown Down
wait 0.006158
keyup Control_L
wait 0.006433
keyup Down
wait 0.106360
keydown Control_L
wait 0.006103
keydown Down
wait 0.006063
keyup Control_L
wait 0.006247
keyup Down
wait 0.106706
keydown Control_L
wait 0.006374
keydown Down
wait 0.006039
keyup Control_L
wait 0.006006
keyup Down
wait 0.106448
keydown Control_L
wait 0.006216
keydown Down
wait 0.006368
keyup Control_L
wait 0.006054
keyup Down
wait 0.106428
keydown Control_L
wait 0.006238
keydown Down
wait 0.006074
keyup Control_L
wait 0.006134
keyup Down
wait 0.106652
keydown Control_L
wait 0.006452
keydown Down
wait 0.006231
keyup Control_L
wait 0.005930
keyup Down
wait 0.106910
keydown Control_L
wait 0.006526
keydown Down
wait 0.006288
keyup Control_L
wait 0.006244
keyup Down
wait 0.106010
keydown Control_L
wait 0.006669
keydown Down
wait 0.006526
keyup Control_L
wait 0.006513
keyup Down
wait 2.050450
keydown Control_L
wait 0.006277
keydown Up
wait 0.006236
keyup Control_L
wait 0.006237
keyup Up
wait 0.106467
keydown Control_L
wait 0.006125
keydown Up
wait 0.006378
keyup Control_L
wait 0.006119
keyup Up
wait 0.106890
keydown Control_L
wait 0.006472
keydown Up
wait 0.006334
keyup Control_L
wait 0.006285
keyup Up
wait 0.106082
keydown Control_L
wait 0.006588
keydown Up
wait 0.006197
keyup Control_L
wait 0.006348
keyup Up
wait 0.106644
keydown Control_L
wait 0.006407
keydown Up
wait 0.006191
keyup Control_L
wait 0.006248
keyup Up
wait 0.106694
keydown Control_L
wait 0.006259
keydown Up
wait 0.006253
keyup Control_L
wait 0.006316
keyup Up
wait 0.106814
keydown Control_L
wait 0.006311
keydown Up
wait 0.006272
keyup Control_L
wait 0.006694
keyup Up
wait 0.106644
keydown Control_L
wait 0.006569
keydown Up
wait 0.006042
keyup Control_L
wait 0.006247
keyup Up
wait 0.106642
keydown Control_L
wait 0.006532
keydown Up
wait 0.006255
keyup Control_L
wait 0.006334
keyup Up
wait 0.106244
keydown Control_L
wait 0.006570
keydown Up
wait 0.006198
keyup Control_L
wait 0.006554
keyup Up
wait 6.147874
mousemove 1420 400
wait 0.006197
log * Volume down and up: turn the volume down to about a quarter and back up to full, by whichever route the player offers - its volume slider, its audio menu or its own volume keys
check vlc/vlc-check-006.png
wait 2.050952
keydown m
wait 0.006386
keyup m
wait 2.050463
keydown m
wait 0.006305
keyup m
wait 5.150161
mousemove 1420 400
wait 0.006077
log * Mute: mute the player, wait for the muted state to show, then unmute it
check vlc/vlc-check-007.png
wait 2.893670
mousemove 266 10
wait 0.000023
mousedown 1
wait 0.000018
mouseup 1
wait 2.484654
mousemove 280 60
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 2.483540
mousemove 470 109
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 2.141854
keydown space
wait 0.006283
keyup space
wait 6.048365
keydown space
wait 0.006185
keyup space
wait 0.804128
mousemove 522 856
wait 0.000025
mousedown 1
wait 0.000007
mouseup 1
wait 6.837384
mousemove 1420 400
wait 0.006134
log * Subtitles on: turn on the German subtitle track and let the clip play through six seconds of its timecode with the subtitles drawing, then pause and put the position on the mark just over a third of the way along the bar, which is inside a subtitle cue and not in the one-second gap between two
check vlc/vlc-check-008.png
wait 2.890866
mousemove 266 10
wait 0.000020
mousedown 1
wait 0.000009
mouseup 1
wait 2.485025
mousemove 280 60
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 2.486774
mousemove 470 60
wait 0.000016
mousedown 1
wait 0.000003
mouseup 1
wait 2.898846
mousemove 259 856
wait 0.000040
mousedown 1
wait 0.000006
mouseup 1
wait 6.835695
mousemove 1420 400
wait 0.006308
log * Subtitles off: turn the subtitles off again, wait for the frame to redraw without them, and put the position on the mark just under a sixth of the way along the bar
check vlc/vlc-check-009.png
wait 2.889178
mousemove 150 10
wait 0.000022
mousedown 1
wait 0.000007
mouseup 1
wait 2.485928
mousemove 200 34
wait 0.000024
mousedown 1
wait 0.000016
mouseup 1
wait 2.485265
mousemove 420 83
wait 0.000020
mousedown 1
wait 0.000018
mouseup 1
wait 2.142916
keydown space
wait 0.006261
keyup space
wait 6.053255
keydown space
wait 0.006216
keyup space
wait 0.803354
mousemove 785 856
wait 0.000018
mousedown 1
wait 0.000009
mouseup 1
wait 6.846412
mousemove 1420 400
wait 0.006165
log * Second audio track: switch from the English stereo track to the German 5.1 track and let the clip play through six seconds of the clip's timecode, then pause and put the position on the mark just over half way along the bar
check vlc/vlc-check-010.png
wait 2.052851
keydown a
wait 0.006088
keyup a
wait 0.706661
keydown a
wait 0.006181
keyup a
wait 7.144461
mousemove 1420 400
wait 0.006233
log * Aspect ratio 4:3: force the video to a 4:3 aspect ratio, by whichever route the player offers - its aspect menu or its own aspect key - and wait for the frame to redraw pillarboxed
check vlc/vlc-check-011.png
wait 2.049158
keydown a
wait 0.006337
keyup a
wait 0.706352
keydown a
wait 0.006417
keyup a
wait 0.707433
keydown a
wait 0.006887
keyup a
wait 0.706371
keydown a
wait 0.006517
keyup a
wait 0.706256
keydown a
wait 0.006079
keyup a
wait 0.706778
keydown a
wait 0.006290
keyup a
wait 0.706610
keydown a
wait 0.006079
keyup a
wait 7.147207
mousemove 1420 400
wait 0.006075
log * Aspect ratio back: put the aspect ratio back to the clip's own and wait for the frame to redraw at full width
check vlc/vlc-check-012.png
wait 2.048319
keydown f
wait 0.006211
keyup f
wait 0.047478
keydown space
wait 0.006244
keyup space
wait 10.071829
keydown space
wait 0.006163
keyup space
wait 0.062099
keydown Left
wait 0.006539
keyup Left
wait 0.576185
keydown Left
wait 0.006323
keyup Left
wait 0.556569
keydown Left
wait 0.006144
keyup Left
wait 0.554607
keydown Left
wait 0.006331
keyup Left
wait 0.573956
keydown Left
wait 0.006359
keyup Left
wait 0.568763
keydown Left
wait 0.006314
keyup Left
wait 0.578704
keydown Left
wait 0.006853
keyup Left
wait 0.567961
keydown Left
wait 0.006298
keyup Left
wait 0.563081
keydown Left
wait 0.006601
keyup Left
wait 0.562044
keydown Left
wait 0.006289
keyup Left
wait 0.572093
keydown Left
wait 0.006339
keyup Left
wait 0.582406
keydown Left
wait 0.006742
keyup Left
wait 2.059339
keydown Right
wait 0.006189
keyup Right
wait 1.073268
keydown Right
wait 0.006541
keyup Right
wait 7.651761
mousemove 1420 400
wait 0.006105
log * Fullscreen: go fullscreen and let the clip play through ten seconds of its timecode scaled to the whole screen, then pause and put the position back to the start of the clip with the player's own seek keys, held down until the seek clamps there, and step forward twice - the position bar is not where it was in the window, so this block ends on the keyboard rather than on a click
check vlc/vlc-check-013.png
wait 2.047901
keydown Escape
wait 0.007046
keyup Escape
wait 6.138871
mousemove 1420 400
wait 0.006133
log * Leave fullscreen: return to the window and wait for the frame to redraw at window size
check vlc/vlc-check-014.png
wait 2.048809
keydown n
wait 0.006151
keyup n
wait 10.050299
keydown space
wait 0.006131
keyup space
wait 0.801094
mousemove 325 856
wait 0.000018
mousedown 1
wait 0.000004
mouseup 1
wait 6.833035
mousemove 1420 400
wait 0.006139
log * Play 60 fps: advance to the next item in the playlist, `02-h264-1440x900p60.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark a fifth of the way along the bar
check vlc/vlc-check-015.png
wait 2.049587
keydown n
wait 0.006157
keyup n
wait 10.049808
keydown space
wait 0.006141
keyup space
wait 0.801524
mousemove 851 856
wait 0.000022
mousedown 1
wait 0.000058
mouseup 1
wait 6.838719
mousemove 1420 400
wait 0.006230
log * Play VP9: advance to `03-vp9-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark three fifths of the way along the bar
check vlc/vlc-check-016.png
wait 2.049670
keydown n
wait 0.006392
keyup n
wait 10.047348
keydown space
wait 0.006169
keyup space
wait 0.795947
mousemove 259 856
wait 0.000021
mousedown 1
wait 0.000170
mouseup 1
wait 6.836207
mousemove 1420 400
wait 0.006032
log * Play HEVC: advance to `04-hevc-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark just under a sixth of the way along the bar
check vlc/vlc-check-017.png
wait 2.051542
keydown n
wait 0.006211
keyup n
wait 10.051040
keydown space
wait 0.006209
keyup space
wait 0.805132
mousemove 1049 856
wait 0.000022
mousedown 1
wait 0.000015
mouseup 1
wait 6.838287
mousemove 1420 400
wait 0.006083
log * Play AV1: advance to `05-av1-1440x900p30.mkv`, let it play through ten seconds of its timecode, then pause and put the position on the mark three quarters of the way along the bar
check vlc/vlc-check-018.png
wait 2.048107
keydown n
wait 0.006169
keyup n
wait 10.047652
keydown space
wait 0.005940
keyup space
wait 0.799947
mousemove 851 856
wait 0.000020
mousedown 1
wait 0.000015
mouseup 1
wait 6.837026
mousemove 1420 400
wait 0.006325
log * Play upscaled SD: advance to `06-h264-640x400p30.mkv`, which the player has to scale up to fill the same window, let it play through ten seconds of its timecode, then pause and put the position on the mark three fifths of the way along the bar
check vlc/vlc-check-019.png
wait 2.046518
keydown p
wait 0.005902
keyup p
wait 3.049797
keydown space
wait 0.006083
keyup space
wait 0.800864
mousemove 325 856
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 6.837333
mousemove 1420 400
wait 0.006231
log * Previous clip: go back one item in the playlist to `05-av1-1440x900p30.mkv`, pause, and put the position on the mark a fifth of the way along the bar
check vlc/vlc-check-020.png
wait 2.799009
mousemove 1246 856
wait 0.000020
mousedown 1
wait 0.000015
mouseup 1
wait 1.740852
keydown space
wait 0.006204
keyup space
wait 12.047708
keydown space
wait 0.006201
keyup space
wait 0.804446
mousemove 1180 856
wait 0.000022
mousedown 1
wait 0.000007
mouseup 1
wait 6.839577
mousemove 1420 400
wait 0.006122
log * Play to the end of a clip: click the position bar inside the last five seconds of that clip, resume, and let it run past the end so the playlist advances to `06-h264-640x400p30.mkv` on its own, then pause and put the position on the mark most of the way along that clip's bar
check vlc/vlc-check-021.png
wait 36.147304
mousemove 1420 400
wait 0.006077
log * Idle paused: leave the player paused and untouched for thirty seconds
check vlc/vlc-check-022.png

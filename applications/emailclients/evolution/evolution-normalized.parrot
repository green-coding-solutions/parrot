# Parrot recording v2

startcommand = bash /tmp/repo/applications/emailclients/common/launch-with-session.sh evolution
windowtitle = Mail
windowclass = evolution

wait 47.547581
mousemove 720 890
wait 0.006030
wait 5.074049
log * Load app: wait for the main window to finish drawing, with the folder list and the empty message pane visible
check evolution/evolution-check-001.png
wait 3.107950
mousemove 90 376
wait 0.000020
mousedown 1
wait 0.000004
mouseup 1
wait 91.215132
mousemove 1117 147
wait 0.000016
mousedown 1
wait 0.000004
mouseup 1
wait 5.215341
mousemove 807 509
wait 0.000019
mousedown 1
wait 0.000007
mouseup 1
wait 7.215959
mousemove 1117 147
wait 0.000023
mousedown 1
wait 0.000007
mouseup 1
wait 12.290352
mousemove 720 890
wait 0.006327
wait 48.566436
log * Sync account: let the inbox finish downloading until the message count stops rising, entering the password `parrot` and ticking "remember" only if the client asks
check evolution/evolution-check-002.png
wait 3.116885
mousemove 450 172
wait 0.000027
mousedown 1
wait 0.000009
mouseup 1
wait 9.270783
mousemove 720 890
wait 0.006260
wait 4.073211
log * Read newest: open message 1, `Re: Release checklist for Aurora 4.2` from Nadia Oyelaran, and wait for the body to render
check evolution/evolution-check-003.png
wait 2.064618
keydown Control_L
wait 0.006419
keydown End
wait 0.006447
keyup Control_L
wait 0.006360
keyup End
wait 9.198364
mousemove 720 890
wait 0.006056
wait 1.102949
log * Scroll to bottom: scroll the message list down to the very last message without opening anything
check evolution/evolution-check-004.png
wait 2.061924
keydown Control_L
wait 0.006313
keydown Home
wait 0.006201
keyup Control_L
wait 0.006470
keyup Home
wait 5.122046
mousemove 450 196
wait 0.000024
mousedown 1
wait 0.000006
mouseup 1
wait 9.278901
mousemove 720 890
wait 0.006307
wait 3.141185
log * Read second: scroll back to the top and open message 2, `Staging cluster credentials rotated` from Dmitri Sokolov
check evolution/evolution-check-005.png
wait 3.108917
mousemove 450 316
wait 0.000016
mousedown 1
wait 0.000004
mouseup 1
wait 12.210872
mousemove 218 829
wait 0.000033
mousedown 1
wait 0.000007
mouseup 1
wait 6.211110
mousemove 265 785
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 0.150696
mousedown 1
wait 0.000023
mouseup 1
wait 9.397375
mousemove 720 511
wait 0.000019
mousedown 1
wait 0.000007
mouseup 1
wait 9.266788
mousemove 720 890
wait 0.006125
wait 7.479160
log * Open PDF attachment: open message 7, `Quarterly infrastructure review - final PDF`, and open `infrastructure-review-2026-Q2.pdf` from the attachment bar, then go back to the mailbox. Clients that bundle a viewer show it in a tab; the rest hand the file to the desktop, which has no PDF handler, so nothing opens - both are the same user action and both are in scope
check evolution/evolution-check-006.png
wait 3.119553
mousemove 1316 113
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 4.211481
mousemove 1300 175
wait 0.000019
mousedown 1
wait 0.000006
mouseup 1
wait 4.213042
mousemove 870 113
wait 0.000020
mousedown 1
wait 0.000007
mouseup 1
wait 2.153968
keydown Shift_L
wait 0.000021
keydown w
wait 0.020342
keyup Shift_L
wait 0.000142
keyup w
wait 0.020559
keydown i
wait 0.020617
keyup i
wait 0.020511
keydown n
wait 0.020561
keyup n
wait 0.020267
keydown d
wait 0.020733
keyup d
wait 0.020443
keydown v
wait 0.020476
keyup v
wait 0.020551
keydown a
wait 0.020043
keyup a
wait 0.020723
keydown n
wait 0.020531
keyup n
wait 0.020454
keydown e
wait 0.020397
keyup e
wait 2.077939
keydown Return
wait 0.006178
keyup Return
wait 29.179555
mousemove 720 890
wait 0.006368
log * Search account: search the whole account for `Windvane` and wait for the result list to stop growing
check evolution/evolution-check-007.png
wait 3.117006
mousemove 450 172
wait 0.000019
mousedown 1
wait 0.000007
mouseup 1
wait 9.291429
mousemove 720 890
wait 0.006140
wait 1.971509
log * Open result: open the first search result and wait for the body to render
check evolution/evolution-check-008.png
wait 3.111374
mousemove 1166 113
wait 0.000017
mousedown 1
wait 0.000009
mouseup 1
wait 12.152847
keydown Control_L
wait 0.006216
keydown Home
wait 0.006307
keyup Control_L
wait 0.006330
keyup Home
wait 9.196451
mousemove 720 890
wait 0.006094
wait 7.322130
log * Clear search: leave the search results and return to the inbox message list
check evolution/evolution-check-009.png
wait 3.126423
mousemove 450 196
wait 0.000025
mousedown 1
wait 0.000008
mouseup 1
wait 4.148352
mousedown 3
wait 0.000020
mouseup 3
wait 4.217457
mousemove 520 440
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 13.273113
mousemove 720 890
wait 0.006317
wait 17.941218
log * Move to Archive: select message 2 and move it into the archive folder
check evolution/evolution-check-010.png
wait 3.117312
mousemove 450 244
wait 0.000020
mousedown 1
wait 0.000007
mouseup 1
wait 4.152799
keydown Delete
wait 0.006182
keyup Delete
wait 13.195592
mousemove 720 890
wait 0.006173
wait 1.124347
log * Delete message: select message 4 as the list now stands and delete it, so it lands in the trash
check evolution/evolution-check-011.png
wait 3.107904
mousemove 450 268
wait 0.000024
mousedown 1
wait 0.000007
mouseup 1
wait 4.201662
mousemove 281 268
wait 0.000030
mousedown 1
wait 0.000004
mouseup 1
wait 9.273465
mousemove 720 890
wait 0.005949
wait 13.578183
log * Flag message: select message 5 as the list now stands and flag or star it
check evolution/evolution-check-012.png
wait 3.122538
mousemove 450 172
wait 0.000025
mousedown 1
wait 0.000008
mouseup 1
wait 2.150762
keydown Shift_L
wait 1.116430
mousemove 450 268
wait 0.000020
mousedown 1
wait 0.000004
mouseup 1
wait 0.157078
keyup Shift_L
wait 3.065352
keydown Control_L
wait 0.006232
keydown Shift_L
wait 0.006403
keydown k
wait 0.006189
keyup Shift_L
wait 0.000017
keyup Control_L
wait 0.012466
keyup k
wait 9.183834
mousemove 720 890
wait 0.006193
wait 4.116673
log * Mark five unread: select the top five messages and mark them as unread
check evolution/evolution-check-013.png
wait 3.112405
mousemove 32 399
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 5.222618
mousemove 95 445
wait 0.000020
mousedown 1
wait 0.000015
mouseup 1
wait 46.211764
mousemove 450 172
wait 0.000020
mousedown 1
wait 0.000014
mouseup 1
wait 16.264952
mousemove 720 890
wait 0.006350
wait 42.997172
log * Open Archive 2024: open the 2024 folder under the archive and read the newest message in it
check evolution/evolution-check-014.png
wait 3.127271
mousemove 90 376
wait 0.000020
mousedown 1
wait 0.000007
mouseup 1
wait 13.213914
mousemove 450 196
wait 0.000018
mousedown 1
wait 0.000003
mouseup 1
wait 5.152932
keydown Control_L
wait 0.006212
keydown r
wait 0.006262
keyup Control_L
wait 0.006170
keyup r
wait 2.357137
mousemove 614 150
wait 0.000022
mousedown 1
wait 0.000007
mouseup 1
wait 7.275982
mousemove 700 500
wait 0.000027
mousedown 1
wait 0.000023
mouseup 1
wait 2.154105
keydown Control_L
wait 0.006289
keydown Home
wait 0.006209
keyup Control_L
wait 0.006290
keyup Home
wait 2.065491
keydown Shift_L
wait 0.000040
keydown t
wait 0.017912
keyup Shift_L
wait 0.000027
keyup t
wait 0.017821
keydown h
wait 0.017765
keyup h
wait 0.017991
keydown a
wait 0.018014
keyup a
wait 0.017564
keydown n
wait 0.018063
keyup n
wait 0.017960
keydown k
wait 0.017837
keyup k
wait 0.017981
keydown space
wait 0.017930
keyup space
wait 0.018175
keydown y
wait 0.017861
keyup y
wait 0.018110
keydown o
wait 0.017778
keyup o
wait 0.017825
keydown u
wait 0.017745
keyup u
wait 0.018156
keydown space
wait 0.018178
keyup space
wait 0.017774
keydown s
wait 0.017790
keyup s
wait 0.018063
keydown o
wait 0.017828
keyup o
wait 0.017471
keydown space
wait 0.018121
keyup space
wait 0.017750
keydown m
wait 0.017863
keyup m
wait 0.017621
keydown u
wait 0.017761
keyup u
wait 0.017823
keydown c
wait 0.017793
keyup c
wait 0.017877
keydown h
wait 0.018035
keyup h
wait 2.077489
keydown Return
wait 0.006125
keyup Return
wait 1.073922
keydown Return
wait 0.006224
keyup Return
wait 3.123748
mousemove 52 26
wait 0.000017
mousedown 1
wait 0.000009
mouseup 1
wait 37.321258
mousemove 720 890
wait 0.006570
wait 34.305589
log * Reply and send: go back to the inbox, reply to message 2 with the body text `Thank you so much` and send it, entering the password `parrot` again only if the outgoing server asks
check evolution/evolution-check-015.png
wait 2.050273
keydown Control_L
wait 0.006225
keydown n
wait 0.006191
keyup Control_L
wait 0.006153
keyup n
wait 7.175995
keydown a
wait 0.015765
keyup a
wait 0.015408
keydown l
wait 0.015046
keyup l
wait 0.015569
keydown i
wait 0.015570
keyup i
wait 0.015489
keydown c
wait 0.015463
keyup c
wait 0.015569
keydown e
wait 0.015448
keyup e
wait 0.015572
keydown period
wait 0.015463
keyup period
wait 0.015391
keydown b
wait 0.015341
keyup b
wait 0.015393
keydown r
wait 0.015355
keyup r
wait 0.015518
keydown e
wait 0.015329
keyup e
wait 0.015393
keydown n
wait 0.015686
keyup n
wait 0.015512
keydown n
wait 0.015297
keyup n
wait 0.015670
keydown e
wait 0.015386
keyup e
wait 0.015405
keydown r
wait 0.015363
keyup r
wait 0.015461
keydown Shift_L
wait 0.000015
keydown 2
wait 0.015905
keyup Shift_L
wait 0.000037
keyup 2
wait 0.015666
keydown p
wait 0.015594
keyup p
wait 0.015222
keydown a
wait 0.015794
keyup a
wait 0.015513
keydown r
wait 0.015453
keyup r
wait 0.015277
keydown r
wait 0.015289
keyup r
wait 0.015542
keydown o
wait 0.015500
keyup o
wait 0.015527
keydown t
wait 0.015512
keyup t
wait 0.015472
keydown period
wait 0.015488
keyup period
wait 0.015617
keydown t
wait 0.015353
keyup t
wait 0.015616
keydown e
wait 0.015189
keyup e
wait 0.015756
keydown s
wait 0.015483
keyup s
wait 0.015518
keydown t
wait 0.015628
keyup t
wait 4.145917
mousemove 700 239
wait 0.000047
mousedown 1
wait 0.000008
mouseup 1
wait 2.157720
keydown Shift_L
wait 0.000027
keydown p
wait 0.015350
keyup Shift_L
wait 0.000034
keyup p
wait 0.015881
keydown a
wait 0.015566
keyup a
wait 0.015490
keydown r
wait 0.015533
keyup r
wait 0.015184
keydown r
wait 0.015584
keyup r
wait 0.015225
keydown o
wait 0.015695
keyup o
wait 0.015522
keydown t
wait 0.015261
keyup t
wait 0.015383
keydown space
wait 0.015257
keyup space
wait 0.015548
keydown b
wait 0.015294
keyup b
wait 0.015505
keydown e
wait 0.015416
keyup e
wait 0.015649
keydown n
wait 0.015493
keyup n
wait 0.015733
keydown c
wait 0.015318
keyup c
wait 0.015238
keydown h
wait 0.015453
keyup h
wait 0.015549
keydown m
wait 0.015573
keyup m
wait 0.015514
keydown a
wait 0.015382
keyup a
wait 0.015256
keydown r
wait 0.015442
keyup r
wait 0.015713
keydown k
wait 0.015473
keyup k
wait 3.130668
mousemove 700 400
wait 0.000021
mousedown 1
wait 0.000017
mouseup 1
wait 2.162639
keydown Shift_L
wait 0.000123
keydown t
wait 0.015508
keyup Shift_L
wait 0.000020
keyup t
wait 0.015753
keydown h
wait 0.015575
keyup h
wait 0.015597
keydown a
wait 0.015718
keyup a
wait 0.015425
keydown n
wait 0.015484
keyup n
wait 0.015266
keydown k
wait 0.015327
keyup k
wait 0.015373
keydown space
wait 0.015430
keyup space
wait 0.015349
keydown y
wait 0.015399
keyup y
wait 0.015204
keydown o
wait 0.015618
keyup o
wait 0.015447
keydown u
wait 0.015265
keyup u
wait 0.015550
keydown space
wait 0.015311
keyup space
wait 0.015620
keydown s
wait 0.015427
keyup s
wait 0.015555
keydown o
wait 0.015350
keyup o
wait 0.015196
keydown space
wait 0.015449
keyup space
wait 0.015198
keydown m
wait 0.015152
keyup m
wait 0.015550
keydown u
wait 0.015252
keyup u
wait 0.015291
keydown c
wait 0.015271
keyup c
wait 0.015514
keydown h
wait 0.015283
keyup h
wait 3.125558
mousemove 52 26
wait 0.000021
mousedown 1
wait 0.000015
mouseup 1
wait 11.333554
mousemove 720 890
wait 0.006208
wait 71.165718
log * Compose and send: compose a new message to `alice.brenner@parrot.test` with the subject `Parrot benchmark` and the body text `Thank you so much`, then send it
check evolution/evolution-check-016.png
wait 3.119152
mousemove 75 606
wait 0.000024
mousedown 3
wait 0.000006
mouseup 3
wait 4.205418
mousemove 140 829
wait 0.000020
mousedown 1
wait 0.000007
mouseup 1
wait 5.371874
mousemove 941 543
wait 0.000024
mousedown 1
wait 0.000007
mouseup 1
wait 16.258455
mousemove 720 890
wait 0.006157
wait 114.861724
log * Empty trash: empty the trash folder and confirm if asked
check evolution/evolution-check-017.png

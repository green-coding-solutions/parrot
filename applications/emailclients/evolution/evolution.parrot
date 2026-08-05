# Parrot recording v2

startcommand = bash /tmp/repo/applications/emailclients/common/launch-with-session.sh evolution
windowtitle = Mail
windowclass = evolution

wait 47.520906
mousemove 720 890
wait 0.006197
log * Load app: wait for the main window to finish drawing, with the folder list and the empty message pane visible
check evolution/evolution-check-001.png
wait 3.117159
mousemove 90 376
wait 0.000023
mousedown 1
wait 0.000007
mouseup 1
wait 91.198656
mousemove 1117 147
wait 0.000018
mousedown 1
wait 0.000004
mouseup 1
wait 5.212649
mousemove 807 509
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 7.208109
mousemove 1117 147
wait 0.000025
mousedown 1
wait 0.000007
mouseup 1
wait 12.288707
mousemove 720 890
wait 0.006091
log * Sync account: let the inbox finish downloading until the message count stops rising, entering the password `parrot` and ticking "remember" only if the client asks
check evolution/evolution-check-002.png
wait 3.120978
mousemove 450 172
wait 0.000022
mousedown 1
wait 0.000007
mouseup 1
wait 9.271053
mousemove 720 890
wait 0.006213
log * Read newest: open message 1, `Re: Release checklist for Aurora 4.2` from Nadia Oyelaran, and wait for the body to render
check evolution/evolution-check-003.png
wait 2.065159
keydown Control_L
wait 0.006244
keydown End
wait 0.007964
keyup Control_L
wait 0.006205
keyup End
wait 9.189008
mousemove 720 890
wait 0.006085
log * Scroll to bottom: scroll the message list down to the very last message without opening anything
check evolution/evolution-check-004.png
wait 2.065345
keydown Control_L
wait 0.006279
keydown Home
wait 0.006212
keyup Control_L
wait 0.006170
keyup Home
wait 5.128165
mousemove 450 196
wait 0.000022
mousedown 1
wait 0.000007
mouseup 1
wait 9.278996
mousemove 720 890
wait 0.006175
log * Read second: scroll back to the top and open message 2, `Staging cluster credentials rotated` from Dmitri Sokolov
check evolution/evolution-check-005.png
wait 3.117014
mousemove 450 316
wait 0.000033
mousedown 1
wait 0.000004
mouseup 1
wait 12.218284
mousemove 218 829
wait 0.000015
mousedown 1
wait 0.000003
mouseup 1
wait 6.218859
mousemove 265 785
wait 0.000023
mousedown 1
wait 0.000015
mouseup 1
wait 0.150825
mousedown 1
wait 0.000016
mouseup 1
wait 9.393348
mousemove 720 511
wait 0.000016
mousedown 1
wait 0.000059
mouseup 1
wait 9.278418
mousemove 720 890
wait 0.006143
log * Open PDF attachment: open message 7, `Quarterly infrastructure review - final PDF`, and open `infrastructure-review-2026-Q2.pdf` from the attachment bar, then go back to the mailbox. Clients that bundle a viewer show it in a tab; the rest hand the file to the desktop, which has no PDF handler, so nothing opens - both are the same user action and both are in scope
check evolution/evolution-check-006.png
wait 3.106950
mousemove 1316 113
wait 0.000018
mousedown 1
wait 0.000011
mouseup 1
wait 4.216210
mousemove 1300 175
wait 0.000021
mousedown 1
wait 0.000004
mouseup 1
wait 4.219511
mousemove 870 113
wait 0.000019
mousedown 1
wait 0.000006
mouseup 1
wait 2.155442
keydown Shift_L
wait 0.000034
keydown w
wait 0.020538
keyup Shift_L
wait 0.000080
keyup w
wait 0.020493
keydown i
wait 0.020487
keyup i
wait 0.020710
keydown n
wait 0.020517
keyup n
wait 0.020644
keydown d
wait 0.020599
keyup d
wait 0.020460
keydown v
wait 0.020508
keyup v
wait 0.020709
keydown a
wait 0.020113
keyup a
wait 0.020752
keydown n
wait 0.020694
keyup n
wait 0.020595
keydown e
wait 0.020537
keyup e
wait 2.073951
keydown Return
wait 0.006176
keyup Return
wait 29.168578
mousemove 720 890
wait 0.006188
log * Search account: search the whole account for `Windvane` and wait for the result list to stop growing
check evolution/evolution-check-007.png
wait 3.118378
mousemove 450 172
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 9.267704
mousemove 720 890
wait 0.006250
log * Open result: open the first search result and wait for the body to render
check evolution/evolution-check-008.png
wait 3.119046
mousemove 1166 113
wait 0.000016
mousedown 1
wait 0.000018
mouseup 1
wait 12.159414
keydown Control_L
wait 0.006440
keydown Home
wait 0.006337
keyup Control_L
wait 0.007892
keyup Home
wait 9.161614
mousemove 720 890
wait 0.006038
log * Clear search: leave the search results and return to the inbox message list
check evolution/evolution-check-009.png
wait 3.113079
mousemove 450 196
wait 0.000019
mousedown 1
wait 0.000007
mouseup 1
wait 4.157354
mousedown 3
wait 0.000022
mouseup 3
wait 4.210875
mousemove 520 440
wait 0.000015
mousedown 1
wait 0.000003
mouseup 1
wait 13.268919
mousemove 720 890
wait 0.006226
log * Move to Archive: select message 2 and move it into the archive folder
check evolution/evolution-check-010.png
wait 3.115234
mousemove 450 244
wait 0.000016
mousedown 1
wait 0.000004
mouseup 1
wait 4.154005
keydown Delete
wait 0.006171
keyup Delete
wait 13.178449
mousemove 720 890
wait 0.006185
log * Delete message: select message 4 as the list now stands and delete it, so it lands in the trash
check evolution/evolution-check-011.png
wait 3.116581
mousemove 450 268
wait 0.000017
mousedown 1
wait 0.000009
mouseup 1
wait 4.207906
mousemove 281 268
wait 0.000022
mousedown 1
wait 0.000006
mouseup 1
wait 9.268549
mousemove 720 890
wait 0.006151
log * Flag message: select message 5 as the list now stands and flag or star it
check evolution/evolution-check-012.png
wait 3.125103
mousemove 450 172
wait 0.000021
mousedown 1
wait 0.000016
mouseup 1
wait 2.158294
keydown Shift_L
wait 1.127572
mousemove 450 268
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 0.159863
keyup Shift_L
wait 3.065025
keydown Control_L
wait 0.006296
keydown Shift_L
wait 0.006577
keydown k
wait 0.006183
keyup Shift_L
wait 0.000027
keyup Control_L
wait 0.012508
keyup k
wait 9.176045
mousemove 720 890
wait 0.006290
log * Mark five unread: select the top five messages and mark them as unread
check evolution/evolution-check-013.png
wait 3.119809
mousemove 32 399
wait 0.000016
mousedown 1
wait 0.000004
mouseup 1
wait 5.210034
mousemove 95 445
wait 0.000021
mousedown 1
wait 0.000072
mouseup 1
wait 61.203753
mousemove 450 172
wait 0.000016
mousedown 1
wait 0.000003
mouseup 1
wait 5.156898
keydown Home
wait 0.006197
keyup Home
wait 7.110385
mousemove 450 172
wait 0.000018
mousedown 1
wait 0.000006
mouseup 1
wait 16.273971
mousemove 720 890
wait 0.006248
log * Open Archive 2024: open the 2024 folder under the archive and read the newest message in it
check evolution/evolution-check-014.png
wait 3.119573
mousemove 90 376
wait 0.000025
mousedown 1
wait 0.000008
mouseup 1
wait 13.208752
mousemove 450 196
wait 0.000017
mousedown 1
wait 0.000003
mouseup 1
wait 5.159250
keydown Control_L
wait 0.006157
keydown r
wait 0.006310
keyup Control_L
wait 0.006343
keyup r
wait 2.328460
mousemove 614 150
wait 0.000020
mousedown 1
wait 0.000006
mouseup 1
wait 7.269031
mousemove 700 500
wait 0.000020
mousedown 1
wait 0.000015
mouseup 1
wait 2.149901
keydown Control_L
wait 0.006262
keydown Home
wait 0.006289
keyup Control_L
wait 0.006435
keyup Home
wait 2.052012
keydown Shift_L
wait 0.000169
keydown t
wait 0.017961
keyup Shift_L
wait 0.000027
keyup t
wait 0.018190
keydown h
wait 0.018012
keyup h
wait 0.017863
keydown a
wait 0.018324
keyup a
wait 0.017992
keydown n
wait 0.017998
keyup n
wait 0.018170
keydown k
wait 0.018040
keyup k
wait 0.018017
keydown space
wait 0.018307
keyup space
wait 0.018102
keydown y
wait 0.017914
keyup y
wait 0.018020
keydown o
wait 0.017745
keyup o
wait 0.017740
keydown u
wait 0.018049
keyup u
wait 0.017985
keydown space
wait 0.017877
keyup space
wait 0.017973
keydown s
wait 0.017770
keyup s
wait 0.017915
keydown o
wait 0.018109
keyup o
wait 0.017741
keydown space
wait 0.017720
keyup space
wait 0.018093
keydown m
wait 0.017841
keyup m
wait 0.017829
keydown u
wait 0.018062
keyup u
wait 0.017662
keydown c
wait 0.017847
keyup c
wait 0.018131
keydown h
wait 0.017972
keyup h
wait 2.073148
keydown Return
wait 0.006222
keyup Return
wait 1.066958
keydown Return
wait 0.006200
keyup Return
wait 3.113784
mousemove 52 26
wait 0.000015
mousedown 1
wait 0.000003
mouseup 1
wait 37.225631
mousemove 720 890
wait 0.006174
log * Reply and send: go back to the inbox, reply to message 2 with the body text `Thank you so much` and send it, entering the password `parrot` again only if the outgoing server asks
check evolution/evolution-check-015.png
wait 2.055154
keydown Control_L
wait 0.006420
keydown n
wait 0.006098
keyup Control_L
wait 0.006217
keyup n
wait 7.179640
keydown a
wait 0.015328
keyup a
wait 0.015451
keydown l
wait 0.015478
keyup l
wait 0.015392
keydown i
wait 0.015151
keyup i
wait 0.015363
keydown c
wait 0.015208
keyup c
wait 0.015762
keydown e
wait 0.015262
keyup e
wait 0.015762
keydown period
wait 0.015466
keyup period
wait 0.015970
keydown b
wait 0.015389
keyup b
wait 0.015734
keydown r
wait 0.015510
keyup r
wait 0.015477
keydown e
wait 0.015806
keyup e
wait 0.015158
keydown n
wait 0.015728
keyup n
wait 0.015609
keydown n
wait 0.015544
keyup n
wait 0.015709
keydown e
wait 0.015602
keyup e
wait 0.015935
keydown r
wait 0.014805
keyup r
wait 0.015959
keydown Shift_L
wait 0.000028
keydown 2
wait 0.015495
keyup Shift_L
wait 0.000031
keyup 2
wait 0.016052
keydown p
wait 0.015392
keyup p
wait 0.015137
keydown a
wait 0.015251
keyup a
wait 0.015582
keydown r
wait 0.015365
keyup r
wait 0.015431
keydown r
wait 0.015132
keyup r
wait 0.015433
keydown o
wait 0.014958
keyup o
wait 0.015573
keydown t
wait 0.015318
keyup t
wait 0.015449
keydown period
wait 0.015339
keyup period
wait 0.015056
keydown t
wait 0.015450
keyup t
wait 0.015351
keydown e
wait 0.015313
keyup e
wait 0.015389
keydown s
wait 0.015327
keyup s
wait 0.015485
keydown t
wait 0.015454
keyup t
wait 4.129534
mousemove 700 239
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 2.148189
keydown Shift_L
wait 0.000025
keydown p
wait 0.015458
keyup Shift_L
wait 0.000022
keyup p
wait 0.015733
keydown a
wait 0.015146
keyup a
wait 0.015581
keydown r
wait 0.015617
keyup r
wait 0.015606
keydown r
wait 0.015338
keyup r
wait 0.015472
keydown o
wait 0.015607
keyup o
wait 0.015711
keydown t
wait 0.015120
keyup t
wait 0.015243
keydown space
wait 0.015383
keyup space
wait 0.015309
keydown b
wait 0.015259
keyup b
wait 0.015358
keydown e
wait 0.015090
keyup e
wait 0.015361
keydown n
wait 0.015110
keyup n
wait 0.015168
keydown c
wait 0.015082
keyup c
wait 0.015377
keydown h
wait 0.014980
keyup h
wait 0.015767
keydown m
wait 0.015595
keyup m
wait 0.015698
keydown a
wait 0.015709
keyup a
wait 0.015263
keydown r
wait 0.015119
keyup r
wait 0.015587
keydown k
wait 0.014965
keyup k
wait 3.124701
mousemove 700 400
wait 0.000020
mousedown 1
wait 0.000004
mouseup 1
wait 2.157318
keydown Shift_L
wait 0.000034
keydown t
wait 0.015338
keyup Shift_L
wait 0.000047
keyup t
wait 0.015297
keydown h
wait 0.015290
keyup h
wait 0.014971
keydown a
wait 0.015228
keyup a
wait 0.015302
keydown n
wait 0.015400
keyup n
wait 0.015583
keydown k
wait 0.015197
keyup k
wait 0.015345
keydown space
wait 0.015081
keyup space
wait 0.015297
keydown y
wait 0.015275
keyup y
wait 0.015512
keydown o
wait 0.015189
keyup o
wait 0.015577
keydown u
wait 0.015172
keyup u
wait 0.015194
keydown space
wait 0.015198
keyup space
wait 0.015486
keydown s
wait 0.015248
keyup s
wait 0.015273
keydown o
wait 0.015082
keyup o
wait 0.015738
keydown space
wait 0.015422
keyup space
wait 0.015301
keydown m
wait 0.015384
keyup m
wait 0.015451
keydown u
wait 0.015305
keyup u
wait 0.015669
keydown c
wait 0.015379
keyup c
wait 0.015544
keydown h
wait 0.015395
keyup h
wait 3.123902
mousemove 52 26
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 11.342538
mousemove 720 890
wait 0.006096
log * Compose and send: compose a new message to `alice.brenner@parrot.test` with the subject `Parrot benchmark` and the body text `Thank you so much`, then send it
check evolution/evolution-check-016.png
wait 3.120308
mousemove 75 606
wait 0.000021
mousedown 3
wait 0.000007
mouseup 3
wait 4.217405
mousemove 140 829
wait 0.000024
mousedown 1
wait 0.000007
mouseup 1
wait 5.354582
mousemove 941 543
wait 0.000019
mousedown 1
wait 0.000006
mouseup 1
wait 16.274988
mousemove 720 890
wait 0.006173
log * Empty trash: empty the trash folder and confirm if asked
check evolution/evolution-check-017.png

# Parrot recording v2

startcommand = bash /tmp/repo/applications/emailclients/common/launch-with-session.sh mailspring
windowtitle = Mailspring
windowclass = mailspring

wait 42.890695
mousemove 1290 700
wait 0.006147
log * Load app: wait for the main window to finish drawing, with the folder list and the empty message pane visible
check mailspring/mailspring-check-001.png
wait 96.174134
mousemove 1290 700
wait 0.006146
log * Sync account: let the inbox finish downloading until the message count stops rising, entering the password `parrot` and ticking "remember" only if the client asks
check mailspring/mailspring-check-002.png
wait 3.121916
mousemove 450 103
wait 0.000015
mousedown 1
wait 0.000004
mouseup 1
wait 9.269425
mousemove 1290 700
wait 0.006191
log * Read newest: open message 1, `Re: Release checklist for Aurora 4.2` from Nadia Oyelaran, and wait for the body to render
check mailspring/mailspring-check-003.png
wait 2.063531
keydown End
wait 0.006006
keyup End
wait 9.184595
mousemove 1290 700
wait 0.006130
log * Scroll to bottom: scroll the message list down to the very last message without opening anything
check mailspring/mailspring-check-004.png
wait 2.060710
keydown Home
wait 0.006346
keyup Home
wait 5.115479
mousemove 450 188
wait 0.000022
mousedown 1
wait 0.000006
mouseup 1
wait 9.264336
mousemove 1290 700
wait 0.006223
log * Read second: scroll back to the top and open message 2, `Staging cluster credentials rotated` from Dmitri Sokolov
check mailspring/mailspring-check-005.png
wait 3.125375
mousemove 450 613
wait 0.000020
mousedown 1
wait 0.000007
mouseup 1
wait 12.220793
mousemove 949 518
wait 0.000014
mousedown 1
wait 0.000009
mouseup 1
wait 6.226503
keydown Control_L
wait 0.006297
keydown w
wait 0.006092
keyup Control_L
wait 0.006820
keyup w
wait 9.230496
mousemove 1290 700
wait 0.006262
log * Open PDF attachment: open message 7, `Quarterly infrastructure review - final PDF`, and open `infrastructure-review-2026-Q2.pdf` from the attachment bar, then go back to the mailbox. Clients that bundle a viewer show it in a tab; the rest hand the file to the desktop, which has no PDF handler, so nothing opens - both are the same user action and both are in scope
check mailspring/mailspring-check-006.png
wait 3.112885
mousemove 455 43
wait 0.000024
mousedown 1
wait 0.000245
mouseup 1
wait 2.151908
keydown Shift_L
wait 0.000026
keydown w
wait 0.015316
keyup Shift_L
wait 0.000025
keyup w
wait 0.015414
keydown i
wait 0.015425
keyup i
wait 0.015568
keydown n
wait 0.015444
keyup n
wait 0.015206
keydown d
wait 0.015800
keyup d
wait 0.015628
keydown v
wait 0.015630
keyup v
wait 0.015575
keydown a
wait 0.015292
keyup a
wait 0.015438
keydown n
wait 0.015220
keyup n
wait 0.015682
keydown e
wait 0.015310
keyup e
wait 2.065642
keydown Return
wait 0.006145
keyup Return
wait 29.173768
mousemove 1290 700
wait 0.006324
log * Search account: search the whole account for `Windvane` and wait for the result list to stop growing
check mailspring/mailspring-check-007.png
wait 3.130504
mousemove 450 103
wait 0.000016
mousedown 1
wait 0.000004
mouseup 1
wait 9.267868
mousemove 1290 700
wait 0.006249
log * Open result: open the first search result and wait for the body to render
check mailspring/mailspring-check-008.png
wait 3.115350
mousemove 645 43
wait 0.000019
mousedown 1
wait 0.000014
mouseup 1
wait 10.163974
keydown Home
wait 0.006325
keyup Home
wait 9.170072
mousemove 1290 700
wait 0.006382
log * Clear search: leave the search results and return to the inbox message list
check mailspring/mailspring-check-009.png
wait 3.107830
mousemove 450 188
wait 0.000024
mousedown 1
wait 0.000006
mouseup 1
wait 5.210734
mousemove 887 44
wait 0.000020
mousedown 1
wait 0.000004
mouseup 1
wait 13.288092
mousemove 1290 700
wait 0.006923
log * Move to Archive: select message 2 and move it into the archive folder
check mailspring/mailspring-check-010.png
wait 3.122378
mousemove 450 358
wait 0.000019
mousedown 1
wait 0.000102
mouseup 1
wait 5.203213
mousemove 971 44
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 13.270535
mousemove 1290 700
wait 0.006157
log * Delete message: select message 4 as the list now stands and delete it, so it lands in the trash
check mailspring/mailspring-check-011.png
wait 3.114535
mousemove 450 443
wait 0.000020
mousedown 1
wait 0.000017
mouseup 1
wait 5.201752
mousemove 1024 44
wait 0.000019
mousedown 1
wait 0.000007
mouseup 1
wait 9.278514
mousemove 1290 700
wait 0.006128
log * Flag message: select message 5 as the list now stands and flag or star it
check mailspring/mailspring-check-012.png
wait 3.120479
mousemove 450 103
wait 0.000024
mousedown 1
wait 0.000016
mouseup 1
wait 2.156182
keydown Shift_L
wait 1.117666
mousemove 450 443
wait 0.000022
mousedown 1
wait 0.000015
mouseup 1
wait 0.149493
keyup Shift_L
wait 5.121515
mousemove 1049 44
wait 0.000021
mousedown 1
wait 0.000006
mouseup 1
wait 11.278623
mousemove 1290 700
wait 0.006162
log * Mark five unread: select the top five messages and mark them as unread
check mailspring/mailspring-check-013.png
wait 3.118746
mousemove 85 372
wait 0.000020
mousedown 1
wait 0.000007
mouseup 1
wait 46.203263
mousemove 450 103
wait 0.000025
mousedown 1
wait 0.000197
mouseup 1
wait 13.270638
mousemove 1290 700
wait 0.006461
log * Open Archive 2024: open the 2024 folder under the archive and read the newest message in it
check mailspring/mailspring-check-014.png
wait 3.122351
mousemove 85 101
wait 0.000022
mousedown 1
wait 0.000007
mouseup 1
wait 15.161212
keydown Home
wait 0.006090
keyup Home
wait 4.128625
mousemove 450 188
wait 0.000021
mousedown 1
wait 0.000007
mouseup 1
wait 7.204695
mousemove 1078 140
wait 0.000016
mousedown 1
wait 0.000004
mouseup 1
wait 9.211622
mousemove 900 745
wait 0.000032
mousedown 1
wait 0.000008
mouseup 1
wait 2.154434
keydown Shift_L
wait 0.000024
keydown t
wait 0.017866
keyup Shift_L
wait 0.000029
keyup t
wait 0.017944
keydown h
wait 0.018129
keyup h
wait 0.017622
keydown a
wait 0.017836
keyup a
wait 0.017711
keydown n
wait 0.018432
keyup n
wait 0.018161
keydown k
wait 0.017943
keyup k
wait 0.018098
keydown space
wait 0.017887
keyup space
wait 0.017813
keydown y
wait 0.018008
keyup y
wait 0.018202
keydown o
wait 0.017687
keyup o
wait 0.017999
keydown u
wait 0.017827
keyup u
wait 0.017979
keydown space
wait 0.018221
keyup space
wait 0.017981
keydown s
wait 0.018120
keyup s
wait 0.018241
keydown o
wait 0.017836
keyup o
wait 0.018304
keydown space
wait 0.017989
keyup space
wait 0.017992
keydown m
wait 0.018002
keyup m
wait 0.018172
keydown u
wait 0.017902
keyup u
wait 0.017929
keydown c
wait 0.018244
keyup c
wait 0.017884
keydown h
wait 0.018165
keyup h
wait 3.118778
mousemove 729 867
wait 0.000018
mousedown 1
wait 0.000014
mouseup 1
wait 26.290520
mousemove 1290 700
wait 0.006100
log * Reply and send: go back to the inbox, reply to message 2 with the body text `Thank you so much` and send it, entering the password `parrot` again only if the outgoing server asks
check mailspring/mailspring-check-015.png
wait 3.122778
mousemove 110 44
wait 0.000023
mousedown 1
wait 0.000017
mouseup 1
wait 7.280979
mousemove 700 59
wait 0.000016
mousedown 1
wait 0.000094
mouseup 1
wait 1.153582
keydown a
wait 0.015267
keyup a
wait 0.015450
keydown l
wait 0.015543
keyup l
wait 0.015352
keydown i
wait 0.015335
keyup i
wait 0.015712
keydown c
wait 0.015499
keyup c
wait 0.015618
keydown e
wait 0.015355
keyup e
wait 0.015283
keydown period
wait 0.015367
keyup period
wait 0.015480
keydown b
wait 0.015315
keyup b
wait 0.016089
keydown r
wait 0.015261
keyup r
wait 0.015574
keydown e
wait 0.015531
keyup e
wait 0.015335
keydown n
wait 0.015521
keyup n
wait 0.015581
keydown n
wait 0.015379
keyup n
wait 0.015368
keydown e
wait 0.015503
keyup e
wait 0.015411
keydown r
wait 0.015592
keyup r
wait 0.015307
keydown Shift_L
wait 0.000201
keydown 2
wait 0.015265
keyup Shift_L
wait 0.000172
keyup 2
wait 0.015625
keydown p
wait 0.015431
keyup p
wait 0.015559
keydown a
wait 0.015235
keyup a
wait 0.015291
keydown r
wait 0.015131
keyup r
wait 0.015571
keydown r
wait 0.015090
keyup r
wait 0.015371
keydown o
wait 0.015423
keyup o
wait 0.015534
keydown t
wait 0.015332
keyup t
wait 0.015293
keydown period
wait 0.015100
keyup period
wait 0.015312
keydown t
wait 0.015280
keyup t
wait 0.015518
keydown e
wait 0.015470
keyup e
wait 0.015306
keydown s
wait 0.015364
keyup s
wait 0.015638
keydown t
wait 0.015187
keyup t
wait 4.114817
mousemove 700 152
wait 0.000037
mousedown 1
wait 0.000009
mouseup 1
wait 2.155988
keydown Shift_L
wait 0.000026
keydown p
wait 0.015149
keyup Shift_L
wait 0.000023
keyup p
wait 0.015395
keydown a
wait 0.015306
keyup a
wait 0.015564
keydown r
wait 0.015589
keyup r
wait 0.015740
keydown r
wait 0.015277
keyup r
wait 0.015520
keydown o
wait 0.015471
keyup o
wait 0.015745
keydown t
wait 0.015544
keyup t
wait 0.015625
keydown space
wait 0.015470
keyup space
wait 0.015597
keydown b
wait 0.015354
keyup b
wait 0.015653
keydown e
wait 0.015315
keyup e
wait 0.015470
keydown n
wait 0.015395
keyup n
wait 0.015566
keydown c
wait 0.015241
keyup c
wait 0.015336
keydown h
wait 0.015323
keyup h
wait 0.015345
keydown m
wait 0.015365
keyup m
wait 0.015382
keydown a
wait 0.015518
keyup a
wait 0.015462
keydown r
wait 0.015413
keyup r
wait 0.015541
keydown k
wait 0.015418
keyup k
wait 3.128391
mousemove 700 300
wait 0.000023
mousedown 1
wait 0.000006
mouseup 1
wait 2.157073
keydown Shift_L
wait 0.000033
keydown t
wait 0.015333
keyup Shift_L
wait 0.000025
keyup t
wait 0.015436
keydown h
wait 0.015231
keyup h
wait 0.015463
keydown a
wait 0.015512
keyup a
wait 0.015663
keydown n
wait 0.015493
keyup n
wait 0.015447
keydown k
wait 0.015613
keyup k
wait 0.015690
keydown space
wait 0.015626
keyup space
wait 0.015407
keydown y
wait 0.015607
keyup y
wait 0.015467
keydown o
wait 0.015421
keyup o
wait 0.015720
keydown u
wait 0.015532
keyup u
wait 0.015557
keydown space
wait 0.015500
keyup space
wait 0.015602
keydown s
wait 0.015324
keyup s
wait 0.015495
keydown o
wait 0.015348
keyup o
wait 0.015664
keydown space
wait 0.015408
keyup space
wait 0.015450
keydown m
wait 0.015280
keyup m
wait 0.015216
keydown u
wait 0.015249
keyup u
wait 0.015427
keydown c
wait 0.015321
keyup c
wait 0.015818
keydown h
wait 0.015432
keyup h
wait 3.137261
mousemove 63 878
wait 0.000019
mousedown 1
wait 0.000004
mouseup 1
wait 21.322920
mousemove 1290 700
wait 0.006219
log * Compose and send: compose a new message to `alice.brenner@parrot.test` with the subject `Parrot benchmark` and the body text `Thank you so much`, then send it
check mailspring/mailspring-check-016.png
wait 3.116306
mousemove 85 263
wait 0.000022
mousedown 1
wait 0.000016
mouseup 1
wait 21.209640
mousemove 596 78
wait 0.000024
mousedown 1
wait 0.000014
mouseup 1
wait 21.270057
mousemove 1290 700
wait 0.006616
log * Empty trash: empty the trash folder and confirm if asked
check mailspring/mailspring-check-017.png

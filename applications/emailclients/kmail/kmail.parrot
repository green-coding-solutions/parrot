# Parrot recording v2

startcommand = bash /tmp/repo/applications/emailclients/common/launch-with-session.sh kmail
windowtitle = KMail
windowclass = kmail2

wait 52.621451
mousemove 125 780
wait 0.006209
log * Load app: wait for the main window to finish drawing, with the folder list and the empty message pane visible
check kmail/kmail-check-001.png
wait 3.109216
mousemove 10 188
wait 0.000063
mousedown 1
wait 0.000021
mouseup 1
wait 8.222573
mousemove 60 205
wait 0.000023
mousedown 1
wait 0.000049
mouseup 1
wait 156.279459
mousemove 125 780
wait 0.006193
log * Sync account: let the inbox finish downloading until the message count stops rising, entering the password `parrot` and ticking "remember" only if the client asks
check kmail/kmail-check-002.png
wait 3.109422
mousemove 700 98
wait 0.000047
mousedown 1
wait 0.000024
mouseup 1
wait 11.282753
mousemove 125 780
wait 0.006340
log * Read newest: open message 1, `Re: Release checklist for Aurora 4.2` from Nadia Oyelaran, and wait for the body to render
check kmail/kmail-check-003.png
wait 3.110559
mousemove 1433 540
wait 0.000016
mousedown 2
wait 0.000004
mouseup 2
wait 9.274448
mousemove 125 780
wait 0.006186
log * Scroll to bottom: scroll the message list down to the very last message without opening anything
check kmail/kmail-check-004.png
wait 3.126459
mousemove 1433 95
wait 0.000025
mousedown 2
wait 0.000018
mouseup 2
wait 5.216800
mousemove 700 136
wait 0.000032
mousedown 1
wait 0.000020
mouseup 1
wait 11.279852
mousemove 125 780
wait 0.006171
log * Read second: scroll back to the top and open message 2, `Staging cluster credentials rotated` from Dmitri Sokolov
check kmail/kmail-check-005.png
wait 3.109648
mousemove 700 326
wait 0.000021
mousedown 1
wait 0.000059
mouseup 1
wait 12.217560
mousemove 800 750
wait 0.000018
mousedown 5
wait 0.000071
mouseup 5
wait 0.120283
mousedown 5
wait 0.000015
mouseup 5
wait 0.119974
mousedown 5
wait 0.000118
mouseup 5
wait 0.120194
mousedown 5
wait 0.000133
mouseup 5
wait 0.120007
mousedown 5
wait 0.000291
mouseup 5
wait 0.119902
mousedown 5
wait 0.000021
mouseup 5
wait 0.120064
mousedown 5
wait 0.000032
mouseup 5
wait 0.120223
mousedown 5
wait 0.000044
mouseup 5
wait 0.120159
mousedown 5
wait 0.000016
mouseup 5
wait 0.120076
mousedown 5
wait 0.000074
mouseup 5
wait 5.231368
mousemove 420 841
wait 0.000022
mousedown 1
wait 0.000081
mouseup 1
wait 0.150080
mousedown 1
wait 0.000024
mouseup 1
wait 7.417831
mousemove 560 446
wait 0.000021
mousedown 1
wait 0.000026
mouseup 1
wait 9.280454
mousemove 1029 207
wait 0.000022
mousedown 1
wait 0.000014
mouseup 1
wait 9.336134
mousemove 125 780
wait 0.006098
log * Open PDF attachment: open message 7, `Quarterly infrastructure review - final PDF`, and open `infrastructure-review-2026-Q2.pdf` from the attachment bar, then go back to the mailbox. Clients that bundle a viewer show it in a tab; the rest hand the file to the desktop, which has no PDF handler, so nothing opens - both are the same user action and both are in scope
check kmail/kmail-check-006.png
wait 3.120361
mousemove 700 66
wait 0.000016
mousedown 1
wait 0.000024
mouseup 1
wait 2.161222
keydown Shift_L
wait 0.000034
keydown w
wait 0.017857
keyup Shift_L
wait 0.000036
keyup w
wait 0.017844
keydown i
wait 0.017696
keyup i
wait 0.017742
keydown n
wait 0.017661
keyup n
wait 0.017822
keydown d
wait 0.017618
keyup d
wait 0.017947
keydown v
wait 0.017646
keyup v
wait 0.018337
keydown a
wait 0.017860
keyup a
wait 0.018409
keydown n
wait 0.017815
keyup n
wait 0.017690
keydown e
wait 0.017753
keyup e
wait 24.191877
mousemove 125 780
wait 0.006130
log * Search account: search the whole account for `Windvane` and wait for the result list to stop growing
check kmail/kmail-check-007.png
wait 3.115759
mousemove 700 98
wait 0.000025
mousedown 1
wait 0.000042
mouseup 1
wait 11.264229
mousemove 125 780
wait 0.006055
log * Open result: open the first search result and wait for the body to render
check kmail/kmail-check-008.png
wait 3.108109
mousemove 1398 66
wait 0.000019
mousedown 1
wait 0.000066
mouseup 1
wait 13.214842
mousemove 1433 95
wait 0.000044
mousedown 2
wait 0.000058
mouseup 2
wait 4.205793
mousemove 700 98
wait 0.000044
mousedown 1
wait 0.000028
mouseup 1
wait 11.272733
mousemove 125 780
wait 0.006039
log * Clear search: leave the search results and return to the inbox message list
check kmail/kmail-check-009.png
wait 3.112148
mousemove 700 136
wait 0.000047
mousedown 1
wait 0.000044
mouseup 1
wait 7.261508
mousemove 248 10
wait 0.000023
mousedown 1
wait 0.000086
mouseup 1
wait 4.263744
mousemove 350 288
wait 0.000032
mousedown 1
wait 0.000056
mouseup 1
wait 4.273533
mousemove 668 315
wait 0.000016
mousedown 1
wait 0.000011
mouseup 1
wait 4.268251
mousemove 816 390
wait 0.000018
mousedown 1
wait 0.000009
mouseup 1
wait 4.266469
mousemove 979 467
wait 0.000021
mousedown 1
wait 0.000059
mouseup 1
wait 15.260634
mousemove 125 780
wait 0.006250
log * Move to Archive: select message 2 and move it into the archive folder
check kmail/kmail-check-010.png
wait 3.107481
mousemove 700 212
wait 0.000020
mousedown 1
wait 0.000127
mouseup 1
wait 5.149152
keydown Delete
wait 0.006293
keyup Delete
wait 13.184533
mousemove 125 780
wait 0.006138
log * Delete message: select message 4 as the list now stands and delete it, so it lands in the trash
check kmail/kmail-check-011.png
wait 3.121171
mousemove 700 250
wait 0.000020
mousedown 1
wait 0.000088
mouseup 1
wait 7.262715
mousemove 248 10
wait 0.000020
mousedown 1
wait 0.000095
mouseup 1
wait 4.249902
mousemove 350 315
wait 0.000023
mousedown 1
wait 0.000065
mouseup 1
wait 4.259455
mousemove 706 367
wait 0.000022
mousedown 1
wait 0.000022
mouseup 1
wait 11.267354
mousemove 125 780
wait 0.006276
log * Flag message: select message 5 as the list now stands and flag or star it
check kmail/kmail-check-012.png
wait 3.120714
mousemove 700 98
wait 0.000020
mousedown 1
wait 0.000103
mouseup 1
wait 2.154665
keydown Shift_L
wait 1.127997
mousemove 700 250
wait 0.000019
mousedown 1
wait 0.000069
mouseup 1
wait 0.153331
keyup Shift_L
wait 4.066305
keydown Control_L
wait 0.006163
keydown u
wait 0.006180
keyup Control_L
wait 0.006263
keyup u
wait 9.187178
mousemove 125 780
wait 0.006318
log * Mark five unread: select the top five messages and mark them as unread
check kmail/kmail-check-013.png
wait 3.117562
mousemove 30 256
wait 0.000015
mousedown 1
wait 0.000009
mouseup 1
wait 6.205944
mousemove 95 290
wait 0.000018
mousedown 1
wait 0.000116
mouseup 1
wait 91.228676
mousemove 700 98
wait 0.000017
mousedown 1
wait 0.000050
mouseup 1
wait 13.256895
mousemove 125 780
wait 0.006056
log * Open Archive 2024: open the 2024 folder under the archive and read the newest message in it
check kmail/kmail-check-014.png
wait 4.119655
mousemove 60 205
wait 0.000018
mousedown 1
wait 0.000215
mouseup 1
wait 26.221524
mousemove 1433 95
wait 0.000023
mousedown 2
wait 0.000122
mouseup 2
wait 4.208219
mousemove 700 136
wait 0.000022
mousedown 1
wait 0.000015
mouseup 1
wait 5.153038
keydown r
wait 0.006242
keyup r
wait 10.247727
mousemove 700 500
wait 0.000017
mousedown 1
wait 0.000005
mouseup 1
wait 2.153489
keydown Control_L
wait 0.006258
keydown Home
wait 0.006544
keyup Control_L
wait 0.006055
keyup Home
wait 2.063025
keydown Shift_L
wait 0.000101
keydown t
wait 0.017890
keyup Shift_L
wait 0.000034
keyup t
wait 0.018046
keydown h
wait 0.017872
keyup h
wait 0.018061
keydown a
wait 0.018131
keyup a
wait 0.018214
keydown n
wait 0.017856
keyup n
wait 0.018014
keydown k
wait 0.018208
keyup k
wait 0.018005
keydown space
wait 0.017753
keyup space
wait 0.017595
keydown y
wait 0.017832
keyup y
wait 0.018179
keydown o
wait 0.018186
keyup o
wait 0.017927
keydown u
wait 0.018021
keyup u
wait 0.018514
keydown space
wait 0.017623
keyup space
wait 0.017867
keydown s
wait 0.017895
keyup s
wait 0.018459
keydown o
wait 0.017781
keyup o
wait 0.018156
keydown space
wait 0.017841
keyup space
wait 0.018046
keydown m
wait 0.018106
keyup m
wait 0.018027
keydown u
wait 0.018068
keyup u
wait 0.017888
keydown c
wait 0.017817
keyup c
wait 0.018097
keydown h
wait 0.018058
keyup h
wait 2.069796
keydown Return
wait 0.006298
keyup Return
wait 1.064392
keydown Return
wait 0.006333
keyup Return
wait 3.118455
mousemove 344 197
wait 0.000027
mousedown 1
wait 0.000101
mouseup 1
wait 11.409847
mousemove 758 486
wait 0.000019
mousedown 1
wait 0.000071
mouseup 1
wait 0.152647
keydown p
wait 0.020310
keyup p
wait 0.020065
keydown a
wait 0.020786
keyup a
wait 0.020437
keydown r
wait 0.020049
keyup r
wait 0.020439
keydown r
wait 0.020316
keyup r
wait 0.020760
keydown o
wait 0.020369
keyup o
wait 0.020506
keydown t
wait 0.020568
keyup t
wait 3.279648
mousemove 805 548
wait 0.000016
mousedown 1
wait 0.000015
mouseup 1
wait 6.419414
mousemove 653 550
wait 0.000019
mousedown 1
wait 0.000088
mouseup 1
wait 31.351535
mousemove 125 780
wait 0.005938
log * Reply and send: go back to the inbox, reply to message 2 with the body text `Thank you so much` and send it, entering the password `parrot` again only if the outgoing server asks
check kmail/kmail-check-015.png
wait 4.178172
mousemove 248 10
wait 0.000020
mousedown 1
wait 0.000048
mouseup 1
wait 4.258928
mousemove 248 34
wait 0.000032
mousedown 1
wait 0.000016
mouseup 1
wait 10.214792
keydown a
wait 0.015559
keyup a
wait 0.015441
keydown l
wait 0.015618
keyup l
wait 0.015519
keydown i
wait 0.015635
keyup i
wait 0.015388
keydown c
wait 0.015827
keyup c
wait 0.015530
keydown e
wait 0.015470
keyup e
wait 0.015726
keydown period
wait 0.015419
keyup period
wait 0.015641
keydown b
wait 0.015410
keyup b
wait 0.015318
keydown r
wait 0.015359
keyup r
wait 0.015493
keydown e
wait 0.015357
keyup e
wait 0.015446
keydown n
wait 0.015545
keyup n
wait 0.015559
keydown n
wait 0.015534
keyup n
wait 0.015676
keydown e
wait 0.015196
keyup e
wait 0.015580
keydown r
wait 0.015690
keyup r
wait 0.015636
keydown Shift_L
wait 0.000025
keydown 2
wait 0.015395
keyup Shift_L
wait 0.000016
keyup 2
wait 0.015664
keydown p
wait 0.015510
keyup p
wait 0.015517
keydown a
wait 0.015893
keyup a
wait 0.015155
keydown r
wait 0.015705
keyup r
wait 0.015824
keydown r
wait 0.015753
keyup r
wait 0.015433
keydown o
wait 0.015709
keyup o
wait 0.015460
keydown t
wait 0.015525
keyup t
wait 0.015593
keydown period
wait 0.015604
keyup period
wait 0.015561
keydown t
wait 0.015443
keyup t
wait 0.015392
keydown e
wait 0.015508
keyup e
wait 0.015368
keydown s
wait 0.015479
keyup s
wait 0.015281
keydown t
wait 0.015111
keyup t
wait 4.116780
mousemove 767 321
wait 0.000022
mousedown 1
wait 0.000112
mouseup 1
wait 2.153064
keydown Shift_L
wait 0.000076
keydown p
wait 0.015382
keyup Shift_L
wait 0.000021
keyup p
wait 0.015668
keydown a
wait 0.015499
keyup a
wait 0.015584
keydown r
wait 0.015733
keyup r
wait 0.015623
keydown r
wait 0.015469
keyup r
wait 0.015603
keydown o
wait 0.015515
keyup o
wait 0.015470
keydown t
wait 0.015336
keyup t
wait 0.015358
keydown space
wait 0.015696
keyup space
wait 0.015966
keydown b
wait 0.015228
keyup b
wait 0.015570
keydown e
wait 0.015658
keyup e
wait 0.015568
keydown n
wait 0.015427
keyup n
wait 0.015484
keydown c
wait 0.015611
keyup c
wait 0.015588
keydown h
wait 0.015704
keyup h
wait 0.015629
keydown m
wait 0.015509
keyup m
wait 0.015670
keydown a
wait 0.015311
keyup a
wait 0.015757
keydown r
wait 0.015203
keyup r
wait 0.015607
keydown k
wait 0.015078
keyup k
wait 3.122080
mousemove 700 500
wait 0.000016
mousedown 1
wait 0.000089
mouseup 1
wait 2.153355
keydown Shift_L
wait 0.000029
keydown t
wait 0.015834
keyup Shift_L
wait 0.000020
keyup t
wait 0.015760
keydown h
wait 0.015291
keyup h
wait 0.015763
keydown a
wait 0.015281
keyup a
wait 0.015162
keydown n
wait 0.015360
keyup n
wait 0.015599
keydown k
wait 0.015425
keyup k
wait 0.015452
keydown space
wait 0.015781
keyup space
wait 0.015227
keydown y
wait 0.015862
keyup y
wait 0.015627
keydown o
wait 0.015671
keyup o
wait 0.015469
keydown u
wait 0.015685
keyup u
wait 0.015482
keydown space
wait 0.015661
keyup space
wait 0.015624
keydown s
wait 0.015569
keyup s
wait 0.015389
keydown o
wait 0.015525
keyup o
wait 0.015754
keydown space
wait 0.015400
keyup space
wait 0.015853
keydown m
wait 0.015675
keyup m
wait 0.015471
keydown u
wait 0.015680
keyup u
wait 0.015430
keydown c
wait 0.015597
keyup c
wait 0.015666
keydown h
wait 0.015651
keyup h
wait 3.123235
mousemove 344 197
wait 0.000025
mousedown 1
wait 0.000084
mouseup 1
wait 73.137236
mousemove 125 780
wait 0.006239
log * Compose and send: compose a new message to `alice.brenner@parrot.test` with the subject `Parrot benchmark` and the body text `Thank you so much`, then send it
check kmail/kmail-check-016.png
wait 4.123319
mousemove 95 239
wait 0.000021
mousedown 1
wait 0.000043
mouseup 1
wait 62.253115
mousemove 20 10
wait 0.000057
mousedown 1
wait 0.000057
mouseup 1
wait 4.277567
mousemove 110 269
wait 0.000016
mousedown 1
wait 0.000038
mouseup 1
wait 3.358788
mousemove 831 497
wait 0.000020
mousedown 1
wait 0.000016
mouseup 1
wait 22.268508
mousemove 184 10
wait 0.000017
mousedown 1
wait 0.000036
mouseup 1
wait 4.263059
mousemove 232 140
wait 0.000019
mousedown 1
wait 0.000082
mouseup 1
wait 43.272074
mousemove 125 780
wait 0.006016
log * Empty trash: empty the trash folder and confirm if asked
check kmail/kmail-check-017.png

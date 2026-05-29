# Parrot recording v2

startcommand = evince
windowtitle = Evince
windowclass = evince

wait 1.000000
mousemove 720 450
wait 0.063826
wait 8.165767
log * Load app
check evince/evince-check-001.png
wait 2.545072
mousemove 68 30
wait 0.000026
mousedown 1
wait 0.127568
mouseup 1
wait 0.715998
keydown Control_L
wait 0.636720
keydown l
wait 0.066757
keyup l
wait 0.384605
keyup Control_L
wait 0.533307
keydown slash
wait 0.074678
keyup slash
wait 0.265799
keydown t
wait 0.078091
keyup t
wait 0.209159
keydown m
wait 0.039092
keydown p
wait 0.050498
keyup m
wait 0.061586
keyup p
wait 0.336188
keydown slash
wait 0.079698
keyup slash
wait 0.740938
keydown p
wait 0.076781
keyup p
wait 0.185120
keydown d
wait 0.069678
keydown f
wait 0.039396
keyup d
wait 0.055974
keyup f
wait 0.983736
keydown period
wait 0.073907
keyup period
wait 0.615319
keydown p
wait 0.065074
keyup p
wait 0.271053
keydown d
wait 0.063943
keydown f
wait 0.054781
keyup d
wait 0.047970
keyup f
wait 0.240470
keydown Return
wait 0.079741
keyup Return
wait 3.199965
wait 5.137696
log * Open the document [20yearsofKDE.pdf](20yearsofKDE.pdf) from the local disk
check evince/evince-check-002.png
wait 1.904077
mousemove 66 21
wait 0.000020
mousedown 1
wait 0.044488
mouseup 1
wait 0.084118
mousedown 1
wait 0.093151
mouseup 1
wait 1.194647
keydown 8
wait 0.057103
keydown 1
wait 0.022226
keyup 8
wait 0.072230
keyup 1
wait 0.480445
keydown Return
wait 0.079942
keyup Return
wait 1.215358
wait 3.502221
log * Jump to page 81 by entering the page number
check evince/evince-check-003.png
wait 2.660291
mousemove 526 510
wait 0.000019
mousedown 1
wait 0.124654
mousemove 528 510
wait 0.000013
mousemove 531 510
wait 0.016605
mousemove 533 510
wait 0.017675
mousemove 539 510
wait 0.018050
mousemove 557 510
wait 0.016497
mousemove 566 512
wait 0.017981
mousemove 575 513
wait 0.017102
mousemove 593 517
wait 0.017790
mousemove 606 519
wait 0.017898
mousemove 619 522
wait 0.017544
mousemove 628 525
wait 0.016231
mousemove 641 526
wait 0.032900
mousemove 651 530
wait 0.019078
mousemove 659 535
wait 0.000022
mousemove 666 537
wait 0.017798
mousemove 674 540
wait 0.016840
mousemove 680 542
wait 0.018019
mousemove 686 544
wait 0.017470
mousemove 698 552
wait 0.016519
mousemove 713 559
wait 0.017800
mousemove 724 564
wait 0.017645
mousemove 734 569
wait 0.016891
mousemove 749 579
wait 0.017896
mousemove 762 586
wait 0.017973
mousemove 771 589
wait 0.016540
mousemove 783 597
wait 0.017692
mousemove 793 604
wait 0.017704
mousemove 810 618
wait 0.016295
mousemove 820 625
wait 0.017757
mousemove 833 633
wait 0.016775
mousemove 843 642
wait 0.017395
mousemove 848 645
wait 0.016453
mousemove 852 649
wait 0.028561
mousemove 857 653
wait 0.022951
mousemove 861 658
wait 0.000542
mousemove 866 661
wait 0.016937
mousemove 871 664
wait 0.016815
mousemove 877 667
wait 0.017446
mousemove 881 669
wait 0.016791
mousemove 887 671
wait 0.016377
mousemove 891 674
wait 0.018259
mousemove 895 677
wait 0.026975
mousemove 902 680
wait 0.022011
mousemove 907 683
wait 0.005978
mousemove 909 684
wait 0.024961
mousemove 912 686
wait 0.021996
mousemove 916 688
wait 0.000029
mousemove 920 692
wait 0.016684
mousemove 923 693
wait 0.017554
mousemove 925 695
wait 0.017583
mousemove 926 695
wait 0.016458
mousemove 928 696
wait 0.016919
mousemove 929 696
wait 0.017573
mousemove 933 701
wait 0.026554
mousemove 936 705
wait 0.022260
mousemove 937 707
wait 0.006039
mousemove 937 709
wait 0.026934
mousemove 938 712
wait 0.022117
mousemove 939 715
wait 0.000029
mousemove 940 718
wait 0.027176
mousemove 940 720
wait 0.021860
mousemove 940 722
wait 0.006466
mousemove 940 724
wait 0.253250
mouseup 1
wait 1.387222
wait 8.382532
log * Highlight text of last paragraph on page 81
check evince/evince-check-004.png
wait 2.654722
mousemove 1283 20
wait 0.000036
mousedown 1
wait 0.078755
mouseup 1
wait 1.365923
mousemove 1295 397
wait 0.000015
mousedown 1
wait 0.065897
mouseup 1
wait 2.231291
mousemove 943 422
wait 0.081914
wait 3.872612
log * Rotate the page right
check evince/evince-check-005.png
wait 2.512162
mousemove 1155 23
wait 0.000015
mousedown 1
wait 0.095663
mouseup 1
wait 0.073183
mousedown 1
wait 0.070458
mouseup 1
wait 0.072206
mousedown 1
wait 0.088151
mouseup 1
wait 1.377012
keydown 2
wait 0.086960
keyup 2
wait 0.178868
keydown 0
wait 0.053958
keyup 0
wait 0.071681
keydown 0
wait 0.071503
keyup 0
wait 0.329114
keydown Return
wait 0.153755
keyup Return
wait 0.877055
log * Zoom in to 200 %
check evince/evince-check-006.png
wait 0.766628
mousedown 1
wait 0.082568
mouseup 1
wait 0.088879
mousedown 1
wait 0.062734
mouseup 1
wait 0.065401
mousedown 1
wait 0.086796
mouseup 1
wait 1.137175
keydown 5
wait 0.061955
keydown 0
wait 0.023891
keyup 5
wait 0.058568
keyup 0
wait 0.367013
keydown Return
wait 0.110428
keyup Return
wait 0.984613
wait 3.259281
log * Zoom out to 50 %
check evince/evince-check-007.png
wait 2.580173
mousemove 841 324
wait 0.000019
mousedown 4
wait 0.000006
mouseup 4
wait 0.468292
mousedown 4
wait 0.000019
mouseup 4
wait 0.255754
mousedown 4
wait 0.000016
mouseup 4
wait 0.698907
mousedown 4
wait 0.000021
mouseup 4
wait 0.617135
mousedown 4
wait 0.000019
mouseup 4
wait 0.205383
mousedown 4
wait 0.000023
mouseup 4
wait 0.338931
mousedown 4
wait 0.000024
mouseup 4
wait 0.267214
mousedown 4
wait 0.000019
mouseup 4
wait 0.554033
mousedown 4
wait 0.000019
mouseup 4
wait 0.170163
mousedown 4
wait 0.000020
mouseup 4
wait 0.167034
mousedown 4
wait 0.000020
mouseup 4
wait 0.247183
mousedown 4
wait 0.000019
mouseup 4
wait 0.226386
mousedown 4
wait 0.000019
mouseup 4
wait 0.609371
mousedown 4
wait 0.000023
mouseup 4
wait 0.275889
mousedown 4
wait 0.000025
mouseup 4
wait 0.488659
mousedown 4
wait 0.000020
mouseup 4
wait 1.615757
log * Go back 4 pages, page by page
check evince/evince-check-008.png
wait 2.745358
mousemove 1288 25
wait 0.000020
mousedown 1
wait 0.088818
mouseup 1
wait 1.894433
mousemove 1270 401
wait 0.000018
mousedown 1
wait 0.065725
mouseup 1
wait 0.893863
mousemove 1275 28
wait 0.000015
mousedown 1
wait 0.078829
mouseup 1
wait 1.001457
mousemove 1280 394
wait 0.000021
mousedown 1
wait 0.062997
mouseup 1
wait 1.002107
mousemove 1287 36
wait 0.000021
mousedown 1
wait 0.062904
mouseup 1
wait 0.963797
mousemove 1270 394
wait 0.000019
mousedown 1
wait 0.076040
mouseup 1
wait 2.012340
log * Rotate the page left
check evince/evince-check-009.png
wait 1.520897
mousemove 1166 22
wait 0.000019
mousedown 1
wait 0.097465
mouseup 1
wait 0.065262
mousedown 1
wait 0.087055
mouseup 1
wait 0.050401
mousedown 1
wait 0.117343
mouseup 1
wait 0.647196
mousemove 1166 21
wait 0.000018
keydown 1
wait 0.094710
keyup 1
wait 0.383636
keydown 5
wait 0.071618
keyup 5
wait 0.000229
keydown 0
wait 0.065549
keyup 0
wait 0.174777
keydown Return
wait 0.095134
keyup Return
wait 1.023923
wait 1.454136
log * Zoom to 150 %
check evince/evince-check-010.png
wait 2.728014
mousemove 75 32
wait 0.000031
mousedown 1
wait 0.089802
mouseup 1
wait 0.063080
mousedown 1
wait 0.086216
mouseup 1
wait 0.896192
keydown 9
wait 0.066025
keyup 9
wait 0.151125
keydown 5
wait 0.095950
keyup 5
wait 0.120784
keydown Return
wait 0.105182
keyup Return
wait 0.925829
wait 2.335563
log * Jump to page 95 by entering the page number
check evince/evince-check-011.png
wait 2.280374
mousemove 476 249
wait 0.000039
mousedown 1
wait 0.080077
mousemove 476 250
wait 0.017612
mousemove 477 251
wait 0.016973
mousemove 489 256
wait 0.016720
mousemove 498 260
wait 0.027831
mousemove 515 267
wait 0.022494
mousemove 528 271
wait 0.000426
mousemove 539 275
wait 0.017216
mousemove 552 278
wait 0.017583
mousemove 560 283
wait 0.027393
mousemove 574 289
wait 0.022557
mousemove 578 290
wait 0.006001
mousemove 582 293
wait 0.026655
mousemove 589 296
wait 0.020142
mousemove 592 296
wait 0.000020
mousemove 597 298
wait 0.018862
mousemove 601 299
wait 0.033367
mousemove 606 300
wait 0.000021
mousemove 610 302
wait 0.188608
mouseup 1
wait 0.416037
mousedown 1
wait 0.039203
mousemove 609 302
wait 0.016532
mousemove 607 302
wait 0.017860
mousemove 603 302
wait 0.017618
mousemove 598 301
wait 0.016748
mousemove 593 300
wait 0.017719
mousemove 589 299
wait 0.017762
mousemove 582 298
wait 0.016301
mousemove 578 297
wait 0.017949
mousemove 574 295
wait 0.017808
mousemove 570 294
wait 0.016486
mousemove 568 293
wait 0.017752
mousemove 564 292
wait 0.017545
mousemove 562 291
wait 0.017102
mousemove 558 288
wait 0.017092
mousemove 557 287
wait 0.017420
mousemove 554 285
wait 0.016967
mousemove 553 284
wait 0.017893
mousemove 552 284
wait 0.017373
mousemove 551 283
wait 0.017089
mousemove 550 282
wait 0.017352
mousemove 547 280
wait 0.017577
mousemove 544 278
wait 0.016529
mousemove 539 275
wait 0.016833
mousemove 534 271
wait 0.017880
mousemove 532 271
wait 0.118986
mousemove 530 270
wait 0.031404
mousemove 527 268
wait 0.000018
mousemove 521 265
wait 0.017507
mousemove 512 262
wait 0.017704
mousemove 506 259
wait 0.016837
mousemove 497 256
wait 0.016546
mousemove 492 253
wait 0.017894
mousemove 488 251
wait 0.016831
mousemove 483 248
wait 0.035074
mousemove 480 247
wait 0.196962
mouseup 1
wait 0.193460
mousedown 1
wait 0.081268
mouseup 1
wait 0.400773
mousedown 1
wait 0.079999
mousemove 481 247
wait 0.017118
mousemove 484 247
wait 0.017843
mousemove 489 248
wait 0.017862
mousemove 495 250
wait 0.028931
mousemove 502 254
wait 0.022161
mousemove 509 257
wait 0.000310
mousemove 516 258
wait 0.027452
mousemove 523 261
wait 0.021875
mousemove 530 265
wait 0.006327
mousemove 535 267
wait 0.026371
mousemove 543 272
wait 0.020086
mousemove 547 274
wait 0.000018
mousemove 551 277
wait 0.029218
mousemove 557 279
wait 0.022038
mousemove 562 281
wait 0.000077
mousemove 566 282
wait 0.029023
mousemove 569 284
wait 0.021870
mousemove 573 286
wait 0.000986
mousemove 580 291
wait 0.016190
mousemove 585 293
wait 0.017603
mousemove 588 295
wait 0.017544
mousemove 591 297
wait 0.015836
mousemove 593 298
wait 0.017513
mousemove 596 300
wait 0.042435
mousemove 600 303
wait 0.021536
mousemove 601 304
wait 0.402769
mousemove 600 304
wait 0.032791
mousemove 596 303
wait 0.016399
mousemove 594 302
wait 0.017596
mousemove 588 301
wait 0.017494
mousemove 585 301
wait 0.016875
mousemove 582 301
wait 0.017723
mousemove 577 298
wait 0.017289
mousemove 572 298
wait 0.016750
mousemove 568 297
wait 0.017876
mousemove 566 297
wait 0.311581
mouseup 1
wait 1.432117
wait 2.872324
log * Highlight the text of the title
check evince/evince-check-012.png
wait 5.881463
keydown Next
wait 0.112585
keyup Next
wait 0.263535
keydown Next
wait 0.069344
keyup Next
wait 0.284524
keydown Next
wait 0.083749
keyup Next
wait 0.232509
keydown Next
wait 0.097295
keyup Next
wait 0.209397
keydown Next
wait 0.077184
keyup Next
wait 0.232966
keydown Next
wait 0.094602
keyup Next
wait 0.243703
keydown Next
wait 0.078867
keyup Next
wait 0.270133
keydown Next
wait 0.097770
keyup Next
wait 0.262239
keydown Next
wait 0.063296
keyup Next
wait 0.248964
keydown Next
wait 0.087019
keyup Next
wait 0.249389
keydown Next
wait 0.079193
keyup Next
wait 0.281326
keydown Next
wait 0.094978
keyup Next
wait 0.203208
keydown Next
wait 0.118583
keyup Next
wait 0.246566
keydown Next
wait 0.094744
keyup Next
wait 0.305207
keydown Next
wait 0.103025
keyup Next
wait 0.302115
keydown Next
wait 0.083621
keyup Next
wait 0.283807
keydown Next
wait 0.109166
keyup Next
wait 0.262406
keydown Next
wait 0.126731
keyup Next
wait 0.344283
keydown Next
wait 0.105365
keyup Next
wait 0.324026
keydown Next
wait 0.106173
keyup Next
wait 2.587199
wait 3.508981
log * Go forward 14 pages, page by page
check evince/evince-check-013.png

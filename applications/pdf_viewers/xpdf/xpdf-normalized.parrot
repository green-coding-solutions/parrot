# Parrot recording v2

startcommand = xpdf
windowtitle = Xpdf
windowclass = xpdf

wait 1.000000
mousemove 534 187
wait 0.000023
mousedown 1
wait 0.057998
mouseup 1
wait 1.504730
mousemove 1410 13
wait 0.000018
mousedown 1
wait 0.078015
mouseup 1
wait 1.225433
mousemove 557 427
wait 0.000019
mousedown 1
wait 0.084311
mouseup 1
wait 2.114239
wait 3.164807
log * Load app
check xpdf/xpdf-check-001.png
wait 0.954243
mousedown 3
wait 0.079979
mouseup 3
wait 1.440427
mousemove 596 443
wait 0.000022
mousedown 1
wait 0.054222
mouseup 1
wait 1.447717
keydown BackSpace
wait 0.055294
keyup BackSpace
wait 0.649113
keydown t
wait 0.071217
keyup t
wait 0.168505
keydown m
wait 0.080079
keydown p
wait 0.030938
keyup m
wait 0.072535
keyup p
wait 0.705115
keydown slash
wait 0.079071
keyup slash
wait 1.691887
keydown p
wait 0.078362
keyup p
wait 0.197979
keydown d
wait 0.097756
keydown f
wait 0.069978
keyup d
wait 0.066282
keyup f
wait 0.208398
keydown period
wait 0.060561
keyup period
wait 0.169094
keydown p
wait 0.071406
keyup p
wait 0.082878
keydown d
wait 0.061676
keydown f
wait 0.039208
keyup d
wait 0.059203
keyup f
wait 0.269678
keydown Return
wait 0.104768
keyup Return
wait 1.295266
wait 7.693527
log * Open the document [20yearsofKDE.pdf](20yearsofKDE.pdf) from the local disk
check xpdf/xpdf-check-002.png
wait 2.365372
mousemove 295 855
wait 0.000018
mousedown 1
wait 0.102947
mouseup 1
wait 0.962551
keydown BackSpace
wait 0.064196
keyup BackSpace
wait 0.479067
keydown 8
wait 0.088936
keyup 8
wait 0.000432
keydown 1
wait 0.079441
keyup 1
wait 0.529851
keydown Return
wait 0.110480
keyup Return
wait 1.119667
wait 2.847068
log * Jump to page 81 by entering the page number
check xpdf/xpdf-check-003.png
wait 2.863685
mousemove 494 542
wait 0.000023
mousedown 1
wait 0.054590
mousemove 495 542
wait 0.017274
mousemove 497 545
wait 0.017035
mousemove 506 553
wait 0.016373
mousemove 516 564
wait 0.017758
mousemove 532 572
wait 0.017232
mousemove 567 591
wait 0.016909
mousemove 582 598
wait 0.017694
mousemove 601 602
wait 0.016744
mousemove 611 606
wait 0.016821
mousemove 618 608
wait 0.017403
mousemove 623 610
wait 0.016821
mousemove 628 611
wait 0.016717
mousemove 631 612
wait 0.017529
mousemove 635 613
wait 0.016731
mousemove 640 614
wait 0.016892
mousemove 645 616
wait 0.017188
mousemove 650 618
wait 0.016997
mousemove 661 620
wait 0.016190
mousemove 668 624
wait 0.017960
mousemove 678 626
wait 0.016400
mousemove 692 630
wait 0.017078
mousemove 705 634
wait 0.017468
mousemove 721 637
wait 0.017292
mousemove 732 639
wait 0.027233
mousemove 743 643
wait 0.022273
mousemove 753 645
wait 0.001195
mousemove 765 649
wait 0.016492
mousemove 776 652
wait 0.017969
mousemove 785 655
wait 0.017326
mousemove 797 658
wait 0.016983
mousemove 813 663
wait 0.017265
mousemove 824 669
wait 0.016531
mousemove 835 672
wait 0.017744
mousemove 843 676
wait 0.017596
mousemove 848 677
wait 0.027764
mousemove 852 680
wait 0.021452
mousemove 856 684
wait 0.006248
mousemove 859 685
wait 0.017060
mousemove 867 688
wait 0.013184
mousemove 872 692
wait 0.016970
mousemove 879 696
wait 0.016856
mousemove 886 700
wait 0.038991
mousemove 896 707
wait 0.022205
mousemove 897 707
wait 0.005971
mousemove 898 707
wait 0.069702
mousemove 899 707
wait 0.042565
mousemove 901 708
wait 0.000019
mousemove 904 708
wait 0.016636
mousemove 907 709
wait 0.039082
mousemove 908 709
wait 0.022131
mousemove 909 709
wait 0.016628
mousemove 911 710
wait 0.034101
mousemove 912 710
wait 0.287127
mouseup 1
wait 1.049937
mousemove 913 710
wait 0.080499
wait 8.519112
log * Highlight text of last paragraph on page 81
check xpdf/xpdf-check-004.png
wait 2.263738
mousemove 676 479
wait 0.000018
mousedown 3
wait 0.084429
mouseup 3
wait 2.122261
mousemove 819 692
wait 0.000014
mousedown 1
wait 0.053834
mouseup 1
wait 1.563416
wait 4.263455
log * Rotate the page right
check xpdf/xpdf-check-005.png
wait 1.655329
mousemove 462 866
wait 0.000015
mousedown 1
wait 0.100991
mouseup 1
wait 0.387386
mousedown 1
wait 0.061725
mouseup 1
wait 0.074132
mousedown 1
wait 0.086930
mouseup 1
wait 0.873840
keydown 2
wait 0.063188
keyup 2
wait 0.137045
keydown 0
wait 0.056058
keyup 0
wait 0.071373
keydown 0
wait 0.071596
keyup 0
wait 0.617270
keydown Return
wait 0.103439
keyup Return
wait 1.279384
wait 0.472043
log * Zoom in to 200 %
check xpdf/xpdf-check-006.png
wait 1.023111
mousedown 1
wait 0.078527
mouseup 1
wait 0.098180
mousedown 1
wait 0.062727
mouseup 1
wait 1.057578
keydown 5
wait 0.056307
keydown 0
wait 0.023784
keyup 5
wait 0.066310
keyup 0
wait 0.286649
keydown Return
wait 0.134245
keyup Return
wait 1.288707
wait 2.979805
log * Zoom out to 50 %
check xpdf/xpdf-check-007.png
wait 2.993590
mousemove 510 601
wait 0.000021
mousedown 4
wait 0.000004
mouseup 4
wait 0.882179
mousedown 4
wait 0.000017
mouseup 4
wait 0.731977
mousedown 4
wait 0.000015
mouseup 4
wait 0.922466
mousedown 4
wait 0.000016
mouseup 4
wait 2.333311
wait 1.922999
log * Go back 4 pages, page by page
check xpdf/xpdf-check-008.png
wait 1.263988
mousemove 558 486
wait 0.000022
mousedown 3
wait 0.090698
mouseup 3
wait 1.569101
mousemove 669 672
wait 0.000017
mousedown 1
wait 0.061985
mouseup 1
wait 1.936328
wait 6.026643
log * Rotate the page left
check xpdf/xpdf-check-009.png
wait 2.753955
mousemove 448 861
wait 0.000017
mousedown 1
wait 0.061937
mouseup 1
wait 0.106947
mousedown 1
wait 0.061727
mouseup 1
wait 0.669538
mousemove 448 860
wait 0.000019
keydown 1
wait 0.095224
keyup 1
wait 0.385285
keydown 5
wait 0.079211
keyup 5
wait 0.000372
keydown 0
wait 0.064012
keyup 0
wait 0.592200
keydown Return
wait 0.064925
keyup Return
wait 1.013999
log * Zoom to 150 %
check xpdf/xpdf-check-010.png
wait 2.264613
mousemove 302 862
wait 0.000025
mousedown 1
wait 0.083845
mouseup 1
wait 0.084813
mousedown 1
wait 0.081981
mouseup 1
wait 1.106490
keydown 9
wait 0.074566
keyup 9
wait 0.000390
keydown 5
wait 0.079702
keyup 5
wait 0.369417
keydown Return
wait 0.126009
keyup Return
wait 1.187488
wait 2.204454
log * Jump to page 95 by entering the page number
check xpdf/xpdf-check-011.png
wait 2.506079
mousemove 459 153
wait 0.000021
mousedown 1
wait 0.038470
mousemove 459 156
wait 0.016733
mousemove 459 159
wait 0.017851
mousemove 464 178
wait 0.016774
mousemove 474 200
wait 0.016773
mousemove 491 222
wait 0.017439
mousemove 514 240
wait 0.016497
mousemove 545 264
wait 0.017999
mousemove 599 296
wait 0.017709
mousemove 639 312
wait 0.016320
mousemove 658 321
wait 0.017072
mousemove 676 327
wait 0.017238
mousemove 685 331
wait 0.016741
mousemove 691 333
wait 0.033882
mousemove 698 335
wait 0.000435
mousemove 703 337
wait 0.016858
mousemove 710 339
wait 0.027821
mousemove 714 340
wait 0.022328
mousemove 720 342
wait 0.006542
mousemove 726 344
wait 0.026560
mousemove 737 346
wait 0.020683
mousemove 748 350
wait 0.000019
mousemove 757 352
wait 0.029834
mousemove 768 357
wait 0.022017
mousemove 780 359
wait 0.000020
mousemove 793 362
wait 0.028484
mousemove 801 365
wait 0.021743
mousemove 814 369
wait 0.000234
mousemove 820 371
wait 0.017677
mousemove 825 372
wait 0.034100
mousemove 838 379
wait 0.000364
mousemove 849 381
wait 0.016785
mousemove 859 382
wait 0.017192
mousemove 866 383
wait 0.033580
mousemove 871 383
wait 0.000022
mousemove 874 383
wait 0.016931
mousemove 875 383
wait 0.016785
mousemove 877 383
wait 0.030566
mousemove 879 383
wait 0.016688
mousemove 883 383
wait 0.028323
mousemove 894 383
wait 0.021674
mousemove 900 382
wait 0.000224
mousemove 906 381
wait 0.039702
mousemove 907 381
wait 0.012523
mousemove 909 381
wait 0.038315
mousemove 910 380
wait 0.021894
mousemove 912 380
wait 0.004453
mousemove 915 379
wait 0.016596
mousemove 917 378
wait 0.016824
mousemove 921 376
wait 0.017510
mousemove 926 376
wait 0.033432
mousemove 931 374
wait 0.000020
mousemove 934 374
wait 0.017855
mousemove 936 373
wait 0.017137
mousemove 938 373
wait 0.097114
mousemove 940 373
wait 0.043223
mousemove 942 373
wait 0.022155
mousemove 945 373
wait 0.167768
mouseup 1
wait 1.477039
wait 5.298821
log * Highlight the text of the title
check xpdf/xpdf-check-012.png
wait 4.007626
mousemove 742 400
wait 0.000026
keydown Next
wait 0.079106
keyup Next
wait 0.922786
keydown Next
wait 0.069493
keyup Next
wait 0.376826
keydown Next
wait 0.072423
keyup Next
wait 0.311423
keydown Next
wait 0.071739
keyup Next
wait 0.264475
keydown Next
wait 0.054325
keyup Next
wait 0.252402
keydown Next
wait 0.068852
keyup Next
wait 0.302626
keydown Next
wait 0.057683
keyup Next
wait 0.250789
keydown Next
wait 0.067613
keyup Next
wait 0.344610
keydown Next
wait 0.079628
keyup Next
wait 0.393339
keydown Next
wait 0.080695
keyup Next
wait 0.431014
keydown Next
wait 0.055381
keyup Next
wait 0.306734
keydown Next
wait 0.044393
keyup Next
wait 0.325687
keydown Next
wait 0.058697
keyup Next
wait 0.251136
keydown Next
wait 0.068839
keyup Next
wait 0.305650
keydown Next
wait 0.054675
keyup Next
wait 0.325706
keydown Next
wait 0.058569
keyup Next
wait 0.288936
keydown Next
wait 0.054463
keyup Next
wait 0.240361
keydown Next
wait 0.048470
keyup Next
wait 0.281737
keydown Next
wait 0.037951
keyup Next
wait 0.283028
keydown Next
wait 0.052681
keyup Next
wait 0.289324
keydown Next
wait 0.054467
keyup Next
wait 0.265160
keydown Next
wait 0.049802
keyup Next
wait 0.303763
keydown Next
wait 0.047241
keyup Next
wait 0.326959
keydown Next
wait 0.055035
keyup Next
wait 0.304886
keydown Next
wait 0.063407
keyup Next
wait 0.273116
keydown Next
wait 0.054514
keyup Next
wait 0.289526
keydown Next
wait 0.055197
keyup Next
wait 0.288559
keydown Next
wait 0.055254
keyup Next
wait 2.423638
wait 2.008795
log * Go forward 14 pages, page by page
check xpdf/xpdf-check-013.png

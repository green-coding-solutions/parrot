# Parrot recording v2

startcommand = qpdfview
windowtitle = Qpdfview
windowclass = qpdfview

wait 1.699936
mousemove 139 36
wait 0.000020
mousedown 1
wait 0.132002
mouseup 1
wait 1.217860
keydown 9
wait 0.111819
keydown 5
wait 0.006138
keyup 9
wait 0.111836
keyup 5
wait 0.513064
keydown Return
wait 0.134762
keyup Return
wait 1.536154
log * Jump to page 95 by entering the page number
check qpdfview/qpdfview-check-011.png

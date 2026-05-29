# Parrot recording v2

startcommand = xpdf
windowtitle = Xpdf
windowclass = xpdf

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
log * Zoom out to 50 %
check xpdf/xpdf-check-007.png

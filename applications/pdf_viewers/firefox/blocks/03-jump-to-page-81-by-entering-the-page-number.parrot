# Parrot recording v2

startcommand = firefox
windowtitle = Firefox
windowclass = firefox

wait 2.017448
mousemove 159 122
wait 0.000020
mousedown 1
wait 0.075839
mouseup 1
wait 0.104537
mousedown 1
wait 0.086490
mouseup 1
wait 0.964197
keydown 8
wait 0.079204
keyup 8
wait 0.026187
keydown 1
wait 0.094108
keyup 1
wait 0.302493
keydown Return
wait 0.105376
keyup Return
wait 1.752035
log * Jump to page 81 by entering the page number
check firefox/firefox-check-003.png

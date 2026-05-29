# Parrot recording v2

startcommand = firefox
windowtitle = Firefox
windowclass = firefox

wait 1.859738
mousemove 191 115
wait 0.000016
mousedown 1
wait 0.062390
mouseup 1
wait 0.083633
mousedown 1
wait 0.080202
mouseup 1
wait 1.194471
keydown 9
wait 0.098106
keyup 9
wait 0.424845
keydown 5
wait 0.076538
keyup 5
wait 0.392771
keydown Return
wait 0.057830
keyup Return
wait 1.325626
mousemove 197 107
wait 0.080069
log * Jump to page 95 by entering the page number
check firefox/firefox-check-011.png

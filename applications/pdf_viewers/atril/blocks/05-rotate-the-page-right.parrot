# Parrot recording v2

startcommand = atril
windowtitle = Atril
windowclass = atril

label start
wait 2.426185
mousemove 60 35
wait 0.000015
mousedown 1
wait 0.128817
mouseup 1
wait 2.569676
mousemove 135 212
wait 0.000038
mousedown 1
wait 0.096287
mouseup 1
wait 1.791259
mousemove 135 213
wait 0.131804
log * Rotate the page right
loop start 10
check atril/atril-check-005.png

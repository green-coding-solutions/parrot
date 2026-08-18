# Terminal emulator

* Load app: wait for the terminal window to finish drawing with a shell prompt on screen, dismissing any first-run dialog the app puts in front of it
* Print a file: run `corpus/plain.sh`, which cats a large file of plain ASCII, and wait for it to finish scrolling past
* Text attributes: run `corpus/attributes.sh` and wait for the bold, dim, italic, underlined, reversed and struck-through samples to finish drawing
* 256 colours: run `corpus/colours-256.sh` and wait for the sixteen-by-sixteen palette grid to finish drawing
* True colour: run `corpus/colours-true.sh` and wait for the 24-bit gradient to finish drawing
* Unicode: run `corpus/unicode.sh` and wait for the Latin, Greek, Cyrillic, Hebrew and double-width CJK samples to finish drawing
* Line art: run `corpus/boxes.sh` and wait for the box-drawing table to finish
* Cursor addressing: run `corpus/redraw.sh`, which repaints the same twenty lines in place, and wait for it to finish
* Long lines: run `corpus/longlines.sh`, whose lines are several times wider than the window, and wait for the wrapping to finish
* Fast scroll: run `corpus/seq.sh`, which counts to two million, and wait for it to finish
* Coloured listing: run `corpus/ls-tree.sh`, which lists 1,000 files in 40 directories with `ls --color=always -R`, and wait for it to finish
* Page a file: open `corpus/plain.txt` in `less`, wait for the first screen, then press Page Down ten times, letting each screen finish drawing
* Search in the pager: search the pager for `beacon`, jump to the next three matches with `n`, then press `q` to leave the pager
* Select text: drag the mouse across a block of text on screen to select it, and let the selection finish highlighting
* Clear the screen: run `clear` and wait for the empty screen and a fresh prompt
* Verify: run `corpus/verify.sh` and wait for it to print its result

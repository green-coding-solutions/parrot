# Word processor

* Load app: wait for the main window to finish drawing with an editable page on screen, dismissing any first-run, licence, update or sign-in dialog the app puts in front of it
* Open document: open [parrot-report.odt](parrot-report.odt) from the local disk and wait for the first page to finish rendering
* Page through: press Page Down ten times and let every page finish drawing before the next press
* Jump to end: press Ctrl+End and wait for the last page to render
* Jump to start: press Ctrl+Home
* Zoom: set the zoom to 150 %, wait for the page to redraw, then set it back to 100 %
* Find word: open the find bar or dialog, search for `Cormorant`, and step forward through the first three matches
* Replace all: replace every `Cormorant` in the document with `Shearwater` in one operation, and confirm the "N replacements made" result if the app reports one
* Type paragraph: press Ctrl+End, press Enter to start a new paragraph, then type `The kestrel circled above the reservoir before dawn.` and press Enter, type `Three technicians logged the reading and filed the sheet.` and press Enter, type `Nothing in the record explained the drop in pressure.` and do not press Enter after it
* Bold a line: select the line just typed with Shift+Home and make it bold
* Resize the text: with that selection still live, set the font size to 18
* Apply heading: with the cursor still in that line, apply the `Heading 1` paragraph style from the style list
* Insert image: press Ctrl+End, press Enter, and insert [parrot.png](parrot.png) from the local disk at the cursor
* Insert table: press Ctrl+End, press Enter, insert a table of 3 columns by 4 rows, and type `Alpha`, `Beta`, `Gamma` into the first row, moving between cells with Tab
* Insert page break: press Ctrl+End and insert a page break
* Undo and redo: undo the page break with Ctrl+Z, then redo it
* Save: save the document in place with Ctrl+S, keeping the ODT format if the app asks
* Export PDF: produce a PDF of the whole document at `/tmp/parrot-report.pdf` and wait for it to finish, by whichever route the app offers - a direct PDF export or printing to a PDF file are both what a user would do and both are in scope

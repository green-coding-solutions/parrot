# Code editor

* Load app: start the application and wait until its editing surface is ready for input
* Open file: open the prepared source file `src/price_calculator.py`
* Scroll to function: scroll to the function `calculate_total`
* Find identifier: find the identifier `tax_rate` in the active file
* Select line: select the line `tax = subtotal * tax_rate`
* Duplicate line: copy the selected line and paste the copy directly below it
* Undo duplicate: undo the pasted copy
* Replace all: replace all occurrences of `tax_rate` with `vat_rate` in the active file
* Undo replace: undo the replacement so the original identifier is restored
* Insert comment: insert the line `# benchmark complete` immediately before `return subtotal + tax`
* Save file: save the file
* Reopen file: close and reopen `src/price_calculator.py` and verify that the inserted line is present
* Open large file: open the 10 MB file `src/component_library.py` and wait until the editor has finished loading it
* Go to line: jump to line 120000 by entering the line number
* Page down: page down ten times, one whole screen at a time
* Go to start: jump back to the first line of the file
* Type block: type the ten lines of `constants_block.txt` at the top of the file, one keystroke at a time
* Global replace: replace every occurrence of `LEGACY_SKU` with `ARCHIVE_SKU` in every file under `src/legacy/` and write all three files to disk. Editors with a project-wide replace do it in one operation; the rest open each file, replace within it and save - both are the same user action and both are in scope

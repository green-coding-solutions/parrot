# Spreadsheet

* Load app: wait for the main window to finish drawing with an editable grid on screen, dismissing any first-run, licence, update or sign-in dialog the app puts in front of it
* Open workbook: open [parrot-ledger.ods](parrot-ledger.ods) from the local disk and wait for the Readings sheet to finish drawing, answering no if the app offers to recalculate the formulas on load
* Jump to end: press Ctrl+End to land on the last used cell of the Readings sheet and wait for the grid to redraw
* Freeze the header: press Ctrl+Home, move the cursor to A2, and freeze the top row so the column headings stay on screen while scrolling
* Page through: press Page Down ten times and let the grid finish drawing before each next press
* Switch sheets: click the Sites tab, then the Summary tab, then the Readings tab again, waiting for each sheet to finish drawing before the next click
* Sort: select A1:H20001 through the name box and sort it by column E ascending, telling the app the range has column headings if it asks
* Enter formula: select I2 through the name box, type `=ROUND(E2*F2,2)` and press Enter
* Fill down: select I2:I20001 through the name box, fill the formula down the whole selection, and wait for the values to finish appearing
* Total: select K1 through the name box, type `=SUM(I2:I20001)` and press Enter, then wait for the result to appear
* Recalculate: force a full recalculation of the whole workbook by whichever route the app offers, and wait for it to finish
* Filter: turn the autofilter on over A1:H20001 and filter column D down to `Turbine` alone, then wait for the grid to settle
* Clear filter: bring every row back and wait for the grid to redraw
* Format numbers: select E2:E20001 through the name box and apply a two-decimal number format to it
* Replace all: replace every `Cormorant` with `Shearwater` in one operation, and confirm the "N replacements made" result if the app reports one
* Insert chart: go to the Summary sheet, select A1:B7 through the name box, insert a bar chart accepting the app's defaults, and click once outside it to leave chart editing
* Save: save the workbook in place with Ctrl+S, keeping the ODS format if the app asks
* Export PDF: produce a PDF of the whole workbook at `/tmp/parrot-ledger.pdf` and wait for it to finish, by whichever route the app offers - a direct PDF export or printing to a PDF file are both what a user would do and both are in scope

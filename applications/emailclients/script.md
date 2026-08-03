# Email client

* Load app: wait for the main window to finish drawing, with the folder list and the empty message pane visible
* Sync account: let the inbox finish downloading until the message count stops rising, entering the password `parrot` and ticking "remember" only if the client asks
* Read newest: open message 1, `Re: Release checklist for Aurora 4.2` from Nadia Oyelaran, and wait for the body to render
* Scroll to bottom: scroll the message list down to the very last message without opening anything
* Read second: scroll back to the top and open message 2, `Staging cluster credentials rotated` from Dmitri Sokolov
* Open PDF attachment: open message 7, `Quarterly infrastructure review - final PDF`, and open `infrastructure-review-2026-Q2.pdf` from the attachment bar, then go back to the mailbox. Clients that bundle a viewer show it in a tab; the rest hand the file to the desktop, which has no PDF handler, so nothing opens - both are the same user action and both are in scope
* Search account: search the whole account for `Windvane` and wait for the result list to stop growing
* Open result: open the first search result and wait for the body to render
* Clear search: leave the search results and return to the inbox message list
* Move to Archive: select message 2 and move it into the archive folder
* Delete message: select message 4 as the list now stands and delete it, so it lands in the trash
* Flag message: select message 5 as the list now stands and flag or star it
* Mark five unread: select the top five messages and mark them as unread
* Open Archive 2024: open the 2024 folder under the archive and read the newest message in it
* Reply and send: go back to the inbox, reply to message 2 with the body text `Thank you so much` and send it, entering the password `parrot` again only if the outgoing server asks
* Compose and send: compose a new message to `alice.brenner@parrot.test` with the subject `Parrot benchmark` and the body text `Thank you so much`, then send it
* Empty trash: empty the trash folder and confirm if asked

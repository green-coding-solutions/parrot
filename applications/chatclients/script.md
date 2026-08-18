# Matrix chat client

* Load app: wait for the client to finish starting and settle on its first screen - a welcome or sign-in screen for every client in this group - dismissing any first-run, release-notes or notification-permission prompt it puts in front of that
* Sign in: sign in to the homeserver `http://matrix.parrot.test:8008` as `parrot` with the password `parrot`, by whichever route the client offers - some take the full user id `@parrot:parrot.test` and find the server themselves, some ask for the server first, and some only reveal a server field once discovery fails; typing the address in is what a user with a self-hosted server does and is in scope for all of them. End the block when the client leaves the sign-in screen
* Initial sync: let the account finish its first sync until the room list stops growing and the unread badges stop changing, dismissing any encryption-setup, key-backup or device-verification prompt the client raises on first sign-in
* Open busy room: open `Aurora Release` from the room list and wait for the timeline to finish rendering at the live end
* Scroll back: scroll the timeline up through ten screens of history, letting each batch of older messages finish loading before scrolling again
* Jump to live: return to the newest message in the room, by whichever route the client offers - the jump-to-bottom button, End, or scrolling back down
* Open member list: open the member list of `Aurora Release`, let every avatar on the first screen finish loading, then close it
* Open photo room: open `Field Photos` from the room list and wait for the thumbnails on the first screen to finish decoding
* View image full size: open the newest image in the room, `reservoir-at-first-light.jpg`, in the client's image viewer, wait for it to render at full size, then close the viewer and return to the timeline
* Scroll thumbnails: scroll that timeline up through five screens of images, letting the thumbnails on each screen finish decoding before scrolling again
* Filter room list: type `windvane` into the room-list filter and wait for the list to settle. Clients that fold this into one box that also searches messages show more than one section of results; both are the same user action and both are in scope
* Open filtered room: open `Windvane Deployment` from the filtered list, wait for the timeline to render, then clear the filter
* Send message: click into the composer and send the message `Thank you so much`
* Reply to message: reply to `Ship it when the smoke tests are green.` from Nadia Oyelaran, the newest message in the room, with the body text `Agreed, going out today`
* React to message: add the `👍` reaction to that same message from Nadia Oyelaran, through the client's emoji picker
* Edit message: edit the `Thank you so much` message sent earlier to read `Thank you so much indeed`, and confirm the edit
* Upload image: attach [parrot.png](parrot.png) from the local disk to the composer and send it, waiting for the upload to finish and the thumbnail to render in the timeline
* Echo round trip: open `Parrot Echo` from the room list, send the message `ping`, and wait for the bot's `pong` to arrive and render in the timeline
* Join room: join the public room `#parrot-lobby:parrot.test` by its address and wait for its timeline to render
* Create room: create a new public room named `Parrot benchmark` and invite `@alice:parrot.test` to it
* Leave room: leave `#parrot-lobby:parrot.test` and confirm if asked
* Idle quiet: open `Parrot Firehose` from the room list and let it settle, then leave the pointer and keyboard alone and let the client sit untouched for 60 seconds with nothing arriving
* Idle receiving: send the message `drip`, which is what starts the bot posting, then leave the pointer and keyboard alone for the two minutes it takes to post `drip 01` through `drip 24`, one every five seconds - let each one arrive and render on its own, scroll nothing, click nothing, and end the block once `drip 24` is on screen

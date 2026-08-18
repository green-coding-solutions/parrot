# nheko sign-in, blocks 2 and 3 of script.md. Sourced by the measuring scripts.
nheko_login() {
  X mousemove 801 582; X click 1; sleep 3            # welcome LOGIN
  X mousemove 720 424; X click 1; sleep 1
  T '@parrot:parrot.test'; sleep 6                   # autodiscovery fails, form re-lays out
  X mousemove 720 546; X click 1; sleep 1
  K ctrl+a; T 'http://matrix.parrot.test:8008'; sleep 2
  X mousemove 720 445; X click 1; sleep 1
  T 'parrot'; sleep 1
  X mousemove 720 656; X click 1                     # LOGIN
  sleep 30
  X mousemove 1373 861; X click 1; sleep 3           # Setup Encryption -> Cancel
  X mousemove 208 65;   X click 1; sleep 2           # dismiss the yellow banner
}

# Terminology — not in the group

**Status: blocked. Installs and is configured, but cannot be started in this
container.** The files here are complete and correct as far as they go; three
separate blockers were cleared and a fourth stopped it.

Terminology was wanted for one reason: its renderer is Enlightenment's EFL/Evas,
a stack nothing else in the group uses. xterm, urxvt, st and mlterm are Xlib,
GNOME Terminal is GTK/VTE, Konsole is Qt, Alacritty and kitty are OpenGL. EFL
would have been a fifth architecture.

## What was fixed, in order

| | symptom | fix |
| --- | --- | --- |
| 1 | `eldbus ... Failed to connect to socket /run/dbus/system_bus_socket` | wrapped the launch in `dbus-run-session` |
| 2 | same error — the failing bus is type 2, the **system** bus, which `dbus-run-session` does not provide | started `dbus-daemon --system --fork` in the launcher |
| 3 | `Failed to start message bus: Failed to open "/usr/share/dbus-1/system.conf"` — that file ships in `dbus`, not in `dbus-x11` | installed `dbus`, added `dbus-uuidgen --ensure` |

## What stopped it

```
ERR<...>:ecore_con efl_net_server_fd.c:385 _efl_net_server_fd_reuse_port_set()
    setsockopt(23, SOL_SOCKET, SO_REUSEPORT, 1): Operation not supported
```

EFL's `ecore_con` sets `SO_REUSEPORT` on a socket it opens at start-up, and the
container's network namespace refuses it. Terminology aborts with an
`eina_btlog` backtrace before mapping a window, so there is nothing to pin,
drive or capture.

This is an environment restriction rather than a bug in Terminology, and working
around it would mean changing how the container itself is run — extra
`--sysctl` or a different network mode — for one entrant. That would make
Terminology's container different from the other entrants', which defeats the
point of the group: the whole comparison rests on every emulator being measured
under identical conditions.

## If it is ever revisited

The install and configuration here are believed correct and are worth keeping:

- pin string **`main`**, not `terminology` — its `WM_CLASS` is
  `"main", "terminology"`, and fluxbox matches the res_name. Measured against a
  live window during the isolated probe, before the dbus problems appeared.
- Its idle screen **was** steady in that probe, which is the test that matters
  most and the one that ruled out cool-retro-term entirely.
- `--no-wizard --disable-visual-bell --disable-media-visualize` are set, because
  Terminology's defaults include animated effects and background media that
  cannot be replay-verified.

The first thing to try is running the container with a network mode that permits
`SO_REUSEPORT`, and then to re-check the steady-screen test before anything else.

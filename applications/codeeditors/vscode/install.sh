#!/usr/bin/env bash
# Install Visual Studio Code 1.132.0 from Microsoft's pinned download endpoint.
#
# Not from packages.microsoft.com: that repository only ever carries the current
# release, so an apt pin written today stops resolving at the next release and
# the benchmark silently starts measuring a different editor.  The
# update.code.visualstudio.com/<version>/... URL is permanent and serves that
# exact build forever, which is the property a recording needs.
#
# ONE SETTING IS WRITTEN, AND IT IS THE ONLY ONE IN THE WHOLE GROUP.  See
# "editor.largeFileOptimizations" below.  Everything else is left alone: the
# welcome tab, the workspace-trust prompt and the sign-in dialog all appear, and
# the macro clicks them away the way a person would.  Whether an editor greets
# you with three dialogs or none is part of what "load the app" costs, and
# configuring that away would measure a machine nobody has.
set -euo pipefail

CODE_VERSION='1.132.0'
CODE_SHA256='b73e01a1a371eb7d57f2c01712c43e9cedd15d6bad9a44261c4473db946532ef'
CODE_URL="https://update.code.visualstudio.com/${CODE_VERSION}/linux-deb-x64/stable"

USER_DATA=/root/.vscode-data

log() { printf '[install-vscode] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "downloading VS Code ${CODE_VERSION}"
wget -q -O /tmp/code.deb "$CODE_URL"

log "verifying checksum"
echo "${CODE_SHA256}  /tmp/code.deb" | sha256sum -c -

# apt-get install of a local .deb resolves the package's own dependency list,
# which is what Electron needs and is long enough that spelling it out here
# would rot.  The two font packages are not in that list and are added on
# purpose: without a usable font every glyph renders as a box and the screenshot
# assertions stop meaning anything.  Pinning *which* fonts exist is also what
# makes VS Code's default `editor.fontFamily` - a fontconfig pattern, not a
# file - resolve to the same face on every machine.
log "installing"
apt-get install -y -qq --no-install-recommends \
    /tmp/code.deb fonts-dejavu-core fonts-liberation >/dev/null
rm -f /tmp/code.deb
fc-cache -f >/dev/null 2>&1 || true

# A profile from scratch on every setup pass, so run N starts where run 1 did.
# Setup-commands run before every replay, and the scenario leaves VS Code with a
# dirty 10 MB buffer that hot exit would otherwise restore into the next run's
# editor.
rm -rf "${USER_DATA}"

# THE ONE SETTING THIS GROUP CONFIGURES.
#
# VS Code turns syntax highlighting OFF for a file it considers large, and
# "large" is not only about bytes: isTooLargeForTokenization() trips at 20 MB
# *or* at 300,000 lines, whichever comes first.  The generated module is 10 MB
# but 337,537 lines, so it crosses the line-count limit and everything from
# block 13 on renders as undifferentiated grey text - while IntelliJ, PyCharm,
# Android Studio, Eclipse, Sublime, Emacs, Vim and Neovim all still colour the
# same file.
#
# That is a genuine VS Code default and there is a real argument for leaving it:
# not tokenising 337,000 lines is exactly how VS Code stays responsive on a file
# this size, and switching it off means blocks 13 to 18 now include work the
# default avoids.  It was turned off deliberately anyway, so that the one editor
# in the group is not the only one showing a grey wall, and so that the
# screenshots of blocks 14 to 17 can be read against everyone else's.
#
# The cost is recorded rather than hidden: this is why VS Code's large-file
# numbers are not directly comparable with the first recording's, and the README
# says so.
mkdir -p "${USER_DATA}/User"
cat > "${USER_DATA}/User/settings.json" <<'SETTINGS'
{
    "editor.largeFileOptimizations": false
}
SETTINGS

# The two flags are requirements, not preferences: Electron's sandbox needs user
# namespaces, so as root in a container VS Code refuses to start at all without
# --no-sandbox, and it then insists on an explicit --user-data-dir.  Everything
# else is left alone.
cat > /usr/local/bin/vscode <<WRAPPER
#!/bin/sh
exec /usr/share/code/code \\
    --no-sandbox \\
    --user-data-dir=${USER_DATA} \\
    "\$@"
WRAPPER
chmod +x /usr/local/bin/vscode

log "installed: $(/usr/share/code/code --version --no-sandbox --user-data-dir=${USER_DATA} 2>/dev/null | head -n1)"

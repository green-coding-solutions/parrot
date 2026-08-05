#!/usr/bin/env bash
# Pre-configure the benchmark IMAP account in Claws Mail.
#
# Claws is the friendliest of the eight to script: the account lives in
# ~/.claws-mail/accountrc as plain text, and passwords go into passwordrc /
# passwordstorerc rather than a system keyring.  With no primary passphrase set,
# Claws encrypts stored passwords with a key derived from a built-in constant -
# so the only way to plant one is to let Claws write it itself.
#
# This script therefore writes the password as ciphertext, together with the salt
# it was encrypted under - see "the password" further down.
#
# WHY NOT TYPE IT IN THE MACRO.  It was tried, and it works until it does not.
# Claws' password prompt sets no WM_TRANSIENT_FOR, so the window manager has
# nothing tying it to the main window: across runs it appeared both cascaded at
# 1,45 and centred at 532,388, and in the centred case fluxbox stacked it
# UNDERNEATH the full-screen mailbox.  A modal prompt that cannot be seen or
# clicked stops the folder tree responding at all, and the run reads as a hung
# client rather than as a window-manager problem.  Nothing in the macro can
# recover from it, because raising a window is not an input event and so is never
# recorded.
#
# Seeding only the credential keeps the rest of the first run intact: the account
# still has no folder list, so the macro still performs "Check for new folders"
# and the full 2,100-message download.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

log() { printf '[seed-clawsmail] %s\n' "$*"; }

CFG="${HOME}/.claws-mail"
mkdir -p "$CFG"

# The salt Claws will use to derive its password-store key, and the password
# encrypted under it.  They are a matched pair - see "the password" below.
CLAWS_SALT='Dey4DGymPSnQsWDiNgdgtCIhuF05VzvKULlL2lXpgoXsT5zFWzXCgTPolrh1k0TT2pzcxcEFzg/P8WE/sHpn8A=='
CLAWS_RECV='{AES-256-CBC,50000}me5+rpR+/XEN2ecHtj4SKPef5Pg+nzitCr4A9rcShOz4GbAcAqroZHAGaz/dtuvLgIupCMFh2ucUEaJ9Dw9w/rMGeq8nKaYkeiHM0v31b3Sngj2iaZHBWkXS0pcc4paZn+BvzPZtKMfiHjTUFDDBr99URTiAhvTS5Ho7afxx2Z4dxrBoICDOKGhRWSp3nf0q'

# ssl_imap / ssl_smtp: 0 = none, 1 = implicit TLS, 2 = STARTTLS
case "${PARROT_MAIL_SECURITY:-none}" in
    none)     IMAP_PORT="$PARROT_IMAP_PORT";  SSL_IMAP=0
              SMTP_PORT="$PARROT_SUBMISSION_PORT"; SSL_SMTP=0 ;;
    starttls) IMAP_PORT="$PARROT_IMAP_PORT";  SSL_IMAP=2
              SMTP_PORT="$PARROT_SUBMISSION_PORT"; SSL_SMTP=2 ;;
    tls)      IMAP_PORT="$PARROT_IMAPS_PORT"; SSL_IMAP=1
              SMTP_PORT="$PARROT_SMTPS_PORT"; SSL_SMTP=1 ;;
    *) log "ERROR: PARROT_MAIL_SECURITY must be none, starttls or tls"; exit 1 ;;
esac

cat > "${CFG}/accountrc" <<ACC
[Account: 1]
account_name=Parrot benchmark
is_default=1
name=${PARROT_MAIL_REALNAME}
address=${PARROT_MAIL_ADDRESS}
organization=
protocol=3
receive_server=${PARROT_MAIL_HOST}
smtp_server=${PARROT_MAIL_HOST}
user_id=${PARROT_MAIL_USER}
imap_auth_method=0
remove_mail=1
message_leave_time=7
message_leave_hour=0
get_all_mail=0
enable_size_limit=0
size_limit=1024
filter_on_receive=1
filterhook_on_receive=1
imap_check_interval=10
imap_subsdir=
imap_directory=
imap_clear_cache_on_exit=0
imap_use_trash=1
max_news_articles=300
use_mail_command=0
mail_command=/usr/sbin/sendmail -t -i
use_smtp_auth=1
smtp_auth_method=0
# Deliberately EMPTY.  Claws' own wording on the Send page: "If you leave these
# entries empty, the same user ID and password as receiving will be used."  With
# a user ID here and no password, Claws instead prompts for an SMTP password on
# every send - twice during the scenario.  Leaving it empty means the single
# stored credential covers both directions.
smtp_user_id=
pop_before_smtp=0
pop_before_smtp_timeout=5
ssl_pop=0
ssl_imap=${SSL_IMAP}
ssl_nntp=0
ssl_smtp=${SSL_SMTP}
use_nonblocking_ssl=1
ssl_certs_auto_accept=1
in_ssl_client_cert_file=
out_ssl_client_cert_file=
set_smtpport=1
smtpport=${SMTP_PORT}
set_popport=0
popport=110
set_imapport=1
imapport=${IMAP_PORT}
set_nntpport=0
nntpport=119
set_domain=0
domain=${PARROT_MAIL_DOMAIN}
mark_crosspost_read=0
crosspost_color=0
set_sent_folder=0
sent_folder=
set_queue_folder=0
queue_folder=
set_draft_folder=0
draft_folder=
set_trash_folder=0
trash_folder=
sig_type=0
signature_path=
auto_signature=0
signature_separator=--
set_autocc=0
auto_cc=
set_autobcc=0
auto_bcc=
set_autoreplyto=0
auto_replyto=
default_privacy_system=
default_encrypt=0
default_encrypt_reply=1
default_sign=0
default_sign_reply=1
save_clear_text=0
encrypt_to_self=0
imap_maxconnections=4
ACC

# ssl_certs_auto_accept=1 above is what lets a TLS run proceed without a modal
# "unknown certificate" dialog.  The CA is trusted system-wide anyway, so this
# is belt and braces.

# Claws runs its setup wizard whenever ~/.claws-mail/clawsrc is missing - it
# does not check whether an account exists.  A minimal [Common] section is
# enough to skip it; Claws fills in every default it needs on first save.
cat > "${CFG}/clawsrc" <<COMMON
[Common]
check_on_startup=0
autochk_newmail=0
autochk_interval=600
show_startup_dialog=0
confirm_on_exit=0
clean_trash_on_exit=0
ask_mark_all_read=0
warn_dnd=0
warn_sending_many_recipients_num=0
enable_dotted_lines=0
summary_from_show=0
mainwin_width=1400
mainwin_height=850
mainwin_x=20
mainwin_y=20
mainwin_maximised=0
layout_mode=0
summary_col_show_mark=1
summary_col_show_unread=1
summary_col_show_subject=1
summary_col_show_from=1
summary_col_show_date=1
summary_col_show_size=1
summary_sort_key=6
summary_sort_type=1
summaryview_height=550
use_master_passphrase=0
master_passphrase=
master_passphrase_salt=${CLAWS_SALT}
master_passphrase_pbkdf2_rounds=50000
COMMON

# ---- the password ---------------------------------------------------------
# Claws encrypts stored passwords with a key derived from a built-in constant
# AND the per-configuration salt above - which it generates the first time it
# writes clawsrc.  That is why a passwordstorerc copied from another run does not
# work on its own: this script rewrites clawsrc every time, the salt changes, and
# the ciphertext can no longer be decrypted.  The symptom is simply that the
# password prompt appears anyway, which reads as "the seeding did not take".
#
# Writing the salt and the matching ciphertext together makes the pair
# self-consistent, and keeps the credential in a readable file rather than a
# committed tarball.  Both were produced by typing the password once into
# Configuration > Preferences for current account > Basic and reading the two
# files back.  Regenerate them together or not at all.
#
# There is nothing to protect here: the password is "parrot", it is already in
# account.env in plaintext, and it reaches a synthetic mailbox on an isolated
# Docker network.
cat > "${CFG}/passwordstorerc" <<PWSTORE
[config_version:4]

[account:1]
recv ${CLAWS_RECV}
PWSTORE

# summaryview_height is layout, not preference, and was measured at the
# benchmark's pinned 1440x900.  Claws ships 261, which leaves the message list
# about nine rows tall; the scenario addresses rows 1 to 7 and scrolls to the
# bottom, so the list needs to be the larger pane.  550 puts the divider at
# y=560.  It is read once at startup, so it has to be in place before Claws runs
# - which is why it is written here rather than adjusted in the macro.
#
# mimeview_tree_height is deliberately left at its default.  Raising it to show
# the whole MIME tree is not needed: the attachment is reached from the strip of
# part icons down the right-hand edge of the message view, which is always
# visible.  It is also not free - the message view is split between the tree and
# the body, so a taller tree moves the summary/message divider as well, and every
# coordinate below it.

# Claws needs a *default* mailbox as well as an account before it will skip the
# wizard - an IMAP account alone is not enough, because the local MH mailbox is
# what holds the outbox, queue and drafts.  The wizard's whole job on first run
# is to create it, so create it here instead: the MH directories plus a
# folderlist.xml naming both the local mailbox and the IMAP account.
MH="${HOME}/Mail"
for d in inbox outbox draft queue trash; do
    mkdir -p "${MH}/${d}"
done

cat > "${CFG}/folderlist.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<folderlist>
  <folder type="mh" name="Mail" path="Mail" collapsed="0" sort="0">
    <folderitem type="inbox" name="inbox" path="inbox" mtime="0" new="0" unread="0" total="0" />
    <folderitem type="outbox" name="outbox" path="outbox" mtime="0" new="0" unread="0" total="0" />
    <folderitem type="draft" name="draft" path="draft" mtime="0" new="0" unread="0" total="0" />
    <folderitem type="queue" name="queue" path="queue" mtime="0" new="0" unread="0" total="0" />
    <folderitem type="trash" name="trash" path="trash" mtime="0" new="0" unread="0" total="0" />
  </folder>
  <folder type="imap" name="${PARROT_MAIL_HOST}" account_id="1" collapsed="0" sort="0" />
</folderlist>
XML

log "wrote ${CFG}/accountrc, ${CFG}/clawsrc, ${CFG}/folderlist.xml and ${MH}"
log "IMAP ${PARROT_MAIL_HOST}:${IMAP_PORT} (ssl_imap=${SSL_IMAP}), submission :${SMTP_PORT}"
log "the password is seeded into passwordstorerc - see the header"

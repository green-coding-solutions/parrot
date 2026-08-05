# Parrot email-client benchmark - prebuilt mail server.
#
# Bakes Dovecot, Postfix and the whole ~500 MB deterministic corpus into an
# image, so a benchmark run only has to start two daemons instead of installing
# packages and generating 13,481 messages. That turns several minutes of setup
# per run into about a second.
#
# It also removes a real reproducibility hole. The corpus is deterministic for a
# given machine, but the PNG attachments are produced with zlib, and zlib's
# compressed output is not guaranteed identical across versions or builds. A
# different zlib would shift attachment sizes, and with them the message sizes
# recorded in every Maildir filename. Baking the bytes once means every machine
# that pulls this image syncs exactly the same mailbox.
#
# Build from the applications/emailclients directory, so that account.env - the
# single source of truth the scripts read - is inside the build context:
#
#   make mailserver          # build and load locally
#   make push-mailserver     # build and push to the registry
#
# Bump MAIL_TAG in the Makefile whenever the corpus changes; the tag is what the
# usage_scenario files pin.

FROM ubuntu@sha256:9cbed754112939e914291337b5e554b07ad7c392491dba6daf25eef1332a22e8

ENV DEBIAN_FRONTEND=noninteractive

# Lower this to build a smaller image for quick iteration. The floor is about
# 75 MB - the message text alone is 50 MB and two anchor attachments are fixed.
ARG PARROT_MAIL_TARGET_MB=500
ENV PARROT_MAIL_TARGET_MB=${PARROT_MAIL_TARGET_MB}

# Set to 0 to leave Dovecot's indexes cold. See the RUN below.
ARG PARROT_WARM_INDEXES=1

# account.env sits one level up from the scripts, which read it as
# ../account.env - so the layout inside the image has to mirror the repository.
COPY account.env /opt/parrot/account.env
COPY mailserver /opt/parrot/mailserver

RUN chmod +x /opt/parrot/mailserver/*.sh /opt/parrot/mailserver/*.py

# Packages, the account, the corpus and the configuration. The corpus is
# generated before the configuration is written so that editing a config file
# does not invalidate the large, slow corpus layer.
RUN bash /opt/parrot/mailserver/build.sh

# Certificates are baked so the index warm-up below can start Dovecot, and so
# start.sh has nothing slow left to do. They are a throwaway test CA valid for
# ten years; start.sh regenerates them if PARROT_FORCE_CERTS=1.
RUN bash /opt/parrot/mailserver/make-certs.sh

# Pre-build Dovecot's indexes and header cache.
#
# Without this, whichever client connects first pays for indexing 13,481
# messages, and that cost lands in its energy figure rather than in the server's.
# A real mail server people have been using for years has warm indexes, so this
# is both the fairer and the more realistic starting state.
RUN if [ "$PARROT_WARM_INDEXES" = "1" ]; then \
        set -eux; \
        mkdir -p /var/spool/postfix/private; \
        dovecot; \
        for i in $(seq 30); do [ -S /run/dovecot/auth-userdb ] && break; sleep 1; done; \
        doveadm index -u parrot '*'; \
        doveadm stop || true; \
        sleep 2; \
    else \
        echo "skipping index warm-up"; \
    fi

# Convenience entry points on PATH, so a usage_scenario setup-command does not
# need to know where the repository was mounted.
RUN ln -sf /opt/parrot/mailserver/start.sh /usr/local/bin/parrot-mailserver-start \
 && ln -sf /opt/parrot/mailserver/smoke_test.py /usr/local/bin/parrot-mailserver-smoke

EXPOSE 25 143 465 587 993

# The Green Metrics Tool keeps containers alive and drives them with exec, the
# same way ribalba/xwindow-server works, so the image must not exit.
CMD ["sleep", "inf"]

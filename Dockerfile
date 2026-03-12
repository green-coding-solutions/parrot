FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    dbus-x11 \
    fluxbox \
    gnupg \
    imagemagick \
    novnc \
    wget \
    websockify \
    x11vnc \
    x11-xserver-utils \
    xmacro \
    xdotool \
    xvfb

COPY tools/* /usr/local/bin/
COPY replay.py helpers.py timed_xmacro.py /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/position-window.sh /usr/local/bin/check-image.sh /usr/local/bin/replay.py /usr/local/bin/timed_xmacro.py

EXPOSE 5900 6080

CMD ["sleep", "inf"]

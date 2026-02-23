## syntax=docker/dockerfile:1.7
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    dbus-x11 \
    fluxbox \
    gnome-calculator \
    gnupg \
    imagemagick \
    novnc \
    wget \
    websockify \
    x11vnc \
    xmacro \
    xdotool \
    xvfb \
    vlc

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    install -d -m 0755 /etc/apt/keyrings \
    && wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
      > /etc/apt/sources.list.d/mozilla.list \
    && printf "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n" \
      > /etc/apt/preferences.d/mozilla \
    && apt-get update \
    && apt-get install -y --no-install-recommends firefox

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY position-window.sh /usr/local/bin/position-window.sh
COPY check-image.sh /usr/local/bin/check-image.sh

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/position-window.sh /usr/local/bin/check-image.sh

RUN useradd -m -s /bin/bash vlcuser && usermod -aG audio,video vlcuser 2>/dev/null || true

EXPOSE 5900 6080

CMD ["/usr/local/bin/entrypoint.sh"]

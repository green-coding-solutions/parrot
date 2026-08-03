FROM ubuntu@sha256:9cbed754112939e914291337b5e554b07ad7c392491dba6daf25eef1332a22e8

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    bash=5.2.21-2ubuntu4 \
    ca-certificates=20260601~24.04.1 \
    dbus-x11=1.14.10-4ubuntu4.1 \
    fluxbox=1.3.7-1build2 \
    gnupg=2.4.4-2ubuntu17.4 \
    imagemagick=8:6.9.12.98+dfsg1-5.2build2 \
    novnc=1:1.3.0-2 \
    python3-xlib=0.33-2 \
    wget=1.21.4-1ubuntu4.4 \
    websockify=0.10.0+dfsg1-5build2 \
    x11vnc=0.9.16-10 \
    x11-xserver-utils=7.7+10build2 \
    ffmpeg=7:6.1.1-3ubuntu5 \
    xmacro=0.3pre-20000911-8 \
    xdotool=1:3.20160805.1-5build1 \
    xvfb=2:21.1.12-1ubuntu1.6

COPY tools/* /usr/local/bin/
COPY replay.py helpers.py timed_xmacro.py /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/position-window.sh /usr/local/bin/check-image.sh /usr/local/bin/replay.py /usr/local/bin/timed_xmacro.py

EXPOSE 5900 6080

CMD ["sleep", "inf"]

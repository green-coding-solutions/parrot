# Parrot plus a real Firefox and a real Chrome, for the website benchmark group.
#
# This EXTENDS the Parrot window container rather than replacing it. Xvfb,
# fluxbox, xdotool, x11vnc, replay.py, helpers.py and the tools/ scripts all
# come from ribalba/xwindow-server; this image only adds the two browsers and
# the libraries they need.
#
# Build and push it with:
#
#   make browsers          # build locally, load into docker
#   make check-browsers    # smoke test the two browsers in the built image
#   make push-browsers     # push the tag the usage_scenario files pin
#
# The base is taken by TAG, not by digest, on purpose: replay.py lives in the
# base image and is fixed there, and this image should inherit those fixes.
# The cost is that the two images can drift - a `make build && make push` of the
# base does not reach a website run until this image is rebuilt as well. Rebuild
# both, in that order, whenever replay.py or tools/ changes.
FROM ribalba/xwindow-server

ENV DEBIAN_FRONTEND=noninteractive

# Versions are pinned the same way the base Dockerfile pins them. What is being
# pinned here is only the SYSTEM side of the browsers; the browsers themselves
# are pinned by checksum in install-firefox.sh and install-chrome.sh, and that is
# the pin that decides what a measurement measured.
#
# The font packages are not optional decoration. A page whose script or CJK text
# falls back to tofu lays out and paints a different amount of work than the same
# page on a normal desktop, so leaving them out would make the benchmark cheaper
# than reality in a way that varies per site.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl=8.5.0-2ubuntu10.13 \
    unzip=6.0-28ubuntu4.1 \
    xz-utils=5.6.1+really5.4.5-1ubuntu0.3 \
    libnss3-tools=2:3.98-1ubuntu0.2 \
    libnss3=2:3.98-1ubuntu0.2 \
    libnspr4=2:4.35-1.1build1 \
    libgtk-3-0t64=3.24.41-4ubuntu1.3 \
    libdbus-glib-1-2=0.112-3build2 \
    libasound2t64=1.2.11-1ubuntu0.3 \
    libxt6t64=1:1.2.1-1.2build1 \
    libx11-xcb1=2:1.8.7-1build1 \
    libxcb-shm0=1.15-1ubuntu2 \
    libxcomposite1=1:0.4.5-1build3 \
    libxdamage1=1:1.1.6-1build1 \
    libxfixes3=1:6.0.0-2build1 \
    libxrandr2=2:1.5.2-2build1 \
    libxkbcommon0=1.6.0-1build1 \
    libxss1=1:1.2.3-1build3 \
    libatk1.0-0t64=2.52.0-1build1 \
    libatk-bridge2.0-0t64=2.52.0-1build1 \
    libatspi2.0-0t64=2.52.0-1build1 \
    libcups2t64=2.4.7-1.2ubuntu7.14 \
    libdrm2=2.4.125-1ubuntu0.1~24.04.2 \
    libgbm1=25.2.8-0ubuntu0.24.04.2 \
    libpango-1.0-0=1.52.1+ds-1build1 \
    libcairo2=1.18.0-3build1 \
    libfreetype6=2.13.2+dfsg-1ubuntu0.1 \
    libfontconfig1=2.15.0-1.1ubuntu2 \
    fontconfig=2.15.0-1.1ubuntu2 \
    fonts-dejavu-core=2.37-8 \
    fonts-liberation=1:2.1.5-3 \
    fonts-noto-core=20201225-2 \
    fonts-noto-cjk=1:20230817+repack1-3 \
    fonts-noto-color-emoji=2.047-0ubuntu0.24.04.1 \
 && fc-cache -f >/dev/null

COPY install-firefox.sh install-chrome.sh /tmp/
RUN bash /tmp/install-firefox.sh && bash /tmp/install-chrome.sh && rm -f /tmp/install-firefox.sh /tmp/install-chrome.sh

EXPOSE 5900 6080

CMD ["sleep", "inf"]

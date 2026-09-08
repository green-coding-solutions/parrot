# Build and push the website benchmark's browser image.
#
#   make            # same as `make build`
#   make build      # build ribalba/parrot-browsers:v1 locally and load it into docker
#   make check      # prove both browsers actually run in the built image
#   make push       # push the tag the usage_scenario files pin
#   make release    # build, check, then push - the one to use before a cluster run
#
# Everything is implemented ONCE, in the repository-root Makefile, as
# `browsers`, `check-browsers` and `push-browsers`. This file is a wrapper so
# that the group can be built from inside its own directory, the way the other
# per-group images are built from the root. Overrides pass through:
#
#   make push BROWSERS_TAG=v2
#   make build PLATFORM=linux/arm64
#
# BEFORE YOU PUSH: this image extends ribalba/xwindow-server by TAG. If
# replay.py, helpers.py, timed_xmacro.py or tools/ changed, the base has to go
# first, or a website run keeps measuring with the copy baked into the older
# base layer:
#
#   make -C .. build push          # the base image
#   make release                   # then this one
ROOT := ..

build:
	$(MAKE) -C $(ROOT) browsers

check:
	$(MAKE) -C $(ROOT) check-browsers

push:
	$(MAKE) -C $(ROOT) push-browsers

# Never push an image whose browsers have not been started once. A missing
# shared library is invisible until something tries to run the binary, and the
# next place it would surface is a measured run, 90 s into a window wait.
release: build check push

.DEFAULT_GOAL := build
.PHONY: build check push release

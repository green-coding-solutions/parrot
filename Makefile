IMAGE ?= ribalba/xwindow-server

# Single platform for local builds. Override on the CLI, e.g.:
#   make build PLATFORM=linux/arm64
# On Apple Silicon the native default is arm64; linux/amd64 produces an
# x86_64 image (built via QEMU emulation).
PLATFORM ?= linux/amd64

# Both platforms for the multi-arch manifest pushed to the registry.
PLATFORMS ?= linux/amd64

# Build one arch and load it into local Docker so you can run it.
build:
	docker buildx build --platform $(PLATFORM) --load -t $(IMAGE) .

# Build BOTH arches as a single multi-arch manifest and push to the registry.
# A multi-platform build can't be --load'ed into local Docker, so it goes
# straight to the registry via --push.
push:
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE) --push .

# ---------------------------------------------------------------------------
# Email-client benchmark mail server
#
# Carries the ~500 MB deterministic mailbox inside the image, so a benchmark run
# starts two daemons instead of generating 13,481 messages. Bump MAIL_TAG
# whenever the corpus changes - the tag is what the usage_scenario files pin.
# ---------------------------------------------------------------------------
MAIL_IMAGE ?= ribalba/parrot-mailserver
MAIL_TAG ?= v1
MAIL_CONTEXT := applications/emailclients
MAIL_DOCKERFILE := $(MAIL_CONTEXT)/mailserver/Dockerfile

# Build a smaller corpus for quick iteration:
#   make mailserver MAIL_TARGET_MB=100
MAIL_TARGET_MB ?= 500

mailserver:
	docker buildx build --platform $(PLATFORM) --load \
		--build-arg PARROT_MAIL_TARGET_MB=$(MAIL_TARGET_MB) \
		-t $(MAIL_IMAGE):$(MAIL_TAG) \
		-f $(MAIL_DOCKERFILE) $(MAIL_CONTEXT)

push-mailserver:
	docker buildx build --platform $(PLATFORMS) \
		--build-arg PARROT_MAIL_TARGET_MB=$(MAIL_TARGET_MB) \
		-t $(MAIL_IMAGE):$(MAIL_TAG) --push \
		-f $(MAIL_DOCKERFILE) $(MAIL_CONTEXT)

# Start the image on its own and run the smoke test against it. Useful after a
# rebuild, before pushing.
check-mailserver:
	docker rm -f parrot-mailserver-check >/dev/null 2>&1 || true
	docker run -d --name parrot-mailserver-check $(MAIL_IMAGE):$(MAIL_TAG) >/dev/null
	docker exec parrot-mailserver-check parrot-mailserver-start
	docker rm -f parrot-mailserver-check >/dev/null

.PHONY: build push mailserver push-mailserver check-mailserver

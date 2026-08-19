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

# ---------------------------------------------------------------------------
# Chat-client benchmark Matrix homeserver
#
# Carries the seeded corpus inside the image, so a benchmark run starts two
# daemons instead of registering 500 accounts and writing tens of thousands of
# events. Bump MATRIX_TAG whenever the corpus changes - the tag is what the
# usage_scenario files pin, and a reseed changes every room ID.
# ---------------------------------------------------------------------------
MATRIX_IMAGE ?= ribalba/parrot-matrixserver
MATRIX_TAG ?= v1
MATRIX_CONTEXT := applications/chatclients
MATRIX_DOCKERFILE := $(MATRIX_CONTEXT)/matrixserver/Dockerfile

# Build a smaller corpus for quick iteration:
#   make matrixserver MATRIX_HISTORY=2000
# See the note on PARROT_MATRIX_HISTORY in applications/chatclients/account.env
# for why this is 8000 and not 40000: deep history does not make the initial
# sync expensive, and every extra 1000 events costs about 2.5 minutes of build.
MATRIX_HISTORY ?= 8000
MATRIX_PHOTOS ?= 400
MATRIX_MEMBERS ?= 500

# Bootstrap only. The version pins in matrixserver/build.sh were written
# without network access; this builds without them and prints what it resolved,
# ready to be pasted back. Never benchmark from an unpinned build.
MATRIX_UNPINNED ?= 0

matrixserver:
	docker buildx build --platform $(PLATFORM) --load \
		--build-arg PARROT_MATRIX_HISTORY=$(MATRIX_HISTORY) \
		--build-arg PARROT_MATRIX_PHOTOS=$(MATRIX_PHOTOS) \
		--build-arg PARROT_MATRIX_MEMBERS=$(MATRIX_MEMBERS) \
		--build-arg PARROT_ALLOW_UNPINNED=$(MATRIX_UNPINNED) \
		-t $(MATRIX_IMAGE):$(MATRIX_TAG) \
		-f $(MATRIX_DOCKERFILE) $(MATRIX_CONTEXT)

push-matrixserver:
	docker buildx build --platform $(PLATFORMS) \
		--build-arg PARROT_MATRIX_HISTORY=$(MATRIX_HISTORY) \
		--build-arg PARROT_MATRIX_PHOTOS=$(MATRIX_PHOTOS) \
		--build-arg PARROT_MATRIX_MEMBERS=$(MATRIX_MEMBERS) \
		-t $(MATRIX_IMAGE):$(MATRIX_TAG) --push \
		-f $(MATRIX_DOCKERFILE) $(MATRIX_CONTEXT)

# Start the image on its own, serve the corpus and run the smoke test against
# it. Useful after a rebuild, before pushing.
check-matrixserver:
	docker rm -f parrot-matrixserver-check >/dev/null 2>&1 || true
	docker run -d --name parrot-matrixserver-check $(MATRIX_IMAGE):$(MATRIX_TAG) >/dev/null
	docker exec parrot-matrixserver-check parrot-matrixserver-start
	docker exec parrot-matrixserver-check parrot-bot-start
	docker rm -f parrot-matrixserver-check >/dev/null

# Ship a fix to parrot-bot.py, start.sh, start-bot.sh or smoke_test.py by
# layering it onto the PUBLISHED image, so the corpus - and with it every room
# ID the recordings depend on - comes through untouched. A plain rebuild only
# preserves the corpus while the build cache still holds the seeding layer.
# See matrixserver/Dockerfile.runtime-patch, and check-matrixserver after.
MATRIX_PATCH_DOCKERFILE := $(MATRIX_CONTEXT)/matrixserver/Dockerfile.runtime-patch

patch-matrixserver:
	docker buildx build --platform $(PLATFORM) --load \
		--build-arg MATRIX_IMAGE=$(MATRIX_IMAGE) \
		--build-arg MATRIX_TAG=$(MATRIX_TAG) \
		-t $(MATRIX_IMAGE):$(MATRIX_TAG) \
		-f $(MATRIX_PATCH_DOCKERFILE) $(MATRIX_CONTEXT)

push-patched-matrixserver:
	docker buildx build --platform $(PLATFORMS) \
		--build-arg MATRIX_IMAGE=$(MATRIX_IMAGE) \
		--build-arg MATRIX_TAG=$(MATRIX_TAG) \
		-t $(MATRIX_IMAGE):$(MATRIX_TAG) --push \
		-f $(MATRIX_PATCH_DOCKERFILE) $(MATRIX_CONTEXT)

.PHONY: build push mailserver push-mailserver check-mailserver \
	matrixserver push-matrixserver check-matrixserver \
	patch-matrixserver push-patched-matrixserver

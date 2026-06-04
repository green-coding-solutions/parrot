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

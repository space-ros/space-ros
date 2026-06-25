# Convenience wrapper around the Docker build for the Space ROS images.
# See docs/USAGE.md for the underlying `docker buildx` commands.

IMAGE_NAME ?= osrf/space-ros

.PHONY: all main-image dev-image build-test generate-repos

# Build both image variants.
all: main-image dev-image

# Bare-bones Space ROS image, tagged `latest`.
main-image:
	docker buildx build --target image \
	  --build-arg IMAGE_VARIANT=main \
	  --tag $(IMAGE_NAME):latest --load .

# Development image (full workspace, dev tooling, IKOS), tagged `dev`.
dev-image:
	docker buildx build --target image \
	  --build-arg IMAGE_VARIANT=dev \
	  --tag $(IMAGE_NAME):dev --load .

# Build and test the workspace, writing the build results archive to
# ./log/build_results_archives/. Always uses the dev variant (the test linters
# and tooling only exist there).
build-test:
	docker buildx build --target export-build-test \
	  --build-arg IMAGE_VARIANT=dev \
	  --output type=local,dest=log/build_results_archives .

# Regenerate ros2.repos from spaceros-pkgs.txt (writes ./ros2.repos).
generate-repos:
	docker buildx build --target export-repos \
	  --output type=local,dest=. .

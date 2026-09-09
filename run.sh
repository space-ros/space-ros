#!/usr/bin/env bash

# Runs a docker container with the image created by build.sh
# Requires:
#   docker
#   an X server

IMG_NAME=osrf/space-ros

# The Earthfile tags the main variant `latest`
case "${SPACE_ROS_VARIANT:-main}" in
  main) TAG="latest" ;;
  *)    TAG="${SPACE_ROS_VARIANT}" ;;
esac

# Replace `/` with `_` to comply with docker container naming
# And append `_runtime`
CONTAINER_NAME="$(tr '/' '_' <<< "${IMG_NAME}")"

# Start the container
docker run \
  --rm \
  -it \
  --network host \
  --name "${CONTAINER_NAME}" \
  -e DISPLAY \
  -e TERM \
  -e QT_X11_NO_MITSHM=1 \
  "${IMG_NAME}:${TAG}" \
  bash

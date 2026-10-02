#!/usr/bin/env bash

# Exit script with failure if build fails
set -eo pipefail

ORG=osrf
IMAGE=space-ros
VARIANT=${SPACE_ROS_VARIANT:-"main"}

# The main variant is tagged `latest`
case "${VARIANT}" in
  main) TAG="latest" ;;
  *)    TAG="${VARIANT}" ;;
esac

docker buildx build --target image \
  --build-arg IMAGE_VARIANT="${VARIANT}" \
  --tag "${ORG}/${IMAGE}:${TAG}" --load .

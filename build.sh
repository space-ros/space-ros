#!/usr/bin/env bash

ORG=osrf
IMAGE=space-ros
VARIANT=${SPACE_ROS_VARIANT:-"main"}

# Exit script with failure if build fails
set -eo pipefail

earthly "+${VARIANT}-image" --IMAGE_NAME="${ORG}/${IMAGE}"

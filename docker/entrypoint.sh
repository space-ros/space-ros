#!/bin/bash

# Setup the Space ROS environment

# Tell shellcheck to ignore generated file from ROS build scripts
# shellcheck source=/dev/null
source "${SPACEROS_DIR}/setup.bash"

exec "$@"

#!/bin/bash

# Setup the Space ROS environment

# Tell shellcheck to ignore generated file from ROS build scripts
# shellcheck source=/dev/null
source "${SPACEROS_DIR}/setup.bash"

# The dev image ships IKOS for static analysis; expose it when present. The
# main image does not contain /opt/ikos, so this is a no-op there.
if [ -d /opt/ikos/bin ]; then
  export PATH="/opt/ikos/bin:${PATH}"
  export IKOS_SCAN_NOTIFIER_FILES=""
fi

exec "$@"

#!/usr/bin/env bash

# Rehearses a Space ROS release locally without pushing, tagging, or committing:
#
#   1. Regenerates ros2.repos and diffs it against the committed file.
#   2. Builds the main and dev images, and optionally runs the test build.
#   3. Checks the main image still has what downstream images build with.
#   4. Builds the stacks and demos named in the release checklist on top of the
#      new images instead of the published ones.
#
# Every step runs even if an earlier one fails, unless a later step needs its
# image. Logs and the regenerated ros2.repos land in the work directory.
#
# Requires:
#   docker with buildx
#   git

set -uo pipefail

usage() {
  cat <<EOF
Usage: $0 [options]
  --release TAG        Release tag for the local images (default: dryrun-YYYYMMDD)
  --workdir DIR        Logs, clones and outputs (default: /tmp/space-ros-<TAG>)
  --core-image IMAGE   Use an existing main image instead of building one
                       (also skips the dev image)
  --with-tests         Also run the test build (export-build-test, slow)
  --update-repos       Copy the regenerated ros2.repos into this checkout
  --stacks-ref REF     space-ros/stacks branch or tag (default: main)
  --demos-ref REF      space-ros/demos branch or tag (default: main)
  -h, --help           Show this help
EOF
  exit "${1:-0}"
}

RELEASE="dryrun-$(date +%Y%m%d)"
WORKDIR=""
CORE_IMAGE=""
WITH_TESTS=false
UPDATE_REPOS=false
STACKS_REF=main
DEMOS_REF=main

while [ $# -gt 0 ]; do
  case "$1" in
    --release)      RELEASE=$2; shift 2 ;;
    --workdir)      WORKDIR=$2; shift 2 ;;
    --core-image)   CORE_IMAGE=$2; shift 2 ;;
    --with-tests)   WITH_TESTS=true; shift ;;
    --update-repos) UPDATE_REPOS=true; shift ;;
    --stacks-ref)   STACKS_REF=$2; shift 2 ;;
    --demos-ref)    DEMOS_REF=$2; shift 2 ;;
    -h|--help)      usage ;;
    *)              echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${WORKDIR:-"/tmp/space-ros-${RELEASE}"}
LOGS="${WORKDIR}/logs"
mkdir -p "${LOGS}"

# Local names only, so a dry run never overwrites a published osrf/* tag.
ORG=dryrun
MAIN_IMAGE=${CORE_IMAGE:-"${ORG}/space-ros:${RELEASE}"}
DEV_IMAGE="${ORG}/space-ros:${RELEASE}-dev"
MOVEIT2_IMAGE="${ORG}/space-ros-moveit2:${RELEASE}"
NAV2_IMAGE="${ORG}/space-ros-nav2:${RELEASE}"

RESULTS=()

# step NAME CMD... runs CMD with output in logs/NAME.log and records the result.
step() {
  local name=$1; shift
  local log="${LOGS}/${name}.log" start=$SECONDS status
  echo "##### ${name} (log: ${log})"
  "$@" > "${log}" 2>&1
  status=$?
  local result="PASS"
  [ ${status} -eq 0 ] || result="FAIL"
  RESULTS+=("${result} ${name} $(( (SECONDS - start) / 60 ))m")
  echo "##### ${name}: ${result}"
  [ ${status} -eq 0 ] || tail -n 20 "${log}"
  return ${status}
}

skip() {
  RESULTS+=("SKIP $1 ($2)")
  echo "##### $1: SKIP ($2)"
}

# Demos pin published images in FROM. Point every osrf/space-ros* base at the
# local images instead.
base_contexts() {
  local dockerfile=$1
  sed -n 's/^FROM[[:space:]]\+\(osrf\/space-ros[^[:space:]]*\).*/\1/p' "${dockerfile}" | while read -r base; do
    case "${base}" in
      osrf/space-ros-moveit2:*) echo "--build-context ${base}=docker-image://${MOVEIT2_IMAGE}" ;;
      osrf/space-ros-nav2:*)    echo "--build-context ${base}=docker-image://${NAV2_IMAGE}" ;;
      osrf/space-ros:*)         echo "--build-context ${base}=docker-image://${MAIN_IMAGE}" ;;
    esac
  done
}

regenerate_repos() {
  docker buildx build --no-cache-filter setup --target export-repos \
    --output "type=local,dest=${WORKDIR}" "${REPO_DIR}" \
  && { diff -u "${REPO_DIR}/ros2.repos" "${WORKDIR}/ros2.repos" > "${WORKDIR}/ros2.repos.diff" || true; }
}

build_core() {
  docker buildx build --no-cache-filter setup --target image \
    --build-arg IMAGE_VARIANT="$1" --tag "$2" --load "${REPO_DIR}"
}

build_test() {
  docker buildx build --no-cache-filter setup --target export-build-test \
    --build-arg IMAGE_VARIANT=dev \
    --output "type=local,dest=${WORKDIR}/build_results_archives" "${REPO_DIR}"
}

# What stacks and demos expect from the main image. See the Dockerfiles in
# space-ros/stacks and space-ros/demos.
check_main_image() {
  docker run --rm --entrypoint bash "${MAIN_IMAGE}" -c '
    set -e
    for tool in colcon rosdep vcs git cmake g++ rosinstall_generator; do
      command -v "${tool}"
    done
    test -f "${SPACEROS_DIR}/scripts/spaceros.repos"
    find "${SPACEROS_DIR}" -name rclcppConfig.cmake | grep -q .
    source "${SPACEROS_DIR}/setup.bash"
    ros2 pkg list | grep -qx rclcpp'
}

check_dev_image() {
  docker run --rm --entrypoint bash "${DEV_IMAGE}" -c '
    set -e
    command -v ikos
    source "${SPACEROS_DIR}/setup.bash"
    ros2 pkg list | grep -qx ament_lint'
}

clone() {
  rm -rf "${WORKDIR:?}/$1"
  git clone --quiet --depth 1 --branch "$2" "https://github.com/space-ros/$1.git" "${WORKDIR}/$1"
}

build_stack() {
  docker buildx build --build-arg SPACE_ROS_IMAGE="${MAIN_IMAGE}" \
    --tag "$2" --load "${WORKDIR}/stacks/$1"
}

build_demo() {
  local dir="${WORKDIR}/demos/$1"
  # shellcheck disable=SC2046 # base_contexts emits separate flags
  docker buildx build $(base_contexts "${dir}/Dockerfile") \
    --tag "${ORG}/$1:${RELEASE}" --load "${dir}"
}

echo "Release ${RELEASE}, work directory ${WORKDIR}"

if step regenerate-repos regenerate_repos; then
  echo "ros2.repos changes: $(grep -c '^[-+] *version:' "${WORKDIR}/ros2.repos.diff" || true) version lines"
  if ${UPDATE_REPOS}; then
    cp "${WORKDIR}/ros2.repos" "${REPO_DIR}/ros2.repos"
  fi
fi

main_ok=true
if [ -n "${CORE_IMAGE}" ]; then
  skip build-main "using ${CORE_IMAGE}"
  skip build-dev "--core-image given"
  dev_ok=false
else
  step build-main build_core main "${MAIN_IMAGE}" || main_ok=false
  dev_ok=true
  step build-dev build_core dev "${DEV_IMAGE}" || dev_ok=false
fi

if ${WITH_TESTS}; then
  step build-test build_test
else
  skip build-test "pass --with-tests"
fi

if ${main_ok}; then
  step check-main-image check_main_image
else
  skip check-main-image "no main image"
fi
if ${dev_ok}; then
  step check-dev-image check_dev_image
else
  skip check-dev-image "no dev image"
fi

moveit2_ok=false
nav2_ok=false
if ${main_ok} && step clone-stacks clone stacks "${STACKS_REF}"; then
  step build-moveit2 build_stack moveit2 "${MOVEIT2_IMAGE}" && moveit2_ok=true
  step build-navigation2 build_stack navigation2 "${NAV2_IMAGE}" && nav2_ok=true
else
  skip build-moveit2 "no main image or stacks clone"
  skip build-navigation2 "no main image or stacks clone"
fi

if ${main_ok} && step clone-demos clone demos "${DEMOS_REF}"; then
  step build-canadarm2 build_demo canadarm2
  step build-curiosity_rover build_demo curiosity_rover
  if ${moveit2_ok}; then step build-space_robots build_demo space_robots; else skip build-space_robots "no moveit2 image"; fi
  if ${nav2_ok}; then step build-nav2_demo build_demo nav2_demo; else skip build-nav2_demo "no navigation2 image"; fi
else
  for demo in canadarm2 curiosity_rover space_robots nav2_demo; do
    skip "build-${demo}" "no main image or demos clone"
  done
fi

echo
echo "##### Summary for ${RELEASE}"
printf '%s\n' "${RESULTS[@]}" | tee "${WORKDIR}/summary.txt"
echo "Not covered: launching the demos, which needs a display. See the release tracking issue."

! grep -q '^FAIL' "${WORKDIR}/summary.txt"

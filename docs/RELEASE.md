# Release steps

## Update ros2.repos file
```
git clone https://github.com/space-ros/space-ros.git
cd space-ros
git checkout -b <release-id>
docker buildx build --target export-repos --output type=local,dest=. .
git add ros2.repos
git commit -m "Update repos file for <release-id> release"
```

## Dry run a release
`release-dry-run.sh` rehearses a release locally before you start the steps above.
It regenerates `ros2.repos`, builds the `main` and `dev` images, and builds the stacks and demos on top of them.
It names its images `dryrun/*` and never pushes images or creates git tags or commits.
```
./release-dry-run.sh                                   # full run
./release-dry-run.sh --with-tests                      # also run export-build-test
./release-dry-run.sh --core-image osrf/space-ros:main  # reuse an existing main image
./release-dry-run.sh --help                            # all options
```
Logs, clones, the regenerated `ros2.repos`, and its diff go to the work directory, `/tmp/space-ros-<release>` by default (`--workdir`, `--release`).
`--update-repos` also copies the regenerated `ros2.repos` into the checkout.
The script exits nonzero if any step fails.

Each step prints its log path and result, and the script ends with a summary.
This is the summary of `./release-dry-run.sh --release dryrun-test --core-image osrf/space-ros:main`:
```
##### Summary for dryrun-test
PASS regenerate-repos 0m
SKIP build-main (using osrf/space-ros:main)
SKIP build-dev (--core-image given)
SKIP build-test (pass --with-tests)
PASS check-main-image 0m
SKIP check-dev-image (no dev image)
PASS clone-stacks 1m
PASS build-moveit2 37m
PASS build-navigation2 20m
PASS clone-demos 38m
PASS build-canadarm2 1m
PASS build-curiosity_rover 0m
PASS build-space_robots 32m
PASS build-nav2_demo 1m
Not covered: launching the demos, which needs a display. See the release tracking issue.
```

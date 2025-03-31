# Space ROS Docker Image and Earthly configuration

The Earthfile configuration in this directory facilitates builds of Space ROS from source code.
The generated container image is based on Ubuntu 22.04 (Jammy)

## Prerequisites

The following software is required to build the Space ROS Docker image:

- [Docker](https://docs.docker.com/get-docker/)
- [Earthly](https://earthly.dev/get-earthly)
- [Git](https://git-scm.com/downloads)

## Setup

The image is built using the [Earthly](https://earthly.dev/get-earthly) utility.
First, clone the Space ROS repository:

```bash
git clone https://github.com/space-ros/space-ros.git
cd space-ros
```
Make sure docker is running and the user has the necessary permissions to run docker commands.

Space ROS comes in different flavors, the following image variants are available:

 - `main-image`: The main image contains the ROS 2 core packages, including the ROS 2 client libraries, the ROS 2 command line tools, and the ROS 2 middleware implementations.
 - `dev-image`: The dev image contains the main image and additional tools for development, such as the ROS 2 build tools, the ROS 2 test tools, and the ROS 2 launch tools.

Build the Space ROS Docker image by running the following command:

```bash
# To build all image variants, use the following command:
earthly +all --SKIP_BUILD_TEST=true --VCS_REF="$(git rev-parse HEAD)"

# To build a specific image variant, use the following command:
earthly +main-image --SKIP_BUILD_TEST=true --VCS_REF="$(git rev-parse HEAD)"
earthly +dev-image --SKIP_BUILD_TEST=true --VCS_REF="$(git rev-parse HEAD)"
```

The build process will take about 20 or 30 minutes, depending on the host computer.

## Usage

After building the image, you can see the newly-built image by running:

```bash
docker image list
```

The output will look something like this:

```
$ docker image list
REPOSITORY              TAG       IMAGE ID       CREATED          SIZE
osrf/space-ros          dev       f672118c90d8   13 minutes ago   2.36GB
osrf/space-ros          latest    ba485015288a   16 minutes ago   1.13GB
ubuntu                  jammy     a8780b506fa4   5 days ago       77.8MB
```

From here, we will use the `osrf/space-ros:latest` image as an example.

To run the Space ROS Docker container, use the following command:
```bash
docker run -it --rm osrf/space-ros:latest /bin/bash
```

You'll now be running inside the container and should see a prompt similar to this:

```
spaceros-user@d10d85c68f0e:~/$
```

At this point, you can run the `ros2` command line utility to make sure everything is working OK:

```
spaceros-user@d10d85c68f0e:~/$ ros2
usage: ros2 [-h] [--use-python-default-buffering] Call `ros2 <command> -h` for more detailed usage. ...

ros2 is an extensible command-line tool for ROS 2.

optional arguments:
  -h, --help            show this help message and exit
  --use-python-default-buffering
                        Do not force line buffering in stdout and instead use the python default buffering, which might be affected by PYTHONUNBUFFERED/-u and depends on whatever stdout is interactive or not

Commands:
  action     Various action related sub-commands
  component  Various component related sub-commands
  daemon     Various daemon related sub-commands
  doctor     Check ROS setup and other potential issues
  interface  Show information about ROS interfaces
  launch     Run a launch file
  lifecycle  Various lifecycle related sub-commands
  multicast  Various multicast related sub-commands
  node       Various node related sub-commands
  param      Various param related sub-commands
  pkg        Various package related sub-commands
  run        Run a package specific executable
  service    Various service related sub-commands
  topic      Various topic related sub-commands
  trace      Trace ROS nodes to get information on their execution
  wtf        Use `wtf` as alias to `doctor`

  Call `ros2 <command> -h` for more detailed usage.
```

Space ROS promotes building projects from source code, and more instructions can be found in the [Space ROS documentation](https://space.ros.org).


### SpaceROS for development

The `osrf/space-ros:dev` image is intended for development and contains additional tools for development, such as the ROS 2 build tools, the ROS 2 test tools, and the ROS 2 launch tools.

To run the Space ROS Docker container for development, use the following command:

```bash
docker run -it --rm osrf/space-ros:dev /bin/bash
```

This container will have all the tools necessary for building and testing ROS 2 packages.

1. To use IKOS. you can follow the instructuions in the [IKOS Integration](./IKOS.md) documentation.
2. To reproduce the build process, you can follow the instructions in the [Reproducible Builds](./REPRODUCIBLE.md) documentation.

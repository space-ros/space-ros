
# IKOS Integration

IKOS is a static analysis tool that performs interprocedural analysis on C/C++ code.

Make sure you are in the Space ROS Docker container before running the following commands.

## Preparing Space ROS sources

A manifest of the exact sources of Space ROS used to produce the current image is saved as `spaceros.repos` in the `/opt/spaceros` directory.
To clone all sources from this manifest you can use the command sequence

```bash
spaceros-user@d10d85c68f0e:~/$ mkdir -p spaceros_ws/src
spaceros-user@d10d85c68f0e:~/spaceros_ws$ cd spaceros_ws
spaceros-user@d10d85c68f0e:~/spaceros_ws$ vcs import src < /opt/spaceros/scripts/spaceros.repos
```

## Running an IKOS Scan

IKOS uses special compiler and linker settings in order to instrument and analyze binaries.
To run an IKOS scan on all of the Space ROS test binaries (which will take a very long time), run the following command at the root of the Space ROS workspace:

```bash
spaceros-user@d10d85c68f0e:~/spaceros_ws$ CC="ikos-scan-cc" CXX="ikos-scan-c++" LD="ikos-scan-cc" colcon build --cmake-args -DSECURITY=ON -DINSTALL_EXAMPLES=OFF -DCMAKE_EXPORT_COMPILE_COMMANDS=ON --no-warn-unused-cli
```

The previous command generates the instrumented binaries and the associated output in a separate directory from the normal Space ROS build; the command uses *--build-base* option to specify **build_ikos** as the build output directory instead of the default **build** directory.

To run an IKOS scan on a specific package, such as rcpputils in this case, use the *--packages-select* option, as follows:

```bash
spaceros-user@d10d85c68f0e:~/spaceros_ws$ CC="ikos-scan-cc" CXX="ikos-scan-c++" LD="ikos-scan-cc" colcon build --packages-select rcpputils --cmake-args -DSECURITY=ON -DINSTALL_EXAMPLES=OFF -DCMAKE_EXPORT_COMPILE_COMMANDS=ON --no-warn-unused-cli
```

### Generating IKOS Results

To generate JUnit XML/SARIF files for all of the binaries resulting from the build command in the previous step, you can use **colcon test**, as follows:

```bash
spaceros-user@d10d85c68f0e:~/spaceros_ws$ colcon test --ctest-args -L "ikos"
```

To generate a JUnit XML file for a specific package only, you can add the *--packages-select* option, as follows:

```bash
spaceros-user@d10d85c68f0e:~/spaceros_ws$ colcon test --ctest-args -L "ikos" --packages-select rcpputils
```

The `colcon test` command with the `-L "ikos"` flag runs IKOS report generation, which reads the IKOS database generated in the previous analysis step and generates a JUnit XML report file.
After running `colcon test`, you can view the JUnit XML files.
For example, to view the JUnit XML file for IKOS scan of the rcpputils binaries you can use the following command:

```bash
spaceros-user@d10d85c68f0e:~/spaceros_ws$ more build_ikos/rcpputils/test_results/rcpputils/ikos.xunit.xml
```

SARIF files are also available in the same path:
```bash
spaceros-user@d10d85c68f0e:~/spaceros_ws$ more build_ikos/rcpputils/test_results/rcpputils/ikos.sarif
```

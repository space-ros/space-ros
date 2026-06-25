# IKOS Integration

IKOS is a static analysis tool that performs interprocedural analysis on C/C++ code.

We use the `dev` image, which has the tool pre-installed and ready to run.
Ensure the source code and workspace are updated as noted in the [usage docs](./USAGE.md).

## Building with IKOS

IKOS uses special compiler and linker settings in order to instrument and analyze binaries.
To allow packages to be analyzed with IKOS, they must first be built with IKOS.
To start,

```bash
cd ${HOME}/spaceros_ws
```

Next, we can rebuild the entirety of the workspace using a special `colcon` invocation that utilizes the aforementioned IKOS wrappers.
We also skip Cobra packages, as there is no reason to analyze them with IKOS (and `cobra_vendor`'s compilation will not succeed out of the box, though this can be worked around).
The below command keeps the IKOS build separate from the dev install (this may take a long time):

```bash
CC="ikos-scan-cc" CXX="ikos-scan-c++" LD="ikos-scan-cc" \
  colcon build \
  --packages-skip ament_cmake_cobra ament_cobra cobra_vendor \
  --packages-ignore ament_cmake_cobra ament_cobra cobra_vendor \
  --build-base build_ikos \
  --install-base install_ikos \
  --cmake-args \
  -DBUILD_TESTING=ON \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSECURITY=ON \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --no-warn-unused-cli
```

The previous command generates the instrumented binaries and the associated output in a separate directory from the normal Space ROS build.
The command uses *--build-base* option to specify **build_ikos** as the build output directory instead of the default **build** directory.

To build a specific package for IKOS analysis, e.g. `rclcpp`, use the `--packages-up-to` or `--packages-select` options:

```bash
CC="ikos-scan-cc" CXX="ikos-scan-c++" LD="ikos-scan-cc" \
  colcon build \
  --packages-up-to rclcpp \
  --packages-skip ament_cmake_cobra ament_cobra cobra_vendor \
  --build-base build_ikos \
  --install-base install_ikos \
  --cmake-args \
  -DBUILD_TESTING=ON \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSECURITY=ON \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --no-warn-unused-cli
```

## Generating IKOS Results

For many repositories, IKOS will fail analysis.
This is due to it not supporting all LLVM instructions.
When running it with `colcon test` it will silently appear to succeed, though it will generate no results.
This can be seen when running, for example, `colcon test` with the `console_cohesion+` event handler.

This invocation will produce many errors containing `error: unsupported llvm type`, but the `colcon test` without the `console_cohesion+` handler itself will seem like it ran and passed without producing any issues because `colcon test` defaults to swallowing the output.
Even when IKOS cannot run, the `ikos` colcon test invocation does not return an actual failure (non-zero error code), it just prints the error to the console.
Because of this limitation, it may be more fruitful to run it directly on specific targets that are found to not contain unsupported LLVM types.
The IKOS tool can be run on selected `.bc` files, which are produced by the special `colcon build` invocation above.
This is done by simply invoking `ikos` on a `.bc` file, as so:

```bash
ikos build_ikos/cyclonedds/bin/test_ucunit.bc
```

You should then see output similar to this:

```bash
[*] Running ikos preprocessor
[*] Running ikos analyzer
[*] Translating LLVM bitcode to AR
[*] Running liveness analysis
[*] Running widening hint analysis
[*] Running interprocedural value analysis
[*] Analyzing entry point 'main'
[*] Checking properties for entry point 'main'

# Time stats:
ikos-analyzer: 0.018 sec
ikos-pp      : 0.018 sec

# Summary:
Total number of checks                : 23
Total number of unreachable checks    : 7
Total number of safe checks           : 12
Total number of definite unsafe checks: 1
Total number of warnings              : 3

The program is definitely UNSAFE
```

## Unsupported `.bc` files

When using IKOS, you may find that it does not produce results.
This can occur when using it on `.bc` files that contain unsupported LLVM, as mentioned above.
Such an error will look similar to this:

```bash
[*] Running ikos preprocessor
[*] Running ikos analyzer
[*] Translating LLVM bitcode to AR
ikos-analyzer: /tmp/ikos-pdak502e/test_executors.pp.bc: error: unsupported llvm type
ikos: error: a run-time error occurred
```

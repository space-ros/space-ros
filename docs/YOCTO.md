# Space ROS on Yocto / Space Grade Linux

This document describes how to **build**, **deploy**, and **test** Space ROS as a
native Yocto/OpenEmbedded image, using **Space Grade Linux (SGL)** as the
distribution. The **QEMU RISC-V 64-bit** target is used as the worked example
throughout because it needs no hardware and is the reference target used in CI.

> Status: this is a community port driven by the
> [ELISA Space Grade Linux SIG](https://elisa.tech/space-grade-linux-sig/)
> (primarily [@robwoolley](https://github.com/robwoolley)). It is tracked in
> Space ROS [discussion #370](https://github.com/space-ros/space-ros/discussions/370).
> The Yocto build does **not** use the `Earthfile`/Docker flow in this repo — it
> is an independent build path. See "Relationship to the Docker build" below.

---

## 1. Background: why Yocto?

The standard Space ROS image (`osrf/space-ros`, built with Earthly) is an
Ubuntu-based Docker container. A Yocto build instead produces a **complete,
self-contained Linux filesystem image** with Space ROS baked in. This matters for
spaceflight use cases:

- **Cross-architecture & bare-metal targets** — RISC-V, ARM64, x86-64, and real
  flight-candidate boards (e.g. BeagleV-Fire / Microchip PolarFire SoC).
- **Reproducible, auditable, minimal images** — only the packages you select,
  with full source provenance and license tracking, suitable for certification.
- **A single artifact** — kernel + rootfs + Space ROS, deployable to flash or run
  in QEMU, with no container runtime needed.

---

## 2. How the build is wired

### 2.1 The component stack

The build composes several upstream Yocto layers. From the bottom up:

| Layer / repo | Role |
|---|---|
| **bitbake** + **openembedded-core** (`meta`) | The build engine and core recipes (Yocto **Scarthgap**, the 5.0 LTS) |
| **meta-openembedded** (`meta-oe`, `meta-python`, `meta-networking`, …) | Extra middleware/runtime recipes Space ROS depends on |
| **meta-clang** + **meta-clang-revival** | Clang/LLVM toolchain bits (incl. `libomp`) used by parts of the ROS stack |
| **meta-python-ai** | Provides Fortran/`libquadmath` plumbing some scientific deps need |
| **[meta-sgl](https://github.com/elisa-tech/meta-sgl)** (`meta-sgl-core`) | The **SGL distro** definition (`DISTRO = "sgl"`) and BSP/machine glue |
| **[meta-ros](https://github.com/ros/meta-ros)** (`meta-ros-common`, `meta-ros2`, `meta-spaceros`, `meta-spaceros-jazzy`) | The actual **ROS 2 + Space ROS recipes** |

The Space ROS recipes live in `meta-ros`; SGL is the distribution that pulls them
together and adds the space-targeted machine/BSP support. Orchestration is done
with **[kas](https://kas.readthedocs.io/)**, which clones each layer at a pinned
commit and assembles `bblayers.conf` / `local.conf` for you.

### 2.2 The kas include chain (qemuriscv64 + Space ROS)

kas configs are layered via `header.includes`. The top-level file for our example
is tiny — it just composes a base board config with the Space ROS overlay:

```
kas/sgl-scarthgap-spaceros-jazzy-2025.10-qemuriscv64.yml
├── kas/sgl-scarthgap-qemuriscv64.yml          # the base SGL board build
│   ├── kas/yocto/scarthgap.yml                # OE-core + bitbake + meta-openembedded (pinned), branch=scarthgap
│   │   └── kas/layer/clang-revival.yml        #   meta-clang-revival repo
│   ├── kas/machine/qemuriscv64.yml            # MACHINE = "qemuriscv64"
│   ├── kas/common.yml                         # shared local.conf (usrmerge, empty root pw, rm_work, …)
│   ├── kas/sgl/sgl.yml                         # DISTRO = "sgl"; meta-sgl-core; target = core-image-minimal
│   └── kas/sgl/clang.yml                       # meta-clang + libomp PACKAGECONFIG
└── kas/spaceros/jazzy-2025.10.yml             # the Space ROS overlay (see below)
```

**The board base** (`sgl-scarthgap-qemuriscv64.yml`) defines *what kind of Linux*
and *for which machine*:

```yaml
header:
  version: 14
  includes:
    - kas/yocto/scarthgap.yml      # Yocto release + core layers
    - kas/machine/qemuriscv64.yml  # machine: "qemuriscv64"
    - kas/common.yml               # common local.conf tweaks
    - kas/sgl/sgl.yml              # distro: "sgl", target core-image-minimal
    - kas/sgl/clang.yml            # clang toolchain
```

**The Space ROS overlay** (`spaceros/jazzy-2025.10.yml`) is the only Space
ROS-specific piece. It adds the `meta-ros` layers (pinned to an exact commit) and
appends the Space ROS package group to the image:

```yaml
header:
  version: 14

repos:
  spaceros:
    url: "https://github.com/ros/meta-ros.git"
    path: "layers/meta-ros"
    commit: "8fb0ee223c8dfcd69f7b71ef8bce449015c1d3fa"   # pins jazzy-2025.10
    layers:
      meta-ros-common:
      meta-ros2:
      meta-spaceros:
      meta-spaceros-jazzy:

local_conf_header:
  spaceros: |
    IMAGE_INSTALL:append = "packagegroup-spaceros-jazzy-world"
```

That single `IMAGE_INSTALL:append` line is what turns a plain
`core-image-minimal` into a Space ROS image: **`packagegroup-spaceros-jazzy-world`**
is the curated set of Space ROS Jazzy packages (defined in `meta-spaceros-jazzy`).

### 2.3 What this means in practice

- To target a **different machine**, swap the `kas/machine/*.yml` include (or use
  the matching `sgl-scarthgap-spaceros-jazzy-2025.10-<machine>.yml`). Available
  machines today: `qemuriscv64`, `qemuarm64`, `qemux86-64`, and `beaglev-fire`.
- To target a **different Space ROS release**, swap the `kas/spaceros/*.yml`
  overlay (the pinned `meta-ros` commit changes per release — see §7).
- The image type is **`core-image-minimal`** + the Space ROS package group. The
  result for qemuriscv64 is roughly a **~1.4 GB ext4** rootfs.

---

## 3. Prerequisites

On a Linux host (native or VM):

- `python3` + `venv`, `git`
- Standard Yocto host build deps (gcc, make, diffstat, gawk, chrpath, zstd, etc.
  — see the [Yocto quick start](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html))
- `qemu-system-misc` (for `qemu-system-riscv64`) to run the image
- Disk: **plan for ~100 GB** and a multi-hour first build (ROS from source is large)

> The build downloads several layers and a lot of sources. A warm sstate/download
> cache makes rebuilds dramatically faster. 
> If you have weak internet connection or VPN or just unlucky with cloudflare(?) infrastructure your downloads may be throttled or denied. 
> Just keep restarting the kas build and/or try different connections to internet.

---

## 4. Build (QEMU RISC-V example)

### 4.1 Install kas

```bash
python3 -m venv venv
source venv/bin/activate
pip3 install kas
```

### 4.2 Get the kas configuration

```bash
git clone https://github.com/elisa-tech/meta-sgl
```

### 4.3 Build the image

```bash
# Choose a build/work directory (gets large)
export KAS_WORK_DIR=$PWD/build-spaceros-riscv64
mkdir -p "$KAS_WORK_DIR"

kas build meta-sgl/kas/sgl-scarthgap-spaceros-jazzy-2025.10-qemuriscv64.yml
```

kas will clone every layer at its pinned commit, generate `bblayers.conf` /
`local.conf`, and run bitbake. On success the artifacts are under:

```
$KAS_WORK_DIR/build/tmp-glibc/deploy/images/qemuriscv64/
├── Image                                              # kernel
└── core-image-minimal-qemuriscv64.rootfs.ext4         # rootfs (~1.4 GB) with Space ROS
```

> **Tip:** to build just the base SGL image (no Space ROS) for a faster sanity
> check, use `meta-sgl/kas/sgl-scarthgap-qemuriscv64.yml` instead.

---

## 5. Deploy / run in QEMU

Yocto way:

```bash
cd "$KAS_WORK_DIR"
source layers/openembedded-core/oe-init-build-env
runqemu qemuriscv64 nographic
```

Custom way:

```bash
cd "$KAS_WORK_DIR"
qemu-system-riscv64 \
  -M virt -m 512M -nographic \
  -kernel build/tmp-glibc/deploy/images/qemuriscv64/Image \
  -append "root=/dev/vda rw console=ttyS0" \
  -drive file=build/tmp-glibc/deploy/images/qemuriscv64/core-image-minimal-qemuriscv64.rootfs.ext4,format=raw,id=hd0,if=none \
  -device virtio-blk-device,drive=hd0 \
  -netdev user,id=net0 \
  -device virtio-net-device,netdev=net0
```

You'll see OpenSBI → kernel boot → systemd, ending at:

```
...
[  OK  ] Finished Record Runlevel Change in UTMP.

Space Grade Linux 0.1 qemuriscv64 ttyS0

qemuriscv64 login: 
```

- **Login:** `root`, no password.
- **Quit QEMU:** `Ctrl-A` then `x`.

> For more memory-hungry workloads (the demos), bump `-m` to `2048M` or more.

---

## 6. Run Space ROS inside the image

Space ROS is installed under **`/opt/ros/spaceros`**. The image does not ship the
usual `setup.bash`, so export the environment manually (Jazzy uses Python 3.12):

```bash
export SPACEROS_DIR=/opt/ros/spaceros
export ROS_DISTRO=jazzy
export ROS_VERSION=2
export ROS_PYTHON_VERSION=3
export AMENT_PREFIX_PATH=$SPACEROS_DIR
export COLCON_PREFIX_PATH=$SPACEROS_DIR
export LD_LIBRARY_PATH=$SPACEROS_DIR/lib:$LD_LIBRARY_PATH
export PATH=$SPACEROS_DIR/bin:$PATH
export PYTHONPATH=$SPACEROS_DIR/lib/python3.12/site-packages:$PYTHONPATH
export CMAKE_PREFIX_PATH=$SPACEROS_DIR:$CMAKE_PREFIX_PATH
```

Sanity check:

```bash
ros2 --help
ros2 pkg list | head
```

Run a demo (the Canadarm demo is known to launch on this image):

```bash
ros2 launch canadarm_demo canadarm.launch.py
```

Expected output:

```
[INFO] [launch]: All log files can be found below /root/.ros/log/...
[INFO] [launch]: Default logging verbosity is set to INFO
[INFO] [move_arm-1]: process started with pid [...]
```

> The `AMENT_PREFIX_PATH` / `COLCON_PREFIX_PATH` / `PATH` / `PYTHONPATH` /
> `LD_LIBRARY_PATH` exports are the minimum needed to launch nodes. Whether the
> `CMAKE_*`/`COLCON_*` vars are strictly required at runtime (vs. only for
> building) is still being confirmed; export them to be safe.

---

## 7. Testing & CI

CI lives in `meta-sgl` under `.github/workflows/`. Builds are factored into a
**reusable workflow** (`build-sgl.yml`) that each target calls with three inputs:
the kas config, the hardware arch, and a build profile. The Space ROS RISC-V job is:

```yaml
# .github/workflows/test_build_qemu_riscv64_spaceros.yml
name: QEMU RISCV64 + SpaceROS
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
jobs:
  build:
    uses: ./.github/workflows/build-sgl.yml
    with:
      kas_config: sgl-scarthgap-spaceros-jazzy-2025.10-qemuriscv64.yml
      hardware_arch: qemuriscv64
      build_profile: spaceros
```

Equivalent matrix jobs exist for `qemuarm64` (+ Space ROS) and `qemux86-64`. CI
runs build the image on every push/PR to `main` and upload the build artifacts.

### Local verification checklist

Until a formal test suite is wired in, validate a build like this:

1. **Build** completes (§4) and produces the kernel + ext4 rootfs.
2. **Boot** in QEMU reaches the `qemuriscv64 login:` prompt (§5).
3. **Environment** sets up and `ros2 pkg list` returns Space ROS packages (§6).
4. **Demo** — `canadarm_demo` launches without errors (§6).
5. **Package parity** — confirm the curated packages match the corresponding
   official Space ROS release (the `meta-ros` commit pinned in the overlay).

> Open work toward a complete acceptance story (per discussion #370): running the
> Space ROS unit tests on-image, validating curated-package parity automatically,
> publishing prebuilt SGL CI images, and publishing Yocto-based Docker images.

---

## 8. Release lineage (which commit = which release)

The Space ROS release is pinned by the `meta-ros` commit in
`kas/spaceros/<release>.yml`. Known releases:

| Space ROS release | meta-ros PR | Status |
|---|---|---|
| Jazzy **2025.10** | [ros/meta-ros#1623](https://github.com/ros/meta-ros/pull/1623) | merged — current kas overlay |
| Jazzy **2026.01.0** | [ros/meta-ros#1662](https://github.com/ros/meta-ros/pull/1662) | merged (kas overlay in progress, [meta-sgl#43](https://github.com/elisa-tech/meta-sgl/pull/43)) |
| Jazzy **2026.04.0** | [ros/meta-ros#1721](https://github.com/ros/meta-ros/pull/1721) | merged |

To move to a newer release, add a `kas/spaceros/jazzy-<release>.yml` overlay that
points `repos.spaceros.commit` at the corresponding `meta-ros` commit, and create
the matching `sgl-scarthgap-spaceros-jazzy-<release>-<machine>.yml` top-level file.

---

## 9. Relationship to the Docker build in this repo

| | Docker build (this repo) | Yocto / SGL build |
|---|---|---|
| Tooling | Earthly (`Earthfile`) | kas + bitbake |
| Base | Ubuntu | OpenEmbedded (Scarthgap LTS) |
| Output | Container image (`osrf/space-ros`) | Bootable kernel + rootfs image |
| Source of packages | `ros2.repos` / built from source | `meta-ros` recipes |
| Repo | `space-ros/space-ros` | `elisa-tech/meta-sgl` + `ros/meta-ros` |

The two are independent paths to a Space ROS environment. The Docker image targets
developer workstations; the Yocto image targets embedded/flight-like deployment and
certification workflows.

---

## References

- Space ROS tracking discussion: https://github.com/space-ros/space-ros/discussions/370
- Initial port PR: https://github.com/elisa-tech/meta-sgl/pull/26
- meta-sgl build docs: https://github.com/elisa-tech/meta-sgl/blob/main/docs/building.md
- ELISA Space Grade Linux SIG: https://elisa.tech/space-grade-linux-sig/
- kas documentation: https://kas.readthedocs.io/
- meta-ros: https://github.com/ros/meta-ros

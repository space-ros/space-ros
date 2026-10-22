# AGENTS.md

Guidance for AI agents working in this repository.
Human-readable rules: the [contributing guide](https://github.com/space-ros/.github/blob/master/CONTRIBUTING.md). If they conflict, it wins.

## Repository

Builds the Space ROS Docker images: `build.sh`, `Dockerfile`, `docker/`, `*.repos`, CI in `.github/workflows/`. Docs live in `docs/` and https://space.ros.org.

Other repos in the [space-ros](https://github.com/space-ros) org:

- `stacks`: Docker images built on top of the Space ROS image (MoveIt 2, Nav2, dev environments).
- `demos`: demo applications.
- `simulation`: simulation assets for the demos (uses git-lfs).
- `docs`: the documentation site, https://space.ros.org.
- `process_sarif`, `dashboard`: static analysis (SARIF) tooling.
- `.github`: org-wide `CONTRIBUTING.md` and issue templates.

Make each change in the repo that owns it. A change spanning repos needs one issue and one PR per repo, cross-linked. The same commit and PR rules apply in `stacks`, `demos` and `simulation`.

## Scope

- One issue, one PR. No issue yet? Ask the human to open one first.
- Keep PRs as small as possible. Change only what the issue needs.
- No drive-by refactors, reformatting or unrelated fixes. Suggest a separate issue instead.
- Be concise in code comments, commit messages, issues and PRs. Say what a reviewer needs, nothing more.

## Commits

- Every commit message must reference its issue, e.g. `(#123)`. CI rejects commits without one.
- Subject: imperative, sentence case, code in backticks, ends with `(#N).`
  - ``Add a `build.sh` entry point for the Space ROS image (#410).``
  - `Pin Docker build runners to ubuntu-24.04 (#432).`
- Body, if needed: why the change was made, briefly. Do not restate the diff.
- One logical change per commit. Most PRs have one commit.
- Squash fixups before review. History must show the final change, not how you got there.
- Do not create merge commits. Maintainers merge with `--no-ff` and `Close #N.`
- When unsure, follow precedent in `git log --oneline <path>`.

## AI-assisted contributions

- Add an `Assisted-by` trailer naming tool and model, e.g. `Assisted-by: Claude Code (claude-opus-5-5)`. Do not add `Co-authored-by` for the AI.
- Never add `Signed-off-by`. Only the human may certify authorship.
- Do not commit, push, or open PRs without explicit human direction. The human reviews and owns every change.

## Before opening a PR

- Run `pre-commit run --all-files` (includes hadolint for Dockerfiles).
- Shell scripts must pass shellcheck. `ros2.repos` must pass `yamllint` and `vcs validate`.
- Update docs (`README.md`, `docs/`) in the same PR when behavior changes.

## Pull requests

- Title states the change. Body links the issue (`Closes #N`) and says how it was tested.
- A maintainer must approve. CI must pass.

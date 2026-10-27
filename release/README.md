# Release tooling

CI (`.github/workflows/check.yml`) uses these scripts to turn a build of the
series into a release on the fork; the host scripts then install a release on
a machine that runs the Omnigent host service.

| File | What |
| --- | --- |
| `build.sh` | From a tree `scripts/build-custom.sh` built: stamp the version, build the three wheels (web UI bundled), export `constraints.txt` from `uv.lock`, copy the host scripts, write `manifest.json`, the notes and `custom-docs.md`, and the image context |
| `server.Dockerfile`, `build-image.sh` | The server image, from the same wheels and constraints |
| `plan.py` | Picks the release tag and finds the previous release |
| `notes.py` | Release notes, `custom-docs.md`, the series list for the manifest |
| `publish.sh` | Pushes the fork's `custom`, the tag, the image, and creates the release |
| `install-host.sh` | Installs a release folder's wheels as the `omnigent` uv tool |
| `upgrade-host.sh` | Installs a release on a host, applies the service environment, restarts and verifies; `--rollback` |
| `check-host.sh` | Read-only drift check of a host against its release |
| `host-common.sh`, `hostlib.py` | Shared shell helpers; stdlib Python helper (manifest, env files, systemd drop-ins, launchd plists) |
| `tests/` | `python3 -m unittest discover -s release/tests` |

## Building one locally

```bash
scripts/build-custom.sh --repo <clone> --worktree /tmp/custom-tree
release/build.sh --tree /tmp/custom-tree --out /tmp/install-set
release/build-image.sh /tmp/install-set          # optional: loads the image locally
```

Needs `uv`, Node 22 and pnpm (the web UI is built into the wheel), and Docker
with buildx for the image. A local build gets the tag `build/<build-id>` and
a `.dirty` build id when `patches/` or `release/` has uncommitted changes.

## Why the image has its own Dockerfile

Upstream's `deploy/docker/Dockerfile` installs the package editable with
`uv pip install -e .`, which resolves dependencies afresh and ignores
`uv.lock`; that once shipped a Starlette release that broke file previews.
`server.Dockerfile` installs the release's own wheels with `constraints.txt`
instead, so the server runs the same bytes and the same dependency versions
the hosts get, and no build tools or Node are needed in the image. It keeps
upstream's runtime contract (entrypoint copied from the build's
`deploy/docker/entrypoint.py`, port 8000, `/data/artifacts`, the `/health`
check), so upstream's `docker-compose.yaml` runs it with
`OMNIGENT_IMAGE=ghcr.io/desidero/omnigent-server` and
`OMNIGENT_IMAGE_TAG=custom-<date>.<n>`. When upstream changes its runtime
stage (new system packages, environment), mirror it here.

## Setting up publishing

The `publish` job pushes to the fork with a token, because the workflow token
of this repository cannot write to another repository.

1. Create a **fine-grained personal access token** (Settings → Developer
   settings → Fine-grained tokens): resource owner `Desidero`, repository
   access **only `Desidero/omnigent`**, permissions **Contents: Read and
   write** and **Workflows: Read and write** (a refreshed base brings upstream
   commits that change `.github/workflows/`, and GitHub refuses those pushes
   without it). Metadata: Read is added automatically. Pick an expiry and a
   reminder to rotate it.
2. Add it to this repository as the Actions secret **`FORK_RELEASE_TOKEN`**:
   `gh secret set FORK_RELEASE_TOKEN -R Desidero/omnigent-patches`.
3. **Ruleset on the fork's `custom`**: it allows updates only through its
   bypass list, which has the Repository admin role. The token acts as its
   owner, so a push with it is a push by the admin and is let through, as an
   admin's own forced push is today. If the first real publish is rejected
   anyway, add a GitHub App with Contents and Workflows write to the bypass
   list and use its installation token instead.
4. **GHCR**: the image is pushed with this workflow's own token
   (`packages: write`); the first push creates
   `ghcr.io/desidero/omnigent-server`, linked to this repository. Packages
   start out private: make it public in its package settings, or log the
   server in with a token that has `read:packages`. A fine-grained token
   cannot write to GHCR; if the workflow token is refused (for example
   because the package already exists and isn't linked here), grant this
   repository write access in the package's settings, or add a classic token
   with `write:packages` as the secret `GHCR_TOKEN`.
5. Optional: protect the tags with a tag ruleset on the fork for
   `custom/**` that restricts updates and deletions, and turn on release
   immutability in the fork's settings. `publish.sh` never moves a tag and
   never edits a published release.

Test it with a manual run first: `gh workflow run check.yml -R
Desidero/omnigent-patches --ref main` is a dry run (the default) that prints
everything it would push.

## Releases

A merge to `main` publishes a **pre-release**. When a release has run
somewhere safe and goes to production, mark it as the full release:

```bash
gh release edit custom/2026-10-27.1 -R Desidero/omnigent --prerelease=false --latest
```

Releases and tags stay; drop old pre-releases by hand if they pile up
(`gh release delete <tag> -R Desidero/omnigent`, keeping the tag).

## Installing a release on a host

The host scripts run with bash 3.2 and BSD tools (macOS) as well as Linux
(systemd user unit `omnigent-host.service`). Each host needs a host config
folder `<hosts-dir>/<host>/` (may be empty) from your own deployment config:

- `systemd/*.conf` (Linux): drop-ins installed into
  `~/.config/systemd/user/omnigent-host.service.d/`. The script owns that
  directory; any other `.conf` there is moved to
  `~/omnigent-deploy/backups/<time>/`.
- `host.env` (optional, non-secret): `KEY=VALUE` lines for the service
  environment; `~` and `$HOME` expand; `RELEASE_EXTRA_PATH=dir:dir` adds PATH
  entries (`PATH` itself is generated).
- A `TODO(user)` marker in either makes `upgrade-host.sh` refuse that host.

Secrets go in `~/.omnigent/secrets/host.env` on the host (mode 600, plain
`KEY=VALUE`), never in the config: systemd reads it with `EnvironmentFile=`,
and on macOS it is merged into the launchd plist.

```bash
# First time, or to bootstrap the scripts on a host:
gh release download custom/2026-10-27.1 -R Desidero/omnigent -D /tmp/rel   # or curl the assets
bash /tmp/rel/check-host.sh --host <name> --release /tmp/rel
bash /tmp/rel/upgrade-host.sh --host <name> --hosts-dir <hosts-dir> /tmp/rel

# Later releases, straight from GitHub (gh if logged in, else HTTPS):
bash ~/omnigent-deploy/current/upgrade-host.sh --host <name> --release custom/2026-11-02.1

# Check, roll back:
bash ~/omnigent-deploy/current/check-host.sh --host <name>
bash ~/omnigent-deploy/current/upgrade-host.sh --host <name> --rollback
```

`--dry-run` prints every action first; `--no-restart` installs and
configures but leaves the running service alone. `upgrade-host.sh` is
idempotent. It:

1. verifies the release's sha256s against `manifest.json`, checks the host
   config for `TODO(user)`, and requires `rg` on the service PATH;
2. copies the release to `~/omnigent-deploy/<date>.<n>/` (the tag's last
   part) with the host configs it used, so later runs and `--rollback` find
   them, and installs the wheels with `install-host.sh` unless the installed
   tool already reports the release's commit (`--reinstall` forces it);
3. points `~/omnigent-deploy/current` at it and `previous` at the release it
   replaces;
4. applies the service environment (drop-ins plus a generated
   `90-omnigent-release.conf` on Linux; the plist's `EnvironmentVariables` on
   macOS), backing up what it replaces;
5. restarts detached from the host's own process tree (`systemd-run --user`
   on Linux, `bootout` + `bootstrap` in a new session on macOS), waits for
   `Connected as` in the host log, and checks the commit the service binary
   reports. Results go to `~/omnigent-deploy/rollout.log`, details to
   `upgrade.log`.

Every host also gets `OMNIGENT_NO_UPDATE_CHECK=1` (upstream's update notice
would offer stock PyPI wheels), a PATH resolved from a clean login shell, and
shell leftovers (`SSH_AUTH_SOCK`, `TERM*`, terminal-app variables) removed.
After `omnigent host enable`, which rewrites the service definition from the
current shell, rerun `upgrade-host.sh` with the current release.

## Installing the server

With upstream's Docker Compose setup (`deploy/docker/` from the release's
tag): back up the database, set `OMNIGENT_IMAGE=ghcr.io/desidero/omnigent-server`
and `OMNIGENT_IMAGE_TAG=custom-<date>.<n>` in `.env`, `docker compose pull
omnigent && docker compose up -d omnigent`, and check `/health` and that
`/v1/info` reports the release's `server_version`. Roll back by restoring the
previous tag in `.env` (and the database dump if the newer version migrated
it).

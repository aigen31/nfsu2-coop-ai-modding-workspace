# AGENTS.md

Workspace for building AI-assisted mods for **Need for Speed: Underground 2** (PC v1.2).
One script provisions every tool inside this folder; the mod itself is `nfsu2-coop/`.

## Layout

| Path | What it is |
|---|---|
| `setup.ps1` | provisions toolchain, references, builds and tests (idempotent) |
| `toolchain/` | MinGW i686, x64dbg, Ghidra, cached archives — installed, not committed |
| `references/` | study clones of nfsu2-web, nfsu2-recompiled, Unlimiter, FRSFastTest, nfsu2-re |
| `nfsu2-coop/` | the co-op mod: source, tests, docs (its own git history) |
| `coop-anything/` | the shared co-op modding playbook (its own git history) |
| `game/`, `game test player/` | two test installs (host/profile Player, guest/profile Test) |
| `local/` | screenshots, logs, scratch — never committed |

## Commands

```powershell
.\setup.ps1                      # tools, references, build, tests
.\setup.ps1 -Force               # re-download every pinned tool
.\setup.ps1 -InstallMods         # copy the ASI + FRSFastTest into both game folders
nfsu2-coop\build.ps1             # build only (server, bots, tests, plugin)
nfsu2-coop\tests\run_all.ps1     # core + sync + net + probe + two-process suite
nfsu2-coop\build.ps1 -Targets plugin
```

Finish a change only when `tests\run_all.ps1` prints `ALL OK`; a build alone is not a test.

## Pinned build

`speed2.exe`: 4,800,512 bytes, SHA-256 `bc34932b36bb19194000690ec26edf964176856c31fb0978e01e61ee814eee9d`.
Every offset in this workspace was measured on it. The mod refuses other builds; do not
generalise offsets without re-deriving them.

## Hard facts that cost hours

- **GCC cannot run from a path with spaces.** MinGW lives at `toolchain\mingw32` and is
  reached through the junction `C:\nfsu2-toolchain`; `build.ps1` uses that junction. Keep
  the junction when moving things.
- **A new `.asi` needs a game restart.** The file is locked while the game runs; copying
  over it silently fails.
- **Two instances, two profiles:** first launch is profile `Player` (press Enter), second
  is `Test` (Down, then Enter on the profile screen). Saves live in
  `%LOCALAPPDATA%\NFS Underground 2\{Player,Test}`.
- **FRSFastTest** boots straight into free roam; with `AutoContinue=0` the profile list
  waits for the keys above.
- **In-game bridge** (`[Debug] BridgePort` in `scripts\nfsu2coop.ini`, 27971 host /
  27972 guest) is how state is inspected and mutated without menus. `ping` answers while
  the game is paused: `mainLoopAgeMs` tells paused from dead. Requests run on the game
  thread.
- **Never commit game files, assets or saves.** `references/` are third-party study
  copies: read them, do not redistribute.

## Where the knowledge is

- Mod internals, offsets, protocol, sync rules: `nfsu2-coop/docs/` — start with
  `ARCHITECTURE.ru.md`, `GAME-BINDINGS.ru.md`, `PROTOCOL.ru.md`, `CAR-RENDER-API.ru.md`.
- Reference projects and what each answers: `references/README.md`.
- Co-op modding playbook (QA, networking, RE method): `coop-anything/AGENTS.md` and
  `coop-anything/playbook/`.

## Current state

Remote players' cars render with their owner's model, pose, heading and speed (model
streamed through the CarLoader when the district lacks it). Collisions and wheel spin are
not ported yet. See `nfsu2-coop/docs/KNOWN-ISSUES.ru.md` before planning work.

# NFSU2 AI-modding workspace

Everything needed to reverse engineer, build and test mods for **Need for Speed:
Underground 2** (PC v1.2) with an AI agent — in one folder, provisioned by one script.

```powershell
.\setup.ps1 -InstallMods
```

That downloads and verifies the pinned toolchain, clones the mod (`aigen31/nfsu2-coop`),
the playbook fork (`aigen31/coop-anything`, branch `game/nfs-underground-2`) and the reference projects, builds the co-op mod, runs the full test suite and copies the
plugins into both test installs.

## What is inside

| | |
|---|---|
| **Co-op mod** | `nfsu2-coop/` — [aigen31/nfsu2-coop](https://github.com/aigen31/nfsu2-coop) (branch `master`), cloned by `setup.ps1`, updated with `-UpdateMod`. Host-authoritative session, race director, career ledger, mirrored traffic, remote players' cars with their own model and pose, D3D9 overlay, in-game RPC bridge. Docs in `nfsu2-coop/docs/`. |
| **Playbook** | `coop-anything/` — fork [aigen31/coop-anything](https://github.com/aigen31/coop-anything/tree/game/nfs-underground-2), branch `game/nfs-underground-2`. Cloned by `setup.ps1`, updated with `-UpdatePlaybook`. |
| **Toolchain** | `toolchain/` — i686 MinGW-w64, x64dbg (GUI + headless), Ghidra 12.2, cached archives. Installed by `setup.ps1`, never committed. |
| **References** | `references/` — clones of [th0mk/nfsu2-web](https://github.com/th0mk/nfsu2-web) (browser port with working multiplayer), [codepdbh/nfsu2-recompiled](https://github.com/codepdbh/nfsu2-recompiled) (the game as C), [nlgxzef/NFSU2Unlimiter](https://github.com/nlgxzef/NFSU2Unlimiter) + fork (structures and addresses), [chrystianfarias/FRSFastTest](https://github.com/chrystianfarias/FRSFastTest) (boot straight into free roam), [yugecin/nfsu2-re](https://github.com/yugecin/nfsu2-re). |
| **Two installs** | `game-host/` (host, profile Player) and `game-client/` (guest, profile Test). |
| **Scratch** | `local/` — screenshots, logs, dumps. Not committed. |

## Everyday commands

```powershell
.\setup.ps1                       # provision, build, test
.\setup.ps1 -InstallMods          # also copy ASI + FRSFastTest into the game folders
.\scripts\launch-pair.ps1         # start both instances (Player, then Test)
nfsu2-coop\tests\run_all.ps1      # the suite must end with ALL OK
```

## Status

Working: career/free-roam co-op session, race director with finish places, shared career
ledger, mirrored traffic and bots, HUD, remote players rendered with their owner's car
model, pose, heading and speed, in-game bridge for tests.

Open: collisions between players' cars, wheel spin, paint/tuning sync. Details in
`nfsu2-coop/docs/KNOWN-ISSUES.ru.md`.

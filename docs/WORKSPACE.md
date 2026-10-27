# Workspace reference

The layout `setup.ps1` produces, why each piece is where it is, and the routines that keep
iteration cheap.

## Directory map

```
<workspace>
  setup.ps1                    one-shot provisioning (idempotent, SHA-256 pinned)
  README.md  AGENTS.md         human intro / agent instructions
  docs/                        this file and topic notes
  scripts/                     small helpers (launch a pair, install mods)
  toolchain/
    mingw32/                   i686 MinGW-w64 (real files)
    tools/x64dbg/              x32dbg.exe, headless.exe
    tools/ghidra_12.2_PUBLIC/  analyzeHeadless.bat
    cache/                     pinned archives for offline reinstall
  references/                  study clones (see references/README.md)
  nfsu2-coop/                  the mod repository
  coop-anything/               the playbook repository
  game-host/                   host install (profile Player)
  game-client/                 guest install (profile Test)
  local/                       screenshots, logs, dumps (git-ignored)
```

MinGW is the one tool that cannot physically live here: GCC resolves its own real path and
breaks on spaces, and this workspace path has one. Its files stay at `C:\nfsu2-toolchain`
and the workspace reaches them through the junctions `toolchain\mingw32` and
`nfsu2-coop\toolchain\mingw32`. Everything else (x64dbg, Ghidra, archives) is a real
directory under `toolchain\`. `nfsu2-coop\toolchain\tools` is a junction to `toolchain\tools`
so the older project scripts keep working.

## Tools and what they are for

| Tool | Path | Use |
|---|---|---|
| MinGW-w64 i686 | `C:\nfsu2-toolchain\bin\g++.exe` (junction `toolchain\mingw32`) | builds the ASI, the host, the bots, the tests |
| x64dbg | `toolchain\tools\x64dbg\release\x32\x32dbg.exe` | interactive debugging; `headless.exe` for scripted sessions |
| Ghidra | `toolchain\tools\ghidra_12.2_PUBLIC\support\analyzeHeadless.bat` | decompile the game |
| Decompile-all script | `nfsu2-coop\tools\ghidra_scripts\DecompileAll.java` | one `.c` + `index.tsv` into `build\decomp` |
| Search | `nfsu2-coop\tools\search_decomp.py` | grep the decompiled output by pattern |
| Probe/recon | `nfsu2-coop\build\recon.exe` | read process memory, dump floats, scan |
| Bridge client | `coop-anything\tools\bridge\bridge_client.py` | talk to the in-game RPC server |
| FRSFastTest | `toolchain\tools\FRSFastTest.asi` | boot into free roam without menus |

## Routines

**Rebuild + test**

```powershell
nfsu2-coop\build.ps1
nfsu2-coop\tests\run_all.ps1      # must print ALL OK
```

**Install into the two games** (the game must be closed — the ASI is locked while running)

```powershell
.\setup.ps1 -InstallMods
```

**Launch a pair**

```powershell
.\scripts\launch-pair.ps1         # Player first, Test second, both focused in turn
```

**Decompile the game** (minutes, runs in the background)

```powershell
$env:DECOMP_OUT = "$PWD\nfsu2-coop\build\decomp"
& toolchain\tools\ghidra_12.2_PUBLIC\support\analyzeHeadless.bat `
    "$PWD\nfsu2-coop\build\ghidra-proj" nfsu2 `
    -import "$PWD\game-host\speed2.exe" `
    -scriptPath "$PWD\nfsu2-coop\tools\ghidra_scripts" `
    -postScript DecompileAll.java -analysisTimeoutPerFile 1200 -deleteProject
python nfsu2-coop\tools\search_decomp.py "0x554" "RideInfo"
```

**Inspect a running game**

```powershell
python coop-anything\tools\bridge\bridge_client.py --endpoint tcp://127.0.0.1:27971 ping
python coop-anything\tools\bridge\bridge_client.py --endpoint tcp://127.0.0.1:27971 state
python coop-anything\tools\bridge\bridge_client.py --endpoint tcp://127.0.0.1:27971 call car.slots
```

The guest bridge is on 27972. `[Debug] BridgePort` in `scripts\nfsu2coop.ini` turns it on.

## Where the reverse-engineered knowledge lives

- `nfsu2-coop/docs/GAME-BINDINGS.ru.md` — car array, transforms, model fields, call sites.
- `nfsu2-coop/docs/CAR-RENDER-API.ru.md` — `CarRenderInfo`, `RideInfo`, `CarLoader`, the
  model-streaming recipe taken from nfsu2-web.
- `nfsu2-coop/docs/PROTOCOL.ru.md`, `SYNC-RULES.ru.md`, `ARCHITECTURE.ru.md` — the session.
- `references/README.md` — which reference project answers which question.
- `coop-anything/playbook/` — the method: in-game bridge, automated QA, networking, RE.

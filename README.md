# Passport

Run Windows Steam games on a Mac through Steam itself, in a Linux engine, so games that protect themselves with
Easy Anti-Cheat's Linux support start.

Passport is a Steam compatibility tool. Steam launches the game as it does with Proton; Passport runs it in
[Voile](https://github.com/Zagrios/voile)'s Linux engine, a Linux Wine on top of an x86-64 Linux kernel layer for
macOS ([voile-lkd](https://github.com/Zagrios/voile-lkd)). Easy Anti-Cheat sees Linux and loads its Linux module.
Valve's Linux steamclient inside the engine talks to the Steam running on your Mac, so Steam sees the game running.

Steam for macOS has no compatibility tools of its own, so Passport also carries a small hook, forked from
[NotProton](https://github.com/NotProtonNot/NotProton), that Steam loads to turn Steam Play on. You don't need
NotProton, and the two can't be installed at once.

Passport is early. It was tried on three games:

| Game | Steam | Easy Anti-Cheat | Game |
| --- | --- | --- | --- |
| VRChat | connects | loads | works, 60 fps, started from Steam's Play button |
| Blindfire | connects | loads | no frames (Voile's graphics layer errors) |
| My Hero Ultra Rumble | connects | no Linux module for this game | not started |

Not tried: joining an anti-cheat protected session, gamepads, and whether Steam Cloud saves sync (Steam only maps
them for tools with "proton" in the name). Voile's Wine is built for 64-bit programs only, so
a 32-bit launcher can't start. When the game's launcher is 32-bit and Easy Anti-Cheat's 64-bit
`start_protected_game.exe` sits beside it (VRChat's `launch.exe`), Passport starts that instead. A 32-bit anti-cheat
bootstrapper (TABG's) still can't start.

## Install

You need a Mac with Apple silicon and Steam for macOS in `/Applications` (set `STEAM_APP` if it is elsewhere). Quit
Steam first. From a checkout, the hook is built on your Mac, which also needs the Xcode command line tools and `cmake`.
The app carries a built hook and needs neither.

```sh
./install.sh
```

It downloads Voile from this repo's releases (430 MB, 2.4 GB unpacked) and the Linux steamclient for your Steam into
`~/Library/Application Support/Passport`, builds the hook, installs the tool into Steam's `compatibilitytools.d`,
and makes Steam load the hook by adding it to Steam.app's `Info.plist` and signing Steam.app again. macOS then asks
for Steam's input permissions again. If Steam already loads another hook (NotProton's), the installer stops.

Start Steam, then pick "Passport (Linux engine)" in the game's Properties, Compatibility. Run `install.sh` again
after Steam updates itself. `uninstall.sh` puts Steam.app's `Info.plist` back and removes the tool.

The first launch of a game builds its prefix, about a minute. The prefix lives in the game's Steam `compatdata`
folder, and `passport-run.log` beside it holds the last launch's log. The hook logs to `passport.log` in
`~/Library/Application Support/Passport`.

## The app

`gui/build.sh` builds `Passport.app`, a small window that shows what is set up (Steam, the engine, the Steam link,
the hook) and runs the same `install.sh` and `uninstall.sh`, with their log underneath. It carries the scripts and a built hook
inside, so it works without a checkout or build tools.

Releases carry a built `Passport.zip`. The app isn't notarized, so macOS blocks it the first time: right-click it and
choose Open, or run `xattr -cr Passport.app` once. Publishing a GitHub release builds the app and attaches it.

## The Steam version

The Linux steamclient has to be the same build as your Mac's Steam, or Steam answers with "Unknown IPC call" and the
game crashes. Every launch compares the two and fetches Valve's matching Linux client when Steam has updated.

The hook finds the Steam functions it patches by signature (`hook/signatures`, taken from NotProton's database). Most
Steam updates leave them alone. When one moves them, `passport.log` says how many signatures resolved and nothing is
patched until the database has an entry for that build.

## Anti-cheat

Passport doesn't bypass or alter any anti-cheat. Easy Anti-Cheat just sees Linux, and loads its Linux module if the
game's developer made one. A developer can still decide not to allow it, so a game may refuse to join protected
sessions or ban the account. Use it at your own risk, and not on games that don't support Linux.

## Layout

- `install.sh` and `uninstall.sh` set Passport up and take it out.
- `gui/` is the app that runs them.
- `hook/` is the dylib Steam loads. `hook/build.sh` builds it with [Dobby](https://github.com/jmpews/Dobby), which is bundled in `hook/vendor`.
- `tool/run` is what Steam starts: it makes the prefix, puts Valve's libraries in it and starts the game.
- `tool/steamclient.sh` keeps the Linux steamclient in step with the Mac's Steam.
- `tool/launch.sh` starts the window server, the render server and the game in Voile's engine (from Obelisk).

Passport is GPL-3.0 licensed, as the projects it builds on are. See `NOTICE`.

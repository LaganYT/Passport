# Passport

Passport runs Windows Steam games on a Mac, through Steam, inside a Linux engine. Easy Anti-Cheat sees Linux and
loads its Linux module, so games that ship it can start.

Steam launches the game the way it does with Proton. Passport hands it to [Voile](https://github.com/Zagrios/voile)'s
Linux Wine, and Valve's Linux steamclient inside the engine talks to the Steam on your Mac, so Steam shows the game as
running. Steam for macOS has no compatibility tools, so Passport also carries a small hook, forked from
[NotProton](https://github.com/NotProtonNot/NotProton), that turns Steam Play on. Don't install both.

## Status

Passport is early. I tried three games.

| Game | Steam | Easy Anti-Cheat | Game |
| --- | --- | --- | --- |
| VRChat | connects | loads | works at 60 fps, started from Steam's Play button |
| Blindfire | connects | loads | no frames, Voile's graphics layer errors |
| My Hero Ultra Rumble | connects | no Linux module for this game | not started |

I haven't tried joining a protected session, gamepads, or Steam Cloud saves. Voile's Wine only runs 64-bit programs,
so a 32-bit launcher can't start. If the 64-bit `start_protected_game.exe` sits beside it, as with VRChat's
`launch.exe`, Passport starts that instead. A 32-bit anti-cheat bootstrapper, like TABG's, still fails.

## Install

You need a Mac with Apple silicon and Steam for macOS in `/Applications`.

1. Download `Passport.zip` from the latest release and unzip it.
2. Right-click `Passport.app` and choose Open. The app isn't notarized, so macOS blocks a plain double-click.
3. Quit Steam and press Install.
4. Start Steam, open a game's Properties, then Compatibility, and pick "Passport (Linux engine)".

Install downloads Voile (430 MB, 2.4 GB unpacked) and Valve's Linux steamclient, adds the hook to Steam.app and signs it
again. macOS then asks for Steam's input permissions again. Uninstall puts Steam.app back.

A game's first launch builds its prefix, which takes about a minute. `passport-run.log` in the game's `compatdata`
folder has the last launch's log. The hook logs to `passport.log` in `~/Library/Application Support/Passport`.

To install from a checkout, run `./install.sh` and `./uninstall.sh`. They build the hook, so they need the Xcode command
line tools and `cmake`. `gui/build.sh` builds the app.

## When Steam updates

The Linux steamclient has to match your Mac's Steam build, or Steam answers "Unknown IPC call" and the game crashes.
Every launch compares the two and fetches the right client if they differ. Run Install again after a Steam update so the
hook is signed again.

The hook finds the Steam functions it patches by signature, from NotProton's database in `hook/signatures`. Most Steam
updates leave them alone. If one moves them, `passport.log` shows how many resolved and nothing is patched until the
database has that build.

## Anti-cheat

Passport doesn't bypass or alter any anti-cheat. Easy Anti-Cheat sees Linux and loads its Linux module if the game's
developer made one. The developer can still refuse it, so a game may block protected sessions or ban the account. Use
Passport at your own risk, and not on games that don't support Linux.

## License

GPL-3.0, like the projects it builds on. See `NOTICE` for what it includes.

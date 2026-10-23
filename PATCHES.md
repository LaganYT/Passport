# Patches laid over Voile

Passport 0.1.1 installs Voile `v26.3.0-16` (not the newest) and replaces three of its files with fixes Voile has not merged
yet. `install.sh` does both. This file says what they are and how to take them out again.

| File in the runtime | Fix | Open PR | Built from |
| --- | --- | --- | --- |
| `engine/wsd` | Microphone input for the Linux engine | [voile-lkd #3](https://github.com/Zagrios/voile-lkd/pull/3) | [LaganYT/voile-lkd `microphone-input`](https://github.com/LaganYT/voile-lkd/tree/microphone-input) |
| `wine/lib/wine/x86_64-unix/wineobeliskaudio.so` | Microphone input for Wine | [voile-wine #3](https://github.com/Zagrios/voile-wine/pull/3) | [LaganYT/voile-wine `microphone-input`](https://github.com/LaganYT/voile-wine/tree/microphone-input) |
| `graphics/libexec/virgl_render_server` | Fixes a crash when joining busy VRChat worlds | [neptune #2](https://github.com/Zagrios/neptune/pull/2) | [LaganYT/neptune `install-v16`](https://github.com/LaganYT/neptune/tree/install-v16), the same patch as the PR on the v16 base |

The three files are packed as `passport-patches.tar.xz` (with a `.sha256`) and attached to the Passport release that
`install.sh` points at. They were built and tried on v26.3.0-16, so that is the version `install.sh` pins. A file from
one Voile build is not known to work on another. The originals are kept beside them as `.orig`, and
`.passport-patches` in the runtime holds the checksum of what was applied.

## Taking them out

Do this once all three PRs are in a Voile release.

1. In `install.sh`, delete the block from `# Microphone input` through its closing `fi`.
2. Put the newest-release lookup back where `voile=v26.3.0-16` is:
   ```bash
   voile=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/Zagrios/Voile/releases/latest)
   voile=${voile##*/}
   ```
3. Restore the `pick up a newer Voile` line in the header comment of `install.sh`.
4. Delete this file and the `passport-patches.tar.xz` assets from the release.

A PR that is merged only in part: keep the block, and rebuild the archive without the files that landed.

## Moving to a newer Voile before then

Rebuild each fix on the new Voile's sources, pack the three files with
`tar -cJf passport-patches.tar.xz engine/wsd wine/lib/wine/x86_64-unix/wineobeliskaudio.so graphics/libexec/virgl_render_server`
from the runtime's `linux` folder, write its `shasum -a 256` to `passport-patches.tar.xz.sha256`, attach both to a new
release, then change `voile=` and `url=` in `install.sh`. Try a game first.

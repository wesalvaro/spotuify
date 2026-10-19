# spotuify

[spotifyd](https://spotifyd.rs) on macOS, done properly: a Spotify Connect device that also

* shows what's playing in the **Now Playing** widget (Control Center, menu bar, lock screen),
* answers the **media keys** and headset buttons — play on an idle Mac pulls playback over from
  the phone,
* keeps `~/.local/state/spotifyd/now_playing.json` current for shell prompts and other tools.

All of it runs *inside* spotifyd: this repo builds the
[`macos-media-controls` branch of a spotifyd fork](https://github.com/wesalvaro/spotifyd/tree/macos-media-controls),
which adds an opt-in `macos_media_controls` cargo feature (one new module, a few cfg-gated lines
elsewhere). Nothing else to run: no D-Bus, no helper daemon.

Binaries are in the `spotifyd` cachix cache; see `flake.nix` for the public key.

## Try it

```sh
just auth   # once: OAuth in the browser; or skip and pick the device from a Spotify client
just run    # foreground spotifyd, named after the machine (hostname -s)
just now    # the now-playing file
```

## Install (nix-darwin)

```nix
# flake.nix inputs — do not `follows` nixpkgs, or the cachix binaries won't match.
spotuify.url = "github:wesalvaro/spotuify";

# darwin configuration
imports = [ inputs.spotuify.darwinModules.default ];
services.spotuify.enable = true;
nix.settings = {
  substituters = [ "https://spotifyd.cachix.org" ];
  trusted-public-keys = [ "spotifyd.cachix.org-1:FUqQHTP26vow8BSLlWy22Mvr0/d9GFEPjHmpTuGVOFk=" ];
};
```

Options: `services.spotuify.{deviceName,cachePath,nowPlayingFile,extraSpotifydConfig,package}`.
Logs land in `/tmp/spotifyd.{out,err}.log`.

## The now-playing file

Rewritten atomically on every change:

```json
{
  "status": "playing",
  "track_id": "spotify:track:5A85dIAMLQ2sFOCs5PTrb7",
  "title": "Koffein",
  "artists": ["Ooooklart"],
  "album": "Koffein",
  "duration_ms": 172306,
  "position_ms": 20606,
  "cover_url": "https://i.scdn.co/image/…",
  "updated_at": 1792416958
}
```

`status` is `playing`, `paused` or `stopped`; when stopped only `status` and `updated_at` are
present. `position_ms` is as of `updated_at`.

## Developing the fork

```sh
git clone git@github.com:wesalvaro/spotifyd.git ../spotifyd   # branch macos-media-controls
nix develop                                                    # cargo, rustc, portaudio, ...
cd ../spotifyd && cargo build --no-default-features --features portaudio_backend,macos_media_controls
cd ../spotuify && just run-dev
```

After pushing to the fork: `just update`, rebuild, fix the cargo hash in `nix/spotifyd.nix` if it
changed, then `just push`.

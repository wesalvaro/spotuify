cache := "spotuify"
cache_path := env("HOME") / ".cache/spotifyd"
device_name := `hostname -s`

# Build the fork (portaudio + macos_media_controls).
build:
    nix build .#spotifyd -L

# Build and push spotifyd and the dev shell to cachix. Needs a one-time `cachix authtoken`.
push: build
    cachix push {{ cache }} ./result
    nix build .#devShells.aarch64-darwin.default -o result-devshell
    cachix push {{ cache }} ./result-devshell

# One-time OAuth login in the browser; writes credentials.json under the cache path.
auth:
    nix run .#spotifyd -- authenticate --cache-path {{ cache_path }}

# Foreground spotifyd for ad-hoc testing (Ctrl-C to stop).
run:
    nix run .#spotifyd -- --no-daemon -v --cache-path {{ cache_path }} \
      --backend portaudio --device-name {{ device_name }} --device-type computer

# Same, but the locally built fork from ~/git/spotifyd (cargo build output).
run-dev:
    ../spotifyd/target/debug/spotifyd --no-daemon -v --cache-path {{ cache_path }} \
      --backend portaudio --device-name {{ device_name }} --device-type computer

# Show the now-playing file.
now:
    jq . ~/.local/state/spotifyd/now_playing.json

# Point the flake at the fork's current branch head and refresh the cargo vendor hash.
update:
    nix flake update spotifyd-src
    @echo "Now rebuild; if the cargo hash changed, copy the 'got:' hash into nix/spotifyd.nix."

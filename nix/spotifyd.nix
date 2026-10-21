# spotifyd built from the fork with the `macos_media_controls` feature: inside the spotifyd
# process, playback is mirrored to the macOS Now Playing widget, media keys drive it, and a
# now-playing JSON file is kept up to date. MPRIS/D-Bus stays off (not useful on macOS).
{
  spotifyd,
  rustPlatform,
  lib,
  stdenv,
  src,
}:
(spotifyd.override { withMpris = false; }).overrideAttrs (old: {
  pname = "spotifyd-spotuify";
  inherit src;
  # Vendored crates for the fork's Cargo.lock; update the hash when it changes (`just update`).
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    name = "spotifyd-spotuify-${old.version}-vendor";
    hash = "sha256-EOvNTyiFsCins1VC7DFN4oXZhhLszWZeU1lAdhn3NW4=";
  };
  # buildRustPackage derives these from `buildFeatures` before overrideAttrs runs, so the
  # derived attributes are what the cargo hooks actually read.
  cargoBuildFeatures =
    old.cargoBuildFeatures ++ lib.optional stdenv.hostPlatform.isDarwin "macos_media_controls";
  cargoCheckFeatures =
    old.cargoCheckFeatures ++ lib.optional stdenv.hostPlatform.isDarwin "macos_media_controls";
  meta = old.meta // {
    description = "spotifyd with macOS Now Playing and media keys";
    homepage = "https://github.com/wesalvaro/spotuify";
  };
})

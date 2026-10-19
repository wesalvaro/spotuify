{
  description = "spotuify: spotifyd for macOS with Now Playing, media keys and a now-playing file";

  # Binary cache for the custom spotifyd build (pushed with `just push`). Nix asks once whether
  # to trust these; ~/git/nix sets the same in nix.settings so no prompt appears there.
  nixConfig = {
    extra-substituters = [ "https://spotuify.cachix.org" ];
    extra-trusted-public-keys = [
      "spotuify.cachix.org-1:szg7DN36MPYtFAmMS2oQup2AM+nQZKKWQZzgsN2HDu4="
    ];
  };

  inputs = {
    # Pinned on purpose: the cachix binaries are built against exactly this revision, so
    # consumers should not `follows` it.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-darwin";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The fork: upstream spotifyd plus the `macos_media_controls` feature.
    spotifyd-src = {
      url = "github:wesalvaro/spotifyd/macos-media-controls";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
      spotifyd-src,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem = f: lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      packages = eachSystem (pkgs: rec {
        spotifyd = pkgs.callPackage ./nix/spotifyd.nix { src = spotifyd-src; };
        default = spotifyd;
      });

      # `nix run .#spotifyd -- --no-daemon ...` for ad-hoc foreground use.
      apps = eachSystem (pkgs: {
        spotifyd = {
          type = "app";
          program = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.spotifyd;
        };
      });

      # Enough to `cargo build` the fork in ~/git/spotifyd and to push to cachix.
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            cargo
            rustc
            rust-analyzer
            clippy
            rustfmt
            pkg-config
            cmake
            portaudio
            rustPlatform.bindgenHook
            cachix
            just
            jq
          ];
        };
      });

      darwinModules.default = import ./nix/darwin-module.nix { inherit self; };

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}

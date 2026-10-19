# nix-darwin module: spotifyd (the spotuify fork) as a launchd user agent. It shows up as a
# Spotify Connect device, mirrors playback into the macOS Now Playing widget, answers media
# keys, and keeps ~/.local/state/spotifyd/now_playing.json current.
#
# One-time setup after `darwin-rebuild switch`: `spotifyd authenticate --cache-path <cachePath>`
# (OAuth in the browser), or just pick the device from a Spotify client (zeroconf discovery
# caches the credentials). Logs: /tmp/spotifyd.{out,err}.log.
{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.spotuify;
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  format = pkgs.formats.toml { };
  spotifydToml = format.generate "spotifyd.toml" {
    global = {
      backend = "portaudio";
      device_name = cfg.deviceName;
      device_type = "computer";
      cache_path = cfg.cachePath;
      bitrate = 320;
    }
    // cfg.extraSpotifydConfig;
  };
in
{
  options.services.spotuify = {
    enable = lib.mkEnableOption "spotifyd with macOS Now Playing and media keys";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.spotifyd;
      defaultText = lib.literalExpression "spotuify.packages.\${system}.spotifyd";
      description = "The spotifyd build to run.";
    };
    deviceName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Name shown in Spotify clients' device list; the machine's short hostname by default.";
    };
    cachePath = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.cache/spotifyd";
      defaultText = lib.literalExpression ''"''${home}/.cache/spotifyd"'';
      description = "Where spotifyd keeps credentials.json and the audio cache.";
    };
    nowPlayingFile = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.local/state/spotifyd/now_playing.json";
      defaultText = lib.literalExpression ''"''${home}/.local/state/spotifyd/now_playing.json"'';
      description = "JSON file rewritten on every playback change.";
    };
    extraSpotifydConfig = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        initial_volume = 60;
        device = "External Headphones";
      };
      description = "Extra keys merged into the [global] section of spotifyd.toml.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.spotifyd = {
      command = "${lib.getExe cfg.package} --no-daemon --config-path ${spotifydToml}";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        # Needs the user's WindowServer session for the Now Playing widget and media keys.
        ProcessType = "Interactive";
        EnvironmentVariables = {
          SPOTIFYD_MEDIA_CONTROLS = "1";
          SPOTIFYD_NOW_PLAYING_FILE = cfg.nowPlayingFile;
        };
        StandardOutPath = "/tmp/spotifyd.out.log";
        StandardErrorPath = "/tmp/spotifyd.err.log";
      };
    };
  };
}

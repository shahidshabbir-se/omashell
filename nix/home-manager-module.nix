{ config, lib, pkgs, ... }:
let
  cfg = config.programs.omashell;
in
{
  options.programs.omashell = {
    enable = lib.mkEnableOption "Omashell desktop shell";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "Omashell package to install and run.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Settings written to $XDG_CONFIG_HOME/omashell/shell.json.";
      example = {
        bar = {
          left = [ "logo" "workspaces" ];
          center = [ "clock" "worldclock" "weather" ];
          right = [ "notifications" "network" "audio" "power" ];
        };
      };
    };

    wallpaper.omarchy = {
      enable = lib.mkEnableOption "Omarchy backgrounds in the Omashell wallpaper carousel";

      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression "inputs.omarchy-wallpapers.outPath";
        description = "Pinned Omarchy source containing the themes directory. No Omarchy code is run.";
      };

      themes = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.strMatching "[a-zA-Z0-9][a-zA-Z0-9_-]*"));
        default = null;
        example = [ "catppuccin" "tokyo-night" ];
        description = "Themes to include the backgrounds from, or null for all upstream themes.";
      };
    };

    systemd = {
      enable = lib.mkEnableOption "the Omashell user service";

      target = lib.mkOption {
        type = lib.types.str;
        default = config.wayland.systemd.target;
        defaultText = lib.literalExpression "config.wayland.systemd.target";
        example = "hyprland-session.target";
        description = "Wayland session target that starts Omashell.";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "QT_QPA_PLATFORMTHEME=qt5ct" ];
        description = "Additional environment variables for the user service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.omashell.settings = lib.mkIf cfg.wallpaper.omarchy.enable {
      wallpaper.omarchy = {
        source = if cfg.wallpaper.omarchy.source == null then "" else "${cfg.wallpaper.omarchy.source}";
        inherit (cfg.wallpaper.omarchy) themes;
      };
    };

    assertions = [
      {
        assertion = !cfg.wallpaper.omarchy.enable || cfg.wallpaper.omarchy.source != null;
        message = "Set programs.omashell.wallpaper.omarchy.source to a pinned Omarchy source when enabling its backgrounds.";
      }
      {
        assertion = !cfg.systemd.enable || cfg.systemd.target != "";
        message = "programs.omashell.systemd.target must not be empty when the service is enabled.";
      }
    ];

    home.packages = [ cfg.package ];

    xdg.configFile."omashell/shell.json" = lib.mkIf (cfg.settings != { }) {
      text = builtins.toJSON cfg.settings;
    };

    systemd.user.services.omashell = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Omashell Quickshell desktop shell";
        After = [ cfg.systemd.target ];
        PartOf = [ cfg.systemd.target ];
      };

      Service = {
        Type = "exec";
        ExecStart = "${cfg.package}/bin/omashell";
        Restart = "on-failure";
        RestartSec = "3s";
        Environment = [
          "QT_QPA_PLATFORM=wayland"
          "OMASHELL_ROOT=${cfg.package}/share/omashell"
        ] ++ cfg.systemd.extraEnvironment;
        Slice = "session.slice";
      };

      Install.WantedBy = [ cfg.systemd.target ];
    };
  };
}

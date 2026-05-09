{ self, config, lib, inputs, ... }:

{
  flake.aspects.steam.nixos = { pkgs, ... }: {
    programs.steam.enable = true;
    programs.steam.extest.enable = true;
    programs.steam.extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];

    # hidapi is required by Steam's controller firmware updater. Without it
    # Steam logs `ImportError: Unable to load ... libhidapi-hidraw.so` and
    # shows "Failed to update Steam Controller firmware" for the
    # Steam Controller 2026.
    programs.steam.extraPackages = with pkgs; [ hidapi ];

    # Installs Valve's udev rules (60-steam-input.rules etc.) so the
    # Steam Controller's hidraw nodes are accessible without root.
    hardware.steam-hardware.enable = true;

    # Gamescope compositor - fixes controller input on Wayland by providing
    # proper XWayland with XTest extension support
    # Run with: gamescope -- steam
    programs.gamescope = {
      enable = true;
      args = [
        "-W 2560"
        "-H 1440"
        "--hide-cursor-delay -1"
      ];
    };

    # work around for issue with capSysNice not working in gamescope.  even though it still
    # complains that it doesn't have cap nice ability to set it its own nice value.  ananicy
    # is setting it -20 (highest priority).  this could probably go into its own config since
    # ananicy-rules-cachyos has quality of life rules for a lot more then just gamescope.
    # and games.
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-cpp;
      extraRules = [
        {
          "name" = "gamescope";
          "nice" = -20;
        }
      ];
    };

    systemd.services.kill-steam-on-shutdown = {
      description = "Kill steam on shutdown to prevent shutdown delay";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = ''
          ${pkgs.procps}/bin/pkill -x steam
        '';
      };

      wantedBy = [ "shutdown.target" ];
    };
  };

  flake.aspects.steam.homeManager = { pkgs, ... }: {
    home.packages = [
      pkgs.protontricks
    ];

    xdg.desktopEntries.steam-gamescope = {
      name = "Steam (Gamescope)";
      comment = "Steam with controller support via Gamescope";
      exec = "gamescope -W 2560 -H 1440 --hide-cursor-delay -1 --fullscreen --force-grab-cursor --expose-wayland -- steam";
      icon = "steam";
      terminal = false;
      type = "Application";
      categories = [ "Game" ];
    };
  };
}

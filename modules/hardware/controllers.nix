{ config, lib, pkgs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareControllers = {
      description = "Support for controllers";

      nixos = { pkgs, ... }: {
        services.joycond.enable = true;
        services.udev.packages = [
          pkgs.game-devices-udev-rules
        ];

        hardware.uinput.enable = true;
        hardware.xone.enable = true;
        # hardware.xpadneo.enable = true; # Overrides deadzones
        
        boot.kernelModules = [
          "xone-wired"
          # "xone-dongle"
          "xone-gip"
          # "xone-gip-gamepad"
          # "xone-gip-headset"
          # "xone-gip-chatpad"
          # "xone-gip-guitar"
        ];
      };

      homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
          evtest
          # jstest-gtk
          linuxConsoleTools # for evdev-joystick
        ];
      };
    };
  };
}

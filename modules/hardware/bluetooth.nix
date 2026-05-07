{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareBluetooth = {
      description = "Bluetooth with blueman";

      nixos = { pkgs, ... }: {
        hardware.bluetooth.enable = true;
        hardware.bluetooth.settings = {
          General.ControllerMode = "dual";
          Controller = { };
          GATT = { };
        };

        # Disable ertm so Nintendo Switch Pro controllers work
        boot.extraModprobeConfig = ''
          options bluetooth disable_ertm=Y
        '';

        services.blueman.enable = true;
      };
    };
  };
}

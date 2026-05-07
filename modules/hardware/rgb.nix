{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareRgb = {
      description = "RGB lighting control (OpenRGB)";

      nixos = { pkgs, ... }: {
        services.hardware.openrgb.enable = true;
      };
    };
  };
}

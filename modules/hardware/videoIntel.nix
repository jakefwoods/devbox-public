{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareVideoIntel = {
      description = "Intel GPU";

      nixos = { pkgs, ... }: {
        services.xserver.videoDrivers = ["intel"];
        services.xserver.deviceSection = ''
          Option "DRI" "3"
          Option "TearFree" "true"
        '';

        hardware.opengl.enable = true;
        hardware.opengl.driSupport = true;
        hardware.opengl.driSupport32Bit = true;
        hardware.opengl.extraPackages = [
          pkgs.vaapiIntel
        ];

        local.userDefaults.extraGroups = [ "video" ];
      };
    };
  };
}

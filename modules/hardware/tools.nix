{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareTools = {
      description = "Hardware monitoring and debugging tools";

      nixos = { pkgs, ... }: {
        environment.systemPackages = [
          pkgs.lm_sensors
        ];

        programs.usbtop.enable = true;
      };

      homeManager = { pkgs, ... }: {
        home.packages = [
          pkgs.btop
          pkgs.inxi
          pkgs.phoronix-test-suite
          pkgs.pciutils
          pkgs.usbutils
        ];
      };
    };
  };
}

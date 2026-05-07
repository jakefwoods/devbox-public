{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareCooling = {
      description = "Thermal management (thermald)";

      nixos = { pkgs, ... }: {
        services.thermald.enable = true;
      };
    };
  };
}

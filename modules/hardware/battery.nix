{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareBattery = {
      description = "Battery management with TLP";

      nixos = { pkgs, ... }: {
        services.upower.enable = true;
        services.tuned.enable = true;

        services.tlp = {
          enable = true;
          settings = {
            CPU_SCALING_GOVERNOR_ON_AC = "powersave";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
            CPU_HWP_ON_AC = "balance_performance";
            CPU_HWP_ON_BAT = "balance_power";
            SCHED_POWERSAVE_ON_AC = 1;
            SCHED_POWERSAVE_ON_BAT = 1;
            ENERGY_PERF_POLICY_ON_AC = "balance-performance";
            ENERGY_PERF_POLICY_ON_BAT = "balance-power";
          };
        };
      };
    };
  };
}

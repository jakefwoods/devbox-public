{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareVideoNvidia = {
      description = "NVIDIA GPU";

      nixos = { pkgs, ... }: {
        hardware.opengl.enable = true;
        hardware.opengl.driSupport32Bit = true;
        hardware.nvidia.modesetting.enable = true;

        services.xserver.videoDrivers = ["nvidia"];

        local.userDefaults.extraGroups = [ "video" ];

        # RegistryDwords controls the performance of the GPU. We can use it to force certain performance levels and behaviors:
        #
        # - Quiet but stuck on Level 1:
        #   Option "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x3333; PowerMizerDefault=0x2; PowerMizerDefaultAC=0x2"
        #
        # - Fast but stuck on max power:
        #   Option "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerDefault=0x1; PowerMizerDefaultAC=0x1"
        #
        # - Scalable:
        #   Option "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x3333"
        #
        # - Stuck on 3/4 power:
        #   Option "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x3333; OverrideMaxPerf=0x4"
        services.xserver.deviceSection = ''
          Option "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x3333"
          # Option "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x3333; OverrideMaxPerf=0x4"
          Option "Coolbits" "31"
          Option "UseNvKmsCompositionPipeline" "Off"
          Option "TripleBuffer" "On"
        '';

        environment.variables."__GL_ExperimentalPerfStrategy" = "1";
      };
    };
  };
}

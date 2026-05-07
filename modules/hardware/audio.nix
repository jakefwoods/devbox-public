{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareAudio = {
      description = "Audio - PipeWire with PulseAudio compatibility";

      nixos = { pkgs, ... }: {
        services.pulseaudio.enable = false;

        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };

      homeManager = { pkgs, ... }: {
        home.packages = [
          pkgs.alsa-utils
          pkgs.pulseaudio # for pactl
          pkgs.pavucontrol
          pkgs.easyeffects
        ];
      };
    };
  };
}

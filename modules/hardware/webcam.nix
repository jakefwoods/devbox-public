{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareWebcam = {
      description = "Webcam utilities";

      nixos = { pkgs, ... }: {
        environment.systemPackages = [
          pkgs.v4l-utils
          pkgs.guvcview
        ];
      };
    };
  };
}

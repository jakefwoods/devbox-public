{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareStorage = {
      description = "Storage - NTFS, exFAT, MTP support";

      nixos = { pkgs, ... }: {
        services.udisks2.enable = true;

        environment.systemPackages = with pkgs; [
          ntfs3g
          exfat
          mtpfs
          jmtpfs
          mergerfs
        ];
      };
    };
  };
}

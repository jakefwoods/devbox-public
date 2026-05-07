{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    hardwareNetwork = {
      description = "Network - NetworkManager with WiFi stability tweaks";

      nixos = { pkgs, ... }: {
        networking.networkmanager.enable = true;
        networking.networkmanager.wifi.powersave = false;

        # WIFI Stability
        boot.extraModprobeConfig = ''
          # Disable power saving on Wi-Fi module to reduce radio state changes
          options iwlwifi power_save=0

          # Disable Unscheduled Automatic Power Save Delivery (U-APSD)
          options iwlwifi uapsd_disable=1

          # Disable D0i3 power state to avoid problematic power transitions
          options iwlwifi d0i3_disable=1

          # Set power scheme for performance (iwlmvm)
          options iwlmvm power_scheme=1
        '';

        # networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

        services.expressvpn.enable = true;

        environment.systemPackages = with pkgs; [
          networkmanagerapplet

          # VPN support
          openconnect
          openssl
          networkmanager-openconnect
          expressvpn
        ];

        programs.wireshark.enable = true;
        programs.wireshark.package = pkgs.wireshark;

        local.userDefaults.extraGroups = [ "networkmanager" ];
      };
    };
  };
}

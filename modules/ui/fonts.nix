{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    fonts = {
      description = "System fonts configuration";

      nixos = { pkgs, lib, ... }: {
        fonts = {
          fontconfig = {
            subpixel.rgba = "rgb";
            enable = true;
            antialias = true;
            hinting.enable = true;
          };

          fontDir.enable = true;
          enableGhostscriptFonts = true;
          packages = with pkgs; [
            et-book
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
            fira
            fira-code
            fira-mono
            liberation_ttf

            hack-font
            terminus_font
            anonymousPro
            freefont_ttf
            corefonts
            dejavu_fonts
            source-code-pro
            source-sans-pro
            source-serif-pro
            ubuntu-classic
            ttf_bitstream_vera
            emacs-all-the-icons-fonts
          ] ++ (builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts));
        };
      };
    };
  };
}

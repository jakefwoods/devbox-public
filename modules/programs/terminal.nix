{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    terminal = {
      description = "Terminal utilities and shell configuration";

      homeManager = { pkgs, lib, ... }:
      let
        shellAliases = {
          top = "bottom";
          nixpkgs-build = "nix-build -E \"with import <nixpkgs> {}; callPackage ./. {}\"";
        };
      in
      {
        # Direnv for automatic environment loading
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        # Bash shell
        programs.bash = {
          enable = true;
          shellAliases = shellAliases;
        };

        # Zsh aliases (if zsh is enabled elsewhere)
        programs.zsh.shellAliases = shellAliases;

        # Starship prompt
        programs.starship = {
          enable = true;
          settings = {
            aws.disabled = true;
            directory = {
              truncation_length = 8;
              truncation_symbol = "…/";
            };
          };
        };

        # Readline (vi mode)
        programs.readline = {
          enable = true;
          extraConfig = ''
            # Use vi bindings for navigating the terminal
            set editing-mode vi

            # Change the bash cursor depending on the vi mode
            set show-mode-in-prompt on
            set vi-cmd-mode-string "\1\x1b[\x32 q\2"
            set vi-ins-mode-string "\1\x1b[\x36 q\2"
          '';
        };

        programs.ghostty = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
          enableBashIntegration = true;
          settings = {
            theme = "Abernathy";
            background-opacity = "0.95";
          };
        };

        # Terminal utilities
        home.packages = [
          pkgs.awscli
          pkgs.bottom
          pkgs.bat
          pkgs.binutils
          pkgs.dust
          pkgs.fd
          pkgs.file
          pkgs.fzf
          pkgs.pandoc
          pkgs.procs
          pkgs.lsof
          pkgs.tokei
          pkgs.unzip
        ] ++ lib.optionals pkgs.stdenv.isLinux [
          # s-tui is marked broken on Darwin in nixpkgs.
          pkgs.s-tui
        ];
      };
    };
  };
}

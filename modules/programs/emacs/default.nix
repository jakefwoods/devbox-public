{ inputs, ... }:

{
  flake-file.inputs.emacs-overlay.url = "github:nix-community/emacs-overlay";

  flake.aspects = { aspects, ... }: {
    emacs = {
      description = "Emacs with Doom configuration";

      nixos = { pkgs, ... }: {
        nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];
      };

      homeManager = { config, pkgs, ... }:
      let
        doomRepoUrl = "https://github.com/doomemacs/doomemacs";
      in
      {
        programs.emacs = {
          enable = true;
          extraPackages = epkgs: with epkgs; [
            vterm
            treesit-grammars.with-all-grammars
          ];
        };

        services.emacs = {
          enable = true;
          client.enable = true;
          startWithUserSession = "graphical";
        };

        home.packages = [
          pkgs.source-code-pro
          pkgs.et-book

          # for treemacs
          pkgs.python3

          # for doom module: nix
          pkgs.nixfmt

          # for doom module: sh
          pkgs.shellcheck

          # for org-roam
          pkgs.sqlite
          pkgs.graphviz

          # for org-download (i.e. +dragndrop)
          pkgs.xclip

          # for plantuml
          pkgs.plantuml

          # for text checking
          pkgs.proselint
        ];

        xdg.configFile."proselint/config".text = builtins.toJSON {
          checks = {
            # This causes a false positive with org-mode `TODO` blocks.
            "annotations.misc" = false;
          };
        };

        home.sessionPath = [ "${config.xdg.configHome}/emacs/bin" ];

        home.activation.installDoom = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -d "${config.xdg.configHome}/emacs" ]; then
            ${pkgs.git}/bin/git clone --depth=1 --single-branch "${doomRepoUrl}" "${config.xdg.configHome}/emacs"
          fi
        '';

        xdg.configFile."doom".source =
          config.lib.file.mkOutOfStoreSymlink
            "${config.home.homeDirectory}/devbox-public/modules/programs/emacs/doom.d";
      };
    };
  };
}

{ inputs, ... }:

{
  flake-file.inputs.emacs-overlay.url = "github:nix-community/emacs-overlay";

  flake.aspects = { aspects, ... }: {
    emacs = {
      description = "Emacs with Doom configuration";

      nixos = { pkgs, ... }: {
        nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];
      };

      homeManager = { config, pkgs, lib, ... }:
      let
        doomRepoUrl = "https://github.com/doomemacs/doomemacs";
      in
      {
        options.local.emacs.doomSource = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Absolute path to a doom.d directory on the host's filesystem,
            used as a live-edit out-of-store symlink so changes take effect
            without a home-manager rebuild.

            When null (the default), the doom.d shipped alongside this aspect
            is symlinked into ~/.config/doom via a regular store-path link,
            pinned to the flake input revision. Set this on hosts where you
            keep a working copy of the source and want to iterate on the
            doom config in place.
          '';
        };

        config = {
          # Apply the emacs-overlay so `pkgs.emacs-macport` (and friends) are
          # available in standalone home-manager too. In NixOS the same overlay
          # is applied via the nixos block above.
          nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

          programs.emacs = {
            enable = true;
            # Cross-platform: the Mitsuharu Yamamoto port gives a proper macOS
            # native feel (smooth scrolling, native fullscreen, retina text).
            # On Linux we stay on plain pkgs.emacs.
            package =
              if pkgs.stdenv.isDarwin
              then pkgs.emacs-macport
              else pkgs.emacs;
            extraPackages = epkgs: with epkgs; [
              vterm
              treesit-grammars.with-all-grammars
            ];
          };

          # Linux: systemd user service. No-op (and silently broken) on Darwin.
          services.emacs = lib.mkIf pkgs.stdenv.isLinux {
            enable = true;
            client.enable = true;
            startWithUserSession = "graphical";
          };

          # macOS: launchd agent. Use --fg-daemon so launchd can supervise the
          # process correctly (it watches the foreground PID).
          launchd.agents.emacs = lib.mkIf pkgs.stdenv.isDarwin {
            enable = true;
            config = {
              ProgramArguments = [
                "${config.programs.emacs.finalPackage}/bin/emacs"
                "--fg-daemon"
              ];
              KeepAlive = true;
              RunAtLoad = true;
              StandardOutPath = "${config.xdg.cacheHome}/emacs/daemon.log";
              StandardErrorPath = "${config.xdg.cacheHome}/emacs/daemon.log";
            };
          };

          home.packages = [
            pkgs.source-code-pro
            pkgs.et-book

            # Glyph font for the nerd-icons elisp package (Doom's default icon
            # library since ~2024). Without this, treemacs/doom-modeline/etc.
            # render bare Unicode codepoints instead of icons. Symbols-only is
            # ~2 MB, composes with whatever programming font is in use.
            pkgs.nerd-fonts.symbols-only

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

          # Two modes:
          #   - default (no override): regular store-path symlink to the doom.d
          #     shipped next to this aspect, pinned to the flake input.
          #   - override: out-of-store symlink to a working copy on disk for
          #     live editing.
          xdg.configFile."doom".source =
            if config.local.emacs.doomSource == null
            then ./doom.d
            else config.lib.file.mkOutOfStoreSymlink config.local.emacs.doomSource;
        };
      };
    };
  };
}

{ ... }:

{
  flake.aspects = { aspects, ... }: {
    darwin = {
      description = ''
        macOS-specific home-manager plumbing.

        Currently: copies `.app` bundles from `home.packages` into
        `~/Applications/Nix Apps/` so Spotlight, the Dock, and Finder can
        discover GUI apps installed via Nix. Spotlight does not index
        symlinks into the Nix store, so we copy rather than link.

        This aspect is a no-op on non-Darwin systems, so it is safe to
        unconditionally include in shared composite aspects.
      '';

      homeManager = { config, lib, pkgs, ... }:
        lib.mkIf pkgs.stdenv.isDarwin {
          home.activation.copyApplications =
            let
              apps = pkgs.buildEnv {
                name = "home-manager-applications";
                paths = config.home.packages;
                pathsToLink = [ "/Applications" ];
              };
            in
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              baseDir="$HOME/Applications/Nix Apps"
              # Tearing down the previous tree is harder than it looks on
              # macOS:
              #   - /nix/store files are read-only; rsync -a preserves perms,
              #     so the copy ends up read-only too.
              #   - Apps with Sparkle (Ghostty, Emacs.app, …) set the BSD
              #     `uchg` (user-immutable) flag on framework binaries.
              #     `chmod` silently no-ops on uchg files; you must clear
              #     the flag with `chflags nouchg` first or `rm -rf` fails
              #     with EACCES on every protected file.
              if [ -d "$baseDir" ]; then
                $DRY_RUN_CMD chflags -R nouchg "$baseDir" 2>/dev/null || true
                $DRY_RUN_CMD chmod -R u+w "$baseDir" 2>/dev/null || true
                $DRY_RUN_CMD rm -rf "$baseDir"
              fi
              $DRY_RUN_CMD mkdir -p "$baseDir"
              for appFile in ${apps}/Applications/*; do
                target="$baseDir/$(basename "$appFile")"
                # -a preserves internal symlinks (frameworks like Sparkle use
                #   Versions/Current -> Versions/B; turning those into files
                #   breaks the framework). DO NOT add --copy-unsafe-links.
                # --chmod=ugo+rwX gives both files and dirs (X = +x only on
                #   already-executable files / directories) write perms so
                #   the next activation's rm can win without help.
                $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --chmod=ugo+rwX \
                  "$appFile/" "$target/"
                # Belt-and-braces: clear uchg in case rsync copied any in.
                $DRY_RUN_CMD chflags -R nouchg "$target" 2>/dev/null || true
              done
            '';
        };
    };
  };
}

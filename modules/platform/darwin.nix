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
                pathsToLink = "/Applications";
              };
            in
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              baseDir="$HOME/Applications/Nix Apps"
              if [ -d "$baseDir" ]; then
                $DRY_RUN_CMD rm -rf "$baseDir"
              fi
              $DRY_RUN_CMD mkdir -p "$baseDir"
              for appFile in ${apps}/Applications/*; do
                target="$baseDir/$(basename "$appFile")"
                $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --copy-unsafe-links \
                  "$appFile/" "$target/"
              done
            '';
        };
    };
  };
}

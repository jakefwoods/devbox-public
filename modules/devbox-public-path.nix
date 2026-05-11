{ ... }:

{
  flake.aspects = { aspects, ... }: {
    devbox-public-path = {
      description = ''
        Per-host option pointing at the devbox-public checkout on disk.

        Aspects that want to mkOutOfStoreSymlink into the live repo (so edits
        in the working copy show up immediately, without rebuilding) should
        derive their paths from `config.local.devboxPublic.path` and `includes`
        this aspect.

        The default assumes the canonical devbox layout (`~/devbox-public`).
        Hosts that keep the checkout elsewhere (e.g. the Canva work laptop in
        `~/work/devbox-public`) should override this in their host module.
      '';

      homeManager = { config, lib, ... }: {
        options.local.devboxPublic.path = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/devbox-public";
          description = "Absolute path to the devbox-public checkout on this host.";
        };
      };
    };
  };
}

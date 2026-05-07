{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    users = {
      description = "User management";

      nixos = { config, lib, ... }: {
        options.local = {
          normalUsers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Normal user accounts managed by this flake";
          };

          userDefaults = lib.mkOption {
            type = lib.types.submodule {
              options.extraGroups = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
              };
            };
            default = {};
            description = "Config applied to all normal users";
          };
        };

        config.users.users = lib.genAttrs config.local.normalUsers (_: {
          inherit (config.local.userDefaults) extraGroups;
        });
      };
    };
  };
}

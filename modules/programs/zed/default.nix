{ self, inputs, ... }:

{
  flake.aspects =
    { aspects, ... }:
    {
      zed = {
        description = "Zed Editor";

        homeManager =
          { config, pkgs, ... }:
          {
            # We don't use the home-manager package since we're using
            # our mutableInputs module to manage settings anyway.
            home.packages = [] 
              ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ 
                   (pkgs.zed-editor.fhsWithPackages (pkgs: [
                     pkgs.nixd
                   ]))
                 ])
              ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [ 
                   # no fhs wrap on darwin
                   pkgs.zed-editor
		   pkgs.nixd
                 ]);
   
            xdg.configFile."zed/settings.json".source = config.lib.mutableInputs.link ./settings.json;
            xdg.configFile."zed/keymap.json".source = config.lib.mutableInputs.link ./keymap.json;
          };
      };
    };
}

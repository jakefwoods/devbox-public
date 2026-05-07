{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    vim = {
      description = "Vim editor";

      homeManager = { pkgs, ... }: {
        programs.vim = {
          enable = true;
          plugins = [
            pkgs.vimPlugins.vim-colors-solarized
          ];
          extraConfig = builtins.readFile ./vimrc;
        };
      };
    };
  };
}

{ config, ... }:

{
  flake.aspects.devCsharp.description = "devtools - C#";

  flake.aspects.devCsharp.homeManager = { pkgs, ... }: {
    home.packages = [
      pkgs.omnisharp-roslyn
      # pkgs.jetbrains.rider  -- slow build, re add later
    ];
  };
}

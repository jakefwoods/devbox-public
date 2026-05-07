{ self, inputs, config, withSystem, ... }:

{
  flake.aspects.devScala.description = "devtools - JavaScript";

  flake.aspects.devJavascript.homeManager = { pkgs, ... }: {
    home.packages = [
      pkgs.nodejs_latest
    ];
  };
}

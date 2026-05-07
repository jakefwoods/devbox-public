{ self, inputs, config, withSystem, ... }:

{
  flake.aspects = { aspects, ... }: {
    dev = {
      description = "devtools";
      includes = with aspects; [
        devCsharp
        devJvm
        devJavascript
      ];
    };
  };
}

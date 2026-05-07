{ self, inputs, config, withSystem, ... }:

{
  flake.aspects.devJvm = {
    description = "devtools - JVM (Java, Scala, Kotlin)";

    nixos = {
      programs.java.enable = true;
    };

    homeManager = { config, pkgs, ... }: {
      home.packages = [
        # Java
        pkgs.jetbrains.idea
        pkgs.jdt-language-server
        pkgs.gradle
        pkgs.maven
        pkgs.google-java-format

        # Scala
        pkgs.sbt
        self.packages.${pkgs.system}.scalastyle
        pkgs.scalafmt
        pkgs.unstable.metals

        # Kotlin
        pkgs.kotlin-language-server
      ];

      # IntelliJ IdeaVim configuration
      home.file.".ideavimrc".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/devbox-public/modules/dev/jvm/ideavimrc";
      home.file.".intellidoom".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/devbox-public/modules/dev/jvm/intellidoom";
    };
  };
}

{ inputs, ... }:

{
  perSystem = { pkgs, ... }: {
    packages.scalastyle = pkgs.stdenv.mkDerivation rec {
      pname = "scalastyle";
      version = "1.0.0";

      src = pkgs.fetchurl {
        url = "https://oss.sonatype.org/content/repositories/releases/org/scalastyle/scalastyle_2.12/${version}/scalastyle_2.12-${version}-batch.jar";
        sha256 = "1jzdb9hmvmhz3niivm51car74l8f3naspz4b3s6g400dpsbzvnp9";
      };

      dontUnpack = true;

      installPhase = ''
        mkdir -p "$out/bin"
        mkdir -p "$out/lib"

        cp "${src}" "$out/lib/${pname}-${version}.jar"

        cat > "$out/bin/${pname}" << EOF
        #!${pkgs.stdenv.shell}
        exec ${pkgs.jre}/bin/java -jar "$out/lib/${pname}-${version}.jar" "\$@"
        EOF

        chmod a+x "$out/bin/${pname}"
      '';

      meta = with pkgs.lib; {
        description = "Scalastyle examines your Scala code and indicates potential problems with it.";
        homepage = "http://scalastyle.org";
        license = licenses.asl20;
        platforms = platforms.linux ++ platforms.darwin;
      };
    };
  };
}

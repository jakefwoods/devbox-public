{ inputs, ... }:

{
  perSystem = { pkgs, ... }: {
    packages.plymouth-adi1090x = pkgs.stdenv.mkDerivation {
      pname = "plymouth-adi1090x";
      version = "0.0.1";

      src = pkgs.fetchFromGitHub {
        owner = "adi1090x";
        repo = "plymouth-themes";
        rev = "bf2f570bee8e84c5c20caac353cbe1d811a4745f";
        sha256 = "sha256-VNGvA8ujwjpC2rTVZKrXni2GjfiZk7AgAn4ZB4Baj2k=";
      };

      dontBuild = true;

      installPhase = ''
        mkdir -p $out/share/plymouth/themes
        cp -r pack_1/* $out/share/plymouth/themes
        cp -r pack_2/* $out/share/plymouth/themes
        cp -r pack_3/* $out/share/plymouth/themes
        cp -r pack_4/* $out/share/plymouth/themes

        shopt -s nullglob
        for plymouth_path in "$out/share/plymouth/themes"/**/*.plymouth; do
          substituteInPlace $plymouth_path --replace "/usr" "$out"
        done
      '';
    };
  };
}

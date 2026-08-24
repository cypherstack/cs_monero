{
  description = "Reproducible Linux native library build for cs_monero";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    monero-c = {
      url = "git+https://github.com/MrCyjaneK/monero_c?rev=07f7a7f80735130ebfa5842ddee5139076408c0d";
      flake = false;
    };
    monero = { url = "github:monero-project/monero/0232839913b13cf0ab0bb7ad25fff0c05f37d2fe"; flake = false; };
    miniupnp = { url = "github:miniupnp/miniupnp/544e6fcc73c5ad9af48a8985c94f0f1d742ef2e0"; flake = false; };
    rapidjson = { url = "github:Tencent/rapidjson/129d19ba7f496df5e33658527a7158c79b99c21c"; flake = false; };
    supercop = { url = "github:monero-project/supercop/633500ad8c8759995049ccd022107d1fa8a1bbc9"; flake = false; };
    randomx = {
      url = "git+https://github.com/MrCyjaneK/RandomX?rev=ce72c9bb9cb799e0d9171094b9abb009e04c5bfc";
      flake = false;
    };
    bc-ur = {
      url = "git+https://github.com/MrCyjaneK/bc-ur?rev=d82e7c753e710b8000706dc3383b498438795208";
      flake = false;
    };
    polyseed = {
      url = "git+https://github.com/tevador/polyseed?rev=bd79f5014c331273357277ed8a3d756fb61b9fa1";
      flake = false;
    };
    utf8proc = {
      url = "git+https://github.com/JuliaStrings/utf8proc?rev=3de4596fbe28956855df2ecb3c11c0bbc3535838";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, monero-c, monero, miniupnp, rapidjson, supercop, randomx, bc-ur, polyseed, utf8proc }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          hostAbi = if system == "x86_64-linux"
            then "x86_64-linux-gnu"
            else "aarch64-linux-gnu";
        in {
          cs-monero = pkgs.stdenv.mkDerivation {
            pname = "cs-monero-native";
            version = "3.2.0";
            src = monero-c;

            nativeBuildInputs = [ pkgs.cmake pkgs.gitMinimal pkgs.pkg-config ];
            buildInputs = [
              pkgs.boost186
              pkgs.libsodium
              pkgs.openssl
              pkgs.readline
              pkgs.unbound
              pkgs.zeromq
            ];

            postPatch = ''
              chmod -R u+w .
              rm -rf monero
              cp -a ${monero} monero
              chmod -R u+w monero
              git -C monero init -q
              for patchFile in ${monero-c}/patches/monero/*.patch; do
                git -C monero apply --whitespace=nowarn \
                  --exclude=.gitmodules \
                  --exclude=external/randomx \
                  --exclude=external/bc-ur \
                  --exclude=external/polyseed \
                  --exclude=external/utf8proc \
                  "$patchFile"
              done

              rm -rf monero/external/{miniupnp,rapidjson,supercop,randomx,bc-ur,polyseed,utf8proc}
              cp -a ${miniupnp} monero/external/miniupnp
              cp -a ${rapidjson} monero/external/rapidjson
              cp -a ${supercop} monero/external/supercop
              cp -a ${randomx} monero/external/randomx
              cp -a ${bc-ur} monero/external/bc-ur
              cp -a ${polyseed} monero/external/polyseed
              cp -a ${utf8proc} monero/external/utf8proc

              # The final wallet C API is shared, but its bundled polyseed
              # dependency must be linked statically so no sandbox RPATH is
              # retained in the deliverable.
              substituteInPlace monero/external/polyseed/CMakeLists.txt \
                --replace-fail 'if (STATIC)' 'if (TRUE)'

              git apply --whitespace=nowarn ${./patches/fix-monero-av.patch}
            '';

            cmakeFlags = [
              "-DHOST_ABI=${hostAbi}"
              "-DARCH=default"
              "-DMONERO_FLAVOR=monero"
              "-DMANUAL_SUBMODULES=ON"
              "-DUSE_DEVICE_TREZOR=OFF"
              "-DBUILD_GUI_DEPS=ON"
              "-DBUILD_TESTS=OFF"
              "-DBUILD_DOCUMENTATION=OFF"
              "-DReadline_ROOT_DIR=${pkgs.readline.dev}"
            ];
            cmakeDir = "../monero_libwallet2_api_c";

            env = {
              SOURCE_DATE_EPOCH = "1";
              NIX_CFLAGS_COMPILE = "-ffile-prefix-map=/build/source=. -fdebug-prefix-map=/build/source=.";
              NIX_LDFLAGS = "--build-id=none";
            };

            installPhase = ''
              runHook preInstall
              install -Dm755 libwallet2_api_c.so "$out/lib/libmonero_libwallet2_api_c.so"
              install -Dm644 ../monero_libwallet2_api_c/src/main/cpp/wallet2_api_c.h \
                "$out/include/wallet2_api_c.h"
              runHook postInstall
            '';

            doCheck = false;
          };

          default = self.packages.${system}.cs-monero;
        });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) cs-monero;
      });
    };
}

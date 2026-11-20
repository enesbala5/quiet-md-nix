{
  description = "Nix package for Quiet.md, a local-first notes app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Upstream only publishes an x86_64 Linux AppImage.
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      version = "0.1.13";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;

          # Quiet.md has no nixpkgs package and no Flatpak. Upstream ships an
          # official x86_64 AppImage (experimental, glibc 2.35 baseline), so
          # extract the prebuilt binary at build time instead of compiling the
          # Rust/GPUI source tree.
          #
          # extractType2 only unpacks the squashfs; it does not build the FHS
          # chroot that wrapType2 would add. The extracted tree keeps its own
          # xkbcommon/xcb helpers on RUNPATH ($ORIGIN/../lib), and the wrapper
          # below supplies what the AppImage expects from the host:
          #   - libxcb.so.1 (NEEDED but not bundled)
          #   - wayland / libglvnd / vulkan-loader (dlopened by GPUI's blade renderer)
          #   - XLOCALEDIR + XKB_CONFIG_ROOT: bundled libxkbcommon cannot find
          #     NixOS keyboard data in /usr/share/X11
          #   - /run/opengl-driver/share so the Vulkan loader finds NixOS GPU ICDs
          appimage = pkgs.appimageTools.extractType2 {
            pname = "quiet-md";
            inherit version;
            src = pkgs.fetchurl {
              url = "https://github.com/s1dashu/quiet-md/releases/download/v${version}/quiet-md-${version}-x86_64.AppImage";
              # sha256 from the release's quiet-md-<version>-x86_64.AppImage.sha256
              hash = "sha256-dReoK03PV0MP3LVveBBizlBCGJXAwnPwUNWXM44b19c=";
            };
          };

          quiet-md = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "quiet-md";
            inherit version;

            unpackPhase = "true";
            dontConfigure = true;
            dontBuild = true;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share
              cp -a ${appimage}/usr $out/libexec-quiet-md

              makeWrapper $out/libexec-quiet-md/bin/quiet_md $out/bin/quiet_md \
                --prefix LD_LIBRARY_PATH : ${
                  lib.makeLibraryPath [
                    pkgs.libxcb
                    pkgs.wayland
                    pkgs.libglvnd
                    pkgs.vulkan-loader
                  ]
                } \
                --set XLOCALEDIR $out/libexec-quiet-md/share/X11/locale \
                --set XKB_CONFIG_ROOT ${pkgs.xkeyboard-config}/share/X11/xkb \
                --prefix XDG_DATA_DIRS : /run/opengl-driver/share

              # The upstream desktop file runs `quiet_md`; keep that name and
              # also expose a conventional `quiet-md` command.
              ln -s quiet_md $out/bin/quiet-md
              cp -a $out/libexec-quiet-md/share/applications $out/share/
              cp -a $out/libexec-quiet-md/share/icons $out/share/

              runHook postInstall
            '';

            meta = {
              description = "Local-first notes app with a native GPUI editor";
              homepage = "https://quiet.md";
              license = lib.licenses.mit;
              platforms = systems;
              mainProgram = "quiet-md";
              sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            };
          });
        in
        {
          default = quiet-md;
          inherit quiet-md;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/quiet-md";
        };
      });
    };
}

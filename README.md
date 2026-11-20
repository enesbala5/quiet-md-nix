# Quiet.md for Nix

Nix package for [Quiet.md](https://quiet.md), a local-first notes app built with Rust + GPUI. This flake installs the official x86_64 Linux AppImage (currently 0.1.13). It does not compile Quiet.md.

There is no nixpkgs package for Quiet.md (nixpkgs' `quiet` is an unrelated P2P chat app) and no Flatpak release, so the prebuilt AppImage is the only no-compile path on Linux.

## How it works

The AppImage is extracted at build time with `appimageTools.extractType2`. This is deliberately not `wrapType2`: that would add a large FHS chroot, while the AppImage already bundles its own xkbcommon and xcb helpers on `RUNPATH` (`$ORIGIN/../lib`).

The derivation wraps `usr/bin/quiet_md` and supplies what the AppImage expects from the host:

- `libxcb.so.1` — `NEEDED` by the binary but not bundled in the AppImage
- `wayland`, `libglvnd`, `vulkan-loader` — dlopened by GPUI's blade/Vulkan renderer
- `XLOCALEDIR` and `XKB_CONFIG_ROOT` — bundled libxkbcommon cannot find NixOS keyboard data under `/usr/share/X11`
- `/run/opengl-driver/share` on `XDG_DATA_DIRS` — lets the Vulkan loader see NixOS GPU drivers

The upstream desktop entry (`com.s1dashu.quietmd.desktop`, including `text/markdown` MIME types) and the hicolor icon are installed under `$out/share`. Both `quiet_md` (used by the desktop file) and `quiet-md` are on `PATH`.

## Usage

```nix
inputs = {
  # ...
  quiet-md-nix.url = "github:enesbala5/quiet-md-nix";

  # optional: share one nixpkgs with the rest of the system
  quiet-md-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

Home Manager:

```nix
home.packages = [
  inputs.quiet-md-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Run without installing:

```sh
nix run github:enesbala5/quiet-md-nix
```

## Packages

One package (`default` / `quiet-md`) for `x86_64-linux`, matching the only Linux artifact upstream publishes. Also exposed as `apps.default`.

## Bump

Edit `version` and the `hash` in `flake.nix`. The URL is derived from `version`. Grab the new hash from the release's `.sha256` asset:

```sh
nix-prefetch-url --type sha256 \
  "https://github.com/s1dashu/quiet-md/releases/download/<VERSION>/quiet-md-<VERSION>-x86_64.AppImage"
# convert the base32 result to SRI:
nix hash convert --hash-algo sha256 --to sri <base32>
```

## Caveats

- **Linux only, x86_64 only.** macOS and Windows builds are not packaged, and upstream has no aarch64 AppImage.
- **NixOS Vulkan.** The wrapper looks for drivers in `/run/opengl-driver/share`, provided by `hardware.graphics.enable`. On a non-NixOS Nix install the prefix is harmless if that directory is absent.
- **Experimental upstream build.** Linux support is still marked experimental by Quiet.md; use the AppImage's in-app updater only if you run the raw AppImage, not this Nix package. Bump the version here instead.
- **glibc 2.35+ baseline.** Any modern nixpkgs satisfies this.

## License

Quiet.md is MIT; see `THIRD_PARTY.md` in the AppImage for bundled third-party notices (notably the commercially licensed Nucleo icons, which are not relicensed here). The Nix packaging in this repository is MIT.

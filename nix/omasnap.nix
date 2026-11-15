{
  lib,
  stdenv,
  cmake,
  pkg-config,
  wayland-scanner,
  wayland,
  wayland-protocols,
  libdeflate,
  qt6,
  kdePackages,
  hyprland,
  wl-clipboard,
  xdg-utils,
  systemd,
  src,
}:

stdenv.mkDerivation {
  pname = "omasnap";
  version = "1.26.2";
  inherit src;

  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    kdePackages.layer-shell-qt
    libdeflate
    qt6.qtbase
    qt6.qtwayland
    wayland
    wayland-protocols
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "/usr/share/wayland-protocols" "${wayland-protocols}/share/wayland-protocols"
  '';

  cmakeFlags = [ "-DOMASNAP_VERSION=1.26.2" ];
  cmakeBuildType = "Release";

  qtWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ hyprland wl-clipboard xdg-utils systemd ]}"
  ];

  postInstall = ''
    install -Dm644 "$src/LICENSE" "$out/share/licenses/omasnap/LICENSE"
  '';

  meta = {
    description = "Native Wayland screenshot and annotation overlay";
    homepage = "https://github.com/omacom/omasnap";
    license = lib.licenses.mit;
    mainProgram = "omasnap";
    platforms = lib.platforms.linux;
  };
}

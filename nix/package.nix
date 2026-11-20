{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  qt6,
  hyprland,
  jq,
  gawk,
  bash,
  coreutils,
  python3,
  systemd,
  brightnessctl,
  awww,
  libwebp,
  curl,
  networkmanager,
  wireplumber,
  pulseaudio,
  cava,
  power-profiles-daemon,
  upower,
  tzdata,
  bluez,
  wl-clipboard,
  wtype,
  qrencode,
  iproute2,
  xdg-utils,
  omasnap,
}:
let
  runtimePackages = [
    quickshell
    hyprland
    omasnap
    jq
    gawk
    bash
    coreutils
    (python3.withPackages (ps: [ ps.pillow ]))
    systemd
    brightnessctl
    awww
    libwebp
    curl
    networkmanager
    wireplumber
    pulseaudio
    cava
    power-profiles-daemon
    upower
    tzdata
    bluez
    wl-clipboard
    wtype
    qrencode
    iproute2
    xdg-utils
  ];
in
stdenvNoCC.mkDerivation {
  pname = "omashell";
  version = "0.1.0";
  src = lib.cleanSource ../.;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -d "$out/share/omashell/bin" "$out/share/applications" "$out/bin"
    ln -s "${quickshell}/share/applications/org.quickshell.desktop" "$out/share/applications/org.quickshell.desktop"
    cp -a assets common config modules shell.qml "$out/share/omashell/"
    install -m755 bin/omashell "$out/bin/omashell"
    install -m755 bin/omashell-open-screenshot bin/omashell-screenshot "$out/share/omashell/bin/"
    ln -s "${omasnap}/bin/omasnap" "$out/bin/omasnap"
    ln -s ../share/omashell/bin/omashell-open-screenshot "$out/bin/omashell-open-screenshot"
    ln -s ../share/omashell/bin/omashell-screenshot "$out/bin/omashell-screenshot"
    wrapProgram "$out/bin/omashell" \
      --prefix PATH : "${lib.makeBinPath runtimePackages}" \
      --prefix QT_PLUGIN_PATH : "${qt6.qtimageformats}/${qt6.qtbase.qtPluginPrefix}" \
      --set OMASHELL_ROOT "$out/share/omashell" \
      --set TZDIR "${tzdata}/share/zoneinfo" \
      --set PYTHONTZPATH "${tzdata}/share/zoneinfo"
    runHook postInstall
  '';

  meta = {
    description = "Independent Quickshell desktop shell for Hyprland";
    homepage = "https://github.com/shahidshabbir-se/omashell";
    mainProgram = "omashell";
    platforms = lib.platforms.linux;
  };
}

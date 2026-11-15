{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  hyprland,
  jq,
  gawk,
  bash,
  coreutils,
  python3,
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
  qrencode,
  iproute2,
  xdg-utils,
}:
let
  runtimePackages = [
    quickshell
    hyprland
    jq
    gawk
    bash
    coreutils
    python3
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
    install -d "$out/share/omashell" "$out/bin"
    cp -a assets common config modules shell.qml "$out/share/omashell/"
    install -m755 bin/omashell bin/omashell-open-screenshot bin/omashell-screenshot "$out/bin/"
    wrapProgram "$out/bin/omashell" \
      --prefix PATH : "${lib.makeBinPath runtimePackages}" \
      --set OMASHELL_ROOT "$out" \
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

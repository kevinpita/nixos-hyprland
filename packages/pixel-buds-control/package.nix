{
  coreutils,
  gnugrep,
  jq,
  pbpctrl,
  util-linux,
  writeShellApplication,
}:
writeShellApplication {
  name = "pixel-buds-control";
  runtimeInputs = [
    coreutils
    gnugrep
    jq
    pbpctrl
    util-linux
  ];
  text = builtins.readFile ./pixel-buds-control;
}

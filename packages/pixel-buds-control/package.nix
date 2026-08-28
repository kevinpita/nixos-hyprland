{
  coreutils,
  gnugrep,
  jq,
  pbpctrl,
  writeShellApplication,
}:
writeShellApplication {
  name = "pixel-buds-control";
  runtimeInputs = [
    coreutils
    gnugrep
    jq
    pbpctrl
  ];
  text = builtins.readFile ./pixel-buds-control;
}

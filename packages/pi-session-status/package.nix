{ buildGoModule }:
buildGoModule {
  pname = "pi-session-status";
  version = "1.0.0";
  src = ./.;
  vendorHash = null;
  ldflags = [
    "-s"
    "-w"
  ];
}

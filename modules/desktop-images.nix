{
  pkgs,
  username,
  ...
}:
let
  nixosWallpapers = pkgs.symlinkJoin {
    name = "nixos-wallpapers";
    paths = with pkgs.nixos-artwork.wallpapers; [
      catppuccin-mocha
      dracula
      gradient-grey
      moonscape
      mosaic-blue
      nineish-dark-gray
      waterfall
      watersplash
    ];
  };
  profileImages = pkgs.runCommand "profile-images" { } ''
    mkdir -p "$out"
    cp ${pkgs.gnome-control-center}/share/pixmaps/faces/* "$out/"
  '';
in
{
  home-manager.users.${username}.home.file = {
    "Pictures/Avatars".source = profileImages;
    "Pictures/Wallpapers/NixOS".source = "${nixosWallpapers}/share/backgrounds/nixos";
  };
}

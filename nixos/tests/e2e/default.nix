{
  pkgs,
  nixos-lib,
  nixosModule,
  ...
}: {
  service = import ./service.nix {inherit pkgs nixos-lib nixosModule;};
  socket = import ./socket.nix {inherit pkgs nixos-lib nixosModule;};
}

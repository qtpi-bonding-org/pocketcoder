{ pkgs }:
pkgs.buildGoModule {
  pname = "pocketcoder-release";
  version = "dev";
  src = ../release-manager;
  # This keeps the first-boot verifier inside the attested NixOS image; it
  # never downloads a verifier or dependency from a mutable origin at boot.
  vendorHash = "sha256-aoh5NE4ji/0rtBO3I2r0llAZiWyvVtF1XQFvgeCsaGM=";
  subPackages = [ "cmd/pocketcoder-release" ];
}

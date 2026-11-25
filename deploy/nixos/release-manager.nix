{ pkgs, releaseManagerSrc ? ../release-manager }:
pkgs.buildGoModule {
  pname = "pocketcoder-release";
  version = "dev";
  src = releaseManagerSrc;
  # This keeps the first-boot verifier inside the attested NixOS image; it
  # never downloads a verifier or dependency from a mutable origin at boot.
  vendorHash = "sha256-rndB/a0lrQugsg3GT9Knxy5R9UDsSr900If+XHBfe7s=";
  subPackages = [ "cmd/pocketcoder-release" ];
}

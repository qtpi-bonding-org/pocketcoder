{
  description = "PocketCoder NixOS server image for Linode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    sourceCommit = import ./release-commit.nix;
    releaseManager = import ./release-manager.nix { inherit pkgs; };
  in {
    nixosConfigurations.pocketcoder = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit sourceCommit releaseManager; };
      modules = [
        ./configuration.nix
        ./caddy.nix
        ./bootstrap.nix
      ];
    };

    packages.${system} = {
      release-manager = releaseManager;

    # Built directly via make-disk-image.nix (not nixos-generators' "raw"
    # format) with partitionTableType = "none": this matches Linode's own
    # documented NixOS install approach (unpartitioned disk, GRUB
    # chainloaded from grub.cfg via `forceInstall`/`device = "nodev"` in
    # configuration.nix) -- nixos-generators' raw format instead assumes a
    # partitioned disk with its own fileSystems."/" and grub.device
    # defaults, which directly conflicted with the config below.
      linode-image = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs;
        inherit (pkgs) lib;
        config = self.nixosConfigurations.pocketcoder.config;
        partitionTableType = "none";
        format = "raw";
        # Produces a raw .img suitable for Linode custom images API
        # Upload with: linode-cli image-upload --region us-east result/nixos.img
      };
    };

    checks.${system}.ordering =
      import ./tests/ordering.nix { inherit pkgs self system; };
  };
}

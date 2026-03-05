{
  description = "PocketCoder NixOS server image for Linode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.pocketcoder = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        ./caddy.nix
        ./bootstrap.nix
      ];
    };

    packages.${system}.linode-image = nixos-generators.nixosGenerate {
      inherit system;
      modules = [
        ./configuration.nix
        ./caddy.nix
        ./bootstrap.nix
      ];
      format = "raw";
      # Produces a raw .img suitable for Linode custom images API
      # Upload with: linode-cli image-upload --region us-east result/nixos.img
    };
  };
}

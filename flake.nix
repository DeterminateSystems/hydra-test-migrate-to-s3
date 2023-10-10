{
  description = "hydra-test-migrate-to-s3";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.533189.tar.gz";

  outputs =
    { self
    , nixpkgs
    , ...
    } @ inputs:
    let
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      allSystems = [ "x86_64-linux" "aarch64-linux" "i686-linux" "x86_64-darwin" ];

      forAllSystems = f: genAttrs allSystems (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      devShell = forAllSystems ({ system, pkgs, ... }:
        pkgs.mkShell {
          name = "hydra-test-migrate-to-s3";

          buildInputs = with pkgs; [
            codespell
            nixpkgs-fmt
            (pkgs.terraform.withPlugins (plugins: [ plugins.hydra ]))
          ];
        });

      packages = forAllSystems ({ pkgs, system, ... }: {
        hydra-minio = import ./hydra-minio.nix { inherit pkgs; } { inherit pkgs system; };
      });
    };
}

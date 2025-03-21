{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      nix-config = pkgs.writeTextFile {
        name = "nix-config";
        destination = "/etc/nix/nix.conf";
        text = ''
          experimental-features = nix-command flakes
        '';
      };
      prodPkgs = with pkgs; [
        curl
        git
        openssh
        bash
        nodejs
        nix
        nix-config
      ];
      devPkgs = with pkgs; [
        podman
        awscli2
      ] ++ prodPkgs;
    in
    {
      devShells = {
        default = pkgs.mkShell {
          buildInputs = devPkgs;
        };
        prod = pkgs.mkShell {
          buildInputs = prodPkgs;
        };  
      };
      packages = {
        default = pkgs.dockerTools.buildLayeredImage {
          name = "amplify-builder";
          contents = prodPkgs;
        };
      };
    }
  );
}

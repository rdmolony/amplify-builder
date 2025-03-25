{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils, ... } @ inputs: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      nix-config = pkgs.writeTextFile {
        name = "nix-config";
        destination = "/etc/nix/nix.conf";
        text = ''
          experimental-features = nix-command flakes
          build-users-group =
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
      sayHello = pkgs.writeShellScriptBin "say-hello" ''
        echo "Hello from Nix integration with Amplify!"
        echo "Running on branch: $AWS_BRANCH"
        echo "App ID: $AWS_APP_ID"
        echo "Current time: $(date)"
      '';
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
        default = pkgs.dockerTools.buildImage {
          name = "amplify-builder";
          fromImage = pkgs.dockerTools.pullImage {
            imageName = "public.ecr.aws/amazonlinux/amazonlinux";
            imageDigest = "sha256:0d19ca211e6c020e9123a52e595afcf9495dc3fa2657e0633d5d2151d52c45c4";
            sha256 = "sha256-+XZheGIejgbsZZ66RnQ23SKE9OMvaHd/xK5yIyjYB3w=";
            finalImageTag = "2023";
            finalImageName = "amazonlinux";
          };
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = prodPkgs;
            pathsToLink = [ "/bin" "/etc" "/lib" "/share" ];
          };
          config = {
            Cmd = [ "${pkgs.bash}/bin/bash" ];
            WorkingDir = "/";
          };
        };
      };
      apps = {
        hello = {
          type = "app";
          program = "${sayHello}/bin/say-hello";
        };
      };
    }
  );
}

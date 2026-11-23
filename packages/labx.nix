{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labx";
  version = "0.0.0";

  src = fetchFromGitHub {
    owner = "sagikazarmark";
    repo = "labx";
    rev = "c81bba2322087d7a0bf10f76e9ec503633c92174";
    sha256 = "sha256-WRIh4S3tBUGh3VrZg2A+nSKHNAbmYHj3bYFarWsGpXE=";
  };

  vendorHash = "sha256-mc0edNMwyn32QQXaqZi1fKEeDjvoe12YNjfGXQoNVRo=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labctl";
  version = "0.1.75";

  src = fetchFromGitHub {
    owner = "iximiuz";
    repo = "labctl";
    rev = "v${version}";
    sha256 = "sha256-kE4nhksg7ArWtShay7xg4WHP9W+SVJqRvYZUrcaZ7CQ=";
  };

  vendorHash = "sha256-YZhKZ2O073+u1AMo8w+UNazfaOS6KgbMOAUceBgeALc=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labx";
  version = "0.0.0";

  src = fetchFromGitHub {
    owner = "sagikazarmark";
    repo = "labx";
    rev = "06045ea2fc34f4b191ed066af75cc001a1e99fe0";
    sha256 = "sha256-FxrJRG4+W19C7gbhNy/G4uLJY1dfGwEliaz0sb/R8OE=";
  };

  vendorHash = "sha256-qoEL7TAOcVmUU2tbakZ8BH6835InG5+mt9Bxqy14Jfg=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

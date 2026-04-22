{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labctl";
  version = "0.1.68";

  src = fetchFromGitHub {
    owner = "iximiuz";
    repo = "labctl";
    # rev = "v${version}";
    rev = "873d3cc7579e1cdd5302d67d9317fd197712b8fd";
    sha256 = "sha256-93c1Qjov9/1KFUXEkvUSHqhZFpPWj7BxULq1Nise+bg=";
  };

  vendorHash = "sha256-TruaquC6sGjLZ5HcaavxqcO9Gy2PK3gqLfUTtFGOAtw=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

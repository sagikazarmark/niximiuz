{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labctl";
  version = "0.1.75";

  src = fetchFromGitHub {
    owner = "iximiuz";
    repo = "labctl";
    # rev = "v${version}";
    rev = "2498be2dad26aaa90faaeed1a8207de67f8d483e";
    sha256 = "sha256-Bx8rGONk50sSqDU6Pd/hMOt3sH9NPs7RT4pXbCfS5dg=";
  };

  vendorHash = "sha256-E9H8J5KvtkWoPLswuoZ4CJHu3pw6d7Oyr4H25jRto6U=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labctl";
  version = "0.1.112";

  src = fetchFromGitHub {
    owner = "iximiuz";
    repo = "labctl";
    rev = "v${version}";
    sha256 = "sha256-cPKFSlVU6C5ymP8mZlvL6aejymyJhbw3koPeH6N0mRw=";
  };

  vendorHash = "sha256-YNjguFRCgm3W5fsyUXRPXka0sWJUJYCXMhv9tAL+JYU=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

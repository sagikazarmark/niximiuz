{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labctl";
  version = "0.1.116";

  src = fetchFromGitHub {
    owner = "iximiuz";
    repo = "labctl";
    rev = "v${version}";
    sha256 = "sha256-a2GUNR8lhAtvE15c5xv4VxEP9eckru9AHYiiCvBNukI=";
  };

  vendorHash = "sha256-YNjguFRCgm3W5fsyUXRPXka0sWJUJYCXMhv9tAL+JYU=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

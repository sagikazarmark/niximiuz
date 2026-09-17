{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "labx";
  version = "0.0.0";

  src = fetchFromGitHub {
    owner = "sagikazarmark";
    repo = "labx";
    rev = "d49e5b1299af6cf9f22b5ad3766daf515ce01873";
    sha256 = "sha256-FHzJGkU7jjWMxc34jtjcwhugIShwpoTWqU5W6f72hGA=";
  };

  vendorHash = "sha256-H6PjIgOCaQIVedlWyI78l00X94nDJZN61VxaGi0iQm8=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
    "-X main.version=v${version}"
  ];
}

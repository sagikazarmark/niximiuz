{ name, ... }:
{
  kind = "tutorial";
  title = "With Nix Manifest (${name})";
  channels = {
    alpha = {
      name = "with-nix-alpha";
    };
    beta = {
      name = "with-nix-beta";
    };
  };
}

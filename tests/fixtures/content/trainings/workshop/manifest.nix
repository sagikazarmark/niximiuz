{ name, ... }:
{
  inherit name;
  title = "Workshop";
  channels = {
    live = {
      name = "workshop-live";
    };
    dev = {
      name = "workshop-dev";
    };
  };
}

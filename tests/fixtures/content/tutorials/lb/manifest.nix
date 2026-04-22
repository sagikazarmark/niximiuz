{ name, ... }:
{
  inherit name;
  title = "Load Balancing";
  channels = {
    live = {
      name = "lb-live";
    };
    dev = {
      name = "lb-dev";
    };
  };
}

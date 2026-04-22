{ name, ... }:
{
  inherit name;
  title = "Invisible Pod";
  channels = {
    live = {
      name = "invisible-pod-live";
    };
    dev = {
      name = "invisible-pod-dev";
    };
  };
}

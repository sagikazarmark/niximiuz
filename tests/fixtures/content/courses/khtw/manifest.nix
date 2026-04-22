{ name, ... }:
{
  inherit name;
  title = "K8s The Hard Way";
  channels = {
    live = {
      name = "khtw-live";
    };
    dev = {
      name = "khtw-dev";
    };
  };
}

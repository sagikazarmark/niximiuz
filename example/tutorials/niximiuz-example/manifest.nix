{
  channel,
  ...
}:
let
  playgroundSlug =
    if channel == "live" then "niximiuz-example-2c20ac05" else "niximiuz-example-2c20ac05.${channel}";
in
{
  title = "Niximiuz Example";
  description = "Tutorial that exercises the niximiuz content pipeline end to end.";

  channels = {
    live = {
      name = "niximiuz-example-9b788ed3";
    };
    dev = {
      name = "niximiuz-example-9b788ed3.dev";
    };
  };

  categories = [ "linux" ];

  playground = {
    name = playgroundSlug;
  };

  tasks = {
    verify_marker_file = {
      machine = "ubuntu";
      user = "laborant";
      run = "test -f /tmp/niximiuz-tutorial-done";
    };
  };
}

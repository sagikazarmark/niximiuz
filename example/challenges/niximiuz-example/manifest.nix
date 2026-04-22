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
  description = "Challenge that exercises the niximiuz content pipeline end to end.";

  channels = {
    live = {
      name = "niximiuz-example-a4a18654";
    };
    dev = {
      name = "niximiuz-example-a4a18654.dev";
    };
  };

  categories = [ "linux" ];
  tagz = [ "example" ];
  difficulty = "easy";
  createdAt = "2026-04-22";
  updatedAt = "2026-04-22";

  playground = {
    name = playgroundSlug;
  };

  tasks = {
    verify_challenge_answer = {
      machine = "ubuntu";
      user = "laborant";
      run = "test -f /tmp/niximiuz-challenge-answer && grep -q 'Niximiuz' /tmp/niximiuz-challenge-answer";
    };
  };
}

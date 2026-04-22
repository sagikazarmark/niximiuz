{
  lib,
  ...
}:
{
  targets = {
    default = lib.tagTarget "playgrounds/niximiuz-example" (
      lib.mkRootTarget {
        name = "default";
        context = lib.mkContext ./image;
      }
    );
  };
}

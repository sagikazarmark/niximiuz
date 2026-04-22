# Course content builder. Static-only (no labx orchestration): the existing
# production pipeline doesn't render courses through labx. Children are
# walked with substituteChannel for __CHANNEL__ replacement; top-level
# accessControl is injected for public channels. Accepts either a static
# `manifest` or a `loadManifest` closure (same convention as other kinds).
{
  core,
  content,
  pkgs,
}:
{
  mkCourse =
    args@{
      name,
      manifest ? null,
      loadManifest ? null,
      children ? { },
      # Orchestrating-mode args (accepted for collector symmetry; currently
      # ignored, courses don't render through labx).
      source ? null,
      templateDirs ? [ ],
      data ? { },
      ...
    }:
    let
      # Drop collector-only args so they don't leak to core.mkCourse.
      restArgs = builtins.removeAttrs args [
        "loadManifest"
        "source"
        "templateDirs"
        "data"
      ];

      getManifest =
        if loadManifest != null then
          loadManifest
        else if manifest != null then
          _: manifest
        else
          throw "content.mkCourse: manifest or loadManifest is required";

      probe = getManifest null;
      channels = probe.channels or (throw "content.mkCourse: manifest.channels is required");

      forChannel =
        channelName:
        let
          raw = getManifest channelName;
          channelConfig = channels.${channelName};
          rootResolved = content.resolveChannelFields channelName raw;

          # Courses use top-level accessControl, unlike playgrounds which
          # nest it under manifest.playground.
          withAccessControl =
            if content.isChannelPublic channelConfig then
              rootResolved // { accessControl = content.publicAccessControl; }
            else
              rootResolved;

          # Walk the children tree substituting __CHANNEL__ in all strings.
          transformedChildren = content.substituteChannel channelName children;
        in
        core.mkCourse (
          restArgs
          // {
            inherit name;
            manifest = withAccessControl;
            children = transformedChildren;
          }
        );
    in
    builtins.listToAttrs (
      map (c: {
        name = c;
        value = forChannel c;
      }) (builtins.attrNames channels)
    );
}

# Playground content builder. Injects access control before labx render.
# In orchestrating mode, inlines README.md as manifest.markdown. Does NOT
# add a `.content-name` root file or a `body` arg, core.mkPlayground
# doesn't accept those.
{
  core,
  content,
  pkgs,
}:
let
  common = import ./common.nix { inherit core content pkgs; };

  accessControlPostResolve =
    channelConfig: resolved:
    let
      pg = resolved.playground or { };
      accessControl =
        if content.isChannelPublic channelConfig then
          content.publicAccessControl
        else
          pg.accessControl or content.defaultAccessControl;
    in
    resolved
    // {
      playground = pg // {
        inherit accessControl;
      };
    };
in
{
  # mkPlayground accepts an optional `postResolve` hook that runs AFTER
  # the library's access-control injection. Consumers use it to layer
  # repo-specific defaults (drive-size budgets, per-machine shapes, ...)
  # without forking the content builder.
  mkPlayground =
    args@{
      postResolve ? (_channelConfig: resolved: resolved),
      ...
    }:
    let
      restArgs = builtins.removeAttrs args [ "postResolve" ];
      composed =
        channelConfig: resolved:
        postResolve channelConfig (accessControlPostResolve channelConfig resolved);
      builder = common.mkChanneled {
        kind = "playground";
        coreBuilder = core.mkPlayground;
        postResolve = composed;

        builderArgs =
          {
            name,
            resolved,
            rendered,
            staticDir,
          }:
          let
            readmePath = "${rendered}/README.md";
            hasReadme = builtins.pathExists readmePath;
          in
          {
            inherit name;
            manifest = resolved // (if hasReadme then { markdown = builtins.readFile readmePath; } else { });
            static = staticDir;
          };
      };
    in
    builder restArgs;
}

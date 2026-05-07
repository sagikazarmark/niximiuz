# Shared channel-iterating orchestrator for content builders. Handles the
# translation pipeline from authoring-shape input to core-builder calls.
#
# Static mode (source == null): thin channel iteration. `manifest` or
# `loadManifest` provides per-channel authoring-shape manifests. Caller-
# supplied `restArgs` (body, static, rootFiles, ...) forward to the core
# builder unchanged. `postResolve` lets the caller transform the resolved
# manifest (e.g. inject accessControl).
#
# Orchestrating mode (source != null): full translation. Per channel,
# renders the source via labx. `builderArgs` callback produces the full
# args for the core builder, gets { name, resolved, rendered, staticDir }.
# `defaultBuilderArgs` captures the tutorial-style shape (manifest minus
# name, body from index.md, static, .content-name rootFile) and kinds
# compose off it as needed.
{
  core,
  content,
  pkgs,
}:
let
  isPlainAttrs = v: builtins.isAttrs v && (v.type or null) != "derivation";

  mergeRootFiles =
    context: base: extra:
    if extra == null || extra == { } then
      base
    else if base == null then
      extra
    else if isPlainAttrs base && isPlainAttrs extra then
      base // extra
    else
      throw "${context}: generated rootFiles can only be merged with attrset rootFiles";

  applyRootFiles =
    context: args: extra:
    let
      merged = mergeRootFiles context (args.rootFiles or null) extra;
    in
    if merged == null then args else args // { rootFiles = merged; };

  # Default core-builder args for tutorial / training / course. Not used
  # by playground (no body) or challenge (adds solution).
  defaultBuilderArgs =
    {
      name,
      resolved,
      rendered,
      staticDir,
    }:
    {
      inherit name;
      manifest = builtins.removeAttrs resolved [ "name" ];
      body = builtins.readFile "${rendered}/index.md";
      static = staticDir;
      rootFiles = {
        ".content-name" = pkgs.writeText "content-name" resolved.name;
      };
    };

  mkChanneled =
    {
      kind,
      coreBuilder,
      postResolve ? (_channelConfig: resolved: resolved),
      builderArgs ? defaultBuilderArgs,
    }:
    {
      name,
      manifest ? null,
      loadManifest ? null,
      source ? null,
      templateDirs ? [ ],
      data ? { },
      rootFiles ? null,
      rootFilesFor ? _channel: { },
      ...
    }@args:
    let
      restArgs = builtins.removeAttrs args [
        "name"
        "manifest"
        "loadManifest"
        "source"
        "templateDirs"
        "data"
        "rootFilesFor"
      ];

      getManifest =
        if loadManifest != null then
          loadManifest
        else if manifest != null then
          _: manifest
        else
          throw "content.mk${kind}: manifest or loadManifest is required";

      probe = getManifest null;
      channels = probe.channels or (throw "content.mk${kind}: manifest.channels is required");
      channelNames = builtins.attrNames channels;

      autoStatic = if source != null then (core.discoverAssets source).static else null;

      forChannel =
        channelName:
        let
          raw = getManifest channelName;
          channelConfig = channels.${channelName};
          resolved = content.resolveChannelFields channelName raw;
          finalManifest = postResolve channelConfig resolved;

          rendered =
            if source != null then
              content.renderWithLabx {
                inherit
                  name
                  source
                  templateDirs
                  data
                  ;
                channel = channelName;
                manifest = finalManifest // {
                  inherit kind;
                };
              }
            else
              null;

          baseArgs =
            if source == null then
              # Static mode: forward caller args with postResolve-resolved manifest.
              restArgs
              // {
                inherit name;
                manifest = finalManifest;
              }
            else
              # Orchestrating mode: hand off to caller's builderArgs, then
              # merge any caller-provided root sidecars that static mode would
              # have forwarded directly.
              applyRootFiles "content.mk${kind}.rootFiles" (builderArgs {
                inherit name rendered;
                resolved = finalManifest;
                staticDir = autoStatic;
              }) rootFiles;

          finalArgs = applyRootFiles "content.mk${kind}.rootFilesFor" baseArgs (rootFilesFor channelName);
        in
        coreBuilder finalArgs;
    in
    builtins.listToAttrs (
      map (c: {
        name = c;
        value = forChannel c;
      }) channelNames
    );
in
{
  inherit mkChanneled defaultBuilderArgs;
}

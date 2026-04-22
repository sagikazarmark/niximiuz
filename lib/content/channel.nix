# Channel-related transforms applied to manifests before handing them to
# core. All pure: string/attrset/list walks, no IO, no derivations.
{ lib }:
let
  substituteChannel =
    channel: value:
    let
      sub =
        v:
        if builtins.isString v then
          builtins.replaceStrings [ "__CHANNEL__" ] [ channel ] v
        else if builtins.isList v then
          map sub v
        else if builtins.isAttrs v && (v.type or null) != "derivation" then
          builtins.mapAttrs (_: sub) v
        else
          v;
    in
    sub value;

  prefixTitle =
    channel: title: if channel == "live" then title else "${lib.toUpper channel}: ${title}";

  resolveChannelFields =
    channel: manifest:
    let
      channels =
        if !(manifest ? channels) then
          throw "resolveChannelFields: manifest.channels is required"
        else if !(builtins.isAttrs manifest.channels) then
          throw "resolveChannelFields: manifest.channels must be an attrset"
        else
          manifest.channels;

      channelConfig =
        if !(channels ? ${channel}) then
          throw "resolveChannelFields: channel '${channel}' is not declared in manifest.channels (have: ${builtins.concatStringsSep ", " (builtins.attrNames channels)})"
        else
          channels.${channel};

      channelName =
        if !(channelConfig ? name) then
          throw "resolveChannelFields: manifest.channels.${channel}.name is required"
        else if !(builtins.isString channelConfig.name) then
          throw "resolveChannelFields: manifest.channels.${channel}.name must be a string"
        else if channelConfig.name == "" then
          throw "resolveChannelFields: manifest.channels.${channel}.name must not be empty"
        else
          channelConfig.name;

      authoredTitle = manifest.title or "";
      # substituteChannel is kept for backward compat with __CHANNEL__
      # placeholders. For manifest.nix files that use ${channel} interpolation
      # directly, this is a harmless no-op.
      substituted = substituteChannel channel (builtins.removeAttrs manifest [ "channels" ]);
    in
    substituted
    // {
      name = channelName;
      title = prefixTitle channel authoredTitle;
    };

  publicAccessControl = {
    canList = [ "anyone" ];
    canRead = [ "anyone" ];
    canStart = [ "anyone" ];
  };

  defaultAccessControl = {
    canList = [ "owner" ];
    canRead = [ "owner" ];
    canStart = [ "owner" ];
  };

  isChannelPublic = channelConfig: (channelConfig.public or false) == true;

  # mkChanneledContent: generic content-level wrapper. Loops over channels,
  # applies resolveChannelFields, lets the caller post-process the resolved
  # manifest, and forwards to the core builder.
  #
  # Supports two manifest-loading modes:
  #
  #   1. Static manifest (existing):
  #        args = { manifest = { channels = { ... }; ... }; ... }
  #      One attrset for all channels. __CHANNEL__ placeholders get
  #      substituted per channel. Good for backward compat and YAML-origin
  #      manifests.
  #
  #   2. Per-channel loading (new, preferred for manifest.nix):
  #        args = { loadManifest = channel: { channels = { ... }; ... }; ... }
  #      Called once per channel. The manifest.nix receives `channel` as a
  #      param and interpolates directly, no __CHANNEL__ placeholders.
  #      Nix laziness makes probing safe: `.channels` is read without
  #      forcing channel-dependent fields.
  #
  # When `loadManifest` is provided, `manifest` is ignored.
  #
  # Returns { <channel> = <drv>; ... }.
  mkChanneledContent =
    {
      coreBuilder,
      builderName,
      postResolve ? (_channelConfig: resolved: resolved),
    }:
    args:
    let
      hasLoadManifest = args ? loadManifest;

      # Probe for the channels attrset. Nix is lazy: only .channels is
      # forced, so channel-dependent fields (drives, etc.) aren't evaluated.
      probeManifest =
        if hasLoadManifest then
          args.loadManifest null
        else
          args.manifest or (throw "${builderName}: manifest or loadManifest is required");

      channels = probeManifest.channels or (throw "${builderName}: manifest.channels is required");

      # Clean args: strip loadManifest/manifest so they don't leak to core.
      restArgs = builtins.removeAttrs args [
        "manifest"
        "loadManifest"
      ];

      forChannel =
        channelName:
        let
          # Load the manifest for this specific channel.
          manifest = if hasLoadManifest then args.loadManifest channelName else args.manifest;

          channelConfig = channels.${channelName};
          resolved = resolveChannelFields channelName manifest;
          finalManifest = postResolve channelConfig resolved;
        in
        coreBuilder (
          restArgs
          // {
            manifest = finalManifest;
          }
        );
    in
    builtins.mapAttrs (channelName: _: forChannel channelName) channels;
in
{
  inherit
    substituteChannel
    prefixTitle
    resolveChannelFields
    publicAccessControl
    defaultAccessControl
    isChannelPublic
    mkChanneledContent
    ;
}

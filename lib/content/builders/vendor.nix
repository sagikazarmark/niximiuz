# Vendor content builder. Vendor pages are multi-page Markdown directories:
# every top-level .md file is copied as a page, and __static__/ is copied as
# the vendor static directory. The manifest.nix only supplies channels.
{
  core,
  content,
  pkgs,
}:
let
  markdownFilesFrom =
    dir:
    let
      entries = builtins.readDir dir;
      names = builtins.filter (
        name: entries.${name} == "regular" && builtins.match ".*\\.md" name != null
      ) (builtins.attrNames entries);
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = dir + "/${name}";
      }) names
    );

  autoStyle =
    manifest: source:
    if manifest ? style || source == null || !(builtins.pathExists (source + "/style.css")) then
      { }
    else
      { style = builtins.readFile (source + "/style.css"); };

  staticFrom = dir: if builtins.pathExists (dir + "/static") then dir + "/static" else null;
in
{
  mkVendor =
    args@{
      name,
      manifest ? null,
      loadManifest ? null,
      body ? "",
      pages ? null,
      static ? null,
      rootFiles ? null,
      # Collector/orchestrating-mode args.
      source ? null,
      templateDirs ? [ ],
      data ? { },
      rootFilesFor ? _channel: { },
      ...
    }:
    let
      restArgs = builtins.removeAttrs args [
        "manifest"
        "loadManifest"
        "source"
        "templateDirs"
        "data"
        "rootFilesFor"
        "body"
        "pages"
        "static"
        "rootFiles"
      ];

      getManifest =
        if loadManifest != null then
          loadManifest
        else if manifest != null then
          _: manifest
        else
          throw "content.mkVendor: manifest or loadManifest is required";

      probe = getManifest null;
      channels = probe.channels or (throw "content.mkVendor: manifest.channels is required");

      sourceBody = if source != null then builtins.readFile (source + "/index.md") else body;
      sourcePages =
        if source != null then
          builtins.removeAttrs (markdownFilesFrom source) [ "index.md" ]
        else if pages == null then
          { }
        else
          pages;
      sourceStatic = if source != null && static == null then staticFrom source else static;
      sourceRootFiles = if rootFiles == null then { } else rootFiles;

      forChannel =
        channelName:
        let
          raw = getManifest channelName;
          withAutoStyle = raw // autoStyle raw source;
          resolved = content.resolveChannelFields channelName withAutoStyle;
        in
        core.mkVendor (
          restArgs
          // {
            inherit name;
            body = sourceBody;
            manifest = builtins.removeAttrs resolved [ "name" ];
            pages = sourcePages;
            static = sourceStatic;
            rootFiles = sourceRootFiles // {
              ".content-name" = pkgs.writeText "content-name" resolved.name;
            };
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

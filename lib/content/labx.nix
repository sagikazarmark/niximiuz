# labx integration for the content pipeline.
#
# renderWithLabx is a PURE derivation that runs `labx render` for
# Go-template expansion only (no manifest transforms, no SHA resolution,
# no network). The output is a directory of rendered .md files that Nix
# builders consume as body/solution/units.
{ pkgs, core }:
let
  yamlFormat = pkgs.formats.yaml { };
  inherit (core.lib.resolve) resolveCover makeFilesCmds;
in
{
  # renderWithLabx: render Go templates in a content source directory.
  #
  # Takes a Nix-resolved manifest (already channel-transformed) and the
  # original source directory. Overlays the resolved manifest.yaml onto
  # a prepared source tree, then runs `labx render` which:
  #   - Reads manifest.yaml as template data (.Manifest)
  #   - Renders all .md template files (index.md, README.md, solution.md,
  #     program.md, units/*.md)
  #   - Copies __static__/
  #   - Outputs raw rendered markdown (no frontmatter wrapping)
  #
  # This is a PURE derivation, no network, no __impure. Template
  # rendering needs only the source files and data.
  #
  # Returns: a store path containing the rendered files.
  #
  # Parameters:
  #   name: derivation name stem (required)
  #   channel: channel name for {{ .Channel }} in templates (required)
  #   manifest: already-resolved Nix attrset; written as manifest.yaml
  #                  for labx to read as template data (required)
  #   source: original content source directory (required)
  #   templateDirs, list of global template directories (default: [])
  #   data: attrset of data files; each key → <key>.json exposed
  #                  as {{ .Extra.<key> }} in templates (default: {})
  renderWithLabx =
    {
      name,
      channel,
      manifest,
      source,
      templateDirs ? [ ],
      data ? { },
    }:
    let
      # Resolve cover markers before serializing. labx expects cover to be
      # a plain string, not a { _coverHash, src } attrset.
      coverRes = resolveCover manifest;
      resolvedManifest = coverRes.manifest;
      coverCmds =
        if coverRes.coverSources == [ ] then "" else makeFilesCmds coverRes.coverSources "$out/__static__";

      manifestFile = yamlFormat.generate "manifest.yaml" resolvedManifest;

      preparedSource = pkgs.runCommand "prepared-${name}-${channel}" { } ''
        mkdir -p $out
        cp -r ${source}/. $out/
        chmod -R u+w $out
        cp ${manifestFile} $out/manifest.yaml
        ${coverCmds}
      '';

      dataDir = pkgs.runCommand "data-${name}" { } ''
        mkdir -p $out
        ${builtins.concatStringsSep "\n" (
          map (key: ''
            cp ${builtins.toFile "${key}.json" (builtins.toJSON data.${key})} $out/${key}.json
          '') (builtins.attrNames data)
        )}
      '';

      templateArgs = builtins.concatStringsSep " " (map (d: "--template-dir ${d}") templateDirs);
    in
    pkgs.runCommand "rendered-${name}-${channel}"
      {
        nativeBuildInputs = [ pkgs.labx ];
      }
      ''
        labx render \
          --channel ${channel} \
          --data-dir ${dataDir} \
          ${templateArgs} \
          --path ${preparedSource} \
          --output $out
      '';
}

# Shared helpers for path/file resolution used across builders:
#   - resolveCover    : promote a Nix-path `cover` to __static__/<basename>
#   - makeFilesCmds   : shell commands to copy a flexible file/dir spec into
#                       a target directory. Accepts path | list | attrset |
#                       null. Used for static, contentFiles, rootFiles.
let
  # stripStoreHash: strip the 32-char Nix-store hash prefix from a basename,
  # if present. Leaves non-prefixed names unchanged.
  stripStoreHash =
    s:
    let
      m = builtins.match "[0-9a-z]{32}-(.*)" s;
    in
    if m == null then s else builtins.head m;

  # srcName: extract a human-readable filename from a source. Works for:
  #   - Plain Nix paths (./file.ext), baseNameOf gives the pre-import name
  #   - Derivations (pkgs.writeText etc.), uses .name to avoid the hashed
  #     store-path basename
  #   - builtins.path results and other store paths, baseNameOf includes
  #     the 32-char store-hash prefix; stripStoreHash removes it
  srcName =
    src: if builtins.isAttrs src && src ? name then src.name else stripStoreHash (baseNameOf src);

  # isDir: true only for on-disk directories (not derivations).
  isDir = src: !(builtins.isAttrs src) && (builtins.readFileType src == "directory");

  # hashedCover: opt-in marker constructor for covers that should be renamed
  # to `<basename>.<hash8>.<ext>` for CDN cache-busting.
  #
  #   manifest = { cover = core.hashedCover ./cover.svg; };
  #
  # The marker shape (`{ _coverHash = true; src = path; }`) is detected by
  # resolveCover. Plain `cover = ./path` keeps the original filename.
  hashedCover = src: {
    _coverHash = true;
    inherit src;
  };

  # splitExt: split a filename into [base ext]. ext includes the leading dot
  # and is "" if there is none.
  splitExt =
    fname:
    let
      m = builtins.match "(.*)(\\.[^.]+)" fname;
    in
    if m == null then
      [
        fname
        ""
      ]
    else
      m;

  # hashName: produce "<stem>.<hash8><ext>" from a source. Uses srcName so
  # the stem comes from the authored filename (not the hashed store-path
  # basename when the source is a builtins.path or pkgs.writeText result).
  hashName =
    src:
    let
      base = srcName src;
      parts = splitExt base;
      stem = builtins.elemAt parts 0;
      ext = builtins.elemAt parts 1;
      hash = builtins.substring 0 8 (builtins.hashFile "sha256" src);
    in
    "${stem}.${hash}${ext}";

  # isHashedCover: detect the marker attrset emitted by hashedCover.
  isHashedCover = v: builtins.isAttrs v && (v._coverHash or false) == true;

  # resolveCover returns:
  #   manifest: the input manifest with `cover` rewritten to a string
  #                   ("__static__/<name>") if it was a Nix path or a hashed
  #                   cover marker
  #   coverSources: a file-spec (in any shape makeFilesCmds accepts) to be
  #                   merged into __static__/. Empty list when there's
  #                   nothing to copy.
  resolveCover =
    manifest:
    if manifest ? cover && isHashedCover manifest.cover then
      let
        src = manifest.cover.src;
        targetName = hashName src;
      in
      {
        manifest = manifest // {
          cover = "__static__/${targetName}";
        };
        # Attrset form preserves the hashed target name through makeFilesCmds.
        coverSources = {
          ${targetName} = src;
        };
      }
    else if manifest ? cover && builtins.isPath manifest.cover then
      {
        manifest = manifest // {
          cover = "__static__/${baseNameOf manifest.cover}";
        };
        coverSources = [ manifest.cover ];
      }
    else
      {
        inherit manifest;
        coverSources = [ ];
      };

  # listCpCmds: copy each entry into target. Dirs merged, files by srcName.
  # -f gives last-wins on basename collision (Nix store files are read-only).
  listCpCmds =
    sources: target:
    map (
      src: if isDir src then "cp -rf ${src}/. ${target}/" else "cp -f ${src} ${target}/${srcName src}"
    ) sources;

  # attrsCpCmds: explicit naming, key becomes the target filename.
  # Uses antiquotation directly so Nix paths get imported into the store,
  # rather than `toString` which returns absolute paths verbatim.
  attrsCpCmds =
    files: target: map (fname: "cp -f ${files.${fname}} ${target}/${fname}") (builtins.attrNames files);

  # Detect a derivation (which is also an attrset) so we don't mistake it
  # for an explicit-naming attrset.
  isDerivation = v: builtins.isAttrs v && (v.type or null) == "derivation";

  # makeFilesCmds: copy a flexible file/dir spec into `target`.
  #
  #   null         → ""
  #   single path  → wrapped to [path]; basename used (dirs merged)
  #   derivation   → wrapped to [drv]; .name used
  #   list         → each entry copied with its basename (dirs merged)
  #   attrset      → { "target-name" = source; ... }, explicit naming.
  #                  File-only; use list form to merge a directory.
  #
  # Always emits `mkdir -p target` first when there's anything to copy.
  makeFilesCmds =
    input: target:
    let
      cmds =
        if input == null then
          [ ]
        else if builtins.isList input then
          listCpCmds input target
        else if isDerivation input || builtins.isPath input then
          listCpCmds [ input ] target
        else if input == { } then
          [ ]
        else
          attrsCpCmds input target;
    in
    if cmds == [ ] then "" else builtins.concatStringsSep "\n" ([ "mkdir -p ${target}" ] ++ cmds);

  # buildTimeSubstCmd: shell fragment appended to every builder's runCommand.
  # Replaces utils.buildTime markers in all generated .yaml / .md files
  # under $out with the current UTC timestamp (ISO 8601 with Z suffix).
  # A no-op if no marker is present.
  buildTimeSubstCmd = ''
    chmod -R u+w $out
    _content_core_build_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    find $out -type f \( -name '*.yaml' -o -name '*.md' \) -print0 \
      | xargs -0 -r sed -i "s|__CONTENT_CORE_BUILD_TIME__|$_content_core_build_time|g"
  '';

  # makeFilesCmdsMulti: apply makeFilesCmds to each input in the list,
  # all targeting the same directory. Useful when several independent
  # specs (e.g., user-provided `static` + auto-collected cover sources)
  # need to land in the same place.
  makeFilesCmdsMulti =
    inputs: target:
    builtins.concatStringsSep "\n" (
      builtins.filter (s: s != "") (map (i: makeFilesCmds i target) inputs)
    );

  # targetNamesInSpec: enumerate the basenames a file spec would produce at
  # the top level of its target directory. Used by assertNoReservedNames to
  # catch attempts to clobber mandatory outputs.
  #
  # For directory sources (single path, or inside a list), reads the dir at
  # eval time and returns its top-level entries, so a dir containing
  # index.md will flag index.md as a would-be target.
  targetNamesInSpec =
    spec:
    if spec == null then
      [ ]
    else if builtins.isList spec then
      builtins.concatMap (
        s: if isDir s then builtins.attrNames (builtins.readDir s) else [ (srcName s) ]
      ) spec
    else if isDerivation spec || builtins.isPath spec then
      if isDir spec then builtins.attrNames (builtins.readDir spec) else [ (srcName spec) ]
    else if builtins.isAttrs spec then
      builtins.attrNames spec
    else
      [ ];

  # assertNoPathSeparator: reject attrset keys containing '/'. A key with a
  # slash would write into a subdirectory, bypassing the layer boundary
  # (e.g., rootFiles = { "content/manifest.yaml" = ...; } would clobber
  # the content bundle). Keys must be plain filenames at the given layer.
  # Non-attrset specs pass through unchanged.
  assertNoPathSeparator =
    context: spec:
    let
      keys =
        if builtins.isAttrs spec && (spec.type or null) != "derivation" then
          builtins.attrNames spec
        else
          [ ];
      bad = builtins.filter (k: builtins.match ".*/.*" k != null) keys;
    in
    if bad == [ ] then
      spec
    else
      throw "${context}: attrset keys must be plain filenames (no '/'); got '${builtins.head bad}', use a different file-spec parameter to place files in another layer";

  # assertNoReservedNames: throw if any target name in `spec` matches a
  # reserved name. `context` prefixes the error message.
  #
  # Reserved names are the filenames a builder writes itself (manifest.yaml,
  # index.md, etc.). User specs that would land on top of them fail at eval
  # time with a clear message.
  #
  # Also applies assertNoPathSeparator first, since a key like
  # "content/manifest.yaml" would slip past the reserved-name check but
  # still cause a clobber.
  assertNoReservedNames =
    context: reservedList: spec:
    let
      validatedSpec = assertNoPathSeparator context spec;
      conflicts = builtins.filter (n: builtins.elem n reservedList) (targetNamesInSpec validatedSpec);
    in
    if conflicts == [ ] then
      validatedSpec
    else
      throw "${context}: ${builtins.head conflicts} is a reserved name and would clobber a builder output; rename the entry or use a different parameter";
in
{
  inherit
    resolveCover
    hashedCover
    makeFilesCmds
    makeFilesCmdsMulti
    assertNoReservedNames
    buildTimeSubstCmd
    ;
}

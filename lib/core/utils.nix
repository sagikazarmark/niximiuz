# Author-facing utilities. Strictly additive helpers that flavors/authors
# call to produce values they pass to builder params (body, manifest, …).
# The core library itself does not consume anything from this module.
lib:
let
  # Split a camelCase string at each lowercase→uppercase boundary.
  # "runcVersion" → [ "runc" "Version" ]
  # "cniPluginsVersion" → [ "cni" "Plugins" "Version" ]
  # "DEBUG" → [ "DEBUG" ]       (no lower→upper transitions)
  # "version" → [ "version" ]
  splitCamel =
    s:
    let
      chars = lib.stringToCharacters s;
      isUpperChar = c: lib.hasInfix c "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      step =
        acc: c:
        if acc == [ ] then
          [ c ]
        else
          let
            lastWord = lib.last acc;
            rest = lib.init acc;
            lastChar = lib.last (lib.stringToCharacters lastWord);
            # Don't split when the previous char was an underscore, the
            # string is already segmented by that underscore and a further
            # split would double it on re-join.
            isBoundary = isUpperChar c && !(isUpperChar lastChar) && lastChar != "_";
          in
          if isBoundary then
            rest
            ++ [
              lastWord
              c
            ]
          else
            rest ++ [ (lastWord + c) ];
    in
    builtins.foldl' step [ ] chars;

  camelToUpperSnake = s: lib.concatMapStringsSep "_" lib.toUpper (splitCamel s);
in
{
  # buildTime: sentinel string replaced by the current UTC timestamp
  # (ISO 8601, `YYYY-MM-DDTHH:MM:SSZ`) when the content derivation
  # actually builds. The real time is stamped in by a sed pass over all
  # .yaml / .md files under $out/ at the end of each builder's runCommand.
  #
  # Use case: a real "updated at" field that reflects build time, not the
  # Nix-store-normalized 1970 epoch:
  #
  #   manifest = {
  #     name = "foo";
  #     title = "Foo";
  #     updatedAt = core.lib.buildTime;
  #   };
  #
  # The placeholder is a plain string, so it serializes fine into YAML /
  # frontmatter. Any occurrence of this exact token in the generated
  # output gets substituted, you can use it in `body` too if you want.
  buildTime = "__CONTENT_CORE_BUILD_TIME__";

  # readBlock: extract a named block from a file. Block markers are
  # `@block:<name>` and `@endblock`, typically written inside comments
  # (e.g., `# @block:install` / `// @block:install`). The first matching
  # block wins; the markers themselves are stripped, the content in between
  # is returned as-is (with a trailing newline).
  #
  # Use case: embed named snippets from real scripts / configs into
  # markdown bodies without maintaining two copies.
  #
  #   # install.sh
  #   echo "hi"
  #   # @block:install
  #   curl -fsSL https://example.com/install.sh | sh
  #   # @endblock
  #   echo "bye"
  #
  #   body = ''
  #     Run this:
  #     ```bash
  #     ${core.lib.readBlock ./install.sh "install"}
  #     ```
  #   '';
  #
  # Throws if the block is not found or has no @endblock.
  readBlock =
    file: blockName:
    let
      content = builtins.readFile file;

      # builtins.split returns alternating strings and match-groups; keep
      # just the strings to get the lines between newlines.
      lines = builtins.filter builtins.isString (builtins.split "\n" content);
      nLines = builtins.length lines;

      # Match "@block:<name>" optionally followed by whitespace and anything
      # else on the same line. Guards against `@block:foo` matching inside
      # `@block:foobar` by requiring a space-or-end after the name.
      startRe = ".*@block:${blockName}([[:space:]].*)?";
      endRe = ".*@endblock([[:space:]].*)?";

      matchesStart = line: builtins.match startRe line != null;
      matchesEnd = line: builtins.match endRe line != null;

      findFrom =
        pred: from:
        if from >= nLines then
          -1
        else if pred (builtins.elemAt lines from) then
          from
        else
          findFrom pred (from + 1);

      startIdx = findFrom matchesStart 0;
      endIdx = if startIdx < 0 then -1 else findFrom matchesEnd (startIdx + 1);
    in
    if startIdx < 0 then
      throw "readBlock: block '${blockName}' not found in ${toString file}"
    else if endIdx < 0 then
      throw "readBlock: block '${blockName}' not terminated (missing @endblock) in ${toString file}"
    else
      builtins.concatStringsSep "\n" (
        builtins.genList (i: builtins.elemAt lines (startIdx + 1 + i)) (endIdx - startIdx - 1)
      )
      + "\n";

  # toBuildArgs: convert a camelCase-keyed attrset into an UPPER_SNAKE-keyed
  # attrset, suitable for use as Docker Bake `args` (which feed Dockerfile
  # `ARG` values).
  #
  #   toBuildArgs { runcVersion = "v1.4.0"; cniPluginsVersion = "v1.9.0"; }
  #   # => { RUNC_VERSION = "v1.4.0"; CNI_PLUGINS_VERSION = "v1.9.0"; }
  #
  # Keys that are already upper-case or UPPER_SNAKE pass through
  # unchanged. Values are untouched.
  toBuildArgs = vars: lib.mapAttrs' (k: v: lib.nameValuePair (camelToUpperSnake k) v) vars;
}

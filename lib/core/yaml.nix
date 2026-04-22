# Small helpers for producing YAML and Markdown-with-frontmatter files.
# These are the two recurring output shapes across content kinds.
{ pkgs }:
{
  # writeYaml: serialize a Nix attrset to a YAML file derivation.
  #   name: output file name (default: "out.yaml")
  #   value: attrset to serialize
  writeYaml =
    {
      name ? "out.yaml",
      value,
    }:
    (pkgs.formats.yaml { }).generate name value;

  # writeFrontMatter: produce a Markdown file with YAML frontmatter.
  #   Output shape:
  #     ---
  #     <frontmatter as yaml>
  #     ---
  #
  #     <body>
  #
  #   name: output file name (default: "index.md")
  #   frontmatter: attrset serialized as YAML between the --- delimiters
  #   body: string OR path; appended after the frontmatter block
  writeFrontMatter =
    {
      name ? "index.md",
      frontmatter,
      body ? "",
    }:
    let
      fmFile = (pkgs.formats.yaml { }).generate "frontmatter.yaml" frontmatter;
      bodyFile = if builtins.isPath body then body else pkgs.writeText "body.md" body;
    in
    pkgs.runCommand name { } ''
      {
        echo '---'
        cat ${fmFile}
        echo '---'
        echo ""
        cat ${bodyFile}
      } > $out
    '';
}

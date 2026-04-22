{ core, ... }:
let
  inherit (core) writeYaml writeFrontMatter;

  yamlNamed = writeYaml {
    name = "foo.yaml";
    value = {
      a = 1;
    };
  };

  yamlDefault = writeYaml {
    value = { };
  };

  fmNamed = writeFrontMatter {
    name = "index.md";
    frontmatter = {
      title = "hi";
    };
    body = "hello world";
  };

  fmDefault = writeFrontMatter {
    frontmatter = { };
  };
in
{
  testWriteYamlNamed = {
    expr = yamlNamed.name;
    expected = "foo.yaml";
  };

  testWriteYamlKind = {
    expr = yamlNamed._kind;
    expected = "yaml-file";
  };

  testWriteYamlDefaultName = {
    expr = yamlDefault.name;
    expected = "out.yaml";
  };

  testWriteFrontMatterNamed = {
    expr = fmNamed.name;
    expected = "index.md";
  };

  testWriteFrontMatterKind = {
    expr = fmNamed._kind;
    expected = "run-command";
  };

  testWriteFrontMatterDefaultName = {
    expr = fmDefault.name;
    expected = "index.md";
  };
}

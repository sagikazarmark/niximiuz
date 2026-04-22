# Overlay adding the tools the content lib orchestrates:
#   - labx (sagikazarmark/labx) requires go >= 1.25.6; nixpkgs 26.05 ships only
#     1.25.4 as default, so we pin buildGo126Module.
#   - labctl (iximiuz/labctl) builds cleanly with the default go.
#
# Consumers apply this overlay at flake level; the content layer then
# reads pkgs.labx and pkgs.labctl. To override either tool for a single
# call, pass a custom pkgs:
#   mkContentPipeline { pkgs = pkgs.extend (_: _: { labx = myLabx; }); ... }.
final: _prev: {
  labctl = final.callPackage ./packages/labctl.nix { };
  labx = final.callPackage ./packages/labx.nix {
    buildGoModule = final.buildGo126Module;
  };
}

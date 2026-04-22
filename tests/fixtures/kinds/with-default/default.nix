{ name, ... }@args:
{
  # Sentinel proves the escape-hatch path was taken.
  sentinel = "default-escape-hatch";
  # Expose the full args so tests can assert on what defaultArgs injected.
  receivedArgs = args;
  # Convenience boolean for the common "did name arrive" check.
  hasName = name == "with-default";
}

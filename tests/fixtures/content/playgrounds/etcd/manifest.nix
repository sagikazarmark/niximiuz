{
  name,
  channel ? null,
  ...
}:
{
  inherit name;
  title = "Etcd";
  channels = {
    live = {
      name = "etcd-live";
      public = true;
    };
    dev = {
      name = "etcd-dev";
    };
  };
  playground = {
    machines =
      if channel != null then
        [
          {
            name = "etcd";
            drives = [
              { source = "oci://ghcr.io/example/etcd:${channel}"; }
            ];
          }
        ]
      else
        [ ];
  };
}

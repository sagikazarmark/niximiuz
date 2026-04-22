{
  images,
  ...
}:
{
  title = "Niximiuz Example";
  description = "A minimal playground showcasing niximiuz features";

  channels = {
    live = {
      name = "niximiuz-example-2c20ac05";
      public = true;
    };
    dev = {
      name = "niximiuz-example-2c20ac05.dev";
    };
  };

  categories = [ "linux" ];

  playground = {
    networks = [
      {
        name = "local";
        subnet = "172.16.0.0/24";
      }
    ];
    machines = [
      {
        name = "ubuntu";
        users = [
          { name = "root"; }
          {
            name = "laborant";
            default = true;
          }
        ];
        drives = [
          {
            source = images.default.passthru.imageRef;
            mount = "/";
          }
        ];
        network.interfaces = [
          { network = "local"; }
        ];
        resources = {
          cpuCount = 2;
          ramSize = "2GiB";
        };
      }
    ];
    tabs = [
      {
        id = "terminal";
        kind = "terminal";
        name = "ubuntu";
        machine = "ubuntu";
      }
    ];
    initTasks = { };
    initConditions = { };
  };
}

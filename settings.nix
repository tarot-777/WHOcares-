{
  repositoryPath = "/home/malachi/WHOcares!";

  defaultSystem = "x86_64-linux";
  supportedSystems = ["x86_64-linux"];

  user = {
    name = "malachi";
    email = "malachi@aegis-dualis";
    homeDirectory = "/home/malachi";
  };

  defaultHomeHost = "coffin";
  defaultNixosHost = "Aegis-Dualis";

  homeProfiles = {
    coffin = {
      system = "x86_64-linux";
      genericLinux = true;
    };

    "Aegis-Dualis" = {
      system = "x86_64-linux";
      genericLinux = false;
    };
  };

  nixosHosts = {
    "Aegis-Dualis" = {
      system = "x86_64-linux";
      modules = [./hosts/aegis-dualis];
    };
  };
}

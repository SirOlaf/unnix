{ ... }:
rec {
  puppy = {
    pname = "puppy";
    version = "1fd72028b4c83e62f68b29ad1eecd3d7270aa4d6";
    src = fetchGit {
      url = "https://github.com/treeform/puppy";
      rev = "1fd72028b4c83e62f68b29ad1eecd3d7270aa4d6";
    };
  };
  jsony = {
    pname = "jsony";
    version = "4fa3a9b52649e31783ab2165b5476d5737c8842c";
    src = fetchGit {
      url = "https://github.com/treeform/jsony";
      rev = "4fa3a9b52649e31783ab2165b5476d5737c8842c";
    };
  };
  libcurl = {
    pname = "libcurl";
    version = "23f3d90e60d7a233b5eb27fb13e57fd198c73697";
    src = fetchGit {
      url = "https://github.com/Araq/libcurl";
      rev = "23f3d90e60d7a233b5eb27fb13e57fd198c73697";
    };
  };
  zippy = {
    pname = "zippy";
    version = "a3fd6f0458ffdd7cbbd416be99f2ca80a7852d82";
    src = fetchGit {
      url = "https://github.com/guzba/zippy";
      rev = "a3fd6f0458ffdd7cbbd416be99f2ca80a7852d82";
    };
  };
  webby = {
    pname = "webby";
    version = "7796159f4e6875ffa6a6a0980af931ad918eb4e8";
    src = fetchGit {
      url = "https://github.com/treeform/webby";
      rev = "7796159f4e6875ffa6a6a0980af931ad918eb4e8";
    };
  };
  nimPathArgs = "--path:\"${puppy.src}/src\" --path:\"${jsony.src}/src\" --path:\"${libcurl.src}\" --path:\"${zippy.src}/src\" --path:\"${webby.src}/src\"";
}

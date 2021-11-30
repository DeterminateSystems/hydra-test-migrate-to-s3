{ system, nonce }: rec {
  variable = builtins.derivation {
    name = "variable";
    system = system;
    builder = "/bin/sh";
    allowSubstitutes = false;
    preferLocalBuild = true;
    args = [ "-c" ''echo "$@" > $out'' "--" nonce stable ];
  };

  stable = builtins.derivation {
    name = "stable";
    system = system;
    builder = "/bin/sh";
    allowSubstitutes = false;
    preferLocalBuild = true;
    args = [ "-c" ''echo "$@" > $out'' "--" "a stable build!" ];
  };
}

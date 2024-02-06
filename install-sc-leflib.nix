{ pkgs, pname ? "sc-leflib", version ? "0.2.0", format ? "wheel" }:

pkgs.python3Packages.buildPythonPackage {
  pname = pname;
  version = version;
  format = format;
  src = pkgs.python3Packages.fetchPypi {
    inherit pname version format;
    sha256 = "ec741e8ce2f3a6bff0e9b398e35d628b976e6f0096714b442cccaf0d7e6ba449";  # SHA256 hash of the package
  };
}

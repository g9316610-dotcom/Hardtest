{
  description = "Flake hard tests for linux";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            stress-ng
            fio
            nvme-cli
            smartmontools
            sysbench
            hdparm
            lm_sensors
            sysstat
            iotop
            hwinfo
            perf
            memtester
            jq
            gawk
            pv
          ];
        };
      }
    );

}

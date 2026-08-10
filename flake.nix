{
  description = "Hardware diagnostics and stress testing toolkit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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

            ####################
            ## Shell
            ####################

            bash
            jq
            gawk
            coreutils
            gnugrep
            gnused
            findutils

            ####################
            ## Development
            ####################

            git
            shellcheck
            shfmt

            ####################
            ## Hardware
            ####################

            fio
            stress-ng
            sysbench
            memtester

            ####################
            ## Storage
            ####################

            nvme-cli
            smartmontools
            hdparm

            ####################
            ## Monitoring
            ####################

            lm_sensors
            sysstat
            iotop
            hwinfo
            pciutils
            usbutils
            util-linux
            lshw
            dmidecode

            ####################
            ## Misc
            ####################

            pv

          ];

          shellHook = ''
            export HARDTESTS_ROOT=$PWD
            export HARDTESTS_RESULTS=$PWD/results

            mkdir -p "$HARDTESTS_RESULTS"

            echo
            echo "=================================="
            echo " HardTests development shell"
            echo "=================================="
            echo
            echo "Project : $HARDTESTS_ROOT"
            echo "Results : $HARDTESTS_RESULTS"
            echo
          '';
        };
      }
    );
}

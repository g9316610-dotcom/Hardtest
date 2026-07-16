#!/usr/bin/env bash

set -eou pipefail

OUTPUT="/var/log/system_info.log"
mkdir -p "$(dirname "$OUTPUT")"

{
  echo "*******SYSTEM INFO********"
  date

  echo
  echo "******OS********"
  OS_INFO=$(jq -n \
    --arg name "$(grep ^NAME= /etc/os-release | cut -d= -f2-)" \
    --arg version "$(grep ^VERSION= /etc/os-release | cut -d= -f2-)" \
    '{name: $name, version: $version}')

  echo
  echo "********CPU*******"
  lscpu

  echo
  echo "******DISKS******"
  lsblk

  echo
  echo "*********NVME DEVICES*******"
  nvme list || true

  echo
  echo "********SMART DATA*******"
  for d in /dev/nvme* /dev/sd*; do
    [[ -b "$d" ]] || continue
    echo "SMART $d"
    if [[ "$d" == /dev/nvme* ]]; then nvme smart-log "$d" || true
    else smartctl -a "$d" || true
    fi
    echo
  done
  echo; echo "********TEMP********"; sensors || true
} | tee "$OUTPUT"

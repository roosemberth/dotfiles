{ config, pkgs, lib, ... }:

with lib;
{
  options.roos.udev.enable = mkEnableOption "Roos' udev rules";

  config = mkIf config.roos.udev.enable {
    services.udev.extraRules = ''
      ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="6108", MODE="666", SYMLINK+="LimeSDR"
      ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", MODE="666", SYMLINK+="EPFL-Gecko4Education"
      ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6101", MODE="666", SYMLINK+="EPFL-Gecko4Education"
      ATTRS{idVendor}=="04b4", ATTRS{idProduct}=="00f3", MODE="666", SYMLINK+="FX3"
      #Bus 003 Device 055: ID 10c4:ea60 Cygnal Integrated Products, Inc. CP210x UART Bridge / myAVR mySmartUSB light
      ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="666", SYMLINK+="ttyUSB-odroid0"
      #Bus 001 Device 005: ID 067b:2303 Prolific Technology, Inc. PL2303 Serial Port
      ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", MODE="666", SYMLINK+="ttyUSB-odroid1"
      # Honor 8
      ATTRS{idVendor}=="0925", ATTRS{idProduct}=="3881", MODE="666"
      # Suspend on low battery TODO: pre-death clock instead...
      SUBSYSTEM=="power_supply", ATTRS{capacity}=="10", ATTRS{status}=="Discharging", RUN+="${config.systemd.package}/bin/systemctl suspend"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0765", ATTRS{idProduct}=="5010", ATTR{authorized}="0"
     '';
  };
}

# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  my_ssh_port = 2222;
in
rec {
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./include/devenv.nix
    ./include/haskell.nix
    ./include/bashrc.nix
    ./include/systools.nix
    ./include/postfix_relay.nix
    ./include/templatecfg.nix
    ./include/user-grwlf.nix
    ./include/syncthing.nix
    ./include/wheel.nix
    ./include/ntpd.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/vda";

  fileSystems = [
    { mountPoint = "/home";
      device = "/dev/disk/by-label/HOME";
    }
  ];

  networking.hostName = "vps";
  networking.wireless.enable = false;
  networking.firewall.enable = false;

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "lat9w-16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  programs.ssh.setXAuthLocation = true;

  services.openssh.enable = true;
  services.openssh.ports = [my_ssh_port];
  services.openssh.permitRootLogin = "yes";
  services.openssh.gatewayPorts = "yes";
  services.openssh.forwardX11 = true;

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql92;
  };

  services.xserver.enable = false;

  services.httpd = {
    enable = true;
    adminAddr = "grrwlf@gmail.com";
    logPerVirtualHost = true;
    virtualHosts = [
      {
        hostName = "callback.hit.msk.ru";
        globalRedirect = "http://hit.msk.ru:8080/";
      }
      {
        hostName = "uru.hit.msk.ru";
        globalRedirect = "http://hit.msk.ru:8081/";
      }
      {
        hostName = "compet.hit.msk.ru";
        globalRedirect = "http://hit.msk.ru:8082/";
      }
      {
        hostName = "urweb.hit.msk.ru";
        globalRedirect = "http://hit.msk.ru:8083/";
      }
      {
        hostName = "archerydays.ru";
        extraConfig = ''
          ProxyPreserveHost On
          ProxyRequests Off
          ServerName www.archerydays.ru
          ServerAlias archerydays.ru
          ProxyPassMatch "^/$" http://127.0.0.1:8080/Etab/main
          ProxyPassMatch "^.*$" http://127.0.0.1:8080
          ProxyPassReverse / http://127.0.0.1:8080/
        '';
      }
    ];
  };


  services.haproxy = {
    enable = true;
    config = ''

      backend secure_http
          reqadd X-Forwarded-Proto:\ https
          rspadd Strict-Transport-Security:\ max-age=31536000
          mode http
          option httplog
          option forwardfor
          server local_http_server 127.0.0.1:80

      backend ssh
          mode tcp
          option tcplog
          server ssh 127.0.0.1:${toString my_ssh_port}
          timeout server 2h

      frontend ssl
          bind 0.0.0.0:443 ssl crt ${../ideas/stunnel-test/stunnel.pem} no-sslv3
          mode tcp
          option tcplog
          tcp-request inspect-delay 5s
          tcp-request content accept if HTTP

          acl client_attempts_ssh payload(0,7) -m bin 5353482d322e30

          use_backend ssh if !HTTP
          use_backend ssh if client_attempts_ssh
          use_backend secure_http if HTTP
    '';
  };

  environment.systemPackages = with pkgs ; [
    vimHugeX
    (devenv {
      name = "dev";
      extraPkgs = [ haskell710 ];
    })
    postgresql
    imagemagick
    mlton
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };
}

# ImageBuilder Scripts for OpenWRT

My collection of image building scripts for openwrt images.

## Install

After cloning this repo use egit to fetch private files. If packages are not installed (see [openwrt docs](https://openwrt.org/docs/guide-user/additional-software/imagebuilder)) there is a helper for Ubunut/Debian.

```shell
sudo apt install $(cat build_req)
```

Download and extract the appropriate imagebuilder tarball.

## Using The Scripts

Edit the build script as desired, but the only required update is to the version number. When copying be sure to consdier the device type etc. to set up the appropriate defaults.

Then, run the desired script. The following switches are in current scripts.

### First switches

-h | --help
    Print help text

-v | --verbose
    Output log during run

### Config switches (non-default run)

```shell
--no-router
```

Do not install firewall/routing packages

```shell
--keep-pppoe
```

Do not **remove** pppoe packages

```shell
--no-ipv6
```

Remove IPv6 packages

```shell
--no-luci
```

Do not install LUCI WebUI packages

```shell
--luci-ssl | --luci-mbedtls
```

Install mbedtls for HTTPS WebUI

```shell
--luci-openssl
```

Install openssl for HTTPS WebUI

```shell
-p | +p
```

Add or remove a single package

```shell
--
```

End build script argument capture

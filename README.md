# PS.SSL

Module wraps Openssl for creating SSL certificate signing requests and other common tasks

## Prerequisites

This module requires Openssl.
To install Openssl on Windows using either winget or chocolatey, use the code below.

```pwsh
# USING CHOCOLATEY
choco install openssl

# USING WINGET
winget install --Id ShiningLight.OpenSSL

# OR
winget install --Id ShiningLight.OpenSSL.Light
```

To install Openssl on mac OS using Homebrew, use the code below.

```sh
brew install openssl@3
```

To install Openssl on Debian-based Linux, use the follow code.

```sh
# UPDATE PACKAGE LIST
sudo apt update

# INSTALL OPENSSL
sudo apt install openssl -y
```

## Updates

Please see release information for updates

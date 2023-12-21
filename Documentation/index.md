# PS.SSL

Module for creating SSL certificate signing requests

## Prerequisites

Openssl

## Updates

### v0.1.8

- Module will now load without openssl (warning is still presented and openssl required)
- Updated warning language

### v0.1.7

- Added parameter "WindowsCompatible" to Export-PFX to support import on Windows OS

### v0.1.6

- Added function Export-CertificateData to export individual components of a PEM certificate
- Added check for Openssl on the path

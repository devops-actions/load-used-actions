FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:6cf4107b343487fa6f6a34ae0f12fc9482897f9002aede4ef9077cebb8cb4400

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

FROM ghcr.io/rajbos/actions-marketplace/powershell:7

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

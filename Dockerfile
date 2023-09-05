FROM ghcr.io/rajbos/actions-marketplace/powershell:7

COPY /Src/PowerShell/*.ps1 /src/

ENV DOCKER=true

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

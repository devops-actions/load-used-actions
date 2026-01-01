FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:a9fe9a6cb3a2fc18c763899d3e7c0e1863cda5bfd02076e6d4b9accc90df078e

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

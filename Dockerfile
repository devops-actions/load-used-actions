FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:3eb16c1bc7295f1f79c802d876e051dca876819bbb2250bb596d760461a3e7f4

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

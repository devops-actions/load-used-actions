FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:5b46b0645f5bdb12e7e5aedf4dcf725fd84968a25b04de1d8fc8e23b2f23901c

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

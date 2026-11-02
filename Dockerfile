FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:2b8e866c85a2c0380627969f14e6d3493242ab925bb8cafc8e9872354088bd93

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

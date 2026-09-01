FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:d656354c3e416e7d35c2c275ab52308fc8846656db9c203e5cf23589dee0ed0f

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

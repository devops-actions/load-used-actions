FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:b31a6cc258156ee20f3faa06452d70a672617a1a740abe11f237ac6293cc3ffb

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

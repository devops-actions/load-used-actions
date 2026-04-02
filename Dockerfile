FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:0035e9b6bf5882238615e615124965ce3595d03184cca47406c9acb2c4bedfa9

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

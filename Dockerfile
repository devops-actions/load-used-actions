FROM ghcr.io/rajbos/actions-marketplace/powershell:7@sha256:f9581e82b22405506b54152ef4ae0445aa2afcdef36aebab9379724c3ec2b561

ENV DOCKER=true

COPY /Src/PowerShell/*.ps1 /src/

ENTRYPOINT ["pwsh", "/src/entrypoint.ps1"]

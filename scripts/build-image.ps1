param(
    [string]$ImageTag = "slugterra-api:dev"
)

$rootDir = Split-Path -Parent $PSScriptRoot
Set-Location $rootDir

docker build -f docker/Dockerfile -t $ImageTag .

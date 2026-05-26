# use the 730MB sdk image to build
FROM mcr.microsoft.com/dotnet/sdk AS builder

# install the latest version of PowerShell
RUN dotnet tool install -g PowerShell

# discard all the builder data then just copy the required changed files from "builder" to the smaller 180MB base image
#FROM mcr.microsoft.com/dotnet/runtime
#COPY --from=builder /root/.dotnet/tools/ /bin

# install git and ssh client (required by git when cloning/fetching over SSH remotes)
RUN apt-get update && apt-get install -y --no-install-recommends git openssh-client && rm -rf /var/lib/apt/lists/*

# run powershell
ENTRYPOINT ["pwsh"]

@echo off
msbuild %~dp0\ExampleConsole.csproj /p:DeployOnBuild=true /p:PublishProfile=Dev /p:VisualStudioVersion=12.0
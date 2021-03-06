set-psdebug -strict -trace 0

$currentDirectory = split-path $MyInvocation.MyCommand.Definition -parent

$modPath = Join-Path -Path $currentDirectory -ChildPath "PublishIntModule.psm1"
$modFileName = (Get-Item $modPath).BaseName



# load the module, make sure it's a fresh copy
if((Get-Module -Name $modFileName)){
    Remove-Module $modFileName
}

Import-Module $modPath -DisableNameChecking

# load psexpect resources
if (!(Test-Path variable:_TESTLIB)) {
    $testLib = Join-Path -Path $currentDirectory -ChildPath "psexpect\TestLib.ps1"
    & $testLib
}

# Define any common functions here
function global:ExitScript {
    param($succeeded,$sourceScriptFile)
    
    if(!($succeeded)) {
        "Found at least 1 failing test inside of the file [{0}]" -f $sourceScriptFile | Write-Warning
        exit 1
    }
}
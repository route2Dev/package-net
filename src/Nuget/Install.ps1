param($rootPath, $toolsPath, $package, $project)

# When the package is installed into a project we need to perform the following steps:
# 1. Create a .wpp.targets file if it doesn't already exist
# 2. If the .wpp.targets doesn't have an import for Sedodream.Package.proj then insert one

$pwMsbuildLabel = "PackageWeb"

function WriteParamsToFile {
    param([string]$filePath)
    
    $strToWrite="rootPath={0}`r`ntoolsPath={1}`r`npackage={2}`r`nproject path={3}`r`n" -f $rootPath, $toolsPath, $package, $project.FullName
    
    Write-Debug ("params: {0}" -f $strToWrite)
    
    $strToWrite | Out-File $filePath
}

function CreateWppTargetsFile {
    param($project)
    
    $projName = $project.Name
    $projFile = Get-Item ($project.FullName)
    $projDirectory = $projFile.DirectoryName
    
    $wppTargetsPath = Join-Path $projDirectory -ChildPath ("{0}.wpp.targets" -f $projName)
    $wppTargetsExists = Test-Path $wppTargetsPath
    
    
    $msbuildProj = $null
    $projCollection = New-Object Microsoft.Build.Evaluation.ProjectCollection
    if(!($wppTargetsExists)) {
        Write-Debug ("    Creating MSBuild file at {0}" -f $wppTargetsPath) | Out-Null
        # create a new file there        
        $msbuildProj = (New-Object Microsoft.Build.Evaluation.Project -ArgumentList $projCollection)
        $msbuildProj.Save($wppTargetsPath)
    }
    else {
        # file already exists let's load it
        Write-Debug ("    MSBuild file already exists at {0}" -f $wppTargetsPath) | Out-Null
        $projCollection.LoadProject($wppTargetsPath) | Out-Null
    }
    
    $projRoot = [Microsoft.Build.Construction.ProjectRootElement]::Open($wppTargetsPath)
    # now we need to see if the file has the import that we are looking to add
    $wppTargetsHasImport = DoesProjectHaveImport -projRoot $projRoot
    
    if(!($wppTargetsHasImport)) {
        # we need to add an import to that file now
        AddImportToWppTargets -projRoot $projRoot
    }
    
    # add the .wpp.targets file to the project so that it gets checked in
    $project.ProjectItems.AddFromFile($wppTargetsPath) | Out-Null
    $project.Save() | Out-Null
}

function AddImportToWppTargets {
    param($projRoot)
   
    $targetsPropertyName = "PackageWebTargetsPath"
    $importFileName = "Sedodream.Package.targets"
    $importPath = ("`$(MSBuildProjectDirectory)\_Package\{0}" -f $importFileName)
    $importCondition = " '`$(PackageWebTargetsPath)'=='' "
    
    # add the property for the import location 
    $propGroup = $projRoot.AddPropertyGroup()
    $ppe = $propGroup.AddProperty($targetsPropertyName,$importPath)
    $e = $ppe.Condition = (" '`$({0})'=='' " -f $ppe.Name)
    $propGroup.Label = $pwMsbuildLabel
	
    # add the import itself
    $importStr = ("`$({0})" -f $targetsPropertyName)
    $importElement = $projRoot.AddImport($importStr)
    $importElement.Label = $pwMsbuildLabel
    $importElement.Condition= ("Exists('{0}')" -f $importStr)
    $projRoot.Save() | Out-Null
}

function DoesProjectHaveImport {
    param($projRoot)
        
    $hasImport = $false
    foreach($pie in $projRoot.Imports) {
        # see if it has the expected label
        if($pie -ne $null -and $pie.Label -ne $null -and $pie.Label.Trim() -ceq $pwMsbuildLabel) {
            $hasImport = $true
            break
        }               
    }
    
    return $hasImport
}

function AddDependentPropertyGroup {
	param($projRoot)
	
	$propGroup = GetPublishDependencyPropertyGroup -projRoot $projRoot
	if($propGroup -eq $null) {
		# add the property group 
		$propGroup = $projRoot.AddPropertyGroup()
	}

	# add the dependencies if they do not exist.
	AddVisualStudioVersion -propGroup $propGroup
	AddToolsPath -propGroup $propGroup		
}

function AddWebDeployImport {
	param($projRoot)
	
	$importPath = '$(VSToolsPath)\WebApplications\Microsoft.WebApplication.targets'
	
	$hasImport = DoesProjectHaveWebDeployImports -projRoot $projRoot -importPath $importPath
	
	if(!($hasImport)) {
		$importElement = $projRoot.AddImport($importPath)
		$importElement.Condition = (" '`$({0})'=='' " -f "VSToolsPath")
	}	
}

function GetPublishDependencyPropertyGroup{
	param($projRoot)
	
	$propGroup = $null
	foreach($pge in $projRoot.PropertyGroups) {
		if($pge -ne $null) {
			foreach($ppe in $pge.Properties) {
				if($ppe -ne $null -and ($ppe.Name -eq $visualStudioVersionPropertyName -or $ppe.Name -eq $vsToolsPathPropertyName)) {
					$propGroup = $pge
					break
				}
			}
		}
	}
	
	return $propGroup;	
}

function AddVisualStudioVersion {
	param($propGroup)
	
	$hasProperty = $false
	
	foreach($ppe in $propGroup.Properties) {
		if((PropertyExists -projProp $ppe -name $visualStudioVersionPropertyName)) {
			$hasProperty = $true
			break;
		}		
	}	
	
	if(!($hasProperty)) {
		$ppe = $propGroup.AddProperty($visualStudioVersionPropertyName, "10.0")
		$e = $ppe.Condition = (" '`$({0})'=='' " -f $ppe.Name)		
	}
}

function AddToolsPath {
	param($propGroup)
	
	$toolsPath = '$(MSBuildExtensionsPath32)\Microsoft\VisualStudio\v$(VisualStudioVersion)'
	
	$hasProperty = $false
	
	foreach($ppe in $propGroup.Properties) {
		if((PropertyExists -projProp $ppe -name $vsToolsPathPropertyName)) {
			$hasProperty = $true
			break;
		}		
	}	
	
	if(!($hasProperty)) {
		$ppe = $propGroup.AddProperty($vsToolsPathPropertyName, $toolsPath)
		$e = $ppe.Condition = (" '`$({0})'=='' " -f $ppe.Name)		
	}
}

function PropertyExists {
	param($projProp, [string]$name)
	
	$hasProperty = $false;
	if($projProp -ne $null -and $projProp.Name.Trim() -eq $name) {
		$hasProperty = $true 
	}
	
	return $hasProperty
}

function DoesProjectHaveWebDeployImports {
    param($projRoot, [string]$importPath)
        
    $hasImport = $false
    foreach($pie in $projRoot.Imports) {
        # see if it has the Project
        if($pie -ne $null -and $pie.Project.Trim() -ceq $importPath) {
            $hasImport = $true
            break
        }               
    }
    
    return $hasImport
}

# WriteParamsToFile -filePath "C:\temp\sayedha-ps.txt"

$visualStudioVersionPropertyName = "VisualStudioVersion"
$vsToolsPathPropertyName = "VSToolsPath"

$projectMSBuild = [Microsoft.Build.Construction.ProjectRootElement]::Open($project.FullName)

# If this isn't a web project we need to add the necessary elements to support the publish.
AddDependentPropertyGroup -projRoot $projectMSBuild
AddWebDeployImport - -projRoot $projectMSBuild

CreateWppTargetsFile -project $project






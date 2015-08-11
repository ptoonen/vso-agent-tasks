param (
    [string]$mavenPOMFile,
    [string]$options,
    [string]$goals,
    [string]$publishJUnitResults,   
    [string]$testResultsFiles, 
    [string]$jdkVersion,
    [string]$jdkArchitecture,
    [string]$sqAnalysisEnabled, 
    [string]$sqConnectedServiceName, 
    [string]$sqDbDetailsRequired,
    [string]$sqDbUrl,
	[string]$sqDbUsername,
	[string]$sqDbPassword)


Write-Verbose -Verbose 'Entering Maven.ps1'
Write-Verbose -Verbose "mavenPOMFile = $mavenPOMFile"
Write-Verbose -Verbose "options = $options"
Write-Verbose -Verbose "goals = $goals"
Write-Verbose -Verbose "publishJUnitResults = $publishJUnitResults"
Write-Verbose -Verbose "testResultsFiles = $testResultsFiles"
Write-Verbose -Verbose "jdkVersion = $jdkVersion"
Write-Verbose -Verbose "jdkArchitecture = $jdkArchitecture"

Write-Verbose -Verbose "sqAnalysisEnabled = $sqAnalysisEnabled"
Write-Verbose -Verbose "connectedServiceName = $sqConnectedServiceName"
Write-Verbose -Verbose "sqDbDetailsRequired = $sqDbDetailsRequired"
Write-Verbose -Verbose "dbUrl = $sqDbUrl"
Write-Verbose -Verbose "dbUsername = $sqDbUsername"

# Verify Maven POM file is specified
if(!$mavenPOMFile)
{
    throw "Maven POM file is not specified"
}

# Import the Task.Internal dll that has all the cmdlets we need for Build
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.TestResults"

. ./mavenHelper.ps1

# Use a specific JDK
ConfigureJDK $jdkVersion $jdkArchitecture

# Invoke MVN
Write-Host "Running Maven..."
Invoke-Maven -MavenPomFile $mavenPOMFile -Options $options -Goals $goals -ErrorVariable mavenError

if ($mavenError)
{
    # The Invoke-Maven cmdlet will have logged the error message by itself, 
    # but the script still needs to be stopped
    return;
}

# Publish test results
PublishTestResults $publishJUnitResults $testResultsFiles

# Run SonarQUbe analysis by invoking Maven with the "sonar:sonar" goal
RunSonarQubeAnalysis $sqAnalysisEnabled $sqConnectedServiceName $sqDbDetailsRequired $sqDbUrl $sqDbUsername $sqDbPassword $options $mavenPOMFile

Write-Verbose "Leaving script Maven.ps1"





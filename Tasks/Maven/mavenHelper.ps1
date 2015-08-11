function ConfigureJDK
{
	param([string]$jdkVersion, [string]$jdkArchitecture)

	if($jdkVersion -and $jdkVersion -ne "default")
	{
		$jdkPath = Get-JavaDevelopmentKitPath -Version $jdkVersion -Arch $jdkArchitecture
		if (!$jdkPath) 
		{
			throw "Could not find JDK $jdkVersion $jdkArchitecture, please make sure the selected JDK is installed properly"
		}

		Write-Host "Setting JAVA_HOME to $jdkPath"
		$env:JAVA_HOME = $jdkPath
		Write-Verbose "JAVA_HOME set to $env:JAVA_HOME"
	}
}

function PublishTestResults
{
	param([string]$publishJUnitResults,
		  [string]$testResultsFiles)

	$publishJUnitResultsFromAntBuild = Convert-String $publishJUnitResults Boolean

	if($publishJUnitResultsFromAntBuild)
	{
	   # check for JUnit test result files
		$matchingTestResultsFiles = Find-Files -SearchPattern $testResultsFiles
		if (!$matchingTestResultsFiles)
		{
			Write-Host "No JUnit test results files were found matching pattern '$testResultsFiles', so publishing JUnit test results is being skipped."
		}
		else
		{
			Write-Verbose "Calling Publish-TestResults"
			Publish-TestResults -TestRunner "JUnit" -TestResultsFiles $matchingTestResultsFiles -Context $distributedTaskContext
		}    
	}
	else
	{
		Write-Verbose "Option to publish JUnit Test results produced by Maven build was not selected and is being skipped."
	}
}

function RunSonarQubeAnalysis
{
	param([string]$sqAnalysisEnabled,
		  [string]$sqConnectedServiceName,
		  [string]$sqDbDetailsRequired,
		  [string]$sqDbUrl,
		  [string]$sqDbUsername,
		  [string]$sqDbPassword, 
		  [string]$userOptions,
		  [string]$mavenPOMFile)

	# SonarQube Analysis - there is a known issue with the SonarQube Maven plugin that the sonar:sonar goal should be run independently
	$sqAnalysisEnabledBool = Convert-String $sqAnalysisEnabled Boolean

	if ($sqAnalysisEnabledBool)
	{
		$sqServiceEndpoint = GetSonarQubeEndpointData $sqConnectedServiceName
		$sqDbDetailsRequiredBool = Convert-String $sqDbDetailsRequired Boolean 

		if ($sqDbDetailsRequiredBool)
		{
			$sqArguments = CreateSonarQubeArgs $sqServiceEndpoint.Url $sqServiceEndpoint.Authorization.Parameters.UserName $sqServiceEndpoint.Authorization.Parameters.Password $sqDbUrl $sqDbUsername $sqDbPassword
		}
		else
		{
			# The platform may cache the db details values so we force them to be empty
			$sqArguments = CreateSonarQubeArgs $sqServiceEndpoint.Url $sqServiceEndpoint.Authorization.Parameters.UserName $sqServiceEndpoint.Authorization.Parameters.Password "" "" ""
		}

		$sqArguments = $userOptions + $sqArguments
		Write-Verbose -Verbose "sonar:sonar options: $sqArguments"

		Invoke-Maven -MavenPomFile $mavenPOMFile -Options $sqArguments -Goals "sonar:sonar"
	 }
}

# Retrieves the url, username and password from the specified generic endpoint.
# Only UserNamePassword authentication scheme is supported for SonarQube.
function GetSonarQubeEndpointData
{
	param([string][ValidateNotNullOrEmpty()]$connectedServiceName)

	$serviceEndpoint = Get-ServiceEndpoint -Context $distributedTaskContext -Name $connectedServiceName

	if (!$serviceEndpoint)
	{
		throw "A Connected Service with name '$ConnectedServiceName' could not be found.  Ensure that this Connected Service was successfully provisioned using the services tab in the Admin UI."
	}

	$authScheme = $serviceEndpoint.Authorization.Scheme
	if ($authScheme -ne 'UserNamePassword')
	{
		throw "The authorization scheme $authScheme is not supported for a SonarQube server."
	}

    return $serviceEndpoint
}

# Creates a string with command line params that the SQ-Maven plugin understands 
function CreateSonarQubeArgs
{
    param(
          [string]$serverUrl,
	      [string]$serverUsername,
		  [string]$serverPassword,
		  [string]$dbUrl,
		  [string]$dbUsername,
		  [string]$dbPassword)
	
    $sb = New-Object -TypeName "System.Text.StringBuilder"; 

    # Append is a fluent API, i.e. it returns the StringBuilder. However powershell will return the data and use it in the return value.
    # To avoid this, force it to ignore the Append return value using [void]

    if (![String]::IsNullOrWhiteSpace($serverUrl))
    {    
        [void]$sb.Append("-Dsonar.host.url=""$serverUrl""")
    }

    if (![String]::IsNullOrWhiteSpace($serverUsername))
    {
        [void]$sb.Append(" -Dsonar.login=""$serverUsername""")
    }

    if (![String]::IsNullOrWhiteSpace($serverPassword))
    {
        [void]$sb.Append(" -Dsonar.password=""$serverPassword""")
    }

    if (![String]::IsNullOrWhiteSpace($dbUrl))
    {
        [void]$sb.Append(" -Dsonar.jdbc.url=""$dbUrl""")
    }

    if (![String]::IsNullOrWhiteSpace($dbUsername))
    {
        [void]$sb.Append(" -Dsonar.jdbc.username=""$dbUsername""")
    }

    if (![String]::IsNullOrWhiteSpace($dbPassword))
    {
        [void]$sb.Append(" -Dsonar.jdbc.password=""$dbPassword""")
    }

    return $sb.ToString();
}


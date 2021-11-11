<#
.SYNOPSIS
    Downloads and installs the latest version of the CrowdStrike Sensor

.DESCRIPTION
    This script will download and install the latest version of the CrowdStrike Sensor by connecting to your CrowdStrike tenant's API. 
    Requires the following information from your tenant
        - CrowdStrike Customer ID
        - CrowdStrike API Client ID
        - CrowdStrike API Client Secret
.EXAMPLE
    .\CrowdStrike-Sensor-Download-and-Install.ps1 -CrowdStrike_Client_ID "<Client ID>" -CrowdStrike_Client_Secret "<Client Secret>" -CrowdStrike_Customer_ID "<Customer ID>"

.NOTES
    The CrowdStrike Customer ID can be obtained from Hosts > Sensor Downloads in the Falcon Console and is a 35 character string
    A CrowdStrike API Client can be generated from Support > API Clients and Keys in the Falcon Console. Create a new API client as follows:
        Name: CrowdStrike Sensor Deployment - Read
        Scope: Sensor Download - Read
#>

PARAM
(
    # Argument: CrowdStrike_Client_ID
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [String]$CrowdStrike_Client_ID,

    # Argument: CrowdStrike_Client_Secret
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [String]$CrowdStrike_Client_Secret,

    # Argument: CrowdStrike_Customer_ID
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [String]$CrowdStrike_Customer_ID,

    # Argument: CrowdStrike_BaseURL
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [String]$CrowdStrike_BaseURL,

    # Argument: Log
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [Switch]$Log
)

IF ($CrowdStrike_BaseURL)
{
    $BaseURL = $CrowdStrike_BaseURL
}
ELSE
{
    $BaseURLList = @()
    $BaseURLList += "api.crowdstrike.com"
    $BaseURLList += "api.US-2.crowdstrike.com"
    $BaseURLList += "api.EU-1.crowdstrike.com"
}

$exitcode = 0
$global:Log = $Log
$global:CurrentUser = [Environment]::UserName
$global:TZbias = (Get-WmiObject -Query "Select Bias from Win32_TimeZone").bias
$global:StartDateTime = Get-Date -Format "HHmmss"
$global:WorkingPath = (Get-Item -Path ".\").FullName
IF ($MyInvocation.MyCommand.Name)
{
    $global:LogFileName = ($MyInvocation.MyCommand.Name).Replace(".ps1","")
}
ELSE
{
    $global:LogFileName = "ScriptLog"
}
# Function - Output to log file #####################################################################################################################################################################################

FUNCTION OutputToLog($LogText,$Type)
{
    ##Output to Log
    $ErrorActionPreference = "SilentlyContinue"
    $Time = Get-Date -Format "HH:mm:ss.fff"
    $Date = Get-Date -Format "MM-dd-yyyy"
    $LogOutput = "<![LOG[$($LogText)]LOG]!><time=`"$($Time)+$($global:TZBias)`" date=`"$($Date)`" component=`"$global:LogFileName`" context=`"$($Context)`" type=`"$($Type)`" thread=`"$($global:StartDateTime)`" file=`"$($global:CurrentUser)`">"
    IF ((Get-Content "$global:WorkingPath\$global:LogFileName.log" -ErrorAction SilentlyContinue).Count -gt 1000)
    {
        DO
        {
            $ReadCurrentLog = Get-Content "$global:WorkingPath\$global:LogFileName.log"
            $FirstLine = $ReadCurrentLog[0]
            $ReadCurrentLog | where {$_ -ne $FirstLine} | out-file "$global:WorkingPath\$global:LogFileName.log" -Encoding Default
        }
        WHILE((Get-Content "$global:WorkingPath\$global:LogFileName.log").Count -gt 1000)
    }    
    Out-File -InputObject $LogOutput -Append -NoClobber -Encoding Default �FilePath "$global:WorkingPath\$global:LogFileName.log"
}

#####################################################################################################################################################################################################################

# Function - End Script #############################################################################################################################################################################################

FUNCTION End-Script
{
    PARAM
    (
        # Argument: ExitCode
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [int]$ExitCode
    )

    IF ($global:Log){OutputToLog -LogText "+++End thread+++" -Type 1}
    $host.SetShouldExit($ExitCode)
    exit
}

#####################################################################################################################################################################################################################

IF ($global:Log){OutputToLog -LogText "+++Starting thread+++" -Type 1}

IF ($global:Log){OutputToLog -LogText "Identifying region" -Type 1}
IF ($global:Log){OutputToLog -LogText "Requesting access token" -Type 1}

ForEach ($BaseURL in $BaseURLList)
{
    $TokenParams = @{
        "Uri" = "https://${BaseURL}/oauth2/token"
        "Method" = "post"
        "Headers" = @{
            "accept" = "application/json"
            "content-type" = "application/x-www-form-urlencoded"
        }
        Body = "client_id=${CrowdStrike_Client_ID}&client_secret=${CrowdStrike_Client_Secret}"
    }

    TRY
    {
        IF ($global:Log){OutputToLog -LogText "Testing: $BaseURL" -Type 1}
        $Token = Invoke-RestMethod @TokenParams
        break
    }
    CATCH
    {
        IF ($global:Log){OutputToLog -LogText "Failed with exit code $($_.Exception.Response.StatusCode.value__): $($_.Exception.Response.StatusDescription)" -Type 2}
    }
}
IF ($Token)
{
    IF ($global:Log){OutputToLog -LogText "Identified API region as $BaseURL" -Type 1}
    IF ($global:Log){OutputToLog -LogText "Successfully retrieved access token" -Type 1}
}
ELSE
{
    IF ($global:Log){OutputToLog -LogText "Failed to identify region" -Type 3}
    End-Script 1
}

TRY
{
    IF ($global:Log){OutputToLog -LogText "Searching for Sensor downloads options" -Type 1}

    $SensorsParams = @{
    "Uri" = ("https://${BaseURL}/sensors/combined/installers/v1")
    "Method" = "get"
    "Headers" = @{
        "accept" = 'application/json'
        "authorization" = "$($Token.token_type) $($Token.access_token)"
        }
    }

    $Sensors = Invoke-RestMethod @SensorsParams -ErrorAction Stop

    IF ($global:Log){OutputToLog -LogText "Found $(($Sensors.resources | Where-Object {$_.os -like "Windows"}).Count) Windows sensors available for downlaod" -Type 1}

    $LatestWindowsSensor = $Sensors.resources | Where-Object {$_.os -like "Windows"} | Sort-Object version | Select-Object -Last 1
    $SensorsID = $LatestWindowsSensor | Select-Object -ExpandProperty sha256
    $SensorsVersion = $LatestWindowsSensor | Select-Object -ExpandProperty version

    IF ($global:Log){OutputToLog -LogText "Latest Sensor version: $SensorsVersion" -Type 1}
}
CATCH
{
    IF ($global:Log){OutputToLog -LogText "Failed with exit code $($_.Exception.Response.StatusCode.value__): $($_.Exception.Response.StatusDescription)" -Type 3}
    End-Script 1
}

TRY
{
    IF ($global:Log){OutputToLog -LogText "Downloading CrowdStrike Sensor" -Type 1}

    $SensorDownloadParams = @{
        "Uri" = ("https://${BaseURL}/sensors/entities/download-installer/v1?id=${SensorsID}")
        "Method" = "get"
        "Headers" = @{
            "accept" = "application/json"
            "authorization" = "$($Token.token_type) $($Token.access_token)"
        }
    }

    $DownloadFilePath = ("$global:WorkingPath\CrowdStrikeSensor-$SensorsVersion.exe")

    Invoke-WebRequest @SensorDownloadParams -OutFile $DownloadFilePath -Verbose

    IF (Test-Path $DownloadFilePath)
    {
        IF ($global:Log){OutputToLog -LogText "Failed to download Sensor" -Type 3}
        End-Script 1
    }
    ELSE
    {
        IF ($global:Log){OutputToLog -LogText "Successfully downloaded Windows Sensor $SensorsVersion" -Type 1}
    }
    
}
CATCH
{
    IF ($global:Log){OutputToLog -LogText "Failed with exit code $($_.Exception.Response.StatusCode.value__): $($_.Exception.Response.StatusDescription)" -Type 3}
    End-Script 1
}

TRY
{
    Start-Process -FilePath $DownloadFilePath -argumentlist "/install /quiet /norestart CID=$CrowdStrike_Customer_ID" -Verbose

    IF ($global:Log){OutputToLog -LogText "Successfully installed CrowdStrike Sensor" -Type 1}
    End-Script 0
}
CATCH
{
    IF ($global:Log){OutputToLog -LogText "Failed with exit code $($_.Exception.Response.StatusCode.value__): $($_.Exception.Response.StatusDescription)" -Type 3}
    End-Script 1
}

End-Script 0
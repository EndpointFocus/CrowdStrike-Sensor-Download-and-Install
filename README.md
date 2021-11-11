# CrowdStrike-Sensor-Download-and-Install
Script to download and install the latest CrowdStrike Sensor

## Pre-Requisites
The script requires the following arguments
- CrowdStrike Customer ID
- CrowdStrike API Client ID
- CrowdStrike API Client Secret

When creating the CrowdStrike API Client, only the `Sensor Download ; Read` scope is required

## Usage
The script can be deployed with any automation tool, and is executed as follows:
`.\CrowdStrike-Sensor-Download-and-Install.ps1 -CrowdStrike_Client_ID "<Client ID>" -CrowdStrike_Client_Secret "<Client Secret>" -CrowdStrike_Customer_ID "<Customer ID>"`
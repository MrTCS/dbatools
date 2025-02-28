function Get-DbaInstalledPatch {
    <#
    .SYNOPSIS
        Retrives a historical list of all SQL Patches (CUs, Service Packs & Hot-fixes) installed on a Computer.

    .DESCRIPTION
        Retrives a historical list of all SQL Patches (CUs, Service Packs & Hot-fixes) installed on a Computer.

        To test to see if your build is up to date, use Test-DbaBuild.

    .PARAMETER ComputerName
        Allows you to specify a comma separated list of servers to query.

    .PARAMETER Credential
        Credential object used to connect to the Computer as a different user.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Deployment, Updates, Patches
        Author: Hiram Fleitas, @hiramfleitas, fleitasarts.com
        Website: https://dbatools.io
        Copyright: (c) 2021 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaInstalledPatch

    .EXAMPLE
        PS C:\> Get-DbaInstalledPatch -ComputerName HiramSQL1, HiramSQL2

        Gets a list of SQL Server patches installed on HiramSQL1 and HiramSQL2.

    .EXAMPLE
        PS C:\> Get-Content C:\Monitoring\Servers.txt | Get-DbaInstalledPatch

        Gets the SQL Server patches from a list of computers in C:\Monitoring\Servers.txt.

    .EXAMPLE
        PS C:\> Get-DbaInstalledPatch -ComputerName SRV1 | Sort-Object InstallDate.Date

        Gets the SQL Server patches from SRV1 and orders by date. Note that we use
        a special customizable date datatype for InstallDate so you'll need InstallDate.Date

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [DbaInstanceParameter[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [switch]$EnableException
    )
    process {
        foreach ($computer in $ComputerName.ComputerName) {
            try {
                $patches = Invoke-Command2 -ComputerName $computer -Credential $Credential -ScriptBlock {
                    Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -like "Hotfix*SQL*" -or $_.DisplayName -like "Service Pack*SQL*" } | Sort-Object InstallDate
                }
            } catch {
                Stop-Function -Message "Failed" -Continue -Target $computer -ErrorRecord $_
            }

            foreach ($patch in $patches) {
                [pscustomobject]@{
                    ComputerName = $computer
                    Name         = $patch.DisplayName
                    Version      = $patch.DisplayVersion
                    InstallDate  = [DbaDate][datetime]::ParseExact($patch.InstallDate, 'yyyyMMdd', $null)
                }
            }
        }
    }
}
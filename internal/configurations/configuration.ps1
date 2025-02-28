<#

#-------------------------#
# Warning Warning Warning #
#-------------------------#

This is the global configuration management file.

DO NOT EDIT THIS FILE!!!!!
Disobedience shall be answered by the wrath of Fred.
You've been warned.
;)

The purpose of this file is to manage the configuration system.
That means, messing with this may mess with every function using this infrastructure.
Don't, unless you know what you do.

#---------------------------------------#
# Implementing the configuration system #
#---------------------------------------#

The configuration system is designed, to keep as much hard coded configuration out of the functions.
Instead we keep it in a central location: The Configuration store (= this folder).

In Order to put something here, either find a configuration file whose topic suits you and add configuration there,
or create your own file. The configuration system is loaded last during module import process, so you have access to all
that dbatools has to offer (Keep module load times in mind though).

Examples are better than a thousand words:

a) Setting the configuration value
# Put this in a configuration file in this folder
Set-DbatoolsConfig -Name 'Path.DbatoolsLog' -Value "$([System.Environment]::GetFolderPath("ApplicationData"))\PowerShell\dbatools" -Initialize -Description "Sopmething meaningful here"

b) Retrieving the configuration value in your function
# Put this in the function that uses this setting
$path = Get-DbatoolsConfigValue -Name 'Path.DbatoolsLog' -FallBack $Env:TEMP

# Explanation #
#-------------#

In step a), which is run during module import, we assign the configuration of the name 'Path.DbatoolsLog' the value "$([System.Environment]::GetFolderPath("ApplicationData"))\PowerShell\dbatools"
Unless there already IS a value set to this name (that's what the '-Default' switch is doing).
That means, that if a user had a different configuration value in his profile, that value will win. Userchoice over preset.
ALL configurations defined by the module should be 'default' values.

In step b), which will be run whenever the function is called within which it is written, we retrieve the value stored behind the name 'Path.DbatoolsLog'.
If there is nothing there (for example, if the user accidentally removed or nulled the configuration), then it will fall back to using "$($env:temp)\dbatools.log"

#>
#region Paths
$psVersionName = "WindowsPowerShell"
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $psVersionName = "PowerShell"
}

Write-ImportTime -Text "Config system: Set paths"

#region User Local
if ($IsLinux -or $IsMacOs) {
    # Defaults to $Env:XDG_CONFIG_HOME on Linux or MacOS ($HOME/.config/)
    $fileUserLocal = $Env:XDG_CONFIG_HOME
    if (-not $fileUserLocal) {
        $fileUserLocal = [IO.Path]::Combine($HOME, ".config/")
    }

    $script:path_FileUserLocal = [IO.Path]::Combine($fileUserLocal, $psVersionName, "dbatools/")
} else {
    # sets some paths
    $script:path_RegistryUserDefault = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\dbatools\Config\Default"
    $script:path_RegistryUserEnforced = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\dbatools\Config\Enforced"
    $script:path_RegistryMachineDefault = "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\dbatools\Config\Default"
    $script:path_RegistryMachineEnforced = "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\dbatools\Config\Enforced"

    # Defaults to $localappdatapath on Windows
    if ($env:LOCALAPPDATA) {
        $localappdatapath = $env:LOCALAPPDATA
    } else {
        $localappdatapath = [System.Environment]::GetFolderPath("LocalApplicationData")
    }
    $script:path_FileUserLocal = [IO.Path]::Combine($localappdatapath, "$psVersionName\dbatools\Config")
    if (-not $script:path_FileUserLocal) {
        $script:path_FileUserLocal = [IO.Path]::Combine([Environment]::GetFolderPath("LocalApplicationData"), "$psVersionName\dbatools\Config")
    }
}
Write-ImportTime -Text "Config system: Set more paths using Join-Path"
#endregion User Local

#region User Shared
if ($IsLinux -or $IsMacOs) {
    # Defaults to the first value in $Env:XDG_CONFIG_DIRS on Linux or MacOS (or $HOME/.local/share/)
    # Defaults to $HOME .local/share/
    # It previously was picking the first value in $Env:XDG_CONFIG_DIRS, but was causing and exception with ubuntu and xdg, saying that access to path /etc/xdg/xdg-ubuntu is denied.
    $fileUserShared = [IO.Path]::Combine($HOME, ".local/share/")

    $script:path_FileUserShared = [IO.Path]::Combine($fileUserShared, $psVersionName, "dbatools/")
    $script:AppData = $fileUserShared
} else {
    # Defaults to [System.Environment]::GetFolderPath("ApplicationData") on Windows
    $script:path_FileUserShared = [IO.Path]::Combine([System.Environment]::GetFolderPath("ApplicationData"), $psVersionName, "dbatools", "Config")
    $script:AppData = [System.Environment]::GetFolderPath("ApplicationData")
    if (-not $([System.Environment]::GetFolderPath("ApplicationData"))) {
        $script:path_FileUserShared = [IO.Path]::Combine([Environment]::GetFolderPath("ApplicationData"), $psVersionName, "dbatools", "Config")
        $script:AppData = [System.Environment]::GetFolderPath("ApplicationData")
    }
}
Write-ImportTime -Text "Config system: Set even more paths, this time using Join-DbaPath"
#endregion User Shared

#region System
if ($IsLinux -or $IsMacOs) {
    # Defaults to /etc/xdg elsewhere
    $XdgConfigDirs = $Env:XDG_CONFIG_DIRS -split ([IO.Path]::CombinePathSeparator) | Where-Object { $PSItem -and ([IO.File]::Exists($PSItem)) }
    if ($XdgConfigDirs.Count -gt 1) {
        $basePath = $XdgConfigDirs[1]
    } else {
        $basePath = "/etc/xdg/"
    }
    $script:path_FileSystem = [IO.Path]::Combine($basePath, $psVersionName, "dbatools/")
} else {
    # Defaults to $Env:ProgramData on Windows
    $script:path_FileSystem = [IO.Path]::Combine($Env:ProgramData, $psVersionName, "dbatools", "Config")
    if (-not $script:path_FileSystem) {
        $script:path_FileSystem = [IO.Path]::Combine([Environment]::GetFolderPath("CommonApplicationData"), $psVersionName, "dbatools", "Config")
    }
}

#endregion System

#region Special Paths
# $script:AppData is already OS localized
$script:path_Logging = [IO.Path]::Combine($script:AppData, $psVersionName, "dbatools", "Logs")
$script:path_typedata = [IO.Path]::Combine($script:AppData, $psVersionName, "dbatools", "TypeData")
#endregion Special Paths
#endregion Paths

# Determine Registry Availability
$script:NoRegistry = $true
if (($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -notlike "*Windows*")) {
    $script:NoRegistry = $true
}

$configpath = [IO.Path]::Combine($script:PSModuleRoot, "internal", "configurations")
Write-ImportTime -Text "Config system: Set more paths and special paths"
# Import configuration validation
foreach ($file in (Get-ChildItem -Path ([IO.Path]::Combine($configpath, "validation")))) {
    if ($script:serialimport) {
        . $file.FullName
        Write-ImportTime -Text "Config system: Imported some validation files with dot source"
    } else {
        Import-Command -Path $file.FullName
        Write-ImportTime -Text "Config system: Imported some validation files with Import-Command"
    }
}

# Import other configuration files

foreach ($file in (Get-ChildItem -Path ([IO.Path]::Combine($configpath, "settings")))) {
    if ($script:serialimport) {
        . $file.FullName
        Write-ImportTime -Text "Config system: Imported some settings files with dot source"
    } else {
        Import-Command -Path $file.FullName
        Write-ImportTime -Text "Config system: Imported some settings files with Import-Command"
    }
}

if (-not $script:dbatools_ImportFromRegistryDone) {
    # Read config from all settings
    $config_hash = Read-DbatoolsConfigPersisted -Scope 127

    foreach ($value in $config_hash.Values) {
        try {
            if (-not $value.KeepPersisted) {
                Set-DbatoolsConfig -FullName $value.FullName -Value $value.Value -EnableException
            } else {
                Set-DbatoolsConfig -FullName $value.FullName -PersistedValue $value.Value -PersistedType $value.Type -EnableException
            }
            [Dataplat.Dbatools.Configuration.ConfigurationHost]::Configurations[$value.FullName.ToLowerInvariant()].PolicySet = $value.Policy
            [Dataplat.Dbatools.Configuration.ConfigurationHost]::Configurations[$value.FullName.ToLowerInvariant()].PolicyEnforced = $value.Enforced
        } catch {
            $null = 1
        }
    }

    if ($null -ne $global:dbatools_config) {
        if ($global:dbatools_config.GetType().FullName -eq "System.Management.Automation.ScriptBlock") {
            [System.Management.Automation.ScriptBlock]::Create($global:dbatools_config.ToString()).Invoke()
        }
    }

    $script:dbatools_ImportFromRegistryDone = $true

    Write-ImportTime -Text "Config system: Did some final checks"
}
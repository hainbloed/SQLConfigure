﻿#requires -Modules SQLConfigure
#requires -Version 3.0
function Set-SQLDatabaseFile 
<#


    .SYNOPSIS
    This script addes new data files to a database.			

    .DESCRIPTION
    This script addes new data files to a database.	

    .PARAMETER ServerInstance
    This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

    .PARAMETER dbname
    This is the name of the database. The dbname has to be valid.

    .PARAMETER size
    This parameter sets the sie for the database.
    The value is in KB.

    .PARAMETER count
    This parameter sets the number of total data file for a database.
    If the number of files is already greater or equal to the count nothing is done.

    .PARAMETER growth
    This parameter sets growth value for the database.  The parameter can be empty and no change will happen. 
    It must be and integer value. If the value is less or equal to the existing one nothing will change.

    .PARAMETER growthtype
    This parameter sets growthtype  for the database.  The parameter can be empty and no change will happen. 
    If the is equal to the existing one nothing will change.
    Valid values are:'KB','Percent'.

    .PARAMETER restart
    This paramter controls if the instance will be restarted to apply the setting.

    .EXAMPLE
    Set-SqlDatabaseFile -ServerInstance 'server\instance' -dbname 'test' -size 10240 -count 4 -growth 10240 -GrowthType KB -Verbose
#>

{ 
  param(
    [parameter(Mandatory,ValueFromPipeline = $true)][string]$ServerInstance,
    [parameter(Mandatory,ValueFromPipeline = $true)][string]$dbname, 
    [Parameter(Mandatory)][int]$size, 
    [Parameter(Mandatory)][int]$count,
    [Parameter(Mandatory)][int]$growth,
    [Parameter(Mandatory)][ValidateSet('KB','Percent')][string]$GrowthType,
    [switch]$restart = $false
  )

  begin {
    #Load assemblies
    $null = [Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

  }

  Process {
    try 
    {
      #create initial SMO object
      $server = New-Object -TypeName ('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList $ServerInstance

      if($server.Databases.Contains($dbname))
      {
        $db = $server.Databases[$dbname]
        $datapath = $db.PrimaryFilePath
        $fg = $db.FileGroups['PRIMARY']
        if($fg.Files.Count -le $count) 
        { 
          $i = $fg.Files.Count
          $server.KillAllProcesses($dbname) 
          for ($i;$i -le $count-1;$i += 1)
          {
            $filename = $db.Name+'_data'+$i
            $dbfile = New-Object -TypeName ('Microsoft.SqlServer.Management.Smo.DataFile') -ArgumentList ($fg, $filename)
            $fg.Files.Add($dbfile)
            $dbfile.FileName = $datapath + '\' + $filename + '.ndf'
            $dbfile.Size = [double]$size
            $dbfile.Growth = [double]$growth
            $dbfile.GrowthType = $GrowthType

            $db.Alter()
            $fg.Alter()
            Write-Verbose -Message "Datafile $filename created"
                        
            if($server.Databases.Contains('tempdb') -and $restart)
            {
              Stop-SQLService -ServerInstance $ServerInstance -services 'sql'
              Start-SQLService -ServerInstance $ServerInstance -services 'sql'
              Write-Verbose -Message 'Data files changed and service restarted.'
            }
            elseif($server.Databases.Contains('tempdb'))
            {
              Write-Verbose -Message 'Data files changed - Service has to be restarted'
            }
          }
        }
        else 
        {
          Write-Verbose -Message "Datafile count for $dbname is alread $count"
        }
      }
      else 
      {
        Write-Verbose -Message "Database $dbname does not exist."
      }
    }
    catch 
    {
      Write-Error -Message $Error[0]
      $err = $_.Exception
      while ( $err.InnerException ) 
      {
        $err = $err.InnerException
        Write-Output -InputObject $err.Message
      }
    }
  }
  End { Write-Verbose -Message "Database $dbname configured successfully" }
}
 

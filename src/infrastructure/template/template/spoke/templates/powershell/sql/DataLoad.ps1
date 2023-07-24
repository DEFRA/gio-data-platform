[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$sqlUserName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$sqlPass,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$server,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$database,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$dataFilesPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$runWithFormatFiles = $false,

    [Parameter(Mandatory = $false)]
    [string]$codePage
)

$dataFiles = Get-ChildItem -Path $dataFilesPath

foreach ($file in $dataFiles) {
    if (-not $file.PSIsContainer) {
        $tableName = $file.Name -replace $file.Extension, ''
        Write-Output "[START] Loading Bulk Data in: $tableName..."

        if ($runWithFormatFiles) {

            Write-Output "Loading Bulk Data with Format Files.."
            
            if ($codePage) {
                bcp $tableName in "$($file.FullName)" -f "$($file.DirectoryName)\FMT\$tableName.fmt" -t"||" -G -U "$sqlUserName" -P "$sqlPass" -S "$server" -d "$database" -C $codePage
            }
            else {
                bcp $tableName in "$($file.FullName)" -f "$($file.DirectoryName)\FMT\$tableName.fmt" -t"||" -G -U "$sqlUserName" -P "$sqlPass" -S "$server" -d "$database"
            }
        }
        else {
            if ($codePage) {
                bcp $tableName in "$($file.FullName)" -f "$($file.DirectoryName)\FMT\$tableName.fmt" -w -t"||" -G -U "$sqlUserName" -P "$sqlPass" -S "$server" -d "$database" -C $codePage
            }
            else {
                bcp $tableName in "$($file.FullName)" -f "$($file.DirectoryName)\FMT\$tableName.fmt" -w -t"||" -G -U "$sqlUserName" -P "$sqlPass" -S "$server" -d "$database"
            }
        }
        
        Write-Output "[END] Loading Bulk Data in: $tableName..."
    }
}

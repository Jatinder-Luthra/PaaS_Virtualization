
###########################################################################################################################################
######################### Author: Jatinder Luthra
### Date: 02-10-2023
###########################################################################################################################################

$dbName = "bikestores_stg"
$backupFile = "D:\rdsdbdata\BACKUP\s3_backups\bikestores_diff.bak"

$sqlCommand = "RESTORE DATABASE $dbName FROM  DISK = N'$backupFile' WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 10"


$logFile = "C:\Users\Administrator\Desktop\Scripts\rdsbackuplog.txt"

try {
    
    Invoke-Sqlcmd -Query $sqlCommand


} catch {
    # Log the error message to the log file
    $errorMessage = $_.Exception.Message
    Add-Content -Path $logFile -Value "An error occurred while executing the SQL command: $errorMessage"
    exit 1
}

# Define the variables for the SQL Server instance, SQL authentication credentials, SQL command, and log file
################## Encrypt password START ##################
###### $File = "C:\Users\Administrator\Desktop\Scripts\RDS_Credentials\rds_password.txt"
###### $Password = "Password" | ConvertTo-SecureString -AsPlainText -Force
###### $Password | ConvertFrom-SecureString | Out-File $File
################## Encrypt password END ##################


$RDSInstance = "<RDSInstanceEndpoint>"
$RDSUsername = "<RDSInstUsername>"
$dbName = "bikestores"
$backupFile = "arn:aws:s3:::<bucketName>/<bucketPrefix>/bikestores_diff.bak"
$RDSPasswordFile = "C:\Users\Administrator\Desktop\Scripts\RDS_Credentials\rds_password.txt"

$sqlCommand = "exec msdb.dbo.rds_backup_database @source_db_name='$dbName', @s3_arn_to_backup_to='$backupFile',    
  	@overwrite_s3_backup_file=1,
  	@type='DIFFERENTIAL',
  	@number_of_files=1"


$logFile = "C:\Users\Administrator\Desktop\Scripts\rdsbackuplog.txt"

try {
    # Decrypt RDS Password

    $EncryptedSCPass = Get-Content -Path $RDSPasswordFile 

    $secure_passwd = ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $EncryptedSCPass))))

    # Execute the SQL command using Invoke-Sqlcmd

    $backup_rds = Invoke-Sqlcmd -ServerInstance $RDSInstance -Database $dbName -Username $RDSUsername -Password $secure_passwd -Query $sqlCommand

    $backup_task_id = $backup_rds | Select-Object -Property task_id | ForEach-Object {$_.task_id}

    echo "***** Monitoring RDS Backup Status for task $backup_task_id"

    $monitor_sql = "exec msdb.dbo.rds_task_status @task_id=$backup_task_id";
    
    $monitor_backup = Invoke-Sqlcmd -ServerInstance $RDSInstance -Database $dbName -Username $RDSUsername -Password $secure_passwd -Query $monitor_sql

    $backup_status = $monitor_backup | Select-Object -Property lifecycle | ForEach-Object {$_.lifecycle}

    echo "***** RDS Backup Status: $backup_status"

    while($backup_status -ne "SUCCESS")
    {
    
    $monitor_sql = "exec msdb.dbo.rds_task_status @task_id=$backup_task_id";
    
    $monitor_backup = Invoke-Sqlcmd -ServerInstance $RDSInstance -Database $dbName -Username $RDSUsername -Password $secure_passwd -Query $monitor_sql

    $backup_status = $monitor_backup | Select-Object -Property lifecycle | ForEach-Object {$_.lifecycle}

    echo "***** RDS Backup Status: $backup_status......Waiting"

    Start-Sleep -Seconds 5

    }

    Start-Sleep -Seconds 10

    exit 0


} catch {
    # Log the error message to the log file
    $errorMessage = $_.Exception.Message
    Add-Content -Path $logFile -Value "An error occurred while executing the SQL command: $errorMessage"
    exit 1
}

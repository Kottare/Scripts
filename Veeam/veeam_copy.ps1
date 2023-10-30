#$User = "USERNAME"
#$PWord = ConvertTo-SecureString -String "PASSWORD" -AsPlainText -Force
#$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
#New-PSDrive -Name "M" -PSProvider "FileSystem" -Root \\REMOTE-FOLDER -Credential $Credential -Persist


##################################################################

# Names of VMs to backup separated by comma (Mandatory). For instance, $VMNames = “VM1”,”VM2”
$VMNames = "vm1","vm2","vm3"

# Name of vCenter or standalone host VMs to backup reside on (Mandatory)
$HostName = "Name_HV"

# Directory that VM backups should go to (Mandatory; for instance, C:\Backup)
$Directory = "D:\Backup\"

# Desired compression level (Optional; Possible values: 0 - None, 4 - Dedupe-friendly, 5 - Optimal, 6 - High, 9 - Extreme) 
$CompressionLevel = "5"

# Quiesce VM when taking snapshot (Optional; VMware Tools are required; Possible values: $True/$False)
$EnableQuiescence = $false

# Protect resulting backup with encryption key (Optional; $True/$False)
$EnableEncryption = $false

# Encryption Key (Optional; path to a secure string)
$EncryptionKey = ""

# Retention settings (Optional; By default, VeeamZIP files are not removed and kept in the specified location for an indefinite period of time. 
# Possible values: Never , Tonight, TomorrowNight, In3days, In1Week, In2Weeks, In1Month)
$Retention = "In1Week"


$EnableNotification=$true

##################################################################
#                   Notification Settings
##################################################################

$SMTPServer     = "smtp.domain.pl"
$EmailFrom      = "veeam@domain.pl" 
$EmailTo        = "admin@domain.pl"
$EmailSubject   = "Veeam Copy HV"
$key            = "MyEncryptionKey"   # Your Unique Encryption Passkey
$EMailSSL       = $false        # Use ssl for email, set email port
$EMailPort      = 25            # Standard port is 25, SSL port typically 587
$EMailAuth      = $true        # Email Server Requires login
$emaillogin     = "veeam@domain.pl"
$emailpassword  = "PASSWORD"

##################################################################
#                   Email formatting 
##################################################################

$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
$style = $style + "TD{border: 1px solid black; padding: 5px; }"
$style = $style + "</style>"

##################################################################
#                   End User Defined Variables
##################################################################

#################### DO NOT MODIFY PAST THIS LINE ################
Asnp VeeamPSSnapin

$Server = Get-VBRServer -name $HostName
$MesssagyBody = @()

foreach ($VMName in $VMNames)
{
  $VM = Find-VBRHvEntity -Name $VMName -Server $Server
  
  If ($EnableEncryption)
  {
    $EncryptionKey = Add-VBREncryptionKey -Password (cat $EncryptionKey | ConvertTo-SecureString)
    $ZIPSession = Start-VBRZip -Entity $VM -Folder $Directory -Compression $CompressionLevel -DisableQuiesce:(!$EnableQuiescence) -AutoDelete $Retention -EncryptionKey $EncryptionKey
  }
  
  Else 
  {
    $ZIPSession = Start-VBRZip -Entity $VM -Folder $Directory -Compression $CompressionLevel -DisableQuiesce:(!$EnableQuiescence) -AutoDelete $Retention
  }
  
  If ($EnableNotification) 
  {
    $TaskSessions = $ZIPSession.GetTaskSessions().logger.getlog().updatedrecords
    $FailedSessions =  $TaskSessions | where {$_.status -eq "EWarning" -or $_.Status -eq "EFailed"}
  
  if ($FailedSessions -ne $Null)
  {
    $MesssagyBody = $MesssagyBody + ($ZIPSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="Start Time";e={$_.CreationTime}},@{n="End Time";e={$_.EndTime}},Result,@{n="Details";e={$FailedSessions.Title}})
  }
   
  Else
  {
    $MesssagyBody = $MesssagyBody + ($ZIPSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="Start Time";e={$_.CreationTime}},@{n="End Time";e={$_.EndTime}},Result,@{n="Details";e={($TaskSessions | sort creationtime -Descending | select -first 1).Title}})
  }
  
  }  

  ROBOCOPY D:\Backup\  \\WHERE /e /move /mt 
  Get-ChildItem "\\remote_folder" -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-5))}| Remove-Item
   
}
If ($EnableNotification)
{
$Message = New-Object System.Net.Mail.MailMessage $EmailFrom, $EmailTo
$Message.Subject = $EmailSubject
$Message.IsBodyHTML = $True
$message.Body = $MesssagyBody | ConvertTo-Html -head $style | Out-String
$SMTP = New-Object Net.Mail.SmtpClient($SMTPServer)
if ($EMailSSL -eq $true) {
    $SMTP.EnableSSL = $true
}
if ($EMailAuth -eq $true) {
    $SMTP.Credentials = New-Object System.Net.NetworkCredential ($emaillogin, $emailpassword)
}
$SMTP.Send($Message)
}

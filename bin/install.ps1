#	= ^ . ^ =
#	vim: filetype=cs

# http://stackoverflow.com/a/11440595
# http://technet.microsoft.com/en-us/library/ee177015.aspx

# Check admin rights
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
  $arguments = "& '" + $myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  break
}

# Disale SSL validation (we are installing a Root CA Certificate)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$SERVER="xnas.local"
$PREFIX="$env:SYSTEMDRIVE\xNAS"
$CACERT="ca.crt"
$CONNECTOR="xNAS-Connector.ps1"

# Create directory if not exist
# http://technet.microsoft.com/en-us/library/ff730955.aspx
if (-Not (Test-Path $PREFIX))
{
  mkdir $PREFIX
}

# Get the CA certificate
(new-object System.Net.WebClient).DownloadFile("https://$SERVER/$CACERT","$PREFIX\$CACERT")

# Install certificate if exists
if (Test-Path "$PREFIX\$CACERT")
{
  # Install the certificate in the "Trusted Root Certificate Authorities" store
  certutil -addstore -f root "$PREFIX\$CACERT"
}

# Restart Weblient service
net stop  WebClient
net start WebClient

# Since the CA cert was installed restore SSL server certificate validation to default state
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

# Download the xNAS connector script
(new-object System.Net.WebClient).DownloadFile("https://$SERVER/$CONNECTOR","$PREFIX\$CONNECTOR")

# Create a shortcut in the $PREFIX folder and also on All Users Desktop
$lnkPath = "$PREFIX\xNAS.lnk"
$AllUsersDesktop = "$env:SYSTEMDRIVE\Users\Public\Desktop"

$lnk = (New-Object -COMobject WScript.Shell).CreateShortcut($lnkPath)
$lnk.TargetPath = "powershell.exe"
$lnk.Arguments = "-NoLogo -WindowStyle Hidden -File $PREFIX\$CONNECTOR"
$lnk.Description = "xNAS Connector"
$lnk.IconLocation = "$env:SYSTEMROOT\System32\Shell32.dll,9"
$lnk.WorkingDirectory = "$PREFIX"
# Window is minimized
$lnk.WindowStyle = 7
$lnk.Save()

Copy-Item $lnkPath $AllUsersDesktop

# Make $PREFIX read-only
# http://technet.microsoft.com/en-us/library/bb490868.aspx
attrib +r +s +a +h /s /d $PREFIX

# The script $CONNECTOR is signed and validated with $CACERT. Only allow signed scripts to run
#set-executionpolicy remotesigned

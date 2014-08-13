::	= ^ . ^ =
::	vim: filetype=cmd
@ECHO off

:: Check admin privileges
:: http://stackoverflow.com/questions/4051883/batch-script-how-to-check-for-admin-rights
NET SESSION >NUL 2>&1

if %ERRORLEVEL% == 0 (
  :: Admin
  GOTO Admin
) else (
  :: Not admin
  echo This script needs admin rights.
  GOTO FAIL
)

@ECHO on

:FAIL
PAUSE >NUL 2>&1
exit

:Admin
SET PREFIX=%SYSTEMDRIVE%\xNAS

pushd .

mkdir %PREFIX%
cd %PREFIX%

:: Allow execution of unsigned PowerShell scripts
powershell set-executionpolicy unrestricted

:: Download installer stage 2
powershell "[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} ; (new-object System.Net.WebClient).DownloadFile('https://xnas.local/install.ps1','install.ps1')"

:: Invoke stage 2 (like GRUB does :P)
:: Install certificate and create connector shortcut in "All Users" desktop
powershell.exe -File .\install.ps1

popd

:: Move this script to %PREFIX%
start "" /min /B move "%~f0" "%PREFIX%"

exit

@echo on
for %%s in ("dl.CMD", "install.CMD") do (
  powershell "[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} ; (new-object System.Net.WebClient).DownloadFile(\"https://xnas.local/%%s\",\"%%s\") ;"
)

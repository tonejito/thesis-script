#	= ^ . ^ =
# vim: filetype=cs

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$EOT = [char]04;

function setmode()
{
  $H = get-host
  $W = $H.ui.rawui
  $B = $W.buffersize
  $B.width  = 1
  $B.height = 1
  $W.buffersize = $B
}

#setmode

function DisplayBox($location)
{
  $title = "Title"
  $text  = "Text"
  # If the user press OK or <Enter> the textbox contents are returned
  # If the user press Cancel or <Escape> an EOT char (ASCII 0x04) is returned
  #$location = "https://xnas.local/"
  # http://technet.microsoft.com/en-us/library/ff730941.aspx
  # Creating a Custom Input Box
  
  $width = 320
  $height = 240
  $p = 15
  $x = 0
  $y = 0
  $w = 0
  $h = 0

  # Form
  $objForm = New-Object System.Windows.Forms.Form 
  $objForm.Text = $title
  $objForm.Size = New-Object System.Drawing.Size($width,$height)
  $objForm.MinimumSize = $objForm.Size
  $objForm.MaximumSize = $objForm.Size
  $objForm.StartPosition = "CenterScreen"
  # Disable resize
  $objForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
# Customize Form attributes
  # http://msdn.microsoft.com/en-us/library/System.Windows.Forms.Form%28v=vs.110%29.aspx
  # http://social.technet.microsoft.com/Forums/windowsserver/en-US/16444c7a-ad61-44a7-8c6f-b8d619381a27/using-icons-in-powershell-scripts?forum=winserverpowershell
  # http://msdn.microsoft.com/en-us/library/system.drawing.systemicons%28v=vs.110%29.aspx
  # $objForm.Icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)
  #$objForm.Icon [Drawing.Icon]::ExtractAssociatedIcon(@"%SystemRoot%\system32\SHELL32.dll,9");
  $objForm.Icon = [System.Drawing.SystemIcons]::WinLogo #Application
  $objForm.ShowIcon = $true
  $objForm.Topmost = $false
  $objForm.AllowDrop = $false
  $objForm.AllowTransparency = $false
  $objForm.Opacity = 1
  $objForm.AutoSize = $true
  $objForm.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowOnly
  $objForm.MaximizeBox = $false
  $objForm.MinimizeBox = $false
  $objForm.HelpButton = $false
  $objForm.ShowInTaskbar = $true

  # Key handlers
  $objForm.KeyPreview = $True
  $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$location=$objTextBoxLocation.Text;$objForm.Close()}})
  $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$location=$EOT;$objForm.Close()}})

  # StatusBar
  $objStatusBar = New-Object System.Windows.Forms.StatusBar
  $objStatusBar.Text = "= ^ . ^ =	xNAS"
  $objForm.Controls.Add($objStatusBar)

  # Text - Location
  $x = $p
  $y = $p
  $w = $objForm.Size.Width-2*$p
  $h = $p
  $objLabelLocation = New-Object System.Windows.Forms.Label
  $objLabelLocation.Location = New-Object System.Drawing.Size($x,$y)
  $objLabelLocation.Size = New-Object System.Drawing.Size($w,$h) 
  $objLabelLocation.Text = $text
  $objForm.Controls.Add($objLabelLocation)

  # TextBox - Location
  $y = $y + $objLabelLocation.Height + $p
  $objTextBoxLocation = New-Object System.Windows.Forms.TextBox 
  $objTextBoxLocation.Text = $location
  $objTextBoxLocation.Location = New-Object System.Drawing.Size($x,$y)
  $objTextBoxLocation.Size = New-Object System.Drawing.Size($w,$h)
  $objForm.Controls.Add($objTextBoxLocation)

  # CheckBox - Persistent
  $x = 3*$p
  $y = $y + $objTextBoxLocation.Height + $p
  $w = ($objForm.Size.Width-(10*$p))/2
  $objCheckBoxPersisent = New-Object System.Windows.Forms.CheckBox
  $objCheckBoxPersisent.Location = New-Object System.Drawing.Size($x,$y)
  $objCheckBoxPersisent.Text = "/persistent"
  $objForm.Controls.Add($objCheckBoxPersisent)
  
  # CheckBox - SaveCred
  $x = $x + $objCheckBoxPersisent.Width + $p
  $objCheckBoxSaveCred = New-Object System.Windows.Forms.CheckBox
  $objCheckBoxSaveCred.Location = New-Object System.Drawing.Size($x,$y)
  $objCheckBoxSaveCred.Text = "/savecred"
  $objForm.Controls.Add($objCheckBoxSaveCred)

  # OK
  $x = 3*$p
  $y = $y + $objCheckBoxSaveCred.Height + 2*$p
  $h = 2*$p
  $OKButton = New-Object System.Windows.Forms.Button
  $OKButton.Location = New-Object System.Drawing.Size($x,$y)
  $OKButton.Size = New-Object System.Drawing.Size($w,$h)
  $OKButton.Text = "OK"
  $OKButton.Add_Click({$location = $objTextBoxLocation.Text;$objForm.Close()})
  $objForm.Controls.Add($OKButton)

  # Cancel
  $x = $x + $OKButton.Width + 2*$p
  $CancelButton = New-Object System.Windows.Forms.Button
  $CancelButton.Location = New-Object System.Drawing.Size($x,$y)
  $CancelButton.Size = New-Object System.Drawing.Size($w,$h)
  $CancelButton.Text = "Cancel"
  $CancelButton.Add_Click({$location = $EOT; $objForm.Close()})
  $objForm.Controls.Add($CancelButton)

  # Key handlers
  $objForm.AcceptButton = $OKButton
  $objForm.CancelButton = $CancelButton

  # Focus TextBox
  if ( $objTextBoxLocation.CanFocus )
  {
    $objTextBoxLocation.Focus()
  }
  else
  {
    $objTextBoxLocation.Select()
  }

  $objForm.Add_Shown({$objForm.Activate()})
  [void] $objForm.ShowDialog()

  return $location
}

function Credentials($message)
{
  $title = "Enter credentials"
  # Get-Credential
  # http://technet.microsoft.com/en-us/library/hh849815.aspx
  # http://technet.microsoft.com/en-us/library/ee692804.aspx
  # http://technet.microsoft.com/en-us/library/hh849815.aspx
  # http://blogs.technet.com/b/jamesone/archive/2009/06/24/how-to-get-user-input-more-nicely-in-powershell.aspx
  # $Credential = Get-Credential
  # This fails somehow if the user press [Cancel] or <Escape>
  $Credential = $Host.ui.PromptForCredential($title,$message,"","")
  # Username with backslash prepended (damn), must use substring to 
  # remove it
  $user = $Credential.Username.toString().Substring(1)
  $password = $Credential.GetNetworkCredential().Password.toString()
  return @($user,$password)
}

function PasswordAdvisory()
{
  # Display a message box in case of empty password
  # http://msdn.microsoft.com/en-us/library/system.windows.forms.messagebox%28v=vs.110%29.aspx
  # http://gallery.technet.microsoft.com/scriptcenter/PowerShell-Message-Box-6c6e4f75
  
    # Message Box Style 
    # $type = 0  # Empty
    # $type = 1  # Ok-Cancel
    # $type = 2  # Abort-Retry-Ignore
    # $type = 3  # Yes-No-Cancel
    # $type = 4  # Yes-No
    # $type = 5  # Retry-Cancel
    
    # Message box Icon 
    # $Icon =  0  # Empty
    # $Icon = 16  # Critical
    # $Icon = 32  # Question
    # $Icon = 48  # Warning
    # $Icon = 64  # Informational
  $title = "Error"
  $text = "Empty passwords are not allowed"
  [System.Windows.Forms.MessageBox]::Show($text , $title, 0, 16)
  # (New-Object -comobject wscript.shell).popup($text,0,$title,1)
  return
}

# Do not display empty password warning the first time
$flag = 0
$location = ""

while ([string]::IsNullOrEmpty($location))
{
  # Get location from user
  $location = DisplayBox

  # If the user pressed "Cancel"
  if (([string]::Compare($location, $EOT)).Equals(0))
  {
    return;
  }

  # Condition is true if user pressed [OK]
  if(![string]::IsNullOrEmpty($location))
  {
    # Get the credentials until the password is not empty
    while ([string]::IsNullOrEmpty($password))
    {
      # Empty passwords are not allowed
      if ($flag)
      {
        $x = PasswordAdvisory
      }
      $creds = Credentials($location)
      $username = $creds[0]
      $password = $creds[1]
      # Display empty password warning all subsequent times
      $flag = 1
    }

    # Map the drive if the data seems valid
    if(![string]::IsNullOrEmpty($location) -and ![string]::IsNullOrEmpty($username) -and ![string]::IsNullOrEmpty($password))
    {
      # http://technet.microsoft.com/en-us/library/bb490717.aspx
      # http://www.howtogeek.com/132354/how-to-map-network-drives-using-powershell/
      # http://thoughts.stuart-edwards.info/index.php/programming/net-use-in-powershell-with-stored-credentials
      $msg = net use * $location /user:$username $password /persistent:no	2>&1
      $_ = [System.Windows.Forms.MessageBox]::Show($msg)
    }
  }
}

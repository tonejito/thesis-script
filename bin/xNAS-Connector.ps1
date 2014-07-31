#	= ^ . ^ =
# vim: filetype=cs

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

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

function DisplayBox()
{
  $title = "Title"
  $text  = "Text"
  $location = "https://xnas.local/"
  $ret =  ""
  # http://technet.microsoft.com/en-us/library/ff730941.aspx
  # Creating a Custom Input Box

  # Form
  $objForm = New-Object System.Windows.Forms.Form 
  $objForm.Text = $title
  $objForm.Size = New-Object System.Drawing.Size(300,200) 
  $objForm.StartPosition = "CenterScreen"

  # Key handlers
  $objForm.KeyPreview = $True
  $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$ret=$objTextBoxLocation.Text;$objForm.Close()}})
  $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})

  # OK
  $OKButton = New-Object System.Windows.Forms.Button
  $OKButton.Location = New-Object System.Drawing.Size(75,120)
  $OKButton.Size = New-Object System.Drawing.Size(75,23)
  $OKButton.Text = "OK"
  $OKButton.Add_Click({$ret = $objTextBoxLocation.Text;$objForm.Close()})
  $objForm.Controls.Add($OKButton)

  # Cancel
  $CancelButton = New-Object System.Windows.Forms.Button
  $CancelButton.Location = New-Object System.Drawing.Size(150,120)
  $CancelButton.Size = New-Object System.Drawing.Size(75,23)
  $CancelButton.Text = "Cancel"
  $CancelButton.Add_Click({$objForm.Close()})
  $objForm.Controls.Add($CancelButton)

  # Text
  $objLabel = New-Object System.Windows.Forms.Label
  $objLabel.Location = New-Object System.Drawing.Size(10,20) 
  $objLabel.Size = New-Object System.Drawing.Size(280,20) 
  $objLabel.Text = $text
  $objForm.Controls.Add($objLabel) 

  # TextBox - Location
  $objTextBoxLocation = New-Object System.Windows.Forms.TextBox 
  $objTextBoxLocation.Text = $location
  $objTextBoxLocation.Location = New-Object System.Drawing.Size(10,40) 
  $objTextBoxLocation.Size = New-Object System.Drawing.Size(260,20) 
  $objForm.Controls.Add($objTextBoxLocation)
  
  # Focus TextBox
  if ( $objTextBoxLocation.CanFocus )
  {
    $objTextBoxLocation.Focus()
  }
  else
  {
    $objTextBoxLocation.Select()
  }

  $objForm.Topmost = $false

  $objForm.Add_Shown({$objForm.Activate()})
  [void] $objForm.ShowDialog()

  return $ret
}

function Credentials()
{
  # Get-Credential
  # http://technet.microsoft.com/en-us/library/hh849815.aspx
  # http://technet.microsoft.com/en-us/library/ee692804.aspx
  # http://technet.microsoft.com/en-us/library/hh849815.aspx
  # http://blogs.technet.com/b/jamesone/archive/2009/06/24/how-to-get-user-input-more-nicely-in-powershell.aspx
  # $Credential = Get-Credential
  $Credential = $Host.ui.PromptForCredential("Title","Message","","")
  # Username with backslash prepended (damn)
  # must use substring to remove backslash
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
    
  [System.Windows.Forms.MessageBox]::Show("Empty passwords are not allowed" , "Error", 0, 16)
  return
}

# Do not display empty password warning the first time
$flag = 0
$location = ""

while ([string]::IsNullOrEmpty($location))
{
  # Get location from user
  $location = DisplayBox
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
      $creds = Credentials
      $username = $creds[0]
      $password = $creds[1]
      # Display empty password warning all subsequent times
      $flag = 1
    }
    
    # Map the drive if the data seems valid
    if(![string]::IsNullOrEmpty($location) -and ![string]::IsNullOrEmpty($username) -and ![string]::IsNullOrEmpty($password))
    {
      # http://www.howtogeek.com/132354/how-to-map-network-drives-using-powershell/
      # http://thoughts.stuart-edwards.info/index.php/programming/net-use-in-powershell-with-stored-credentials
      $msg = net use * $location /user:$username $password /persistent:no	2>&1
      $_ = [System.Windows.Forms.MessageBox]::Show($msg)
    }
  }
}

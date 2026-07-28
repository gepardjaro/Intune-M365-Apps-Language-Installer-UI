# LanguageSelector.ps1
# Requires an image file named "company_logo.png" (683x125) in the same directory as this script.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuration & Paths ---
$ScriptDir = $PSScriptRoot
$LogoPath = Join-Path -Path $ScriptDir -ChildPath "company_logo.png"

$OutputFile = "$env:PUBLIC\M365_SelectedLangs.txt"
if (Test-Path $OutputFile) { Remove-Item $OutputFile -Force }

# --- Custom Blue-ish Color Palette & White Header ---
$ColorLogoBg   = [System.Drawing.Color]::White                   
$ColorFormBg   = [System.Drawing.Color]::FromArgb(226, 238, 250) 
$ColorText     = [System.Drawing.Color]::FromArgb(10, 37, 88)    
$ColorListBg   = [System.Drawing.Color]::FromArgb(242, 248, 255) 
$ColorBtnPriBg = [System.Drawing.Color]::FromArgb(0, 102, 204)   
$ColorBtnPriFg = [System.Drawing.Color]::White
$ColorBtnSecBg = [System.Drawing.Color]::FromArgb(144, 170, 200) 
$ColorBtnSecFg = [System.Drawing.Color]::White

# --- Fonts ---
$FontTitle  = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$FontHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$FontList   = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$FontButton = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# --- Define Data (Key = Display Name, Value = Code) ---
$Languages = [ordered]@{
    'Afrikaans'             = 'af-za'
    'Albanian'              = 'sq-al'
    'Arabic'                = 'ar-sa'
    'Basque'                = 'eu-es'
    'Bulgarian'             = 'bg-bg'
    'Catalan'               = 'ca-es'
    'Chinese (Simplified)'  = 'zh-cn'
    'Chinese (Traditional)' = 'zh-tw'
    'Croatian'              = 'hr-hr'
    'Czech'                 = 'cs-cz'
    'Danish'                = 'da-dk'
    'Dutch'                 = 'nl-nl'
    'English (US)'          = 'en-us'
    'Estonian'              = 'et-ee'
    'Finnish'               = 'fi-fi'
    'French'                = 'fr-fr'
    'Galician'              = 'gl-es'
    'German'                = 'de-de'
    'Greek'                 = 'el-gr'
    'Hebrew'                = 'he-il'
    'Hindi'                 = 'hi-in'
    'Hungarian'             = 'hu-hu'
    'Indonesian'            = 'id-id'
    'Irish'                 = 'ga-ie'
    'Italian'               = 'it-it'
    'Japanese'              = 'ja-jp'
    'Kazakh'                = 'kk-kz'
    'Korean'                = 'ko-kr'
    'Latvian'               = 'lv-lv'
    'Lithuanian'            = 'lt-lt'
    'Macedonian'            = 'mk-mk'
    'Malay'                 = 'ms-my'
    'Maltese'               = 'mt-mt'
    'Norwegian Bokmål'      = 'nb-no'
    'Norwegian Nynorsk'     = 'nn-no'
    'Polish'                = 'pl-pl'
    'Portuguese (Brazil)'   = 'pt-br'
    'Portuguese (Portugal)' = 'pt-pt'
    'Romanian'              = 'ro-ro'
    'Russian'               = 'ru-ru'
    'Serbian (Latin)'       = 'sr-latn-rs'
    'Slovak'                = 'sk-sk'
    'Slovenian'             = 'sl-si'
    'Spanish'               = 'es-es'
    'Swedish'               = 'sv-se'
    'Thai'                  = 'th-th'
    'Turkish'               = 'tr-tr'
    'Ukrainian'             = 'uk-ua'
    'Vietnamese'            = 'vi-vn'
    'Welsh'                 = 'cy-gb'
}

# --- Create Main Form ---
$FormWidth = 540
$FormHeight = 720

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Add Microsoft 365 Languages"
$Form.Size = New-Object System.Drawing.Size($FormWidth, $FormHeight)
$Form.StartPosition = "CenterScreen"
$Form.TopMost = $true
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.MinimizeBox = $false
$Form.ControlBox = $false
$Form.BackColor = $ColorFormBg

# --- Dedicated White Header for Logo ---
$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Size = New-Object System.Drawing.Size($FormWidth, 90)
$HeaderPanel.BackColor = $ColorLogoBg
$HeaderPanel.Dock = "Top"

# Company Logo (Exactly half of 683x125 -> 342x63)
$LogoBox = New-Object System.Windows.Forms.PictureBox
$LogoBox.Size = New-Object System.Drawing.Size(342, 63)
$LogoBox.Location = New-Object System.Drawing.Point(99, 13)
$LogoBox.SizeMode = "Zoom"
if (Test-Path $LogoPath) {
    try { $LogoBox.Image = [System.Drawing.Image]::FromFile($LogoPath) } catch {}
}

$HeaderPanel.Controls.Add($LogoBox)

# --- Main Content Area ---

# Application Title Label 
$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Language Pack Installer"
$TitleLabel.Font = $FontTitle
$TitleLabel.ForeColor = $ColorText
$TitleLabel.Location = New-Object System.Drawing.Point(0, 105)
$TitleLabel.Size = New-Object System.Drawing.Size($FormWidth, 30)
$TitleLabel.TextAlign = "MiddleCenter"

# User Instruction Label
$LabelInstructions = New-Object System.Windows.Forms.Label
$LabelInstructions.Location = New-Object System.Drawing.Point(25, 150)
$LabelInstructions.Size = New-Object System.Drawing.Size(490, 25)
$LabelInstructions.Font = $FontHeader
$LabelInstructions.ForeColor = $ColorText
$LabelInstructions.Text = "Select one or more languages you wish to install on this device:"
$LabelInstructions.TextAlign = "BottomLeft"

# CheckedListBox (The language list)
$CheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$CheckedListBox.Location = New-Object System.Drawing.Point(25, 185)
$CheckedListBox.Size = New-Object System.Drawing.Size(475, 410)
$CheckedListBox.CheckOnClick = $true
$CheckedListBox.BorderStyle = "None"
$CheckedListBox.BackColor = $ColorListBg
$CheckedListBox.ForeColor = $ColorText
$CheckedListBox.Font = $FontList
$CheckedListBox.IntegralHeight = $false

# Populate the ListBox using the Name = Code structure
foreach ($displayName in $Languages.Keys) {
    $code = $Languages[$displayName]
    [void]$CheckedListBox.Items.Add("$displayName ($code)")
}

# --- Action Buttons ---

# Install (Primary) Button
$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Point(290, 615)
$OKButton.Size = New-Object System.Drawing.Size(100, 40)
$OKButton.Text = "Install"
$OKButton.Font = $FontButton
$OKButton.BackColor = $ColorBtnPriBg
$OKButton.ForeColor = $ColorBtnPriFg
$OKButton.FlatStyle = "Flat"
$OKButton.FlatAppearance.BorderSize = 0
$OKButton.Cursor = "Hand"
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK

# Cancel (Secondary) Button
$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Point(400, 615)
$CancelButton.Size = New-Object System.Drawing.Size(100, 40)
$CancelButton.Text = "Cancel"
$CancelButton.Font = $FontButton
$CancelButton.BackColor = $ColorBtnSecBg
$CancelButton.ForeColor = $ColorBtnSecFg
$CancelButton.FlatStyle = "Flat"
$CancelButton.FlatAppearance.BorderSize = 0
$CancelButton.Cursor = "Hand"
$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

# Add controls to Form
$Form.Controls.Add($HeaderPanel)
$Form.Controls.Add($TitleLabel)
$Form.Controls.Add($LabelInstructions)
$Form.Controls.Add($CheckedListBox)
$Form.Controls.Add($OKButton)
$Form.Controls.Add($CancelButton)

$Form.AcceptButton = $OKButton
$Form.CancelButton = $CancelButton

# Show Dialog and Process Output
$Result = $Form.ShowDialog()

if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
    $SelectedCodes = @()
    foreach ($item in $CheckedListBox.CheckedItems) {
        # The '$' anchors the search to the end of the string, ensuring 
        # it only grabs the actual language code (e.g., zh-tw) and ignores 
        # any other parentheses in the display name.
        if ($item -match "\((?<code_val>[^)]+)\)$") {
            $SelectedCodes += $matches['code_val']
        }
    }
    
    if ($SelectedCodes.Count -gt 0) {
        $SelectedCodes | Out-File -FilePath $OutputFile -Encoding UTF8
    }
}

# Clean up graphic resources
$Form.Dispose()
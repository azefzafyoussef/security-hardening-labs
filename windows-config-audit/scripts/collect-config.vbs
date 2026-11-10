'=============================================================================
' collect-config.vbs  -  Windows configuration-audit collector
'
' Self-contained cold-audit collector. Takes no user input, runs from an
' elevated cmd, and gathers the security-relevant configuration of a Windows
' server into a timestamped folder, then zips it for offline analysis.
' Compatible with Windows Server 2008 and later (uses only built-in tools).
'
' Usage (elevated):  cscript //nologo collect-config.vbs
'=============================================================================
Option Explicit

Dim fso, sh, base, outDir, stamp, logF

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

' --- Output folder: audit_<COMPUTERNAME>_<YYYYMMDD-HHMMSS> -------------------
stamp  = TimeStamp()
base   = sh.ExpandEnvironmentStrings("%COMPUTERNAME%")
outDir = fso.GetParentFolderName(WScript.ScriptFullName) & "\audit_" & base & "_" & stamp
If Not fso.FolderExists(outDir) Then fso.CreateFolder(outDir)

WScript.Echo "[*] Collecting configuration into: " & outDir

' --- Each entry: output filename  +  command to run -------------------------
' The command's stdout is redirected into the file inside outDir.
RunTo outDir, "01_os_config.txt",        "systeminfo"
RunTo outDir, "02_network_config.txt",   "ipconfig /all"
RunTo outDir, "03_open_ports.txt",       "netstat -ano"
RunTo outDir, "04_firewall_rules.txt",   "netsh advfirewall firewall show rule name=all"
RunTo outDir, "05_firewall_profiles.txt","netsh advfirewall show allprofiles"
RunTo outDir, "06_gpo.txt",              "gpresult /z"
RunTo outDir, "07_local_groups.txt",     "net localgroup"
RunTo outDir, "08_local_users.txt",      "net user"
RunTo outDir, "09_installed_software.txt","wmic product get name,version /format:list"
RunTo outDir, "10_installed_updates.txt","wmic qfe list full /format:list"
RunTo outDir, "11_services_all.txt",     "sc query type= service state= all"
RunTo outDir, "12_startup_services.txt", "wmic service where ""startmode='Auto'"" get name,displayname,startmode,state /format:list"
RunTo outDir, "13_startup_apps.txt",     "wmic startup get caption,command,location /format:list"
RunTo outDir, "14_processes.txt",        "tasklist /v"
RunTo outDir, "15_scheduled_tasks.txt",  "schtasks /query /fo LIST /v"
RunTo outDir, "16_smb_shares.txt",       "net share"
RunTo outDir, "17_smb_config.txt",       "powershell -NoProfile -Command ""Get-SmbServerConfiguration | Format-List *"""
RunTo outDir, "18_server_roles.txt",     "powershell -NoProfile -Command ""Get-WindowsFeature | Where-Object Installed | Format-Table -AutoSize"""
RunTo outDir, "19_uac.txt",              "reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA"

' --- Security policy export --------------------------------------------------
sh.Run "cmd /c secedit /export /cfg """ & outDir & "\20_security_policy.inf""", 0, True

' --- Event logs (System + Security) as .evtx --------------------------------
sh.Run "cmd /c wevtutil epl System """   & outDir & "\21_system.evtx""",   0, True
sh.Run "cmd /c wevtutil epl Security """ & outDir & "\22_security.evtx""", 0, True

' --- SAM + SYSTEM registry hives (for offline review) -----------------------
sh.Run "cmd /c reg save HKLM\SAM """    & outDir & "\sam.reg"" /y",    0, True
sh.Run "cmd /c reg save HKLM\SYSTEM """ & outDir & "\system.reg"" /y", 0, True

' --- Package everything into a single archive -------------------------------
ZipFolder outDir, outDir & ".zip"

WScript.Echo "[+] Done. Archive: " & outDir & ".zip"


'============================  helpers  ======================================

Sub RunTo(dir, fileName, cmd)
    Dim full
    full = "cmd /c " & cmd & " > """ & dir & "\" & fileName & """ 2>&1"
    sh.Run full, 0, True
End Sub

Function TimeStamp()
    Dim n : n = Now()
    TimeStamp = Year(n) & P2(Month(n)) & P2(Day(n)) & "-" & _
                P2(Hour(n)) & P2(Minute(n)) & P2(Second(n))
End Function

Function P2(v)
    P2 = Right("0" & v, 2)
End Function

Sub ZipFolder(srcDir, zipPath)
    Dim app, zf, items, started, prevCount
    ' Create an empty zip container.
    Dim s : Set s = fso.CreateTextFile(zipPath, True)
    s.Write "PK" & Chr(5) & Chr(6) & String(18, Chr(0))
    s.Close

    Set app = CreateObject("Shell.Application")
    Set zf  = app.NameSpace(zipPath)
    Set items = app.NameSpace(srcDir).Items()
    zf.CopyHere items
    ' Wait for the async copy to finish.
    started = Timer
    Do
        WScript.Sleep 300
        If zf.Items().Count >= items.Count Then Exit Do
    Loop While (Timer - started) < 120
End Sub

Option Explicit

Dim shell, fileSystem, scriptDirectory, powerShellScript, command, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
powerShellScript = fileSystem.BuildPath(scriptDirectory, "Start-Crewly.ps1")
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & powerShellScript & """"
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode

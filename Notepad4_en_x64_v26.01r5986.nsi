!include "MUI2.nsh"
!include FileFunc.nsh
!insertmacro GetParameters
!insertmacro GetOptions
!include WinVer.nsh
!include psexec.nsh

;--------------------------------
;General
!define BUNDLED_VERSION "v26.01r5986"
!define RELEASEVERSION "en_x64_v26.01r5986"
!define APPNAME "Notepad4"
!define EXENAME "Notepad4.exe"

Name ${APPNAME}
Caption "Notepad4_${RELEASEVERSION} Setup"
Icon "Notepad4_Installer.ico"
!define MUI_ICON "Notepad4_Installer.ico"
!define MUI_UNICON "Notepad4_Installer.ico"

UninstallIcon "Notepad4_Installer.ico"
OutFile "notepad4_${RELEASEVERSION}-install.exe"

SetCompressor /SOLID /FINAL lzma

InstallDir "$PROGRAMFILES\Notepad4"
InstallDirRegKey HKLM "Software\Notepad4" "Install_Dir"

RequestExecutionLevel admin
;--------------------------------
;Variables
Var StartMenuFolder
Var installType
Var DisplayVersion
Var SourceDir
;--------------------------------
;Interface Settings
!define MUI_ABORTWARNING
;--------------------------------
;Pages

!insertmacro MUI_PAGE_LICENSE "Notepad4_${RELEASEVERSION}\License.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY

;Start Menu Folder Page Configuration
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKLM"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\Notepad4"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"

!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
;--------------------------------

!ifndef NOINSTTYPES
InstType "Typical"
InstType "Minimal"
InstType "Full"
!endif

;--------------------------------
; Parse command line parameters
Function .onInit

    StrCpy $INSTDIR "$PROGRAMFILES64\Notepad4"
    StrCpy $DisplayVersion "${BUNDLED_VERSION}"
    StrCpy $SourceDir ""

    ; Default to minimal installation type
    StrCpy $installType "minimal"

    ; Parse command line for "/I=" parameter
    ClearErrors
    ${GetParameters} $R1
    ${GetOptions} $R1 /I= $R0
    IfErrors notFoundI
    StrCpy $installType $R0

    notFoundI:

    ; Check installation type and dynamically adjust section flags
    ; Section indices: 0 = "Fetch latest version", 1 = "Notepad4", 2 = "Replace Windows Editor"
    ${If} $installType == "full"
        SectionGetFlags 2 $R0
        IntOp $R0 $R0 | ${SF_SELECTED}
        SectionSetFlags 2 $R0
    ${Else}
        SectionGetFlags 2 $R0
        IntOp $R0 $R0 & ~${SF_SELECTED}
        SectionSetFlags 2 $R0
    ${EndIf}

    ; For silent installs: /UPDATE enables the online fetch section
    IfSilent 0 initDone
    ClearErrors
    ${GetOptions} $R1 /UPDATE $R0
    IfErrors initDone
    SectionGetFlags 0 $R0
    IntOp $R0 $R0 | ${SF_SELECTED}
    SectionSetFlags 0 $R0

    initDone:

FunctionEnd

;--------------------------------
; Utility: Trim leading/trailing whitespace and newlines from string on stack
Function TrimString
    Exch $R0
    Push $R1
    Push $R2

    ; Trim trailing whitespace/newlines
    trimRight:
    StrCpy $R1 $R0 1 -1
    StrCmp $R1 " " trimRightDo
    StrCmp $R1 "$\r" trimRightDo
    StrCmp $R1 "$\n" trimRightDo
    StrCmp $R1 "$\t" trimRightDo
    Goto trimLeft
    trimRightDo:
    StrCpy $R0 $R0 -1
    Goto trimRight

    ; Trim leading whitespace/newlines
    trimLeft:
    StrCpy $R1 $R0 1
    StrCmp $R1 " " trimLeftDo
    StrCmp $R1 "$\r" trimLeftDo
    StrCmp $R1 "$\n" trimLeftDo
    StrCmp $R1 "$\t" trimLeftDo
    Goto trimDone
    trimLeftDo:
    StrLen $R2 $R0
    IntOp $R2 $R2 - 1
    StrCpy $R0 $R0 "" 1
    Goto trimLeft

    trimDone:
    Pop $R2
    Pop $R1
    Exch $R0
FunctionEnd

;--------------------------------
; Installation Sections

; Online update check — unchecked by default, user must opt in
Section /o "Fetch latest version (online)" SEC00
SectionIn 3

    ; Extract PowerShell scripts to plugin dir
    InitPluginsDir
    SetOutPath $PLUGINSDIR
    File "check_update.ps1"
    File "download_update.ps1"

    ; Run check_update.ps1 to query GitHub API
    ${PowerShellExecFile} "$PLUGINSDIR\check_update.ps1"
    Pop $R0  ; PowerShell output

    ; Read results from temp INI
    ReadINIStr $R1 "$TEMP\notepad4_update.ini" "Update" "Status"
    StrCmp $R1 "OK" 0 updateCheckDone

    ; Read the latest tag name
    ReadINIStr $R2 "$TEMP\notepad4_update.ini" "Update" "TagName"

    ; Compare with bundled version
    StrCmp $R2 "${BUNDLED_VERSION}" updateCheckDone  ; same version, nothing to do

    ; A different (newer) version is available — ask user
    IfSilent doDownload  ; in silent mode, just download
    MessageBox MB_YESNO|MB_ICONQUESTION \
        "A newer version of Notepad4 is available: $R2$\n$\nBundled version: ${BUNDLED_VERSION}$\n$\nWould you like to download and install it?" \
        IDYES doDownload

    ; User chose No — use bundled version
    Goto updateCheckDone

    doDownload:

    ; Run download_update.ps1 (reads URL from the INI file written by check_update.ps1)
    ${PowerShellExecFile} "$PLUGINSDIR\download_update.ps1"
    Pop $R0  ; PowerShell output

    ; Check if download succeeded
    FileOpen $R4 "$TEMP\notepad4_download_status.txt" r
    FileRead $R4 $R5
    FileClose $R4

    ; Trim whitespace
    Push $R5
    Call TrimString
    Pop $R5

    StrCmp $R5 "OK" 0 downloadFailed

    ; Download succeeded — set variables
    StrCpy $SourceDir "$TEMP\Notepad4_latest"
    StrCpy $DisplayVersion $R2
    Goto updateCheckDone

    downloadFailed:
    IfSilent updateCheckDone  ; no messagebox in silent mode
    MessageBox MB_OK|MB_ICONEXCLAMATION \
        "Failed to download the latest version. The bundled version (${BUNDLED_VERSION}) will be installed."

    updateCheckDone:
    ; Clean up temp files
    Delete "$TEMP\notepad4_update.ini"
    Delete "$TEMP\notepad4_download_status.txt"

SectionEnd

;--------------------------------

Section "Notepad4" SEC01
SectionIn 1 2 3 RO

  SetOutPath $INSTDIR

  ; Include all the bundled binaries and configuration files
  File "Notepad4_${RELEASEVERSION}\Notepad4.exe"
  File "Notepad4_${RELEASEVERSION}\matepath.exe"
  File "Notepad4_${RELEASEVERSION}\matepath.ini"
  File "Notepad4_${RELEASEVERSION}\Notepad4 DarkTheme.ini"
  File "Notepad4_${RELEASEVERSION}\Notepad4.ini"
  File "Notepad4_${RELEASEVERSION}\License.txt"

  ; If a newer version was downloaded, overwrite with those files
  StrCmp $SourceDir "" skipCopyLatest

  CopyFiles /SILENT "$SourceDir\Notepad4.exe" "$INSTDIR\Notepad4.exe"
  CopyFiles /SILENT "$SourceDir\matepath.exe" "$INSTDIR\matepath.exe"
  CopyFiles /SILENT "$SourceDir\matepath.ini" "$INSTDIR\matepath.ini"
  CopyFiles /SILENT "$SourceDir\Notepad4 DarkTheme.ini" "$INSTDIR\Notepad4 DarkTheme.ini"
  CopyFiles /SILENT "$SourceDir\Notepad4.ini" "$INSTDIR\Notepad4.ini"
  IfFileExists "$SourceDir\License.txt" 0 +2
  CopyFiles /SILENT "$SourceDir\License.txt" "$INSTDIR\License.txt"

  ; Clean up downloaded files
  RMDir /r "$SourceDir"
  Delete "$TEMP\Notepad4_latest.zip"

  skipCopyLatest:

  WriteRegStr HKLM SOFTWARE\Notepad4 "Install_Dir" "$INSTDIR"

  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4" "DisplayName" "Notepad4"
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4" "DisplayIcon" "$INSTDIR\Notepad4.exe"
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4" "DisplayVersion" "$DisplayVersion"
  WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4" "NoModify" 1
  WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4" "NoRepair" 1
  WriteUninstaller "Uninstall.exe"

  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
  !define MUI_STARTMENUPAGE_DEFAULTFOLDER ${APPNAME}
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Notepad4.lnk" "$INSTDIR\Notepad4.exe"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\matepath.lnk" "$INSTDIR\matepath.exe"
  !insertmacro MUI_STARTMENU_WRITE_END

SectionEnd
;--------------------------------


Section "Replace Windows Editor" SEC02

  SectionIn 1 3
  ${If} ${SectionIsSelected} ${SEC02}
    ; Replace Windows Notepad with Notepad4

  ${If} ${AtLeastWin11}
  ${PowerShellExec} 'Get-AppxPackage *Microsoft.WindowsNotepad* | Remove-AppxPackage'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "" '$INSTDIR\Notepad4.exe'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "Debugger" '"$INSTDIR\Notepad4.exe" /z'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe\0\" "FilterFullPath" '$INSTDIR\Notepad4.exe'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe\1\" "FilterFullPath" '$INSTDIR\Notepad4.exe'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe\2\" "FilterFullPath" '$INSTDIR\Notepad4.exe'
  ${Else}
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "Debugger" '"$INSTDIR\Notepad4.exe" /z'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "" '$INSTDIR\Notepad4.exe'
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "UseFilter" "0"
  ${EndIf}
${EndIf}

SectionEnd


;--------------------------------


; Uninstaller Section
Section "Uninstall"
  Delete $INSTDIR\matepath.exe
  Delete $INSTDIR\matepath.ini
  Delete "$INSTDIR\Notepad4 DarkTheme.ini"
  Delete $INSTDIR\Notepad4.ini
  Delete $INSTDIR\Notepad4.exe
  Delete $INSTDIR\License.txt
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder

  Delete "$SMPROGRAMS\$StartMenuFolder\Notepad4.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\matepath.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
  RMDir "$SMPROGRAMS\$StartMenuFolder"

  ; Check if Notepad4 is the default notepad.exe value, if so restore Windows Notepad
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" ""
  StrCmp $0 '$INSTDIR\Notepad4.exe' value_matches done
  value_matches:
    ${If} ${AtLeastWin11}
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "" 'C:\Windows\notepad.exe'
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "Debugger"
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe\0\" "FilterFullPath"
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe\1\" "FilterFullPath"
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe\2\" "FilterFullPath"
    ${PowerShellExec} 'Get-AppxPackage -allusers Microsoft.WindowsNotepad | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register $$($_.InstallLocation)\AppXManifest.xml}'

  ${Else}
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "Debugger"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "" 'C:\Windows\notepad.exe'
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" "UseFilter"
  ${EndIf}

  done:

  ; Remove uninstall information from Add/Remove Programs
  DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4"
  DeleteRegKey HKLM "SOFTWARE\Notepad4"

SectionEnd

;--------------------------------
;Language
!insertmacro MUI_LANGUAGE "English"

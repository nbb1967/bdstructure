EnableExplicit

Global hInstance = GetModuleHandle_(#Null) ;' the handle to the application itself 
If hInstance = 0
  MessageRequester("Error", "Failed to get program handle.", #PB_MessageRequester_Error + #PB_MessageRequester_Ok) ; cannot be moved to resources: String Table is not available.
  End
EndIf

Procedure.s GetStringFromResources(StringID) ;extracting strings from String Table
  Protected result$, buf${#MAX_PATH}         ; #MAX_PATH == 260 
  If LoadString_(hInstance, StringID, @buf$, #MAX_PATH)  ;' returns number of characters in the string resource 
    result$ = buf$
  Else
    MessageRequester("Error", "Failed to get string from program resources.", #PB_MessageRequester_Error + #PB_MessageRequester_Ok) ; cannot be moved to resources: String Table is not available.
    End
  EndIf 
  ProcedureReturn result$ 
EndProcedure

Enumeration Misc
  #WINDOW
  #SYSTRAYICON
  #STREAM
  #TIMER
EndEnumeration

#SysTrayIconCreatedOrder1 = 1

Procedure MyCallback(WindowID, Message, WParam, LParam)
  If WindowID = WindowID(#WINDOW)   
    If Message = #WM_NOTIFYICON
      If wParam = #SysTrayIconCreatedOrder1
        Select lParam
          Case #NIN_BALLOONTIMEOUT      ;balloon timed out or was closed by the user
            SendMessage_(WindowID(#WINDOW), #WM_CLOSE, #Null, #Null)
          Case #NIN_BALLOONUSERCLICK    ;balloon got clicked by the user
            SendMessage_(WindowID(#WINDOW), #WM_CLOSE, #Null, #Null)
          Case #NIN_BALLOONHIDE         ;balloon got hidden
            SendMessage_(WindowID(#WINDOW), #WM_CLOSE, #Null, #Null)
        EndSelect
        
      EndIf
    EndIf   
  EndIf              
  ProcedureReturn #PB_ProcessPureBasicEvents
EndProcedure

OpenWindow(#WINDOW, 0, 0, 10, 10, "", #PB_Window_Invisible) ;invisible window to just have the systray
Define hIcon = LoadIcon_(hInstance,1)
AddSysTrayIcon(#SYSTRAYICON, WindowID(#WINDOW), hIcon)

Dim BDStructureArray.s(13)
BDStructureArray(0)  = "\BDMV\AUXDATA"
BDStructureArray(1)  = "\BDMV\BACKUP"
BDStructureArray(2)  = "\BDMV\BACKUP\BDJO"
BDStructureArray(3)  = "\BDMV\BACKUP\CLIPINF"
BDStructureArray(4)  = "\BDMV\BACKUP\JAR" 
BDStructureArray(5)  = "\BDMV\BACKUP\PLAYLIST"
BDStructureArray(6)  = "\BDMV\BDJO"
BDStructureArray(7)  = "\BDMV\CLIPINF"
BDStructureArray(8)  = "\BDMV\JAR"
BDStructureArray(9)  = "\BDMV\META"
BDStructureArray(10) = "\BDMV\PLAYLIST"
BDStructureArray(11) = "\BDMV\STREAM"
BDStructureArray(12) = "\CERTIFICATE"
BDStructureArray(13) = "\CERTIFICATE\BACKUP"

Define PathToBDMV$ = "\BDMV"    ;not needed in cycles

Enumeration StringID 6000 
  #AppName             ;6000, "BDStructure"
  #ContexMenu          ;6001, "Restore Blu-ray folder structure"       
  #DirectRun           ;6002, "Failed to get the path to the Blu-ray root folder. You are probably running an executable, but this program works differently.\n\nDo you want to open the user manual?"
  #FailedRunHelp       ;6003, "Failed to open user manual."  
  #FullStructure       ;6004, "Blu-ray folder structure is complete and does not need to be restored."
  #NotRootBD           ;6005, "The selected folder is not a Blu-ray root folder. Select the folder containing the BDMV folder."
  #NotStreem           ;6006, "There is no STREAM folder in the BDMV folder. It's not a Blu-ray."
  #StreemEmpty         ;6007, "M2TS files are not found in the STREAM folder. It's not Blu-ray." 
  #StreemOneFile       ;6008, "There is only one M2TS file in the STREAM folder. It's probably Remux. Restoring the folder structure will not turn Remux into Blu-ray.\n\nDo you want to continue?"
  #FailedCreateFolder  ;6009, "Failed to create folder:"
  #Success             ;6010, "Blu-ray folder structure restored successfully!"
EndEnumeration

SysTrayIconToolTip(#SYSTRAYICON, GetStringFromResources(#AppName))  ;tooltip on the notification area icon

If CountProgramParameters() = 0 ;if there are no command line arguments (running BDSTRUCTURE.EXE in the program folder)
  If MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#DirectRun), #PB_MessageRequester_Error + #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes  ;Yes button is pressed
    Define PathUserManual$ = GetPathPart(ProgramFilename()) + "\BDStructure User Manual.pdf"
    If Not RunProgram(PathUserManual$, "", "", #PB_Program_Open)
      MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#FailedRunHelp), #PB_MessageRequester_Error + #PB_MessageRequester_Ok)
    EndIf
  EndIf
  End
EndIf
Define PathBDRootFolder$ = ProgramParameter(0) ;get the path from the argument

;check that the Blu-ray structure is complete and does not need to be restored
Define iCounterFilesExist = 0
Define i
Define Path$
For i = 0 To 13 Step 1
  Path$ = PathBDRootFolder$ + BDStructureArray(i)
  If FileSize(Path$) = -2
    iCounterFilesExist + 1
  EndIf
Next
If iCounterFilesExist = 14
  MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#FullStructure), #PB_MessageRequester_Info + #PB_MessageRequester_Ok)
  End
EndIf

;сheck if the user made a mistake in selecting the Blu-ray root folder:
Path$ = PathBDRootFolder$ + PathToBDMV$
If FileSize(Path$) <> -2    ;there is no BDMV folder in the selected folder.
  MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#NotRootBD), #PB_MessageRequester_Error + #PB_MessageRequester_Ok)
  End
EndIf

Path$ = PathBDRootFolder$ + BDStructureArray(11)
If FileSize(Path$) <> -2        ;there is no STREAM folder in the selected folder.
  MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#NotStreem), #PB_MessageRequester_Error + #PB_MessageRequester_Ok)
  End
Else
  ;analyzing the STREAM folder
  Define m2tsFiles = 0
  If ExamineDirectory(#STREAM, Path$, "*.m2ts") ; Lists the M2TS files in the STREAM directory
    While NextDirectoryEntry(#STREAM)
      m2tsFiles + 1
    Wend
    FinishDirectory(#STREAM)  
  EndIf
  
  Select m2tsFiles  ; number of M2TS files
    Case 0          ;there are no M2TS files in the STREAM folder.
      MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#StreemEmpty), #PB_MessageRequester_Error + #PB_MessageRequester_Ok)
      End
    Case 1          ;there is only one m2ts file in the STREAM folder: it's probably a Remux
      If MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#StreemOneFile), #PB_MessageRequester_Warning + #PB_MessageRequester_YesNo) = #PB_MessageRequester_No     ;No button is pressed
        End
      EndIf
  EndSelect
EndIf

;creating a Blu-ray folder structure
For i = 0 To 13 Step 1
  Path$ = PathBDRootFolder$ + BDStructureArray(i)
  If FileSize(Path$) <> -2
    If Not CreateDirectory(Path$)
      MessageRequester(GetStringFromResources(#AppName), GetStringFromResources(#FailedCreateFolder) + #CRLF$ + Path$, #PB_MessageRequester_Error + #PB_MessageRequester_Ok)
      End
    EndIf
  EndIf	
Next

;preparation for sending success notification
Structure BD_NOTIFYICONDATA Align #PB_Structure_AlignC
  cbSize.l
  hWnd.i
  uID.l
  uFlags.l
  uCallbackMessage.l
  hIcon.i
  szTip.s{128}
  dwState.l
  dwStateMark.l
  szInfo.s{256}
  StructureUnion
    uTimeout.l
    uVersion.l
  EndStructureUnion
  szInfoTitle.s{64}
  dwInfoFlags.l
EndStructure

SetWindowCallback(@MyCallback(), #WINDOW)

Define NIData.BD_NOTIFYICONDATA
NIData\cbSize = SizeOf(BD_NOTIFYICONDATA)
NIData\hWnd = WindowID(0)
NIData\uID = #SysTrayIconCreatedOrder1
NIData\uFlags = #NIF_INFO | #NIF_MESSAGE
NIData\uCallbackMessage = #WM_NOTIFYICON                
NIData\uTimeout = 2 
NIData\uVersion = #NOTIFYICON_VERSION
NIData\szInfoTitle = GetStringFromResources(#AppName)
NIData\dwInfoFlags = #NIIF_USER | #NIIF_NOSOUND         ;#NIIF_NONE
NIData\szInfo = GetStringFromResources(#Success)

Shell_NotifyIcon_(#NIM_MODIFY, NIData)  ;sending success notification

AddWindowTimer(#WINDOW, #TIMER, 10000)
Define Event

Repeat
  Event = WaitWindowEvent()
  If Event = #PB_Event_Timer And EventTimer() = #TIMER  ; to be safe: time-out exit
    Break
  EndIf
  
Until Event = #PB_Event_CloseWindow

SetWindowCallback(0 , #WINDOW)

End

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 88
; FirstLine = 71
; Folding = -
; EnableXP
; DPIAware
; SharedUCRT
; UseIcon = BR48.ico
; Executable = bdstructure.exe
; DisableDebugger
; IncludeVersionInfo
; VersionField0 = 2,0,0,0
; VersionField1 = 2,0,0,0
; VersionField2 = NyBumBum
; VersionField3 = BDStructure
; VersionField4 = 2.0.0.0
; VersionField5 = 2.0.0.0
; VersionField6 = Blu-ray Disc folder structure repair utility
; VersionField7 = BDStructure
; VersionField8 = bdstructure.exe
; VersionField9 = Copyleft NyBumBum 2022-2025
; VersionField13 = nybumbum@gmail.com
; VersionField14 = bdstructure.ru
; AddResource = stringtable.rc
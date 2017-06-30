{StudioDialog XFCN as part of                               External Function for HyperCard 2.0+     }
{  THE                                                                                               }
{    DIGITAL                                                                                         }
{    SOUND STUDIO version 2.00                                               (c)1996 Matt DeFano     }
{                                                                                                    }
{StudioDialog is an interface extension for hyperCard allowing developers to create custom alert     }
{and progress dialog boxes and display them through HyperCard. StudioDialog supports all             }
{window definition procedures and traps all content clicks. Dialog can be created using any resource }
{complier such as SaRez or ResEdit.                                                                  }
{                                                                                                    }
{  NOTES AND CONVENTIONS:                                                                            }
{      * Because of build requrements, the event loop in the MAIN procedure CANNOT be                }
{        segmented (i.e. - placed in a seperate procedure)                                           }
{      * IT IS NOT ACCEPTABLE to call dispose() after RemoveRes -- RemoveRes disposes                }
{        the handle itself, calling dispose() will damage the master pointer list!!                  }
{      * HC = Hypercard 2.1                                                                          }
{      * Due to build requirements, (gPascalVar = 'AnyString' ), will crash, therfore, the HC        }
{        callback proc stringEqual is used instead.                                                  }
{                                                                                                    }
{  StudioDialog Syntax is as follows:                                                                }
{      for alert boxes:                                                                              }
{        StudioDialog(DLOGId,[text1],[text2],[text3],[text4])                                        }
{                                                                                                    }
{      for progress boxes:                                                                           }
{        StudioDialog("PROGRESS",DLOGId,WindowName,[text1],[text2],[text3],[text4])                  }
{                                                                                                    }
{      Example:                                                                                      }
{        Get StudioDialog(12128,"ParamText ^0")                                                      }
{                                                                                                    }
{    The following is StudioMix's Build (in order):                                                  }
{                                                                                                    }
{      RSRCRuntime.Lib    Contains runtime code for the resource.                                    }
{      Interface.lib        Contains Pascal Commands/Procs & Built-in Mac Toolbox routines           }
{      HyperXLib.Lib      Countains HyperCard XCMD/XFCN Memory data                                  }
{      HyperXCmd.p      HyperXCmd Contains jump code and HyperCard Callback procs                    }
{      StudioDialog.p      Main XFCN Code and Entrypoint                                             }

unit StudioDialog;

interface

uses
  HyperXCmd;

{interface main for entrypoint from HyperCard}
procedure Main (ParamPtr: XCmdPtr);

implementation

{procedure to pass a user error back to HyperCard}
procedure PassError (ParamPtr: XcmdPtr;
                TheErr: Integer);

  const
    Err800 = '(Error 800) Bad DITL Resource. Item 1 must be a validate ''Push Button''';
    Err801 = '(Error 801) Bad DITL Resource. Item 2 must be a ''Push Button''';
    Err802 = '(Error 802) Bad DITL Resource. Item 1 must be a ''UserItem''';
    Err803 = '(Error 803) Couldnt load the DLOG template resource, check the ID number.';
    Err804 = '(Error 804) StudioDialog general failure';

  var
    HyperResultHndl: Handle;

  begin
{determine which error was passed to "PassError" and convert it to a zero terminated string handle}
    case TheErr of
      800:
        HyperResultHndl := PasToZero(ParamPtr, Err800);
      801:
        HyperResultHndl := PasToZero(ParamPtr, Err801);
      802:
        HyperResultHndl := PasToZero(ParamPtr, Err802);
      803:
        HyperResultHndl := PasToZero(ParamPtr, Err803);
      804:
        HyperResultHndl := PasToZero(ParamPtr, Err804);
      otherwise
        HyperResultHndl := PasToZero(ParamPtr, Err804);
    end;

    ParamPtr^.ReturnValue := HyperResultHndl;  {pass the handle back to HyperCard}
  end;

{Funtion to return the number of the DITL item hit by the user that dismissed the dialog}
function DoItemHit (ParamPtr: XcmdPtr;
                ItemHit: Integer): Boolean;

  var
    ReturnStr: Str255;    {string to hold the integer}

  begin
    LongToStr(ParamPtr, ItemHit, ReturnStr);                  {convert the number to a string}
    ParamPtr^.ReturnValue := PasToZero(ParamPtr, ReturnStr);  {pass the string to HC}
    DoItemHit := True;                                        {return a flag that the event has been handled}
  end;

{procedure to update the visible region of a dialog (VisRgn)}
procedure DoUpdateDialog (TheDialog: DialogPtr);

  begin
    BeginUpdate(TheDialog);                      {tell the OS that were updating}
    UpdtDialog(TheDialog, TheDialog^.VisRgn);    {update the region}
    EndUpdate(TheDialog);                        {tell the OS were done}
  end;

{procedure to draw the 3pixel outline around the default (item 1) item of a dialog box}
procedure DrawCntrlOutline (Control: univ ControlHandle);

  const
    kCntlActivate = 0;        {Activation const}
    kCntlDeactivate = $FF;    {control is deactivated}

  var
    Oval: Integer;      {oval region of the control}
    OpRect: Rect;       {controls rectangle}
    OrigPen: PenState;  {pen state before draw}
    origPort: GrafPtr;  {original port before draw}

  begin
    if Control <> nil then    {be sure the control is good}
      begin
        GetPort(origPort);
        SetPort(Control^^.ContrlOwner);
        GetPenState(origPen);
        PenNormal;
        opRect := Control^^.ContrlRect;                      {get the rectangle of the control}
        InsetRect(opRect, -4, -4);                           {inset the rectangle}
        Oval := ((opRect.Bottom - opRect.Top) div 2) + 2;    {determine the oval rectangle}
        PenSize(3, 3);
        FrameRoundRect(opRect, Oval, Oval);                  {draw the oval}
        SetPenState(origPen);
        SetPort(OrigPort);
      end;
  end;

{function to handle a click inside the dialog window}
function DoContentClick (ParamPtr: XCmdPtr;
                WindowClicked: WindowPtr;
                Event: EventRecord): Boolean;

  var
    ItemHit: Integer;    {dialog item number clicked}

  const
    kItem1 = 1;          {number of default item}

  begin
    if DialogSelect(Event, WindowClicked, ItemHit) then    {if event then}
      begin
        if ItemHit >= kItem1 then    {if item was hit}
          DoContentClick := DoItemHit(ParamPtr, ItemHit)   {do content click routine}
        else
          DoContentClick := False;                         {we didn't handle the event}
      end;
  end;

{function to handle any mousedown event when the dialog has popped}
function DoMouseDown (ParamPtr: XcmdPtr;
                Event: EventRecord;
                StudioDLOG: DialogPtr): Boolean;

  const
    kUnlockCmd = 'set lockscreen to false';    {HC command to redraw the cd}
    kUserClosedWind = 0;                       {item returned if user closes window}

  var
    Part: Integer;            {part code of the screen hit}
    thisWindow: WindowPtr;    {window click occured in}

  begin
    part := FindWindow(event.where, thisWindow);    {find the window hit}
    if thisWindow = StudioDLOG then                 {if its our window}
      begin
        case part of

          inContent:     {click hit the window area}
            DoMouseDown := DoContentClick(ParamPtr, thisWindow, Event);

          inDrag:        {click was in the titleBar (drgRgn)}
            begin
              DoMouseDown := False;
              if thisWindow <> FrontWindow then  {be sure the window was ours}
                SysBeep(30)    {otherwise beep}
              else
                begin
                  DragWindow(ThisWindow, event.where, GetGrayRgn^^.rgnBBox);  {drag the window}
                  SendHCMessage(ParamPtr, kUnlockCmd);    {redraw the HC screen}
                end;
            end;

          inGoAway:     {click was in the closeBox}
            if TrackGoAway(thisWindow, event.where) then
              DoMouseDown := DoItemHit(ParamPtr, kUserClosedWind);

          otherwise
            begin
              SysBeep(30);
              DoMouseDown := False;
            end;

        end;  {end case}
      end  {end click in window}
    else
      begin
        SysBeep(30);
        DoMouseDown := False;
      end;
  end;  {procedure}

{function to filter all OS events while the dialog is visible}
function StudioFilterProc (ParamPtr: XcmdPtr;
                theDialog: DialogPtr;
                var TheEvent: EventRecord;
                var ItemHit: Integer): Boolean;

  const
    kReturnKey = CHAR(13);    {ASCII for return}
    KEnterKey = CHAR(3);      {ASCII for enter}
    kEscape = CHAR(27);       {ASCII for escape}
    kPeriod = '.';            {period key}
    kItem1 = 1;               {dialog item 1}
    kItem2 = 2;               {dialog item 2}
    kDummyClickTime = 8;      {visual hilite delay}

  var
    key: Char;                {any key pressed}
    itemType: Integer;        {type of button to hilite}
    itemHandle: Handle;       {handle to the item}
    ItemRect: Rect;           {rectangle of the item}
    FinalTicks: LongInt;      {unused}

  begin
    StudioFilterProc := false;
    case TheEvent.what of     {case the OS event}

      UpdateEvt:              {window needs an update}
        begin
          DoUpdateDialog(TheDialog);       {update the DLOG}
          GetDItem(TheDialog, kItem1, ItemType, ItemHandle, ItemRect);  {get default btn}
          DrawCntrlOutline(ItemHandle);    {redraw the outline}
        end;

      ActivateEvt:   {window was activated}
        begin
          DoUpdateDialog(TheDialog);  {update the dialog}
          GetDItem(TheDialog, kItem1, ItemType, ItemHandle, ItemRect);  {Redraw the button outline}
          DrawCntrlOutline(ItemHandle);
        end;

      KeyDown, AutoKey:   {a key was pressed}
        begin
          Key := CHAR(BAnd(theEvent.message, charCodeMask));     {get the character code}
          if (Key = kReturnKey) or (Key = KEnterKey) then        {a validate key ??}
            begin
              GetDItem(TheDialog, kItem1, ItemType, ItemHandle, ItemRect);

              if ItemType = btnCtrl then      {hilite the control}
                begin
                  hiliteControl(ControlHandle(ItemHandle), inButton);
                  Delay(kDummyClickTime, FinalTicks);
                  hiliteControl(ControlHandle(ItemHandle), 0);
                end;

              ItemHit := kItem1;  {return 1 as the item hit}
              StudioFilterProc := DoItemHit(ParamPtr, 1);
            end;  {end validate keyevent}

          if (Key = kEscape) or (Key = kPeriod) then      {a cancel key was pressed}
            begin
              GetDItem(TheDialog, kItem2, ItemType, ItemHandle, ItemRect);

              if ItemType = btnCtrl then    {hilite the cancel button}
                begin
                  hiliteControl(ControlHandle(ItemHandle), inButton);
                  Delay(kDummyClickTime, FinalTicks);
                  hiliteControl(ControlHandle(ItemHandle), 0);
                end;

              ItemHit := kItem2;
              StudioFilterProc := DoItemHit(ParamPtr, 2);
            end;
        end;

      MouseDown:
        StudioFilterProc := DoMouseDown(ParamPtr, TheEvent, TheDialog);    {user clicked mouse}

    end;
  end;

{procedure to draw a standard alert box -- NOT a progress}
procedure DoStandardDLOG (ParamPtr: XcmdPtr);

  const
    kItem1 = 1;                    {Item number of default item}
    kItem2 = 2;

  var
    ItemHit: Integer;         {enabled item number the user clicked}
    StudioDLOG: DialogPtr;    {Pointer to the dialog record}
    GotEvent: Boolean;        {Did we get the event}
    TheEvent: EventRecord;    {Record to a mac event}
    IsDone: Boolean;          {Event filter has recieved a done command?}
    ParamStr: Str255;         {HC Parameter string}
    IDInt: LongInt;           {DLOG resource id}
    Param0, Param1, Param2, Param3: Str255;    {Strings containing optional DLOG user messages}
    Item: Integer;           {Item number}
    Box: rect;               {rectangle of a DLOG Item}
    ItemHndl: Handle;        {Handle to a DLOG item}
    HasActivated: Boolean;   {boolean response for the activate DLOG function}

  begin
    ZeroToPas(ParamPtr, ParamPtr^.Params[1]^, ParamStr);  {get the DLOG res id from Parameter 1}
    IDInt := StrToLong(ParamPtr, ParamStr);               {convert the ParamStr to a LongInt}

    StudioDLOG := WindowPtr(NewPtr(SizeOf(WindowPtr)));
    StudioDLOG := GetNewDialog(IDInt, nil, POINTER(-1));

    if StudioDLOG = nil then
      exit(DoStandardDLOG);

    GetDItem(StudioDLOG, kItem1, Item, ItemHndl, Box);    {get a handle to DLOG item 1}

    if ParamPtr^.ParamCount > 1 then    {If StudioDialog contains optional String parameters then...}
      begin
        ZeroToPas(ParamPtr, ParamPtr^.Params[2]^, Param0);    {Get parameter 2}
        ZeroToPas(ParamPtr, ParamPtr^.Params[3]^, Param1);    {Get parameter 3}
        ZeroToPas(ParamPtr, ParamPtr^.Params[4]^, Param2);    {Get parameter 4}
        ZeroToPas(ParamPtr, ParamPtr^.Params[5]^, Param3);    {Get parameter 5}

        ParamText(Param0, Param1, Param2, Param3);    {replace hot static text (^0,^1,^2,^3) with the param strs}
      end;

    ShowWindow(StudioDLOG);        {pop the dialog}
    DoUpdateDialog(StudioDLOG);    {Update (redraw) the Dialog}
    HasActivated := DialogSelect(TheEvent, StudioDLOG, Item);    {Select (highlight) the dialog}

    DrawCntrlOutline(ItemHndl);    {draw bold outline around item 1}

    repeat
      GotEvent := WaitNextEvent(-1, TheEvent, 0, nil);                        {Get the mac event record}
      IsDone := StudioFilterProc(ParamPtr, StudioDLOG, TheEvent, ItemHit);    {Determine if filterProc obtained a close cmd}
    until IsDone;

    DisposeDialog(StudioDLOG);    {Dispose dialog and close the window}

  end;

{Procedure to draw a progress window}
procedure DrawNewProgress (ParamPtr: XcmdPtr);

  const
    kItem1 = 1;                             {Item number of default item}
    kBadDLOGid = 'Bad DLOG resource id';    {Error string for a bad resource}

  var
    ProgressPtr: WindowPtr;      {Pointer to the dialog record}
    ParamStr: Str255;            {HC Parameter string}
    IDInt: LongInt;              {DLOG resource id}
    Item: Integer;               {Item number}
    Box: rect;                   {rectangle of a DLOG Item}
    ItemHndl: Handle;            {Handle to a DLOG item}
    HasActivated: Boolean;       {boolean response for the activate DLOG function}
    PixPercent, Offset, TotPix: Integer;
    Param0, Param1, Param2, Param3: Str255;

  begin

    if ParamPtr^.ParamCount > 3 then
      begin
        ZeroToPas(ParamPtr, ParamPtr^.Params[4]^, Param0);    {Get parameter 2}
        ZeroToPas(ParamPtr, ParamPtr^.Params[5]^, Param1);    {Get parameter 3}
        ZeroToPas(ParamPtr, ParamPtr^.Params[6]^, Param2);    {Get parameter 4}
        ZeroToPas(ParamPtr, ParamPtr^.Params[7]^, Param3);    {Get parameter 5}

        ParamText(Param0, Param1, Param2, Param3);    {replace hot static text (^0,^1,^2,^3) with the param strs}
      end;

    ZeroToPas(ParamPtr, ParamPtr^.Params[2]^, ParamStr);  {get the DLOG res id from Parameter 1}
    IDInt := StrToLong(ParamPtr, ParamStr);               {convert the ParamStr to a LongInt}

    ProgressPtr := WindowPtr(NewPtr(SizeOf(GrafPtr)));
    ProgressPtr := GetNewXWindow(ParamPtr, 'DLOG', IDInt, FALSE, TRUE);    {Create the new DLOG record and place the window in front}

    if ProgressPtr = nil then
      begin
        PassError(ParamPtr, 804);
        exit(DrawNewProgress);
      end;

    ZeroToPas(ParamPtr, ParamPtr^.Params[3]^, ParamStr);  {get the windows name}
    SetWTitle(ProgressPtr, ParamStr);

    GetDItem(ProgressPtr, kItem1, Item, ItemHndl, Box);   {get the rectangle of the progress}
    ShowWindow(ProgressPtr);                              {be sure to show th window}
    DoUpdateDialog(ProgressPtr);                          {update it}

    SetPort(ProgressPtr);                                 {Draw the rectangle around the progress}
    PenSize(1, 1);
    PenNormal;
    FrameRect(Box);

    if ParamPtr^.ParamCount > 2 then
      begin
        ZeroToPas(ParamPtr, ParamPtr^.Params[3]^, ParamStr);
        PixPercent := StrToLong(ParamPtr, ParamStr);

        if PixPercent > 100 then
          PixPercent := 100;

        InsetRect(Box, 2, 2);
        Offset := Box.Left;
        TotPix := Box.Right - Box.Left;
        Box.Right := ((TotPix * PixPercent) div 100) + Offset;

        PaintRect(Box);
      end;

  end;

{procedure to handle clicks for a progress window}
procedure doProgressClick (WindEvent: EventRecord;
                ParamPtr: XcmdPtr);

  const
    kUnlockCmd = 'Set lockscreen to false';    {command to redraw the hyperCard screen}

  var
    ThisWindow: WindowPtr;    {Window pointer}
    CTRLPart: Integer;        {part code of any control hit}
    theControl: ControlHandle;  {handle to the control}

  begin

    case (FindWindow(WindEvent.where, thisWindow)) of    {make sure it happened in our window}

      InDrag:     {user hit the titleBar}
        begin
          DragWindow(thisWindow, WindEvent.where, GetGrayRgn^^.rgnBBox);  {drag the window}
          SendHCMessage(ParamPtr, kUnlockCmd);  {redraw the HyperCard screen}
        end;

      inGoAway:   {user clicked the close box}
        begin
          if TrackGoAway(thisWindow, WindEvent.where) then  {track the click}
            CloseXWindow(ParamPtr, thisWindow);    {close the hyperCard window}
        end;

      inContent:
        begin
          exit(doProgressClick);
        end;

    end;  {end case}
  end;  {end procedure}

{Procedure HyperCard jumps to when StudioDialog is called}
procedure Main (ParamPtr: XcmdPtr);

  const
    kUnlockCmd = 'Set Lockscreen to false';    {HC command to redraw the card window}
    kItem1 = 1;      {item 1 of the DLOG}

  var
    pixPercent: LongInt;              {percentage to fill progress}
    Item, Offset, TotPix: Integer;    {Integers for progress routines}
    ItemHndl: Handle;                 {a handle to a dialog item}
    Box: Rect;                        {rectangle to the dialog item}
    ParamStr, PropName: Str255;       {Hypercard parameter strings}
    ProgressWindow: WindowPtr;        {HyperCard progress window}
    WindEvent: EventRecord;           {Events}
    PropStr: Handle;                  {handle to a property string (ie set the PROPERTY of window...)}
    PropVal: Handle;                  {handle to a value string (ie set the property to PROPVALUE)}
    Part: LongInt;                    {window part code}
    OldGraf: GrafPtr;                 {old graphics port used}
    PropNamePtr: ptr;                 {a pointer to property names}
    DelPercent: Integer;
    DelBox: Rect;

  begin

    if ParamPtr^.ParamCount < 0 then  {check to see if this call is for EventHandling}
      begin

        with XWEventInfoPtr(ParamPtr^.Params[1])^ do     {get the property}
          begin
            ProgressWindow := EventWindow;
            WindEvent := Event;
            PropNamePtr := POINTER(EventParams[1]);
            ZeroToPas(paramPtr, PropNamePtr, PropName);  {convert the property name}
            PropVal := HANDLE(EventParams[2]);           {get the value of the property}
          end;

        case WindEvent.what of
          xCloseEvt:     {window was closed}
            begin
              ParamPtr^.PassFlag := True;    {tell HC its OK to dispose the window}
            end;

          xSetPropEvt:   {A propety was set (ie Set the property of window to value)}
            begin
              ZeroTermHandle(ParamPtr, PropVal);                 {zero terminate the handle}
              ZeroToPas(ParamPtr, POINTER(PropVal^), ParamStr);  {convert the value}

              PixPercent := StrToLong(ParamPtr, ParamStr);       {determine percentage}
              if PixPercent > 100 then                           {Note StrToLong will not return a neg integer}
                PixPercent := 100;

              DelPercent := 100 - PixPercent;

              SetPort(ProgressWindow);
              GetDItem(ProgressWindow, kItem1, Item, ItemHndl, Box);
              InsetRect(Box, 2, 2);
              Offset := Box.Left;
              TotPix := Box.Right - Box.Left;
              Box.Right := ((TotPix * PixPercent) div 100) + Offset;
              PaintRect(Box);

              GetDItem(ProgressWindow, kItem1, Item, ItemHndl, Box);
              InsetRect(Box, 2, 2);
              delBox.Right := Box.Right;
              Box.Right := ((TotPix * PixPercent) div 100) + Offset;
              delBox.left := Box.Right;
              delBox.Top := Box.Top;
              delBox.bottom := Box.Bottom;
              EraseRect(delBox);
              exit(main);
    {Must exit! will crash elsewise}
            end;

          activateEvt:
            begin
              DoUpdateDialog(ProgressWindow);  {Update the window}
              SetPort(ProgressWindow);         {redraw the progress box:}
              PenSize(1, 1);
              PenNormal;
              GetDItem(ProgressWindow, kItem1, Item, ItemHndl, Box);
              FrameRect(Box);
              exit(main);
            end;

          UpdateEvt:     {window needs an update}
            begin
              DoUpdateDialog(ProgressWindow);  {Update the window}
              SetPort(ProgressWindow);         {redraw the progress box:}
              PenSize(1, 1);
              PenNormal;
              GetDItem(ProgressWindow, kItem1, Item, ItemHndl, Box);
              FrameRect(Box);
              exit(main);
            end;

          xCursorWithin:                       {cursor is in the window}
            ParamPtr^.passFlag := True;        {tell hypercard to change cursor to standard arrow}

          MouseDown:     {user hit window}
            doProgressClick(WindEvent, ParamPtr);

          otherwise    {unneeded event occured (ie nulEvt)}
            Exit(Main);

        end;
        Exit(Main);
      end;

    InitCursor;  {set the cursor to the system standard (arrow)}

    ZeroToPas(ParamPtr, ParamPtr^.params[1]^, ParamStr);         {get the first Param value}

    if StringEqual(paramPtr, ParamStr, 'KILL') then              {Cmd is "Kill"}
      ExitToShell

    else if StringEqual(paramPtr, ParamStr, 'Progress') then     {Cmd is "Progress"}
      DrawNewProgress(ParamPtr)

    else
      DoStandardDLOG(ParamPtr);

  end;  {end procedure Main}

end.  {end unit StudioDialog}

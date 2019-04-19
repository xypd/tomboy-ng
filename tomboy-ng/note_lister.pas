unit Note_Lister;
{
 * Copyright (C) 2017 David Bannon
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

{	A class that knows how to read a directory full of notes. It keeps that list
	internally, unsorted (easier to sort in the display grid). Note details (
    Title, LastChange) can be updated (eg when a note is saved).

	It keeps a second list if user has done a search.

	History
	2017/11/23 - added functions to save and retreive the Form when a note
    is open. Also added a function to turn a fullfilename, a filename or an ID
    into a filename of the form GID.note

	2017/11/29  Added FileName to "Note has no Title" error message.
	2017/11/29  check to see if NoteList is still valid before passing
				on updates to a Note's status. If we are quiting, it may not be.
	2017/11/29  Fixed a memory leak that occured when Delete-ing a entry in the list
				Turns out you must dispose() that allocation before calling Delete.
	2017/12/28  Commented out unnecessary DebugLn
	2017/12/29  Added a debug line to ThisNoteIsOpen() to try and see if there is
				a problem there. Really don't think there is but ...
	2018/01/25  Changes to support Notebooks
    2018/02/14  Changed code that does Search All Notes stuff cos old code stopped on a tag
    2018/02/15  Can now search case sensitive or not and any combination or exact match
    2018/04/28  Set FixedRows to zero after Clean-ing strgrid, seems necessary in Trunk
    2018/06/26  Used E.Message in exception generated by bad XML - dah ....
    2018/07/04  Added a flag, XMLError, set if we found a note unable to index.    Why ?
    2018/08/24  Debugmode now set by calling process.
    2018/11/04  Added support for updating NoteList after a sync.
    2018/12/29  Small improvements in time to save a file.
    2019/04/13  Tweaks to overload to read help nodes
}

{$mode objfpc}

INTERFACE

uses
		Classes, SysUtils, Grids, Forms;

type
   PNotebook=^TNotebook;
   TNotebook = record
       // Name of the notebook
       Name : ANSIString;
       // The ID of the Template for this Notebook
       Template : ANSIString;
       // A list of the IDs of notes that are members of this Notebook.
       Notes : TStringList;
   end;

type

   { TNoteBookList }

   TNoteBookList = class(TList)
   private
     	function Get(Index : integer) : PNoteBook;
		procedure RemoveNoteBook(const NBName: AnsiString);
   public
        destructor Destroy; Override;
        { Adds the ID to the Notebook, if Notebook does not already exist, creates it }
        procedure Add(const ID, ANoteBook : ANSIString; IsTemplate : boolean);
        { Returns True if the passed ID is in the passed Notebook }
        function IDinNotebook(const ID, Notebook : ANSIstring) : boolean;
        function FindNoteBook(const NoteBook : ANSIString) : PNoteBook;
        { Removes any list entries that do not have a Template }
        procedure CleanList();
        property Items[Index : integer] : PNoteBook read Get; default;
   end;


type
  	PNote=^TNote;
  	TNote = record
        		{ will have 36 char GUI plus '.note' }
		ID : ANSIString;
        Title : ANSIString;
        		{ a 19 char date time string }
    	CreateDate : ANSIString;
                { a 19 char date time string, updateable }
    	LastChange : ANSIString;
        IsTemplate : boolean;
        OpenNote : TForm;
	end;

type                                 { ---------- TNoteInfoList ---------}

   { TNoteList }

   TNoteList = class(TList)   // TFPList
   private
    	function Get(Index: integer): PNote;
    public
        destructor Destroy; override;
        function Add(ANote : PNote) : integer;
        function FindID(const ID : ANSIString) : PNote;
        property Items[Index: integer]: PNote read Get; default;
    end;




type

   { NoteLister }

   { TNoteLister }

   TNoteLister = class
   private
    //DebugMode : boolean;
   	NoteList : TNoteList;
   	SearchNoteList : TNoteList;
    NoteBookList : TNoteBookList;
    		{ Returns a simple note file name, accepts simple filename or ID }
    function CleanFileName(const FileOrID: AnsiString): ANSIString;
    procedure CleanupList(const Lst : TNoteList);
   	procedure GetNoteDetails(const Dir, FileName: ANSIString;
        const SearchTerm: ANSIString; DontTestName: boolean=false);
    		{ Returns True if indicated note contains term in its content }
   	function NoteContains(const Term, FileName : ANSIString) : boolean;
            { Removes any complete xml tags from passed string, only matches '<' to '>' }
    function RemoveXml(const St: AnsiString): AnsiString;

   public
    DebugMode : boolean;

        // Indicates a note was found with an XML (or other) error, checked by calling process.
    XMLError : Boolean;
    ErrorNotes : TStringList;
    		{ The directory, with trailing seperator, that the notes are in }
   	WorkingDir : ANSIString;
   	SearchIndex : integer;
            { Adds details of note of passed to NoteList }
    procedure IndexThisNote(const ID : String);
            { Returns T is ID in current list, takes 36 char GUID or simple file name }
    function IsIDPresent(ID : string) : boolean;
    		{ Removes the Notebook entry with ID=Template from Notebook datastructure }
    procedure DeleteNoteBookwithID(FileorID : AnsiString);
    		{ Returns True if passed string is the ID or short Filename of a Template }
    function IsATemplate(FileOrID : AnsiString) : boolean;
			{ Adds a notebook to the internal data structure, probably only used
              when making a new Notebook and its Template }
	procedure AddNoteBook(const ID, ANoteBook: ANSIString; IsTemplate: Boolean);
    		{ Sets the passed Notebooks as 'parents' of the passed note. Any pre
              existing membership will be cancelled. The list can contain zero to
              many notebooks.  }
    procedure SetNotebookMembership(const ID: ansistring; const MemberList: TStringList);
    		{ If ID is empty, always returns false, puts all Notebook names in strlist.
            If ID is not empty, list is filtered for only notebooks that have that ID
            and returns True iff the passed ID is that of a Template.  A Notebook
            Template will have only one Notebook name in its Tags and that will
            be added to strlist. The StartHere template won't have a Notebook Name
            and therefore wont get mixed up here ???? }
   function GetNotebooks(const NBList : TStringList; const ID : ANSIString = '') : boolean;
    		{ Loads the Notebook StringGrid up with the Notebook names we know about.
              Add a bool to indicate we should only show Notebooks that have one or more
              notes mentioned in SearchNoteList. Call after GetNotes(Term) }
	procedure LoadStGridNotebooks(const NotebookGrid: TStringGrid;
        SearchListOnly: boolean);
            { Adds a note to main list, ie when user creates a new note }
    procedure AddNote(const FileName, Title, LastChange : ANSIString);
    		{ Read the metadata from all the notes in internal data structure,
              this is the main "go and do it" function.
              If 'term' is present we'll just search for notes with that term
              and store date in a different structure. And probably call LoadSearchGrid() }
   	function GetNotes(const Term: ANSIstring=''; DontTestName: boolean=false
        ): longint;
    		{ Copy the internal Note data to the passed TStringGrid, empting it first.
              This is the full note list.}
   	procedure LoadStGrid(const Grid : TStringGrid);
    		{ Returns True if its updated the internal record as indicated,
              will accept either an ID or a filename. }
    function AlterNote(ID, Change : ANSIString; Title : ANSIString = '') : boolean;

    function IsThisATitle(const Title : ANSIString) : boolean;
    		{ Returns the Form this note is open on, Nil if its not open }
    function IsThisNoteOpen(const ID : ANSIString; out TheForm : TForm) : boolean;
    		{ Tells the list that this note is open, pass NIL to indicate its now closed }
    procedure ThisNoteIsOpen(const ID : ANSIString; const TheForm : TForm);
    		{ Returns true if it can find a FileName to Match this Title }
    function FileNameForTitle(const Title: ANSIString; out FileName : ANSIstring): boolean;
    procedure StartSearch();
    function NextNoteTitle(out SearchTerm : ANSIString) : boolean;
    		{ removes note from int data, accepting either an ID or Filename }
    function DeleteNote(const ID : ANSIString) : boolean;
			{ Copy the internal data to the passed TStringGrid, empting it first
              call after a call to GetNotes(term), a non empty term triggering a disk
              search and filling in SearchNoteList.}
	procedure LoadSearchGrid(const Grid : TStringGrid);
    		{ Copy the internal data about notes in passed Notebook to passed TStringGrid
              for display. So, shown would be all the notes in the nominated notebook.}
    procedure LoadNotebookGrid(const Grid : TStringGrid; const NotebookName : AnsiString);
    		{ Returns the ID (inc .note) of the notebook Template, if an empty string we did
              not find a) the Entry in NotebookList or b) the entry had a blank template. }
    function NotebookTemplateID(const NotebookName : ANSIString) : AnsiString;

    constructor Create;
    destructor Destroy; override;
   end;


{ ----------------------- IMPLEMENTATION --------------- }

implementation

uses  laz2_DOM, laz2_XMLRead, LazFileUtils, LazUTF8, settings, LazLogger, SyncUtils;
{ Projectinspector, double click Required Packages and add LCL }

{ TNoteBookList }




{ ========================= N O T E B O O K L I S T ======================== }

function TNoteBookList.Get(Index: integer): PNoteBook;
begin
    Result := PNoteBook(inherited get(Index));
end;

destructor TNoteBookList.Destroy;
var
    I{, X} : Integer;
begin
        for I := 0 to Count-1 do begin
            { debugln(inttostr(I) + ' Destroying Notebook ' + Items[I]^.Name + '  template=' + Items[I]^.Template);
            for X := 0 to Items[I]^.Notes.Count - 1 do
            	debugln('Content ' + Items[I]^.Notes[X]);   }
          	Items[I]^.Notes.free;
    		dispose(Items[I]);
		end;
		inherited Destroy;
end;

procedure TNoteBookList.Add(const ID, ANoteBook: ANSIString; IsTemplate: boolean
		);
var
    NB : PNoteBook;
    NewRecord : boolean = False;
begin
    NB := FindNoteBook(ANoteBook);
    if NB = Nil then begin
        // debugln('Making a new record');
        NewRecord := True;
        new(NB);
    	NB^.Name:= ANoteBook;
        NB^.Template := '';
        NB^.Notes := TStringList.Create;
	end;
    if IsTemplate then begin
        // debugln('Its a Template');
        NB^.Template:= ID
    end else begin
      NB^.Notes.Add(ID);
      // debugln('Ordinary notebook entry');
	end;
	if NewRecord then inherited Add(NB);
end;

function TNoteBookList.IDinNotebook(const ID, Notebook: ANSIstring): boolean;
var
	Index : longint;
    TheNoteBook : PNoteBook;
begin
	Result := False;
    TheNoteBook := FindNoteBook(NoteBook);
    if TheNoteBook = Nil then exit();
    for Index := 0 to TheNoteBook^.Notes.Count-1 do
        if ID = TheNoteBook^.Notes[Index] then begin
            Result := True;
            exit();
		end;
end;

function TNoteBookList.FindNoteBook(const NoteBook: ANSIString): PNoteBook;
var
        Index : longint;
begin
        Result := Nil;
        for Index := 0 to Count-1 do begin
            if Items[Index]^.Name = NoteBook then begin
                Result := Items[Index];
                exit()
    	    end;
    	end;
end;

procedure TNoteBookList.CleanList;
var
	Index : integer = 0;
begin
	while Index < Count do begin
        if Items[Index]^.Template = '' then begin
          	Items[Index]^.Notes.free;
    		dispose(Items[Index]);
            Delete(Index);
		end else
        	inc(Index);
	end;
end;

		// Don't think we use this method  ?
procedure TNoteBookList.RemoveNoteBook(const NBName: AnsiString);
var
	Index : integer;
begin
	for Index := 0 to Count-1 do
    	if Items[Index]^.Name = NBName then begin
          	Items[Index]^.Notes.free;
    		dispose(Items[Index]);
            Delete(Index);
            break;
		end;
    debugln('ERROR, asked to remove a note book that I cannot find.');
end;



{ ====================== NoteLister ============================== }

{ -------------  Things relating to NoteBooks ------------------ }


procedure TNoteLister.AddNoteBook(const ID, ANoteBook: ANSIString; IsTemplate : Boolean);
begin
    NoteBookList.Add(ID, ANoteBook, IsTemplate);
end;

procedure TNoteLister.LoadNotebookGrid(const Grid: TStringGrid;
		const NotebookName: AnsiString);
var
    Index : integer;
begin
  	Grid.Clear;
    //Grid.Clean;
    Grid.FixedRows := 0;
    Grid.InsertRowWithValues(0, ['Title', 'Last Change', 'Create Date', 'File Name']);
    Grid.FixedRows := 1;
    // Scan the main list of notes looking for ones in this Notebook.
	for Index := 0 to NoteList.Count -1 do begin
        if NotebookList.IDinNotebook(NoteList.Items[Index]^.ID, NoteBookName) then begin
        	Grid.InsertRowWithValues(Grid.RowCount, [NoteList.Items[Index]^.Title,
        			NoteList.Items[Index]^.LastChange, NoteList.Items[Index]^.CreateDate,
            		NoteList.Items[Index]^.ID]);

		end;
	end;
    Grid.AutoSizeColumns;
end;

function TNoteLister.NotebookTemplateID(const NotebookName: ANSIString): AnsiString;
var
    Index : integer;
begin
    for Index := 0 to NotebookList.Count - 1 do begin
        if NotebookName = NotebookList.Items[Index]^.Name then begin
            Result := NotebookList.Items[Index]^.Template;
            exit();
		end;
	end;
    debugln('ERROR - asked for the template for a non existing Notebook');
    Result := '';
end;


procedure TNoteLister.DeleteNoteBookwithID(FileorID: AnsiString);
var
    Index : integer;
begin
    for Index := 0 to NotebookList.Count - 1 do begin
        if CleanFileName(FileorID) = NotebookList.Items[Index]^.Template then begin
          	NotebookList.Items[Index]^.Notes.free;
    		dispose(NotebookList.Items[Index]);
            NotebookList.Delete(Index);
            exit();
		end;
	end;
    debugln('ERROR - asked to delete a notebook by ID but cannot find it.');
end;


function TNoteLister.IsATemplate(FileOrID: AnsiString): boolean;
var
    SL : TStringList;
begin
	SL := TStringList.Create;
    Result := GetNotebooks(SL, CleanFileName(FileOrID));
    SL.Free;
end;

procedure TNoteLister.SetNotebookMembership(const ID : ansistring; const MemberList : TStringList);
var
    Index, BookIndex : integer;
begin
    // First, remove any mention of this ID from data structure
	for Index := 0 to NotebookList.Count - 1 do begin
        BookIndex := 0;
        while BookIndex < NotebookList.Items[Index]^.Notes.Count do begin
            if ID = NotebookList.Items[Index]^.Notes[BookIndex] then
            	NotebookList.Items[Index]^.Notes.Delete(BookIndex);
            inc(BookIndex);
        end;
	end;
	// Now, put back the ones we want there.
    for BookIndex := 0 to MemberList.Count -1 do
        for Index := 0 to NotebookList.Count - 1 do
            if MemberList[BookIndex] = NotebookList.Items[Index]^.Name then begin
                NotebookList.Items[Index]^.Notes.Add(ID);
                break;
            end;
end;

procedure TNoteLister.LoadStGridNotebooks(const NotebookGrid : TStringGrid; SearchListOnly : boolean);
var
    Index : integer;

    function FindInSearchList(NB : PNoteBook) : boolean;
    var  X : integer = 0;
    begin
        result := true;
        if Nil = SearchNoteList then
            exit;
        while X < NB^.Notes.Count do begin
            if Nil <> SearchNoteList.FindID(NB^.Notes[X]) then
                exit;
            inc(X);
        end;
        result := false;
    end;

begin
    NotebookGrid.Clear;
    NotebookGrid.FixedRows:=0;
    NotebookGrid.InsertRowWithValues(0, ['Notebooks']);
    NotebookGrid.FixedRows:=1;
    for Index := 0 to NotebookList.Count - 1 do begin
        if (not SearchListOnly) or FindInSearchList(NotebookList.Items[Index]) then begin
            NotebookGrid.InsertRowWithValues(NotebookGrid.RowCount, [NotebookList.Items[Index]^.Name]);
        end;
	end;
    NotebookGrid.AutoSizeColumns;
end;

function TNoteLister.GetNotebooks(const NBList: TStringList; const ID: ANSIString): boolean;
var
    Index, I : Integer;
begin
    // debugln('In GetNotebooks ID=' + ID);
	Result := false;
 	for Index := 0 to NoteBookList.Count -1 do begin
      	if ID = '' then
            NBList.Add(NotebookList.Items[Index]^.Name)
        else begin
            // I := NotebookList.Items[Index]^.Notes.Count;
            // debugln('Comparing ' + ID + ' with ' + NotebookList.Items[Index]^.Template);
            if ID = NotebookList.Items[Index]^.Template then begin
                // debugln('Looks like we asking about a template ' + ID);
                NBList.Add(NotebookList.Items[Index]^.Name);
                if NBList.Count > 1 then
                    debugln('Error, seem to have more than one Notebook Name for template ' + ID);
                Result := True;
                exit();
			end;
			for I := 0 to NotebookList.Items[Index]^.Notes.Count -1 do
            	if ID = NotebookList.Items[Index]^.Notes[I] then
                	NBList.Add(NotebookList.Items[Index]^.Name);
		end;
	end;
end;

{ -------------- Things relating to Notes -------------------- }


procedure TNoteLister.CleanupList(const Lst : TNoteList);
var
    Index : integer;
begin
    { Try and make sure these dates work, even if messed up }
    for Index := 0 to Lst.count -1 do begin;
        while UTF8length(Lst.Items[Index]^.CreateDate) < 20 do
        	Lst.Items[Index]^.CreateDate :=  Lst.Items[Index]^.CreateDate + ' ';
	Lst.Items[Index]^.CreateDate := copy(Lst.Items[Index]^.CreateDate, 1, 19);
        Lst.Items[Index]^.CreateDate[11] := ' ';
        while UTF8length(Lst.Items[Index]^.LastChange) < 20 do
              Lst.Items[Index]^.LastChange := Lst.Items[Index]^.LastChange + ' ';
        Lst.Items[Index]^.LastChange := copy(Lst.Items[Index]^.LastChange, 1, 19);
        Lst.Items[Index]^.LastChange[11] := ' ';
    end;
end;

procedure TNoteLister.GetNoteDetails(const Dir, FileName: ANSIString; const SearchTerm: ANSIString; DontTestName : boolean = false);
			// This is how we search for XML elements, attributes are different.
var
    NoteP : PNote;
    Doc : TXMLDocument;
	Node : TDOMNode;
    J : integer;
begin
    // debugln('Checking note ', FileName);
    if not DontTestName then
        if not IDLooksOK(copy(FileName, 1, 36)) then begin      // In syncutils !!!!
            ErrorNotes.Append(FileName + ', ' + 'Invalid ID in note filename');
            XMLError := True;
            exit;
        end;
  	if FileExistsUTF8(Dir + FileName) then begin
        if SearchTerm <> '' then
        	if not NoteContains(SearchTerm, FileName) then exit();
        new(NoteP);
        NoteP^.IsTemplate := False;
  	    try
	        try
                NoteP^.ID:=FileName;
  			    ReadXMLFile(Doc, Dir + FileName);
  			    Node := Doc.DocumentElement.FindNode('title');
      		    NoteP^.Title := Node.FirstChild.NodeValue;
                //if DebugMode then Debugln('Title is [' + Node.FirstChild.NodeValue + ']');
                Node := Doc.DocumentElement.FindNode('last-change-date');
                NoteP^.LastChange := Node.FirstChild.NodeValue;
                NoteP^.OpenNote := nil;
                Node := Doc.DocumentElement.FindNode('create-date');
                NoteP^.CreateDate := Node.FirstChild.NodeValue;
                Node := Doc.DocumentElement.FindNode('tags');
                if Assigned(Node) then begin
                  	for J := 0 to Node.ChildNodes.Count-1 do
                      	if UTF8pos('system:template', Node.ChildNodes.Item[J].TextContent) > 0 then
                            NoteP^.IsTemplate := True;
                    for J := 0 to Node.ChildNodes.Count-1 do
                        if UTF8pos('system:notebook', Node.ChildNodes.Item[J].TextContent) > 0 then
                        	NoteBookList.Add(Filename, UTF8Copy(Node.ChildNodes.Item[J].TextContent, 17, 1000), NoteP^.IsTemplate);
                            // Node.ChildNodes.Item[J].TextContent) may be something like -
                            // * system:notebook:DavosNotebook - this note belongs to DavosNotebook
                            // * system:template - this note is a template, if does not also have a
                            // Notebook tag its the StartHere note, otherwise its the Template for
                            // for the mentioned Notebook.
				end;
            except 		on E: EXMLReadError do begin
                            DebugLn('XML ERROR' + E.Message);
                            XMLError := True;
                            dispose(NoteP);
                            ErrorNotes.Append(FileName + ', ' + E.Message);
                            exit();
                        end;
            		    on EAccessViolation do DebugLn('Access Violation ' + FileName);
  		    end;
            if NoteP^.IsTemplate then begin    // Don't show templates in normal note list
                dispose(NoteP);
                exit();
			end;
			if SearchTerm = '' then
            		NoteList.Add(NoteP)
            else SearchNoteList.Add(NoteP);
  	    finally
      	    Doc.free;
  	    end;
  end else DebugLn('Error, found a note and lost it !');
end;


function TNoteLister.RemoveXml(const St : AnsiString) : AnsiString;
var
    X, Y : integer;
    FoundOne : boolean = false;
begin
    Result := St;
    repeat
        FoundOne := False;
        X := UTF8Pos('<', Result);
        if X > 0 then begin
            Y := UTF8Pos('>', Result);
            if Y > 0 then begin
                UTF8Delete(Result, X, Y-X+1);
                FoundOne := True;
            end;
        end;
    until not FoundOne;
end;

procedure TNoteLister.IndexThisNote(const ID: String);
begin
    GetNoteDetails(WorkingDir, CleanFileName(ID), '');
end;

function TNoteLister.IsIDPresent(ID: string): boolean;
var
    FileName : string;
    index : integer;
begin
    Result := False;
    FileName := CleanFileName(ID);
    for Index := 0 to NoteList.Count -1 do
      if NoteList.Items[Index]^.ID = FileName then
          exit(True);
end;


function TNoteLister.NoteContains(const Term, FileName: ANSIString): boolean;
var
    SL, SLNote : TStringList;
    //Content : ANSIString;
    I, Index : integer;
begin
    Result := False;
    SL := TStringList.Create;
    if Sett.CheckAnyCombination.Checked then begin
        SL.LineBreak:=' ';          // break up Term at each space
    end;
    SL.AddText(trim(Term));         // A single entry if CheckAnyCombination not checked.
    SLNote := TStringList.Create;
    SlNote.LoadFromFile(WorkingDir + FileName);
    for Index := 0 to SLNote.Count - 1 do
        SLNote.Strings[Index] := RemoveXML(SLNote.Strings[Index]);
    for I := 0 to SL.Count -1 do begin      // Iterate over search terms
        Result := False;
        for Index := 0 to SLNote.Count - 1 do begin // Check each line of note for a match against current word.
            if  Sett.CheckCaseSensitive.Checked then begin
                if (UTF8Pos(SL.Strings[I], SLNote.Strings[Index]) > 0) then begin
                    Result := True;
                    break;
                end;
            end else
                if (UTF8Pos(UTF8LowerString(SL.Strings[I]), UTF8LowerString(SLNote.Strings[Index])) > 0) then begin
                    Result := True;
                    break;
                end;
        end;
        if not Result then break;  // if failed to turn Result on for first word, no point in continuing
    end;
    // when we get here, if Result is true, run finished without a fail.
    FreeandNil(SLNote);
    FreeandNil(SL);
end;


procedure TNoteLister.AddNote(const FileName, Title, LastChange : ANSIString);
var
    NoteP : PNote;
begin
    new(NoteP);
    NoteP^.ID := CleanFilename(FileName);
    NoteP^.LastChange := copy(LastChange, 1, 19);
    NoteP^.LastChange[11] := ' ';
    NoteP^.CreateDate := copy(LastChange, 1, 19);
    NoteP^.CreateDate[11] := ' ';
    NoteP^.Title:= Title;
    NoteP^.OpenNote := nil;
    NoteList.Add(NoteP);
end;


function TNoteLister.GetNotes(const Term: ANSIstring = ''; DontTestName : boolean = false): longint;
var
    Info : TSearchRec;
begin
    XMLError := False;
    if Term = '' then begin
        NoteList.Free;
    	NoteList := TNoteList.Create;
        NoteBookList.Free;
        NoteBookList := TNoteBookList.Create;
        if DebugMode then debugln('Empty Note and Book Lists created');
	end else begin
        if DebugMode then debugln('Empty Search Lists created');
        SearchNoteList.Free;
    	SearchNoteList := TNoteList.Create;
    end;
    FreeandNil(ErrorNotes);
    ErrorNotes := TStringList.Create;

    if WorkingDir = '' then
    	DebugLn('In GetNotes with a blank working dir, thats going to lead to tears....');
    if DebugMode then debugln('Looking for notes in [' + WorkingDir + ']');
  	if FindFirst(WorkingDir + '*.note', faAnyFile and faDirectory, Info)=0 then begin
  		repeat
            //if DebugMode then debugln('Checking note [' + Info.Name + ']');
  			GetNoteDetails(WorkingDir, Info.Name, Term, DontTestName);
  		until FindNext(Info) <> 0;
  	end;
  	FindClose(Info);
    if DebugMode then debugLn('Finished indexing notes');
    if Term = '' then begin
        CleanUpList(NoteList);
        NotebookList.CleanList();
        Result := NoteList.Count;
	end else begin
    	CleanUpList(SearchNoteList);
		result := NoteList.Count;
	end;
end;


procedure TNoteLister.LoadStGrid(const Grid : TStringGrid);
var
    Index : integer;
    // T1, T2, T3, T4 : dword;
begin
    // T1 := gettickcount64();
  	Grid.Clear;                       { TODO : we call these three lines from three different places ! }
    Grid.FixedRows := 0;
    Grid.InsertRowWithValues(0, ['Title', 'Last Change', 'Create Date', 'File Name']);
    Grid.FixedRows := 1;
    // T2 := gettickcount64();    // 2mS
	for Index := 0 to NoteList.Count -1 do begin
        Grid.InsertRowWithValues(Index+1, [NoteList.Items[Index]^.Title,
        	NoteList.Items[Index]^.LastChange, NoteList.Items[Index]^.CreateDate,
            NoteList.Items[Index]^.ID]);
	end;
    // T3 := gettickcount64();     // 3mS
    // Grid.AutoSizeColumns;            // Slow, so, instead, we call it on the SearchUnit.FormActivate()
    //T4 := gettickcount64();     // 0mS
    //debugln('NoteLister - LoadStGrid ' + inttostr(T2 - T1) + ' ' + inttostr(T3 - T2) + ' ' + inttostr(T4 - T3));
end;

procedure TNoteLister.LoadSearchGrid(const Grid: TStringGrid);
var
    Index : integer;
begin
  	Grid.Clear;
    Grid.FixedRows := 0;
    Grid.InsertRowWithValues(0, ['Title', 'Last Change', 'Create Date', 'File Name']);
    Grid.FixedRows := 1;
    for Index := 0 to SearchNoteList.Count -1 do begin
        Grid.InsertRowWithValues(Index+1, [SearchNoteList.Items[Index]^.Title,
        	SearchNoteList.Items[Index]^.LastChange, SearchNoteList.Items[Index]^.CreateDate,
            SearchNoteList.Items[Index]^.ID]);
	end;
    Grid.AutoSizeColumns;
end;


function TNoteLister.AlterNote(ID, Change: ANSIString; Title: ANSIString): boolean;
var
    Index : integer;
begin
	result := False;
    for Index := 0 to NoteList.Count -1 do begin
        if CleanFilename(ID) = NoteList.Items[Index]^.ID then begin
        	if Title <> '' then
            	NoteList.Items[Index]^.Title := Title;
        	if Change <> '' then
                NoteList.Items[Index]^.LastChange := copy(Change, 1, 19);
            	NoteList.Items[Index]^.LastChange[11] := ' ';
            Result := True;
            exit();
		end;
	end;
end;

function TNoteLister.IsThisATitle(const Title: ANSIString): boolean;
var
    Index : integer;
begin
  	Result := False;
	for Index := 0 to NoteList.Count -1 do begin
        if Title = NoteList.Items[Index]^.Title then begin
        	Result := True;
            break;
		end;
	end;
end;

function TNoteLister.CleanFileName(const FileOrID : AnsiString) : ANSIString;
begin
  	if length(ExtractFileNameOnly(FileOrID)) = 36 then
        Result := ExtractFileNameOnly(FileOrID) + '.note'
    else
        Result := ExtractFileNameOnly(FileOrID);
end;

function TNoteLister.IsThisNoteOpen(const ID: ANSIString; out TheForm : TForm): boolean;
var
    Index : integer;
begin
  	Result := False;
    TheForm := Nil;
	for Index := 0 to NoteList.Count -1 do begin
        if CleanFileName(ID) = NoteList.Items[Index]^.ID then begin
        	TheForm := NoteList.Items[Index]^.OpenNote;
            Result := not (NoteList.Items[Index]^.OpenNote = Nil);
            break;
		end;
	end;
end;

procedure TNoteLister.ThisNoteIsOpen(const ID : ANSIString; const TheForm: TForm);
var
    Index : integer;
    //cnt : integer;
begin
    if NoteList = NIl then
        exit;
    if NoteList.Count < 1 then begin
        //DebugLn('Called ThisNoteIsOpen() with empty but not NIL list. Count is '
        //		+ inttostr(NoteList.Count) + ' ' + ID);
        // Occasionally I think we see a non reproducable error here.
        // I believe is legal to start the for loop below with an empty list but ....
        // When we are creating the very first note in a dir, this haappens. Count should be exactly zero.
	end;
	//cnt := NoteList.Count;
	for Index := 0 to NoteList.Count -1 do begin
      	//writeln('ID = ', ID, ' ListID = ', NoteList.Items[Index]^.ID);
        if CleanFileName(ID) = NoteList.Items[Index]^.ID then begin
            NoteList.Items[Index]^.OpenNote := TheForm;
            break;
		end;
	end;
    // if Index = (NoteList.Count -1) then DebugLn('Failed to find ID in List ', ID);
end;

function TNoteLister.FileNameForTitle(const Title: ANSIString; out FileName : ANSIstring): boolean;
var
    Index : integer;
begin
    FileName := '';
  	Result := False;
	for Index := 0 to NoteList.Count -1 do begin
        if lowercase(Title) = lowercase(NoteList.Items[Index]^.Title) then begin
            FileName := NoteList.Items[Index]^.ID;
        	Result := True;
            break;
		end;
	end;
end;

procedure TNoteLister.StartSearch();
begin
	SearchIndex := 0;
end;

function TNoteLister.NextNoteTitle(out SearchTerm: ANSIString): boolean;
begin
  	Result := False;
	if SearchIndex < NoteList.Count then begin
    	SearchTerm := NoteList.Items[SearchIndex]^.Title;
    	inc(SearchIndex);
        Result := True;
	end;
end;

function TNoteLister.DeleteNote(const ID: ANSIString): boolean;
var
    Index : integer;
    // TestID : ANSIString;
begin
    {if length(ID) = 36 then
        TestID := ID + '.note'
    else
    	TestID := ID;  }
	result := False;
    for Index := 0 to NoteList.Count -1 do begin
        if CleanFileName(ID) = NoteList.Items[Index]^.ID then begin
        	dispose(NoteList.Items[Index]);
        	NoteList.Delete(Index);
        	Result := True;
        	break;
		end;
	end;
    if Result = false then
        DebugLn('Failed to remove ref to note in NoteLister ', ID);
end;

constructor TNoteLister.Create;
begin
    SearchNoteList := nil;
    NoteList := nil;
    NoteBookList := Nil;
    ErrorNotes := Nil;
end;


destructor TNoteLister.Destroy;
begin
    NoteBookList.Free;
    NoteBookList := Nil;
    SearchNoteList.Free;
    SearchNoteList := Nil;
    NoteList.Free;
    NoteList := Nil;
    ErrorNotes.Free;
    ErrorNotes := Nil;
	inherited Destroy;
end;

{  =========================  TNoteList ====================== }


destructor TNoteList.Destroy;
var
  I : integer;
begin
    // DebugLn('NoteList - disposing of items x ' + inttostr(Count));
	for I := 0 to Count-1 do begin
    	dispose(Items[I]);
	end;
	inherited Destroy;
end;

function TNoteList.Add(ANote: PNote): integer;
begin
    result := inherited Add(ANote);
end;



function TNoteList.FindID(const ID: ANSIString): PNote;
var
    Index : longint;
begin
    Result := Nil;
    for Index := 0 to Count-1 do begin
        if Items[Index]^.ID = ID then begin
            Result := Items[Index];
            exit()
		end;
	end;
end;

function TNoteList.Get(Index: integer): PNote;
begin
    Result := PNote(inherited get(Index));
end;


end.


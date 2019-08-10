% ======================================================================
%> @file PASensorDataImport.cpp
%> @brief Class for updating display properties of data found in a PASensorData
%> object.
% ======================================================================
%> @brief The PASensorDataImport class handles the interface between the
%> line handles connected with PASensorData signals.
% ======================================================================
classdef PASensorDataImport < handle
    properties(Constant)
        FIG_FUNCTION = @importDlg;
        FIG_WIDTH_PIXELS = 380;
        FIG_WIDTH_CHARS = 106;
        
        FIG_HEIGHT_PIXELS = 640;
        FIG_NAME = 'Import Accelerometer Data File';

        SEPARATORS = {',',';',' ','\t'};
        MAX_LINES = 16;
        
        MIN_FILENAME_WIDTH_CHARS = 80;
        MIN_TABLE_WIDTH_CHARS = 100;
        MIN_CONTENTS_WIDTH_CHARS = 100;
        FIG_BUFFER_CHARS = 3;
        CONFIRM_BUTTON_BUFFER_CHARS = 20; % right edge
    end
    properties(SetAccess=protected)
        figureH;
        handles;
        cancelled = false;  % true when cancelled
        confirmed = true; % true when confirmed
        numLinesScanned = 0;
        lines = {};  % scanned lines
        settings;   % struct with fields:
                    %   headerline = 1;
                    %   separator = ',';
                    %   filename ='';
    end
    
    methods
        function this = PASensorDataImport(importSettings)
            this.figureH = this.FIG_FUNCTION('visible','off');            
            this.handles = guidata(this.figureH);
            
            if(nargin<1 || ~isstruct(importSettings))
                importSettings = [];
            end
            
            this.settings = mergeStruct(this.getDefaults(), importSettings);
            
            this.initWidgets();            
            this.initCallbacks();
            this.setFile(this.settings.filename);
            set(this.figureH,'visible','on');
            uiwait(this.figureH);
        end 
        
        function settings = getSettings(this)
            settings = this.settings;
        end
        
        function didSet = setHeaderLineNum(this, lineNum)
            didSet = false;
            if(lineNum>=0 && lineNum <= this.numLinesScanned)
                this.settings.headerLineNum = lineNum;
                this.updateGUI();
                didSet = true;
            end
        end
        
        function didSet = setSeparator(this, separator)
            didSet = false;
            if(any(strcmpi(this.SEPARATORS,separator)))
                this.settings.separator = separator;
                this.updateGUI();
                didSet = true;
            end
        end        
        
        function didSet = setFile(this,fullfilename)
            didSet = false;
            if(exist(fullfilename,'file'))
                try
                    this.settings.filename = fullfilename;
                    set(this.handles.text_filename,'string',fullfilename,'enable','on');
                    fid = fopen(this.settings.filename,'r');
                    strings = textscan(fid,'%[^\n]',this.MAX_LINES);
                    strings = strings{1};
                    this.lines = strings;
                    this.numLinesScanned = numel(strings);
                    
                    lineNums = num2str((0:this.numLinesScanned-1)');
                    if(this.settings.headerLineNum>this.numLinesScanned)
                        this.settings.headerLineNum = 0;
                    end
                    set(this.handles.menu_headerLineNum,'string',lineNums,'value',this.settings.headerLineNum+1);

                    
                    %strcat({'Line '},num2str(transpose(1:numLinesScanned)),{': '},strings)
                    %set(this.handles.edit_fileContents,'string',char(strings));
                    dispStr = strcat(num2str(transpose(1:this.numLinesScanned)),{':    '},strings);
                    set(this.handles.edit_fileContents,'string',dispStr,'enable','inactive');  % make it look nicer now.
                    set(this.handles.table_headerRow,'enable','on');
                    if(this.settings.headerLineNum>0)
                        
                    end
                    fclose(fid);
                    % how many lines do we have.
                    didSet = true;
                    this.resizeGUI();
                    this.updateGUI();
                    this.enableWidgets();
                catch me
                    showME(me);
                end
            end 
        end
        
        function resizeGUI(this)
            fileContentWidth = size(char(get(this.handles.edit_fileContents,'string')),2);
            resizeWidth = max([numel(this.settings.filename) - this.MIN_FILENAME_WIDTH_CHARS
                fileContentWidth - this.MIN_CONTENTS_WIDTH_CHARS]);
            
            if(resizeWidth>0)
                resizeWidth = resizeWidth*0.9;
                fig_pos= get(this.figureH,'position');
                table_pos = get(this.handles.table_headerRow,'position');
                text_pos = get(this.handles.text_filename,'position');
                edit_pos = get(this.handles.edit_fileContents,'position');
                confirm_pos = get(this.handles.push_confirm,'position');
                fig_pos(3) = this.FIG_WIDTH_CHARS + resizeWidth;
                table_pos(3) = this.MIN_TABLE_WIDTH_CHARS + resizeWidth;
                text_pos(3) = this.MIN_FILENAME_WIDTH_CHARS + resizeWidth;
                edit_pos(3) = this.MIN_CONTENTS_WIDTH_CHARS + resizeWidth;
                confirm_pos(1) = fig_pos(3)-this.CONFIRM_BUTTON_BUFFER_CHARS;
                
                set(this.figureH,'position',fig_pos);
                set(this.handles.table_headerRow,'position',table_pos);
                set(this.handles.text_filename,'position',text_pos);
                set(this.handles.edit_fileContents,'position',edit_pos);
                set(this.handles.push_confirm,'position',confirm_pos);                
            end           
        end
        
        % Primary method for refreshing gui
        function updateGUI(this)
            h = this.handles.table_headerRow;
            values = this.getColumnValues();
            if(this.settings.headerLineNum>0)
                fields = this.getColumnNames();
                numFields = numel(fields);
                if(numFields~=numel(values))                    
                    set(h,'columnname',fields,'data',repmat({'<mismatch>'},size(fields)),...
                        'rowName',{});
                    set(this.handles.text_fieldCount,'string','');
                else
                    fieldMsg = sprintf('Fields found: %d',numel(fields));
                    colfmt = {};
                    rowNames = {};
                    makeSelections = true;
                    if(makeSelections)
                        %colfmt = fields;
                        %colfmt(:) = {'logical'};
                        value = {true};
                        row1 = values;
                        row2 = values;
                        row2(:)= value;
                        row3 = fields;
                        
                        % Don't try drop down menu right now
                        row0 = values;
                        cellOptions = {'Import','Date','Time','Date and Time','Exclude'};
                        colfmt = values;
                        [colfmt{:}] = deal(cellOptions);
                        colfmt = {};
                        % row0(:) = {'Import'};
                        values = [row1
                            row2
                            row3];
                        rowNames = {'Value';'Include';'Display name'};
                        %[values{:}] = deal(value);
                       
                    end
                    set(h,'columnname',fields,'data',values,...
                        'columnformat',colfmt,'columneditable',true,...
                        'rowname',rowNames);
                    set(this.handles.text_fieldCount,'string',fieldMsg);
                    fitTable(h);
                    table_pos = get(h,'position');
                    fig_pos = get(this.figureH,'position');
                    fig_width = fig_pos(3);
                    new_width = sum(table_pos([1,3]))+this.FIG_BUFFER_CHARS;
                    if(new_width>fig_width)
                        fig_pos(3) = new_width;
                        set(this.figureH,'position',fig_pos);
                    else
                        contents_pos = get(this.handles.edit_fileContents,'position');
                        cur_width = sum(contents_pos([1 3]))+this.FIG_BUFFER_CHARS;
                        if(new_width < cur_width && cur_width< fig_width)
                            fig_pos(3) = cur_width;
                            set(this.figureH,'position',fig_pos);
                        end                        
                    end
                end
            else
                
            end
            
           %h = this.handles.edit_fileContents;
           %j = findjobj(h);
           % methods(j)
           %selectionColor = java.awt.Color(0,1,0);  % =green
           % properties(j)
        end
        function fields = getColumnNames(this)
            fields = {};
            headerLine = this.getHeaderLine();            
            if(~isempty(headerLine))
                fields = strtrim(strsplit(headerLine,this.settings.separator));
            end
        end
        function values = getColumnValues(this)
            values = {};
            valueLine = this.getValueLine();
            if(~isempty(valueLine))
                values = strtrim(strsplit(valueLine,this.settings.separator));
            end
        end
        function [fields, values] = parseHeaderLine(this)
            fields = this.getColumnNames();
            values = this.getColumnValues();            
        end
        function curLine = getHeaderLine(this)
            curLine = [];
            if(~isempty(this.lines) && this.settings.headerLineNum>0)                
                curLine = this.lines{this.settings.headerLineNum};
            end
        end
        function curLine = getValueLine(this)
           curLine = [];
           if(~isempty(this.lines) && ...
                   this.settings.headerLineNum>0 ...
                   && this.settings.headerLineNum>0)
               curLine = this.lines{this.settings.headerLineNum+1};
           end           
        end
        
        function cancel(this)
            this.cancelled = true;
            this.close();
        end
        function confirm(this)
            this.confirmed = true;
            this.close();
        end
        function close(this)
            delete(this.figureH);        
        end
    end
    
    methods(Access=protected)
        function disableWidgets(this)
           set([this.handles.label_separator
                this.handles.label_headerLineNum
                this.handles.menu_separator
                this.handles.menu_headerLineNum
                this.handles.push_confirm
                this.handles.table_headerRow],'enable','off'); 
        end
        function enableWidgets(this)
           set([this.handles.label_separator
                this.handles.label_headerLineNum
                this.handles.menu_separator
                this.handles.menu_headerLineNum
                this.handles.push_confirm
                this.handles.table_headerRow],'enable','on');
        end
        function initWidgets(this)
            set(this.figureH,'name',this.FIG_NAME);
            
            set(this.handles.table_headerRow,'rearrangeablecolumns','off',...
                'columnname',[],'data',{});            
            set(this.handles.table_headerRow,'fontName','default','fontsize',12);
            set(this.handles.push_confirm,'string','Import');
            set(this.handles.text_filename,'string','<no file selected>','enable','off');
            set(this.handles.edit_fileContents,'string','','max',2,... % make multi line
                'fontName','default','fontsize',12,'enable','off'); % don't allow editing.
            
            lineNums = num2str((0:this.MAX_LINES-1)');
            set(this.handles.menu_headerLineNum,'string',lineNums,'value',this.settings.headerLineNum+1);
            
            set(this.handles.menu_separator,'string',this.SEPARATORS);
            setMenuSelection(this.handles.menu_separator,this.settings.separator);
            
            set(this.handles.text_fieldCount,'string','');
            this.disableWidgets();
        end
        
        function initCallbacks(this)
            set(this.figureH,'CloseRequestFcn',@this.closeCallback);
            set(this.handles.menu_separator,'callback',@this.menuSeparatorCallback);
            set(this.handles.menu_headerLineNum,'callback',@this.menuHeaderLineNumCallback);
            set(this.handles.push_cancel,'callback',@this.cancelCallback);
            set(this.handles.push_confirm,'callback',@this.confirmCallback);
            set(this.handles.push_fileSelect,'callback',@this.selectFileCallback);
        end
        
        % GUI Callbacks
        function cancelCallback(this, hObject, evtData)
            this.cancel();
        end
        function closeCallback(this, hObject, evtData)
            this.close();
        end
        function confirmCallback(this, hObject, evtData)
            this.confirm();
        end
        
        function menuHeaderLineNumCallback(this, hMenu, ~)
            newValue = str2double(getMenuString(hMenu));
            preValue = this.settings.headerLineNum;
            try
                if(~this.setHeaderLineNum(newValue))
                    set(hMenu,'value',preValue);
                end
            catch me
                warndlg('An error occurred while trying to set the header line number.  I''m sorry :(');
                set(hMenu,'value',preValue);
                showME(me);
            end
        end

        function menuSeparatorCallback(this, hMenu, evtData)
            newValue = getMenuString(hMenu);
            preValue = this.settings.headerLineNum;
            try
                if(~this.setSeparator(newValue))
                    set(hMenu,'value',preValue);
                end
            catch me
                warndlg('An error occurred while trying to set the field separator.  I''m sorry :(');
                set(hMenu,'value',preValue);
                showME(me);
            end
        end
        
        function selectFileCallback(this, hButton, evtData)
            f=uigetfullfile({'*.csv','Comma separated values (.csv)';'*.*','All files'},...
                'Select a file',this.settings.filename);
            if(exist(f,'file'))
                this.setFile(f);
            end
        end
    end
    
    methods(Static)
        % ======================================================================
        %> @brief Gets parameters for default initialization of a
        %> PASensorDataImport instance.
        %> @retval Struct of default paramters.  Fields include
        %> - @c trimResults
        % ======================================================================
        function paramStruct = getDefaults()
            paramStruct.headerLineNum = PANumericParam('default',1,'min',0,'description','Number of header lines to skip');
            paramStruct.separator = PAStringParam('default',',','description','Field separator');
            paramStruct.filename =PAFilenameParam('default','','description','Import filename');
        end         
    end
end


%         function editHeaderLineNumCallback(this, hEdit, ~, lineTag)
%             preValueStr = num2str(this.settings.headerLineNum);
%             newValue = str2double(get(hEdit,'string'));
%             try
%                 if(isempty(newValue) || ~isnumeric(newValue))
%                     set(hEdit,'string',preValueStr);
%                 else
%                     if(~this.setHeaderLineNum(newValue))
%                         set(hEdit,'string',preValueStr);
%                     end
%                 end
%             catch me
%                 warndlg('An error occurred while trying to change the label.  I''m sorry :(');
%                 set(hEdit,'string',preValueStr);
%                 showME(me);
%             end
%         end

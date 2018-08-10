% ======================================================================
%> @file PADataImport.cpp
%> @brief Class for updating display properties of data found in a PAData
%> object.
% ======================================================================
%> @brief The PADataImport class handles the interface between the
%> line handles connected with PAData signals.
% ======================================================================
classdef PADataImport < handle
    properties(Constant)
        figureFcn = @importDlg;
        SEPARATORS = {',',';',' ','\t'};
        figureName = 'Import Accelerometer Data File';
        
        % These come from the .fig file and are the tag prefixes for the
        % row of interactive widgets.

    end
    properties(SetAccess=protected)
        figureH;
        handles;
        cancelled = false;  % true when cancelled
        numLinesToScan = 15;
        settings;   % struct with fields:
                    %   numHeaderLines = 1;
                    %   separator = ',';
                    %   filename ='';
    end
    
    methods
        function this = PADataImport(importSettings)
            this.figureH = this.figureFcn('visible','off');
            
            this.handles = guidata(this.figureH);
            
            if(nargin<1 || ~isstruct(importSettings))
                importSettings = [];
            end
            
            this.settings = mergeStruct(this.getDefaultParameters(), importSettings);

            
            this.initWidgets();
            this.initCallbacks();
            this.setFile(this.settings.filename);
            set(this.figureH,'visible','on');
            uiwait(this.figureH);
        end 
        
        function settings = getSettings(this)
            settings = this.settings;
        end
        function didSet = setNumHeaderLines(this, numLines)
            didSet = false;
            if(numLines>=0)
                this.numHeaderLines = numLines;
                didSet = true;
            end
        end
        
        function didSet = setFile(this,fullfilename)
            didSet = false;
            if(exist(fullfilename,'file'))
                try
                    this.settings.filename = fullfilename;
                    set(this.handles.text_filename,'string',fullfilename);
                    fid = fopen(this.settings.filename,'r');
                    strings = textscan(fid,'%[^\n]',this.numLinesToScan);
                    strings = strings{1};
                    
                    numLinesScanned = numel(strings);
                    %strcat({'Line '},num2str(transpose(1:numLinesScanned)),{': '},strings)
                    %set(this.handles.edit_fileContents,'string',char(strings));
                    dispStr = strcat(num2str(transpose(1:numLinesScanned)),{':    '},strings);
                    set(this.handles.edit_fileContents,'string',dispStr);
                    if(this.settings.numHeaderLines>0)
                        
                    end
                    fclose(fid);
                    
                    % how many lines do we have.
                    didSet = true;
                catch me
                    showME(me);
                end
            end 
        end
        
        function cancel(this)
            this.cancelled = true;
            this.close();
        end
        function confirm(this)
            this.close();
        end
        function close(this)
            delete(this.figureH);        
        end
    end
    
    methods(Access=protected)
        function initWidgets(this)
            set(this.figureH,'name',this.figureName);
            set(this.handles.push_confirm,'string','Import');
            set(this.handles.text_filename,'string','');
            set(this.handles.edit_fileContents,'string','','max',2,... % make multi line
                'fontName','Courier New','fontsize',10,'enable','inactive'); % don't allow editing.
            set(this.handles.edit_numHeaderLines,'string',num2str(this.settings.numHeaderLines));            
            set(this.handles.push_fileSelect,'callback',@this.selectFileCallback);
            value = find(strcmpi(this.SEPARATORS,this.settings.separator),1);
            if(isempty(value))
                value = 1;
            end
            
            set(this.handles.menu_fieldSeparator,'string',this.SEPARATORS,...
                'value',value,'callback',@this.changeSeparatorCallback);            
        end
        
        function initCallbacks(this)
            set(this.figureH,'CloseRequestFcn',@this.cancelCallback);
            set(this.handles.menu_fieldSeparator,'callback',@this.changeSeparatorCallback);
            set(this.handles.edit_numHeaderLines,'callback',@this.editNumHeaderLinesCallback);
            set(this.handles.push_cancel,'callback',@this.cancelCallback);
            set(this.handles.push_confirm,'callback',@this.confirmCallback);
        end
        
        % GUI Callbacks
        function cancelCallback(this, hObject, evtData)
            this.cancel();
        end
        
        function confirmCallback(this, hObject, evtData)
            this.confirm();
        end
        
        function editNumHeaderLinesCallback(this, hEdit, ~, lineTag)            
            preValueStr = num2str(this.settings.numHeaderLines);
            newValue = str2double(get(hEdit,'string'));
            try
                if(isempty(newValue) || ~isnumeric(newValue))
                    set(hEdit,'string',preValueStr);
                else
                    if(~this.setNumHeaderLines(newValue))
                        set(hEdit,'string',preValueStr);
                    end
                end
            catch me
                warndlg('An error occurred while trying to change the label.  I''m sorry :(');
                set(hEdit,'string',preValueStr);
                showME(me);
            end
        end
        
        
        function changeSeparatorCallback(this, hMenu, evtData)
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
        %> PADataImport instance.
        %> @retval Struct of default paramters.  Fields include
        %> - @c trimResults
        % ======================================================================
        function paramStruct = getDefaultParameters()
            paramStruct.numHeaderLines = 1;
            paramStruct.separator = ',';
            paramStruct.filename ='';
        end         
    end
end
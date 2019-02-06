% ======================================================================
%> @brief  
%> @note 
%> @note Copyright Hyatt Moore, Informaton, 2019
classdef PAOutcomesTable < PABase
    events
        LoadSuccess;  
        LoadFail;
    end
    properties(Constant)
        categories = {'studyinfo','subjects','dictionary'}; % padaco results
        optionalCategory = 'dictionary';
    end
    properties(SetAccess=protected)
        filenames;
        tables;
        
        importOnStartup; 
        studyinfo;
        dictionary;
        subjects;  % outcomes, this will be study info...
        primaryKey;
        
        figFcn = @importOutcomesDlg;
        figureH;
    end
    
    properties(Access=protected)
        lastPathChecked;
    end
    
    methods
        
        %> @brief Class constructor.
        %> @retval obj Class instance.
        function this = PAOutcomesTable(settingsStruct)
            this = this@PABase();
            this.tables = mkstruct(this.categories);
            pStruct = this.getDefaultParameters();
            this.filenames = pStruct.filenames; %mkstruct(this.categories);            
            this.importOnStartup= pStruct.importOnStartup;
            try
                if nargin
                    this.setFilenames(settingsStruct.filenames);
                    this.importOnStartup = settingsStruct.importOnStartup;
                    
                    if(this.importOnStartup && this.canImport())                        
                        this.importFiles();
                    end
                end
                
            catch me
                this.logError('Constructor exception',me);
            end
        end
        
        % I want a summary statistic of each subject field, grouped by the primary keys given.
        % dataTable - a filtered version of table, filtered by primary
        %             key and field selection.
        % summaryTable - results of calling summary(dataTable)
        function [dataSummaryStruct, summaryTable, dataTable] = getSubjectInfoSummary(this, primaryKeys, fieldNames, stat)
            %wherePrimaryKeysIn = this.makeWhereInString(primaryKeys,'numeric');
            if(nargin<3)
                stat = [];
            end
            this.primaryKey = 'ID_KID';
            tableCategory = 'subjects';
            t=this.(tableCategory);
            %Rows Of Interest:
            [~,roi,~] = intersect(t.(this.primaryKey),primaryKeys,'stable');
            
            dataTable = t(roi, fieldNames);
            summaryTable = summary(dataTable);
            dataSummaryStruct = summarizeStruct(dataTable);
            %
            %             % This calculates summary stats directly within MySQL server
            %             selectStatFieldsStr = cellstr2statcsv(fieldNames,stat);
            %             sqlStatStr = sprintf('SELECT %s FROM %s WHERE %s in %s',selectStatFieldsStr,this.tableNames.subjectInfo,this.primaryKeys.subjectInfo, wherePrimaryKeysIn);
            %             statStruct = this.query(sqlStatStr);
            %
            %             % This calculates summary stats directly within MySQL server
            %             selectFieldsStr  = this.cellstr2csv(fieldNames);
            %             sqlStr = sprintf('SELECT %s FROM %s WHERE %s in %s',selectFieldsStr,this.tableNames.subjectInfo,this.primaryKeys.subjectInfo, wherePrimaryKeysIn);
            %             dataStruct = this.query(sqlStr);
            %
            %             if(isfield(dataStruct,'sex') && iscell(dataStruct.sex))
            %                 dataStruct.sex = str2double(dataStruct.sex);
            %             end
            %
            %             dataSummaryStruct = summarizeStruct(dataStruct);
        end
        
        function isValid = isvalidCategory(this, categoryName)
            isValid = ismember(categoryName,this.categories);
        end
        function colNames = getColumnNames(this, categoryName)
            colNames = {};
            if(this.isvalidCategory(categoryName))
                tableProp = this.(categoryName);
                if(isa(tableProp,'table'))
                    colNames = tableProp.Properties.VariableNames;
                end
            end
        end
           
        
        %% import file functionality
        
        function setFilenames(this, fStruct)
            for f=1:numel(this.categories)
                category = this.categories{f};
                if(isfield(fStruct,category))
                    filename = fStruct.(category);
                    this.setFilename(category,filename);
                end
            end
        end
        
        function didSet = setFilename(this, category, filename)
            didSet = false;
            if(isfield(this.filenames,category)&& exist(filename,'file')&& ~isdir(filename))
                this.filenames.(category) = filename;
                this.lastPathChecked = fileparts(filename);
                if(ishandle(this.figureH))
                    [~,textH] = this.getCategoryHandles(category);
                    if(ishandle(textH))
                        set(textH,'string',filename,'enable','inactive');
                    end
                    this.updateCanImport();                    
                end
            end
        end       
        
        function importFilesFromDlg(this)
            if this.confirmFilenamesDlg() % make them go through the dialog successfully first.
                this.importFiles(true);
            end
        end
        
        % Show message box is flag ([false]) indicating whether to show a
        % message box to the user with feedback of which file category is
        % being loaded.
        function importFiles(this, showMsgBox)
            if(nargin<2 || isempty(showMsgBox))
                showMsgBox = false;
            end
            if(~this.canImport())
                this.importFilesFromDlg();
            else
                didImportAll = true;
                makeModal = false;
                
                h = [];
                for f=1:numel(this.categories)
                    
                    category = this.categories{f};
                    msg = sprintf('Loading %s table data',category);
                    if(showMsgBox)
                        if f==1
                            h=pa_msgbox(msg,'Loading',makeModal);
                        elseif(~isempty(h))
                            update_msgbox(h,msg);
                        end
                    end
                    
                    filename = this.filenames.(category);
                    [didImport, msg] = this.importFile(category,filename);
                    if(~strcmpi(category, this.optionalCategory))
                        if(~didImport)
                            didImportAll = false;
                            break;
                        end
                    end
                    this.logStatus(msg);
                end
                if(ishandle(h))
                   delete(h);
                end
                
                if(didImportAll)
                    this.notify('LoadSuccess',EventData_Update('Files loaded'));%,'File does not exist')
                else
                    this.notify('LoadFail',msg);
                end
            end
        end
        
        function [didImport, msg] = importFile(this, category, filename)
            
            narginchk(2,3);
            try
                category = lower(category);
                if(~ismember(category,this.categories))
                    msg = sprintf('Unknown import category (%s) for file "%s"',category,filename);
                    this.logStatus(msg);
                    didImport = false;
                    %throw(MException('PA:OutcomesTable:ImportFile',msg));
                elseif(exist(filename,'file'))
                    msg = sprintf('Loading %s table data',category);
                    this.logStatus(msg);
                    this.(category) = readtable(filename);                    
                    didImport = true;
                    msg = sprintf('Loaded %s',filename);
                else
                    didImport = false;
                    msg = sprintf('%s file not found: %s',category,filename);%
                end
            catch me
                didImport = false;
                msg = sprintf('An exception was caught while trying to load %s file (''%s'').\n"%s"',category,filename,me.message);
            end            
        end        
        
        function importDictionary(this, varargin)
            this.importFile('dictionary',varargin{:});
        end
        
        function importSubjects(this, varargin)
            this.importFile('subjects',varargin{:})
        end
        
        function importStudyInfoFile(this, varargin)            
            this.importFile('studyinfo',varargin{:})            
        end        
        
        
        %% Import dialog and functionality
        function didConfirmUpdate = confirmFilenamesDlg(this)
            
            % figFile = 'importOutcomesDlg.fig';
            % x = load(figFile,'-mat');
            outcomeFileStruct = [];
            this.figureH = this.figFcn('visible','off','name','Select outcome files');               
            if(this.initHandles())
                set(this.figureH,'visible','on');                
                waitfor(this.figureH,'visible','off');
                if(ishandle(this.figureH))
                    outcomeFileStruct = this.filenames;
                    this.importOnStartup = get(this.handles.check_importOnStartup,'value');
                    delete(this.figureH);
                end
            end
            didConfirmUpdate = ~isempty(outcomeFileStruct);
        end
        
        function loadOn = getLoadOnStartup(this)
            loadOn = this.importOnStartup;
        end
        
        function updateCanImport(this)
            if(this.canImport())
                set(this.handles.push_import,'enable','on');
            else
                set(this.handles.push_import,'enable','off');
            end
        end
        
        % Check all required categories have a filename for import 
        function canIt = canImport(this)            
            canIt = all(cellfun(@(x)exist(this.filenames.(x),'file') && ~isdir(this.filenames.(x)),setdiff(this.categories,this.optionalCategory)));            
        end
        
        function didInit = initHandles(this)
            if(ishandle(this.figureH))
                this.handles = guidata(this.figureH);
                
                fields = fieldnames(this.filenames);
                for f=1:numel(fields)
                    category = fields{f};
                    [pushH, editH] = this.getCategoryHandles(category);
                    
                    set(editH,'enable','inactive','string','');
                    set(pushH,'callback',{@this.getFileCb,category});
                    
                    filename = this.filenames.(category);
                    if(exist(filename,'file') && ~isdir(filename))
                        set(editH,'string',filename);
                    end
                end
                
                set(this.handles.check_importOnStartup,'value',this.importOnStartup);
                set(this.handles.push_import,'callback', @this.hideFigureCb);
                set(this.handles.push_cancel,'callback', 'closereq');
                
                this.updateCanImport();
                didInit = true;
            else
                didInit = false;
            end
        end
        
        function hideFigureCb(this, varargin)
            set(this.figureH,'visible','off');
        end
        
        function getFileCb(this, hObject, ~, category)
            % this.logStatus('Import outcome file');
            fileExt = {'*.csv;*.txt','Comma Separated Values';
                '*.*','All (only csv supported)'};
            promptStr = sprintf('Select %s file',category);
            locationGuess = this.filenames.(category);
            
            if(isempty(locationGuess) || ~exist(locationGuess,'file'))
                locationGuess = this.lastPathChecked;
            end
            
            f=uigetfullfile(fileExt, promptStr, locationGuess);            
            if(~isempty(f) && ~isdir(f) && exist(f,'file'))
                this.setFilename(category, f);                
            else
                this.logStatus('User cancelled');
            end            
        end
        
        function [pushH, editH] = getCategoryHandles(this, categoryString)
           pushH = [];
           editH = [];
           if(ishandle(this.figureH))
               pushTag = sprintf('push_%s',categoryString);
               editTag = sprintf('edit_%s',categoryString);
               pushH = this.handles.(pushTag);
               editH = this.handles.(editTag);
           end
        end
        
        function pStruct = getSaveParameters(obj)
            pStruct = struct('filenames',obj.filenames,...
                'importOnStartup',obj.importOnStartup);
        end
        
    end
    
    methods(Static)
        
       function pStruct = getDefaultParameters()
            pStruct.filenames = mkstruct(PAOutcomesTable.categories);
            pStruct.importOnStartup = true;
       end 
       
    end
end



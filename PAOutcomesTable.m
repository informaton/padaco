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
        function this = PAOutcomesTable(filenameStruct)
            this = this@PABase();
            this.filenames = mkstruct(this.categories);
            this.tables = mkstruct(this.categories);
            if nargin 
                this.setFilenames(filenameStruct)
            end
        end
        
        function [dataSummaryStruct, statStruct, dataStruct] = getSubjectInfoSummary(this, primaryKeys, fieldNames, stat)
            %wherePrimaryKeysIn = this.makeWhereInString(primaryKeys,'numeric');
            if(nargin<3)
                stat = [];
            end
            tableCategory = 'subjects';
            t=this.(tableCategory);
            % This calculates summary stats directly within MySQL server
            selectStatFieldsStr = this.cellstr2statcsv(fieldNames,stat);
            sqlStatStr = sprintf('SELECT %s FROM %s WHERE %s in %s',selectStatFieldsStr,this.tableNames.subjectInfo,this.primaryKeys.subjectInfo, wherePrimaryKeysIn);
            statStruct = this.query(sqlStatStr);
            
            % This calculates summary stats directly within MySQL server
            selectFieldsStr  = this.cellstr2csv(fieldNames);
            sqlStr = sprintf('SELECT %s FROM %s WHERE %s in %s',selectFieldsStr,this.tableNames.subjectInfo,this.primaryKeys.subjectInfo, wherePrimaryKeysIn);
            dataStruct = this.query(sqlStr);
            
            if(isfield(dataStruct,'sex') && iscell(dataStruct.sex))
                dataStruct.sex = str2double(dataStruct.sex);
            end
            
            dataSummaryStruct = summarizeStruct(dataStruct);
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
                this.importFiles();
            end
        end
        
        function importFiles(this)
            if(~this.canImport())
                this.importFilesFromDlg();
            else
                didImportAll = true;
                for f=1:numel(this.categories)
                    category = this.categories{f};
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
                    makeModal = false;
                    h=pa_msgbox(msg,'Loading',makeModal);
                    this.logStatus(msg);
                    this.(category) = readtable(filename);
                    if(ishandle(h))
                        delete(h);
                    end
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
        
%         function importOutcomesFile(this, varargin)            
%             this.importFile('outcomes',varargin{:})            
%         end        
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
                    delete(this.figureH);
                end
            end
            didConfirmUpdate = ~isempty(outcomeFileStruct);
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
            pStruct = obj.filenames;
        end
        
    end
    
    methods(Static)
        
       function pStruct = getDefaultParameters()
            pStruct = mkstruct(PAOutcomesTable.categories);
       end 
       
    end
end



% ======================================================================
%> @brief  
%> @note 
%> @note Copyright Hyatt Moore, Informaton, 2019
classdef PAOutcomesTableData < PAData
    events
        LoadSuccess;  
        LoadFail;
    end
    properties(Constant)
        categories = {'studyinfo','subjects','dictionary'}; % padaco results
        optionalCategory = 'dictionary';
    end
    properties(SetAccess=protected)        
        isValid = false;
        tables;         
        studyinfo;
        dictionary;
        subjects;  % outcomes, this will be study info...
        primaryKey;
    end
    
    
    methods
        
        %> @brief Class constructor.
        %> @retval obj Class instance.
        function this = PAOutcomesTableData(varargin)            
            this = this@PAData(varargin{:});
            this.tables = mkstruct(this.categories);
            try
                if(this.getSetting('importOnStartup') && this.canImport())
                    this.importFiles();
                end                
            catch me
                this.logError(me, 'Constructor exception');
            end
        end
        
        % varargin is optional argument to show status updates of which
        % files are being loaded.  default is false when not included - see
        % importFiles() method for more detail
        function importWithSettings(this, newSettings, varargin)
            if(this.setSettings(newSettings))
               if(this.canImport())
                   this.importFiles(varargin{:});
               end
            end
        end        
        
        function didExport = exportToDisk(this)
            didExport = false;
            this.logStatus('Export to disk not supported');
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
            if(isempty(fieldNames))
                dataSummaryStruct = [];
            else
                dataSummaryStruct = summarizeStruct(dataTable);
            end
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
           
        function setSelectedField(this, fName)            
            this.setSetting('selectedField',fName);            
        end
        
        function index = getSelectedIndex(this)            
            if isempty(this.subjects)
                index = 1;
            else
                selectedField = this.getSetting('selectedField');
                index = find(strcmpi(this.subjects.Properties.VariableNames,selectedField));
                if(isempty(index))
                    index = 1;
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
            if(isa(filename,'PAParam'))
                filename = filename.value;
            end
            if(exist(filename,'file') && ~isdir(filename))
                this.setSetting('filenames',category,filename);
                this.setSetting('lastPathChecked',fileparts(filename));
            end
        end
        
        % Check all required categories have a filename for import
        function canIt = canImport(this)
            canIt = all(cellfun(@(x)exist(this.getSetting('filenames',x),'file') && ~isdir(this.getSetting('filenames',x)),setdiff(this.categories,this.optionalCategory)));
        end
        
        % showLoadStatus is boolean flag [false] indicating whether to show a
        % message box with updates of which file category being loaded.
        function importFiles(this, showLoadStatus)
            if(nargin<2 || isempty(showLoadStatus))
                showLoadStatus = false;
            end
            if(~this.canImport())
                this.logWarning('Cannot import all files because not all of them exist or could be found.  Consider using PAOutcomesTableSetup to locate them.');
            else
                didImportAll = true;
                makeModal = false;
                h = [];
                
                for f=1:numel(this.categories)
                    category = this.categories{f};
                    msg = sprintf('Loading %s table data',category);
                    if(showLoadStatus)
                        if f==1
                            h=pa_msgbox(msg,'Loading',makeModal);
                        elseif(~isempty(h))
                            update_msgbox(h,msg);
                        end
                    end
                    
                    filename = this.getSetting('filenames',category);
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
                    this.isValid = true;
                    this.notify('LoadSuccess',EventData_Update('Files loaded'));%,'File does not exist')
                    
                else
                    this.isValid = false;
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
                    
                    % This can show up when dealing with table data.
                    warning('off','MATLAB:table:ModifiedAndSavedVarnames');
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
        
        function loadOn = getLoadOnStartup(this)
            loadOn = this.getSetting('importOnStartup');
        end
    end
    
    methods(Access=protected)
        %% Import dialog and functionality - refactored to PAOutcomesTableSetup
        %         function importFilesFromDlg(this)
        %             if this.confirmFilenamesDlg() % make them go through the dialog successfully first.
        %                 this.importFiles(true);
        %             end
        %         end
        %
        %         function didConfirmUpdate = confirmFilenamesDlg(this)
        %
        %             % figFile = 'importOutcomesDlg.fig';
        %             % x = load(figFile,'-mat');
        %             outcomeFileStruct = [];
        %             this.figureH = this.figFcn('visible','off','name','Select outcome files');
        %             if(this.initHandles())
        %                 set(this.figureH,'visible','on');
        %                 waitfor(this.figureH,'visible','off');
        %                 if(ishandle(this.figureH))
        %                     outcomeFileStruct = this.getSetting('filenames');
        %                     this.setSetting('importOnStartup', get(this.handles.check_importOnStartup,'value'));
        %                     delete(this.figureH);
        %                 end
        %             end
        %             didConfirmUpdate = ~isempty(outcomeFileStruct);
        %         end
    end
    
    methods(Static)
        
       function pStruct = getDefaults()
           filenameCats = PAOutcomesTableData.categories;
           pStruct.filenames = mkstruct(filenameCats);
           
           for f = 1:numel(filenameCats)
               cat = filenameCats{f};
               pStruct.filenames.(cat) = PAFilenameParam('default','','Description',sprintf('%s file',cat));
           end
           pStruct.importOnStartup = PABoolParam('default',true,'description','Import On startup');
           pStruct.selectedField = PAStringParam('default','','Description','Selected field');
       end 
    end
end



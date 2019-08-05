% ======================================================================
%> @brief  
%> @note 
%> @note Copyright Hyatt Moore, Informaton, 2019
classdef PAOutcomesTableSetup < PAFigureController
    events
        LoadSuccess;  
        LoadFail;
    end
    properties(Constant)
        categories = {'studyinfo','subjects','dictionary'}; % padaco results
        optionalCategory = 'dictionary';
    end
    properties(SetAccess=protected)
        outcomesFileStruct; 
        importOnStartup;
        dictionary;        
        figFcn = @importOutcomesDlg;
    end
    
    methods
        
        %> @brief Class constructor.
        %> @retval obj Class instance.
        function this = PAOutcomesTableSetup(varargin)
            this = this@PAFigureController(varargin{:});  
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
            if(isfield(this.settings.filenames,category)&& exist(filename,'file')&& ~isdir(filename))
                this.setSetting('filenames',category,filename);                
                this.setSetting('lastPathChecked', fileparts(filename));
                if(ishandle(this.figureH))
                    [~,textH] = this.getCategoryHandles(category);
                    if(ishandle(textH))
                        set(textH,'string',filename,'enable','inactive');
                    end
                    this.updateCanImport();                    
                end
            end
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
            canIt = all(cellfun(@(x)exist(this.settings.filenames.(x),'file') && ~isdir(this.settings.filenames.(x)),setdiff(this.categories,this.optionalCategory)));
        end
        
        function pStruct = getSaveParameters(obj)
            % update our settings 
            throw(MException('a:out','agh'));
            %             obj.setSetting('filenames',obj.filenames
            pStruct = struct('filenames',obj.settings.filenames,...
                'importOnStartup',obj.importOnStartup,...
                'selectedField',obj.selectedField);
        end
        
    end
    
    methods(Access=protected)
        function didInit = initFigure(this)
            didInit = this.initHandles();
            if(didInit)
                this.outcomesFileStruct = [];
                this.importOnStartup = [];
                set(this.figureH,'visible','on');
                waitfor(this.figureH,'visible','off');
                if(ishandle(this.figureH))
                    this.outcomesFileStruct = this.getSetting('filenames');
                    this.importOnStartup = get(this.handles.check_importOnStartup,'value');
                    delete(this.figureH);
                end
            end            
        end
        
        function didInit = initHandles(this)
            if(ishandle(this.figureH))
                this.handles = guidata(this.figureH);
                
                fields = fieldnames(this.settings.filenames);
                for f=1:numel(fields)
                    category = fields{f};
                    [pushH, editH] = this.getCategoryHandles(category);
                    
                    set(editH,'enable','inactive','string','');
                    set(pushH,'callback',{@this.getFileCb,category});
                    
                    %filename = this.settings.filenames.(category);
                    filename = this.getSetting('fillenames',category);
                    if(exist(filename,'file') && ~isdir(filename))
                        set(editH,'string',filename);
                    end
                end
                
                set(this.handles.check_importOnStartup,'value',this.getSetting('importOnStartup'));
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
            locationGuess = this.settings.filenames.(category);
            
            if(isempty(locationGuess) || ~exist(locationGuess,'file'))
                locationGuess = this.getSetting('lastPathChecked');
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
        
        function didSet = setFigureHandle(obj, figHandle)
            if(nargin<2 || isempty(figHandle) || ~ishandle(figHandle))
                figHandle = obj.figFcn('visible','off','name','Select outcome files');
            end
            didSet = setFigureHandle@PAFigureController(obj,figHandle);
        end
    end    
    
    methods(Static)
        
       function pStruct = getDefaults()
           filenameCats = PAOutcomesTableData.categories;
           pStruct.filenames = mkstruct(filenameCats);
           
           for f = 1:numel(filenameCats)
               cat = filenameCats{f};
               pStruct.filenames.(cat) = PAFilenameParam('default','','Description',sprintf('%s file',cat));
           end
           
           pStruct.lastPathChecked = PAPathnameParam('default',getSavePath(),'Description','Pathname of study files to check first');
           pStruct.importOnStartup = PABoolParam('default',true,'description','Import On startup');
       end 
    end
end



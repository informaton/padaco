% ======================================================================
%> @brief  
%> @note 
%> @note Copyright Hyatt Moore, Informaton, 2019
classdef PAOutcomesTable < PABase
    events
        LoadSuccess;  
        LoadFail;
    end
    properties(SetAccess=protected)
        outcomes;
        dictionary;
        subjects;
        primaryKey;
        keys;
    end
    
    methods
        
        %> @brief Class constructor.
        %> @retval obj Class instance.
        function this = PAOutcomesTable(outcomesCSVFilename)
            this = this@PABase();
            if nargin
                this.importOutcomesFile(outcomesCSVFilename);
            end
        end
        
        function importFile(this, category, filename)
            
            narginchk(2,3);
            try
                switch(lower(category))
                    case { 'outcomes','dictionary','subjects'}
                        category = lower(category);
                    otherwise
                        msg = sprintf('Unknown import category (%s) for file "%s"',category,filename);
                        this.logStatus(msg);
                        throw(MException('PA:OutcomesTable:ImportFile',msg));
                end
                
                if(nargin<3 || isempty(filename))
                    promptStr = sprintf('Select %s file to import',category);
                    filename = uigetfullfile({'*.csv;*.txt;*.xls','Comma separated values (*.csv)'},...
                        promptStr);
                end
                
                % throw(MException('PA:Outcomes:Debug','Debug exception'));
                if(exist(filename,'file'))
                    msg = sprintf('Loading %s table data',category);
                    makeModal = false;
                    h=pa_msgbox(msg,'Loading',makeModal);
                    this.logStatus(msg);
                    this.(category) = readtable(filename);
                    if(ishandle(h))
                        delete(h);
                    end
                    this.notify('LoadSuccess',EventData_Update('Loaded %s',filename));%,'File does not exist')
                else
                    this.notify('LoadFail',EventData_Update('%s file not found: %s',category,filename));%
                end
            catch me
                this.notify('LoadFail',EventData_Update('An exception was caught while trying to load %s file (''%s'').\n"%s"',category,filename,me.message));
            end
            
        end
        
        function importDictionary(this, varargin)
            this.importFile('dictionary',varargin{:});
        end
        
        function importSubjects(this, varargin)
            this.importFile('subjects',varargin{:})
        end
        
        function importOutcomesFile(this, varargin)
            
            this.importFile('outcomes',varargin{:})            
        end

        function loadStudyInfo_T(this,csv_filename, visitNumber)
            
                        
            if(exist(csv_filename,'file'))
                
                fid = fopen(csv_filename,'r');
                [~,lineTerminator] = fgets(fid);
                fclose(fid);
                loadStr = sprintf([
                    'LOAD DATA LOCAL INFILE ''%s'' INTO TABLE %s ',...
                    ' FIELDS TERMINATED BY '','' ENCLOSED BY ''"''',...
                    ' LINES TERMINATED BY ''%s''',...
                    ' IGNORE 1 LINES',...
                    '(kidid, filename, total_day_count, complete_day_count, incomplete_day_count, x_cpm, y_cpm, z_cpm, vecmag_cpm)',...
                    ' SET visitnum = %d '],csv_filename,tableName,char(lineTerminator),visitNumber);
                
                this.open();                
                mym(loadStr);
                this.selectSome(tableName);
                this.close();
                %                     'set visitNum=%u'],subjectinfo_csv_filename,tableName,visitNum);
            else
                throw(MException('CLASS_database_goals','Invalid arguments for loadStudyInfo_T'));
            end
        end

    end
end



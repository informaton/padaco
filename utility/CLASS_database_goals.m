%> @file CLASS_database_goals.m
%> @brief Subclasses CLASS_database class for use with GOALS data.
% ======================================================================
%> @brief The class is designed for database development, functionality, and 
%> interaction with deidentified GOALS data collected as part of the GOALS
%> study conducted at Stanford University, Stanford, CA.  Data is not
%> provided.  
%> @note A MySQL database must be installed on the local host for class
%> instantiations to operate correctly.
%> @note Copyright Hyatt Moore, Informaton, 2015
classdef CLASS_database_goals < CLASS_database
    
    properties
        tableNames;
        primaryKeys;
    end
    
    methods(Static, Access=private)
        function dbStruct = getDBStruct()
            dbStruct.name = 'goals_db';
            dbStruct.user = 'goals_user';
            dbStruct.password = 'goals_password';
        end        
    end
    
    
    methods
        
        function [dataSummaryStruct, statStruct, dataStruct] = getSubjectInfoSummary(this, primaryKeys, fieldNames, stat)
            
            wherePrimaryKeysIn = this.makeWhereInString(primaryKeys,'numeric');
            if(nargin<3)
                stat = [];
            end
            
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
        
        %> @brief Class constructor.
        %> @retval obj Instance of CLASS_database.
        function this = CLASS_database_goals()
            this.dbStruct = this.getDBStruct();
            this.tableNames.studyInfo = 'studyinfo_t';
            this.tableNames.subjectInfo = 'subjectinfo_t';
            this.tableNames.dictionary = 'dictionary_t';
            
            this.primaryKeys.studyInfo = 'kidid';
            this.primaryKeys.subjectInfo = 'kidid';  % Note:  subjectInfo table actually has two primary keys; not a problem for now because study num is always 1.
            this.primaryKeys.dictionary = 'short_name';  % Note:  subjectInfo table actually has two primary keys; not a problem for now because study num is always 1.
        end

        % ======== ABSTRACT implementations for database_goals =========
        % ======================================================================
        %> @brief Create a mysql database and tables for the GOALS dataset.
        %> - Creates goals database and GRANTs access to goals_user
        %> and then CREATEs the following tables:
        %> @li  dictionary_t
        %> @li  studyinfo_t
        %> @li  subjectinfo_t        
        %> @param obj Instance of CLASS_database_goals
        % =================================================================
        function createDBandTables(this)
            this.create_DB();
            
            %% these functions create the named tables
            %these functions create the named tables
            this.createSubjectInfo_T();
            this.loadSubjectInfo_T();
            this.createDictionary_T();
            this.loadDictionary_T();
            this.createStudyInfo_T();
            this.loadStudyInfo_T();
            
        end    
        
        % ======================================================================
        %> @brief This creates the 'subjectinfo_t'  table for the goals database.
        %> @param Instance of CLASS_database_goals      
        % =================================================================
        function createSubjectInfo_T(this)                        
            
            tableStr = ['  kidid MEDIUMINT UNSIGNED NOT NULL'...
                ', visitnum TINYINT UNSIGNED NOT NULL'...
                ', bmi DECIMAL(4,2) DEFAULT ''0'''...
                ', height_cm DECIMAL(5,2) DEFAULT ''0'''...
                ', weight_kilo DECIMAL(5,2) DEFAULT ''0'''...
                ', bp_map DECIMAL(4,1) DEFAULT ''0'''...
                ', bp_pulse DECIMAL(4,1) DEFAULT ''0'''...
                ', skin_mm DECIMAL(4,1) DEFAULT ''0'''...
                ', waist_cm DECIMAL(5,2) DEFAULT ''0'''...
                ', sex ENUM (''1'',''2'',''?'') DEFAULT ''?'''...
                ', bmi_zscore DECIMAL(14,12) DEFAULT ''0'''...                
                ', chol_hdl SMALLINT DEFAULT NULL'...
                ', chol_total SMALLINT DEFAULT NULL'...
                ', triglyceride SMALLINT DEFAULT NULL'...
                ', glucose SMALLINT DEFAULT NULL'...
                ', insulin DECIMAL(4,1) DEFAULT ''0'''...  
                ', hs_crp DECIMAL(6,4) DEFAULT ''0'''...                
                ', hba1c DECIMAL(3,1) DEFAULT ''0'''...                
                ', alt SMALLINT DEFAULT NULL'...                
                ', chol_vldl SMALLINT DEFAULT NULL'...
                ', chol_ldl SMALLINT DEFAULT NULL'...                
                ', age DECIMAL(8,6) DEFAULT ''0'''...                
                ', bp_sys DECIMAL(4,1) DEFAULT ''0'''...                
                ', bp_dia DECIMAL(4,1) DEFAULT ''0'''...                
                ', depression_cdi TINYINT DEFAULT NULL'...                
                ', bmi_percent DECIMAL(11,8) DEFAULT ''0'''...
                ', bp_sys_pct DECIMAL(11,8) DEFAULT ''0'''...                
                ', bp_dia_pct DECIMAL(11,8) DEFAULT ''0'''... 
                ', percent_over_50 DECIMAL(11,8) DEFAULT ''0'''...
                ', PRIMARY KEY (kidid,visitnum)'
                ]; 

            this.createTable(this.tableNames.subjectInfo, tableStr);
        end
        
        % ======================================================================
        %> @brief This creates the 'dictionary_t' table for the goals database.
        %> The dictionary maps table column names to verbose descriptions and printable
        %> long names.
        %> @param Instance of CLASS_database_goals       
        % =================================================================
        function createDictionary_T(this)                        
            
            tableStr = [
                '  short_name VARCHAR(20) NOT NULL'...
                ', long_name VARCHAR(40) DEFAULT NULL'...
                ', description VARCHAR(200) DEFAULT NULL'...
                ', PRIMARY KEY (short_name)'
                ]; 

            this.createTable(this.tableNames.dictionary, tableStr);
        end
        
        % ======================================================================
        %> @brief This creates the 'subjectinfo_t'  table for the goals database.
        %> @param Instance of CLASS_database_goals      
        % =================================================================
        function createStudyInfo_T(this)                        
            
            tableStr = ['  kidid MEDIUMINT UNSIGNED NOT NULL'...
                ', visitnum TINYINT UNSIGNED NOT NULL'...
                ', filename VARCHAR(100) DEFAULT NULL'...
                ', total_day_count TINYINT DEFAULT ''0'''...
                ', complete_day_count TINYINT DEFAULT ''0'''...
                ', incomplete_day_count TINYINT DEFAULT ''0'''...
                ', x_cpm DECIMAL(8,4) DEFAULT ''0'''...
                ', y_cpm DECIMAL(8,4) DEFAULT ''0'''...
                ', z_cpm DECIMAL(8,4) DEFAULT ''0'''...
                ', vecmag_cpm DECIMAL(8,4) DEFAULT ''0'''...
                ', PRIMARY KEY (kidid,visitnum)'
                ]; 

            this.createTable(this.tableNames.studyInfo, tableStr);
        end
        
        
        
        function loadSubjectInfo_T(this,subjectinfo_csv_filename)
            this.importCSV('subjectinfo_t',subjectinfo_csv_filename,'Select GOALS subject data file');
        end
        
        function loadStudyInfo_T(this,csv_filename, visitNumber)
            tableName = 'studyinfo_t';
            if(nargin<3 || isempty(visitNumber))
                visitNumber = 1;
            end
            
            if(nargin<2 || ~exist(csv_filename,'file'))
                promptStr = sprintf('Select .csv file to import to %s table',tableName);
                csv_filename = uigetfullfile({'*.csv','Comma separated values (*.csv)'},...
                    promptStr);
                
            end
                        
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
        
        
        function loadDictionary_T(this, dictionary_csv_filename)
            this.importCSV('dictionary_t',dictionary_csv_filename,'Select GOALS dictionary mapping file');            
        end
    end
end

% Old notes, can be deleted if you are reading this:
%         function loadSubjectInfo_T(this,subjectinfo_csv_filename)
%             if(nargin<2 || ~exist(subjectinfo_csv_filename,'file'))  
%                 subjectinfo_csv_filename = uigetfullfile({'*.csv','Comma separated values (*.csv)'},...
%                     'Select GOALS subject data file');
%                 
%             end
            
%             if(exist(subjectinfo_csv_filename,'file'))
%                 tableName = this.tableNames.subjectInfo;
%                 loadStr = sprintf([
%                     'LOAD DATA LOCAL INFILE ''%s'' INTO TABLE %s ',...
%                     ' FIELDS TERMINATED BY '',''',...
%                     ' LINES TERMINATED BY ''\\r''',...
%                     ' IGNORE 1 LINES'],subjectinfo_csv_filename,tableName);
%                 
%                 this.open();                
%                 mym(loadStr);
%                 this.selectSome(tableName);
%                 this.close();
%                 %                     'set visitNum=%u'],subjectinfo_csv_filename,tableName,visitNum);
%             else
%                 throw(MException('CLASS_database','Invalid arguments for loadSubjectInfo_T'));
%             end
            
%         end

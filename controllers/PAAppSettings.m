%> @file PAAppSettings.cpp
%> @brief PAAppSettings Control user settings and preferences of Padaco toolbox.
% ======================================================================
%> @brief PAAppSettings used by Padaco to initialize, store, and update
%> user preferences.  The class is designed for storage and manipulation of
%> the user settings relating to Padaco.
%> @note:  This file was originally taken from SEV's CLASS_settings class,
%> by permission of the author Hyatt Moore.
% ======================================================================
classdef  PAAppSettings < PASettings
    %  A class for handling global initialization and settings
    %  - a.  Load settings - X
    %  - b.  Save settings - X
    %  - c.  Interface for editing the settings
    
    properties(SetAccess=protected)

        %> @brief cell of string names corresponding to the struct properties that
        %> contain settings  <b><i> {'SensorData','SingleStudy', 'Main','BatchMode','StatTool','Importing'}</i></b>
        fieldNames = {'Main','Importing','SingleStudy','StatTool','SensorData','BatchMode','OutcomesTableSetup','OutcomesTableData'}; 
        
        %> @brief Fieldnames whose structures are only one level deep.
        liteFieldNames={'StatTool','SingleStudy','Main','Importing','OutcomesTableSetup','OutcomesTableData'};

        % Inherited: 
        %> pathname of Padaco working directory - determined at run time.
        %> @brief Keeps track of the folder that padaco is run from.  This
        %> is useful when saving the setting's file to make sure it is
        %> always saved in the same place and not in another directory
        %> (e.g. if the user moves about in MATLAB's editor).
        % rootpathname;
    end
    
    properties
        
        %> struct of PAAppController preferences.
        Main;
        %> struct of PASensorData preferences.
        SensorData;
        %> struct of viewer related settings.
        SingleStudy;
        %> struct of batch processing settings.
        BatchMode;
        %> struct of settings for data import
        Importing;
        
        % struct of settings for data/cluster export
        % EXPORT;
        
        %> struct of StatTool plot/analysis settings.
        StatTool;
        
        %> struct for PAOutcomesTableSetup settings
        OutcomesTableSetup;
        OutcomesTableData;        
    end
    
    methods
        % --------------------------------------------------------------------
        % ======================================================================
        %> @brief Class constructor
        %>
        %> Stores the root path and parameters file and invokes initialize
        %> method.  Default settings are used if no parameters filename is
        %> provided or found.
        %>
        %> @param rootpathname Pathname of Padaco execution directory (string)
        %> @param parameters_filename Name of text file to load
        %> settings from (string)
        %> @return obj Instance of PAAppSettings class.
        % =================================================================
        function obj = PAAppSettings(rootpathname,parameters_filename)
            %initialize settings in Padaco....
            if(nargin>1)
                obj.rootpathname = rootpathname;
                if(nargin>2)
                    obj.parameters_filename = parameters_filename;
                end
            end
            obj.initialize();
        end
        
        % --------------------------------------------------------------------
        % =================================================================
        %> @brief Constructor helper function.  Initializes class
        %> either from parameters_filename if such a file exists, or
        %> hardcoded default values (i.e. setDefaults).
        %> @param obj instance of the PAAppSettings class.
        % =================================================================
        function initialize(obj)            
            obj.setDefaults();
            obj.loadDictionary();
            full_paramsFile = fullfile(obj.rootpathname,obj.parameters_filename);
            
            if(exist(full_paramsFile,'file'))
                % This appears to obtain file from odd location
                % determined when the program is first installed.
                % warndlg(sprintf('Loading %s',full_paramsFile));
                paramStruct = obj.loadParametersFromFile(full_paramsFile);
                if(~isstruct(paramStruct))
                    fprintf('\nWarning: Could not load parameters from file %s.  Will use default settings instead.\n\r',full_paramsFile);
                    
                else
                    % This does not work directly because obj is not a
                    % struct and mergeStruct does a check to see if fields
                    % exist in the left hand argument as if it were a
                    % struct.  Instead, build a tmp struct first, merge it,
                    % and then put the tmp struct back into our object.                    
                    % obj = mergeStruct(obj,paramStruct);  
                   
                    fnames = fieldnames(paramStruct);
                    
                    if(isempty(fnames))
                        fprintf('\nWarning: Could not load parameters from file %s.  Will use default settings instead.\n\r',full_paramsFile);
                    else
                        tmpStruct = struct;
                        for f=1:numel(fnames)
                            if(isprop(obj,fnames{f}))
                                tmpStruct.(fnames{f}) = obj.(fnames{f});
                            end
                        end
                        
                        tmpStruct = mergeStruct(tmpStruct,paramStruct);
                        
                        % Do not bring in any new tier-1 fields that may have
                        % existed independtly in the paramStruct.
                        for f=1:numel(fnames)
                            if(isprop(obj,fnames{f}))
                                obj.(fnames{f}) = tmpStruct.(fnames{f});
                            end
                        end
                        
                        % Alternative with more debugging information on what
                        % changed or is not found correctly in the parameter
                        % file.  Unfortunately, it only checks one or two
                        % levels deep into the struct and can miss small
                        % changes like obj.SensorData.color.features.psd vs
                        % obj.SensorData.color.features.psd_band_1.
                        %                         for f=1:numel(obj.fieldNames)
                        %                             cur_field = obj.fieldNames{f};
                        %                             if(~isfield(paramStruct,cur_field) || ~isstruct(paramStruct.(cur_field)))
                        %                                 fprintf('\nWarning: Could not find the ''%s'' parameter in %s.  Default settings for this parameter are being used instead.\n\r',cur_field,full_paramsFile);
                        %                                 continue;
                        %                             else
                        %
                        %                                 structFnames = fieldnames(obj.(cur_field));
                        %                                 for g= 1:numel(structFnames)
                        %                                     cur_sub_field = structFnames{g};
                        %                                     %check if there is a corruption
                        %                                     if(~isfield(paramStruct.(cur_field),cur_sub_field))
                        %                                         fprintf('\nSettings file may be corrupted or incomplete.  The %s.%s parameter is missing.  Using default setting for this paramter.\n\n', cur_field,cur_sub_field);
                        %                                         paramStruct.(cur_field).(cur_sub_field) = obj.(cur_field).(cur_sub_field);  % We'll produce it then and use whatever came up from obj.setDefaults();
                        %                                         continue;
                        %                                     elseif(isempty(paramStruct.(cur_field).(cur_sub_field)))
                        %                                         fprintf('\nSettings file may be corrupted or incomplete.  The %s.%s parameter is empty ('''').  Using default setting for this paramter instead.\n\n', cur_field,cur_sub_field);
                        %                                         paramStruct.(cur_field).(cur_sub_field) = obj.(cur_field).(cur_sub_field);  % We'll take whatever came up from obj.setDefaults();
                        %                                         continue;
                        %                                     end
                        %                                 end
                        %                             end
                        %                         end
                        %
                        %                         % Now that everything has been checked and we have
                        %                         % warned the groups of what we may be missing, we
                        %                         % can continue.
                        %                         for f=1:numel(fnames)
                        %                             obj.(fnames{f}) = paramStruct.(fnames{f});
                        %                         end
                    end
                    
                end
            end
        end
        
        function loadDictionary(obj)
            x.curSignal = 'Signal of interest';
            x.plotType = 'Plot type';
            x.numShades = 'Number of shades for heatmap';
            x.baseFeature = 'Feature function';
            x.clusterDurationHours = 'Cluster length (hours)';
            
            x.minDaysAllowed= 'Minimum number of days required';
            
            x.clusterMethod = {'Clustering Method','(''kmeans'',''kmedoids'')'};
            x.minClusters = 'Minimum number of clusters';
            x.clusterThreshold = 'Cluster threshold';
            x.clusterMethod = 'Clustering method';
            x.useDefaultRandomizer = {'Turn off randomizer','(1 for reproducibility)'};
            x.initClusterWithPermutation = 'Initialize clusters with permutation';           
            
            x.featureFcnName = 'Feature function';
            x.signalTagLine = 'Signal label';
            x.weekdayTag = 'Day of the week inclusion';
           
            x.screenshotPathname = 'Screenshot save path';
            
            x.viewMode = 'View mode';
            x.useSmoothing = 'Use smoothing (0/1)';
            x.highlightNonwear = 'Highlight nonwear (0/1)';            
            x.resultsPathname = 'Results save path';              
            
            x.sourceDirectory = 'Source directory';
            x.outputDirectory = 'Output directory'; 
            x.alignment.elapsedStartHours = 'When to start the first measurement';
            x.alignment.intervalLengthHours = 'Duration of each interval (in hours) once started';
            x.frameDurationMinutes = 'Frame duration (minutes)';
            x.numDaysAllowed = 'Number of days allowed (7)';
            x.featureLabel = 'Feature label (''All'')';
            x.logFilename = 'Batch mode log filename';
            x.summaryFilename = 'Summary output filename';
            x.isOutputPathLinked = 'Link output and input pathnames (0/1)';
            
            x.exportPathname = 'Export save directory';
            x.exportShowNonwear = 'Include nonwear flags with cluster export?';
            
            x.cacheDirectory = 'Caching directory';
            x.useCache = 'Use caching (0/1)';
            
            x.processType = {'Processing type','{''count'',''raw''}'};
            x.useOutcomes = 'Use text file for outcomes data - [0], 1';
            x.profileFieldIndex = 'Profile field index - [1]';
            x.useDatabase = 'Use database - [0], 1';
            x.databaseClass = 'Database classname to use';
            x.discardNonwearFeatures = 'Discard nonwear features (0/1)';
            x.trimResults = 'Trim result';
            x.cullResults = 'Cull result';
            
            x.chunkShapes = 'Segment shapes (0/1)';
            % x.sortValues = 'Sort values';
            x.numChunks='Number of segments';
            x.numDataSegmentsSelection = 'Number of segments selection (index)';
            
            x.preclusterReductionSelection = {'Precluster reduction selection','(1 = ''none'')'};            
            x.preclusterReduction = 'Preclustering reduction method';
            % x.reductionTransformationFcn = 'Precluster reduction method';
            
            x.maxNumDaysAllowed = {'Max days per subject.','0 = all days'};
            x.minNumDaysAllowed = {'Min days per subject.','0 = no minimum.  Not supported.'};
            
            x.normalizeValues = {'Normalize values - (0, 1)'};            
            x.processedTypeSelection = {'Processed type selection','[1]'};
            x.baseFeatureSelection = {'Base feature selection','[1]'};
            x.signalSelection = {'Signal selection','[1]'};
            x.plotTypeSelection = {'Plot type selection','[1]'};
            x.trimToPercent = {'Trim to (%)','1 .. [100]'};
            x.cullToValue = {'Cull to - ','[0] .. inf)'};
            x.showClusterMembers = {'Show shapes with cluster','[0], 1'};
            x.showClusterSummary = {'Display cluster summary','[0], 1'};
            x.yDir = {'Direction of y-axis','{normal, inverted}'};
            x.weekdaySelection = 'Weekday selection [1]';
            x.startTimeSelection = 'Start time selection [1]';
            x.stopTimeSelection = 'Stop time selection [-1]';
            x.customDaysOfWeek = {'Custom days of week selection','(0 for sunday)'};
            
            x.clusterDurationSelection = 'Cluster duration selection';                        
            x.primaryAxis_yLimMode = {'y Limit','(auto, manual)'};
            x.primaryAxis_nextPlot = {'Next plot','(replace, hold)'};
            x.showAnalysisFigure = 'Show analysis figure - [0], 1'; % do not display the other figure at first
            x.clusterDistributionType = sprintf('Cluster distribution type\n{''performance'',''membership'',''weekday''}'); 
            x.profileFieldSelection = 'Profile field selection (numeric)';
            
            x.bootstrapIterations =  'Bootstrap iterations';
            x.bootstrapSampleName = {'Bootstrap sampling ID','{''studyID'',''days''}'};  
            
            x.titleStr = {'Title string'};
            
            
            % SingleStudy
            x.filter_inf_file = 'Filter settings file';
            x.database_inf_file = 'Database credentials file';
            x.loadOutcomesOnStartup = {'Load outcomes file on startup when present','[0], 1'};
            obj.dictionary = x;
            
        end
        
        


        % --------------------------------------------------------------------
        %> @brief sets default values for the class parameters listed in
        %> the input argument <i>fieldNames</i>.
        %> @param obj instance of PAAppSettings.
        %> @param fieldNames (optional) string identifying which of the object's
        %> parameters to reset.  Multiple field names may be listed using a
        %> cell structure to hold additional strings.  If no argument is provided or fieldNames is empty
        %> then object's <i>fieldNames</i> property is used and all
        %> parameter structs are reset to their default values.
        function setDefaults(obj,fieldNames)
            
            if(nargin<2)
                fieldNames = obj.fieldNames; %reset all then
            end
            
            if(~iscell(fieldNames))
                fieldNames = {fieldNames};
            end
            
            for f = 1:numel(fieldNames)
                switch fieldNames{f}
                    case 'Importing'
                        obj.Importing = PASensorDataImport.getDefaults();
                    case 'StatTool'
                        obj.StatTool = PAStatTool.getDefaults();                    
                    case 'OutcomesTableData'
                        obj.OutcomesTableSetup = PAOutcomesTableData.getDefaults();
                    case 'OutcomesTableSetup'
                        obj.OutcomesTableSetup = PAOutcomesTableSetup.getDefaults();
                    case 'SensorData'
                        obj.SensorData = PASensorData.getDefaults();
                    case 'Main'
                        obj.Main = PAAppController.getDefaults();
                    case 'SingleStudy'
                        obj.SingleStudy  = PASingleStudyController.getDefaults();
                    case 'BatchMode'
                        obj.BatchMode = PABatchTool.getDefaults();
                    otherwise
                        fprintf(1,'Unsupported fieldname: %s\n',fieldNames{f});
                end
            end
        end
    end    
end

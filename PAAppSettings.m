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
        %> contain settings  <b><i> {'DATA','VIEW', 'CONTROLLER','BATCH','statTool','IMPORT'}</i></b>
        fieldNames = {'DATA','CONTROLLER','VIEW','BATCH','statTool','IMPORT','outcomesTable'};  
        
        %> @brief Fieldnmaes whose structures are only one level deep.
        liteFieldNames={'statTool','VIEW','CONTROLLER','IMPORT'};

        % Inherited: 
        %> pathname of Padaco working directory - determined at run time.
        %> @brief Keeps track of the folder that padaco is run from.  This
        %> is useful when saving the setting's file to make sure it is
        %> always saved in the same place and not in another directory
        %> (e.g. if the user moves about in MATLAB's editor).
        % rootpathname;
        
    end
    properties

        
        %> struct of PAController preferences.
        CONTROLLER;
        %> struct of PASensorData preferences.
        DATA;
        %> struct of viewer related settings.
        VIEW;
        %> struct of batch processing settings.
        BATCH;
        %> struct of settings for data import
        IMPORT;
        
        % struct of settings for data/cluster export
        % EXPORT;
        
        %> struct of statTool plot/analysis settings.
        statTool;
        
        %> struct for PAOutcomesTable settings
        outcomesTable;
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
            if(nargin==0)
                
            else
                obj.rootpathname = rootpathname;
                obj.parameters_filename = parameters_filename;
                obj.initialize();
            end
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
                        % changes like obj.DATA.color.features.psd vs
                        % obj.DATA.color.features.psd_band_1.
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
            x.centroidDurationHours = 'Centroid length (hours)';
            
            x.minDaysAllowed= 'Minimum number of days required';
            
            x.clusterMethod = {'Clustering Method','(''kmeans'',''kmedoids'')'};
            x.minClusters = 'Minimum number of clusters';
            x.clusterThreshold = 'Cluster threshold';
            x.clusterMethod = 'Clustering method';
            x.useDefaultRandomizer = {'Turn off randomizer','(1 for reproducibility)'};
            x.initCentroidWithPermutation = 'Initialize centroids with permutation';           
            
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
            x.logFilename = 'Batch log filename';
            x.summaryFilename = 'Summary output filename';
            x.isOutputPathLinked = 'Link output and input pathnames (0/1)';
            
            x.exportPathname = 'Export save directory';
            x.exportShowNonwear = 'Include nonwear flags with centroid export?';
            
            x.cacheDirectory = 'Caching directory';
            x.useCache = 'Use caching (0/1)';
            
            x.processType = {'Processing type','{''count'',''raw''}'};
            x.useDatabase = 'Use database (0/1)';
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
            
            x.maxNumDaysAllowed = {'Max days per subject.','Leave 0 to include all days.'};
            x.minNumDaysAllowed = {'Min days per subject.','Leave 0 for no minimum.  Currently variable has no effect at all.'};
            
            x.normalizeValues = {'Normalize values','(0/1)'};            
            x.processedTypeSelection = {'Processed type selection','[1]'};
            x.baseFeatureSelection = {'Base feature selection','[1]'};
            x.signalSelection = {'Signal selection','[1]'};
            x.plotTypeSelection = {'Plot type selection','[1]'};
            x.trimToPercent = {'Trim to (%)','[100]'};
            x.cullToValue = {'Cull to','[0]'};
            x.showCentroidMembers = 'Show centroid members (0/1)';
            x.showCentroidSummary = 'Show centroid summary (0/1)';
            
            x.weekdaySelection = 'Weekday selection (1)';
            x.startTimeSelection = 'Start time selection (1)';
            x.stopTimeSelection = 'Stop time selection (-1)';
            x.customDaysOfWeek = {'Custom days of week selection','(0 for sunday)'};
            
            x.centroidDurationSelection = 'Centroid duration selection';                        
            x.primaryAxis_yLimMode = {'y Limit','(auto, manual)'};
            x.primaryAxis_nextPlot = {'Next plot','(replace, hold)'};
            x.showAnalysisFigure = 'Show analysis figure (0/1)'; % do not display the other figure at first
            x.centroidDistributionType = sprintf('Centroid distribution type\n{''performance'',''membership'',''weekday''}'); 
            x.profileFieldSelection = 'Profile field selection (numeric)';
            
            x.bootstrapIterations =  'Bootstrap iterations';
            x.bootstrapSampleName = {'Bootstrap sampling ID','{''studyID'',''days''}'};  
            
            obj.dictionary = x;
            
        end
        
        
        % -----------------------------------------------------------------
        % =================================================================
        %> @brief Activates GUI for editing single study mode settings
        %> (<b>VIEW</b>,<b>PSD</b>,<b>MUSIC</b>)
        %> @param obj instance of PAAppSettings class.
        %> @param optional_fieldName (Optional)  String indicating which settings to update.
        %> Can be
        %> - @c statTool
        %> - @c VIEW
        %> - @c BATCH
        %> - @c CONTROLLER
        %> - @c IMPORT        
        %> @retval wasModified a boolean value; true if any changes were
        %> made to the settings in the GUI and false otherwise.
        % =================================================================
        function wasModified = defaultsEditor(obj,optional_fieldName)
            tmp_obj = obj.copy();
            if(nargin<2 || isempty(optional_fieldName))
                                       
                lite_fieldNames = tmp_obj.liteFieldNames;
            else
                lite_fieldNames = optional_fieldName;
                if(~iscell(lite_fieldNames))
                    lite_fieldNames = {lite_fieldNames};
                end
            end
            
            tmp_obj.fieldNames = lite_fieldNames;
            
            %             tmp_obj.statTool = rmfield(tmp_obj.statTool,'customDaysOfWeek');  % get rid of fields that contain arrays of values, since I don't actually know how to handle this
            tmp_obj = pair_value_dlg(tmp_obj);
            
            
            if(~isempty(tmp_obj))
                for f=1:numel(lite_fieldNames)
                    fname = lite_fieldNames{f};
                    obj.(fname) = tmp_obj.(fname);
                end
                wasModified = true;
                clear('tmp_obj');%     tmp_obj = []; %clear it out.
                
            else
                wasModified = false;
            end
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
                    case 'IMPORT'
                        obj.IMPORT = PASensorDataImport.getDefaultParameters();
                    case 'statTool'
                        obj.statTool = PAStatTool.getDefaultParameters();                    
                    case 'outcomesTable'
                        obj.outcomesTable = PAOutcomesTable.getDefaultParameters();
                    case 'DATA'
                        obj.DATA = PASensorData.getDefaultParameters();
                    case 'CONTROLLER'
                        obj.CONTROLLER = PAController.getDefaultParameters();
                    case 'VIEW'
                        obj.VIEW.yDir = 'normal';  %or can be 'reverse'
                        obj.VIEW.screenshot_path = obj.rootpathname; %initial directory to look in for EDF files to load
                        obj.VIEW.output_pathname = fullfile(fileparts(mfilename('fullpath')),'output');
                        if(~isdir(obj.VIEW.output_pathname))
                            try
                                mkdir(obj.VIEW.output_pathname);
                            catch me
                                showME(me);
                                obj.VIEW.output_pathname = fileparts(mfilename('fullpath'));
                            end
                        end
                        obj.VIEW.filter_inf_file = 'filter.inf';
                        obj.VIEW.database_inf_file = 'database.inf';
                    case 'BATCH'
                        obj.BATCH = PABatchTool.getDefaultParameters();
                    otherwise
                        fprintf(1,'Unsupported fieldname: %s\n',fieldNames{f});
                end
            end
        end
    end
    
    methods (Access = private)
        
        % -----------------------------------------------------------------
        %> @brief create a new PAAppSettings object with the same property
        %> values as this one (i.e. of obj)
        %> @param obj instance of PAAppSettings
        %> @retval copyObj a new instance of PAAppSettings having the same
        %> property values as obj.
        % -----------------------------------------------------------------
        function copyObj = copy(obj)
            copyObj = PAAppSettings();
            
            props = properties(obj);
            if(~iscell(props))
                props = {props};
            end
            for p=1:numel(props)
                pname = props{p};
                copyObj.(pname) = obj.(pname);
            end
        end
        
    end
end

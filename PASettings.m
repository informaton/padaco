%> @file PAsettings.cpp
%> @brief PAsettings Control user settings and preferences of Padaco toolbox.
% ======================================================================
%> @brief PASettings used by Padaco to initialize, store, and update
%> user preferences.  The class is designed for storage and manipulation of
%> the user settings relating to Padaco.
%> @note:  This file was originally taken from SEV's CLASS_settings class,
%> by permission of the author Hyatt Moore.
% ======================================================================
classdef  PASettings < handle
    %  A class for handling global initialization and settings
    %  - a.  Load settings - X
    %  - b.  Save settings - X
    %  - c.  Interface for editing the settings
    
    properties(SetAccess=protected)
        %> pathname of Padaco working directory - determined at run time.
        %> @brief Keeps track of the folder that padaco is run from.  This
        %> is useful when saving the setting's file to make sure it is
        %> always saved in the same place and not in another directory
        %> (e.g. if the user moves about in MATLAB's editor).
        rootpathname;
        %> @brief name of text file that stores the toolkit's settings
        parameters_filename;
        %> @brief cell of string names corresponding to the struct properties that
        %> contain settings  <b><i> {'DATA','VIEW', 'CONTROLLER','BATCH','StatTool','IMPORT','EXPORT'}</i></b>
        fieldNames = {'DATA','CONTROLLER','VIEW','BATCH','StatTool','IMPORT','EXPORT'};  
        
        %> @brief Fieldnmaes whose structures are only one level deep.
        liteFieldNames={'StatTool','VIEW','CONTROLLER','IMPORT','EXPORT'};                
        dictionary;
    end
    properties

        
        %> struct of PAController preferences.
        CONTROLLER;
        %> struct of PAData preferences.
        DATA;
        %> struct of viewer related settings.
        VIEW;
        %> struct of batch processing settings.
        BATCH;
        %> struct of settings for data import
        IMPORT;
        
        %> struct of settings for data/cluster export
        EXPORT;
        
        %> struct of StatTool plot/analysis settings.
        StatTool;

    end
    
    methods(Static)
        
        % ======================================================================
        %> @brief Returns a structure of parameters parsed from the text file identified by the
        %> the input filename.
        %> Parameters in the text file are stored per row using the
        %> following form:
        %> - fieldname1 value1
        %> - fieldname2 value2
        %> - ....
        %> an optional ':' is allowed after the fieldname such as
        %> fieldname: value
        %
        %> The parameters is
        %>
        %> @param filename String identifying the filename to load.
        %> @retval paramStruct Structure that contains the listed fields found in the
        %> file 'filename' along with their corresponding values
        % =================================================================
        function paramStruct = loadParametersFromFile(filename)
            fid = fopen(filename,'r');
            paramStruct = PASettings.loadStruct(fid);
            fclose(fid);
        end
        
        
        % ======================================================================
        %> @brief Parses the XML file and returns an array of structs
        %> @param xmlFilename Name of the XML file to parse (absolute path)
        %> @retval xmlStruct A structure containing the elements and
        %> associated attributes of the xml as parsed by xml_read.
        % ======================================================================
        function xmlStruct = loadXMLStruct(xmlFilename)
            % Testing dom = xmlread('cohort.xml');
            %             dom = xmlread(xmlFilename);
            %
            %             firstName = dom.getFirstChild.getNodeName;
            %             firstLevel = dom.getElementsByTagName(firstName);
            %             numChildren = firstLevel.getLength();
            %
            %             xmlStruct.(firstName) = cell(numChildren,1);
            %             %numChildren = dom.getChildNodes.getLength();
            %             for i =0:numChildren-1
            %                 printf('%s\n',firstLevel.item(i));
            %             end
            %             % firstLevel.item(0).getElementsByTagName('projectName').item(0).getFirstChild.getData;
            %             %str2double(dom.getDocumentElement.getElementsByTagName('EpochLength').item(0).getTextContent);
            %
            xmlStruct = read_xml(xmlFilename);
        end
        
        % ======================================================================
        %> @brief Parses the file with file identifier fid to find structure
        %> and substructure value pairs.  If pstruct is passed as an input argument
        %> then the file substructure and value pairings will be put into it as new
        %> or overwriting fields and subfields.  If pstruct is not included then a
        %> new/original structure is created and returned.
        %> fid must be open for this to work.  fid is not closed at the end
        %> of this function.
        %> @param fid file identifier to parse
        %> @param pstruct (optional) If included, pstruct fields will be
        %> overwritten if existing, otherwise they will be added and
        %> returned.
        %> @retval pstruct return value of tokens2struct call.
        % ======================================================================
        function pstruct = loadStruct(fid,pstruct)
            % Hyatt Moore IV (< June, 2013)
            
            
            if(~isempty(fopen(fid)))
                file_open = true;
                pat = '^([^\.\s]+)|\.([^\.\s]+)|\s+(.*)+$';
            else
                file_open = false;
            end
            
            
            if(nargin<2)
                pstruct = struct;
            end
            
            while(file_open)
                try
                    curline = fgetl(fid); %remove leading and trailing white space
                    if(~ischar(curline))
                        file_open = false;
                    else
                        tok = regexp(strtrim(curline),pat,'tokens');
                        if(numel(tok)>1 && ~strcmpi(tok{1},'-last') && isempty(strfind(tok{1}{1},'#')))
                            %hack/handle the empty case
                            if(numel(tok)==2)
                                tok{3} = {''};
                            end
                            pstruct = PASettings.tokens2struct(pstruct,tok);
                        end
                    end
                catch me
                    showME(me);
                    fclose(fid);
                    file_open = false;
                end
            end
        end
        
        % ======================================================================
        %> @brief helper function for loadStruct
        %> @param pstruct parent struct by which the tok cell will be converted to
        %> @param tok cell array - the last cell is the value to be assigned while the
        %> previous cells are increasing nestings of the structure (i.e. tok{1} is
        %> the highest parent structure, tok{2} is the substructure of tok{1} and so
        %> and on and so forth until tok{end-1}.  tok{end} is the value to be
        %> assigned.
        %> the tok structure is added as a child to the parent pstruct.
        %> @retval pstruct Input pstruct with any additional tok
        %> children added.
        % ======================================================================
        function pstruct = tokens2struct(pstruct,tok)
            if(numel(tok)>1 && isvarname(tok{1}{:}))
                
                fields = '';
                
                for k=1:numel(tok)-1
                    fields = [fields '.' tok{k}{:}];
                end
                
                
                % the str2num approach fails for timeseries objects that
                % are passed in as the valueStr.  So use the str2vec method
                % instead.
                %    if(~isnan(str2num(valueStr))) %#ok<ST2NM>
                %    evalmsg = ['pstruct' fields '=str2num(valueStr);'];
                valueStr = tok{end}{:};
                if(~isnan(PASettings.str2vec(valueStr)))
                    evalmsg = ['pstruct' fields '=PASettings.str2vec(valueStr);'];
                elseif(isnan(str2double(valueStr)))
                    evalmsg = ['pstruct' fields '=valueStr;'];
                else
                    evalmsg = ['pstruct' fields '=str2double(valueStr);'];
                end
                
                eval(evalmsg);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Converts a string of space delimited numerics to a vector
        %> of numbers.
        %> @param str A string of numbers.  For example
        %> str = '0 0 0'
        %> @param delim Optional delimiter to use.  Default is white space.
        %> @retval vec A vector of numeric values corresponding the str
        %> values.  For example if str = '0 0 0' then vec = [0 0 0]
        %> @note NaN is returned if the entire string cannot be converted to a vector.  For example if
        %> str = '0 'lkj 0 0' then vec = NaN
        % --------------------------------------------------------------------
        function vec = str2vec(str,delim)
            if(isempty(str))
                vec = nan;
            else
                if(nargin<2)
                    vecStr = textscan(str,'%s');
                    vec = textscan(str,'%f');
                    
                else
                    vecStr = textscan(str,'%s','delimiter',delim);
                    vec = textscan(str,'%f','delimiter',delim);
                    
                end
                
                if(~isempty(vecStr) && iscell(vecStr))
                    vecStr = vecStr{1};
                end
                if(~isempty(vec) && iscell(vec))
                    vec = vec{1};
                end
                
                
                % Set this to 1 or less to avoid catching things like this:
                % 700023t00c1.csv.csv
                % which gets parsed to 700023
                if(numel(vecStr) <=1 || numel(vec)~=numel(vecStr))
                    vec = nan;
                else
                    %vec = cell2mat(vec);
                    %we have column vectors
                    vec = vec(:)';
                    if(any(isnan(vec)))
                        vec = nan;
                    end
                end
            end
        end
        
        %> @brief Saves the root structure to the file with file identifier fid.
        %> to display the output to the screen set fid=1
        %> Note: the root node of a structure is not saved as a field to fid.
        %> See the second example on how to save the root node if desired.
        function saveStruct(fid,root,varargin)
            %
            %
            %example:
            %p.x = 1;
            %p.z.b = 'hi'
            %fid = fopen(filename,'w');
            %saveStruct(fid,p);
            %fclose(fid);
            %
            %will save the following to the file named filename
            %    x 1
            %    z.b 'hi'
            %
            %if the above example is altered as such
            %
            %  p.x = 1;
            %  p.z.b = 'hi'
            %  tmp.p = p;
            %  fid = fopen(filename,'w');
            %  saveStruct(fid,tmp);
            %  fclose(fid);
            %
            %the following output is saved to the file named filename
            %
            %    p.x 1
            %    p.z.b 'hi'
            %
            %use loadStruct to recover a structure that has been saved with this
            %function.
            %
            %Author: Hyatt Moore IV
            %21JULY2010
            %Stanford University
            
            if(isempty(varargin))
                if(isstruct(root))
                    fields = fieldnames(root);
                    for k=1:numel(fields)
                        PASettings.saveStruct(fid,root,deblank(fields{k}));
                        fprintf(fid,newline);  %this adds extra line between root groups.
                    end
                    
                else
                    fprintf(fid,['root %s',newline],num2str(root));
                end
                
            else
                field = getfield(root,varargin{:});
                if(isstruct(field))
                    fields = fieldnames(getfield(root,varargin{:}));
                    for k=1:numel(fields)
                        PASettings.saveStruct(fid,root,varargin{:},fields{k});
                    end
                else
                    fprintf(fid,['%s\t%s',newline],PASettings.strcat_with_dot(varargin{:}),num2str(field));
                end
            end
            
        end
        
        %> @brief helper function for loadStruct
        function out_str = strcat_with_dot(root,varargin)
            %like strcat, except here a '.' is placed in between each element
            if(isempty(varargin))
                out_str = root;
            else
                out_str = strcat(root,'.',PASettings.strcat_with_dot(varargin{:}));
            end
        end
        
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
        %> @return obj Instance of PASettings class.
        % =================================================================
        function obj = PASettings(rootpathname,parameters_filename)
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
        %> @param obj instance of the PASettings class.
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
                            tmpStruct.(fnames{f}) = obj.(fnames{f});
                        end
                        
                        tmpStruct = mergeStruct(tmpStruct,paramStruct);
                        
                        % Do not bring in any new tier-1 fields that may have
                        % existed independtly in the paramStruct.
                        for f=1:numel(fnames)
                            obj.(fnames{f}) = tmpStruct.(fnames{f});
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
            x.discardNonWearFeatures = 'Discard nonwear features (0/1)';
            x.trimResults = 'Trim result';
            x.cullResults = 'Cull result';
            
            x.chunkShapes = 'Segment shapes (0/1)';
            % x.sortValues = 'Sort values';
            x.numChunks='Number of segements';
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
        function def = getDefinition(obj, word)
            if(isfield(obj.dictionary,word))
                def = obj.dictionary.(word);
            else
                def = strrep(word,'_',' ');
                def(1) = upper(def(1)); % make an attempt at sentence casing.
            end
        end

        
        
        % -----------------------------------------------------------------
        % =================================================================
        %> @brief Activates GUI for editing single study mode settings
        %> (<b>VIEW</b>,<b>PSD</b>,<b>MUSIC</b>)
        %> @param obj instance of PASettings class.
        %> @param optional_fieldName (Optional)  String indicating which settings to update.
        %> Can be
        %> - @c StatTool
        %> - @c VIEW
        %> - @c BATCH
        %> - @c CONTROLLER
        %> - @c IMPORT
        %> - @c EXPORT
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
            
            %             tmp_obj.StatTool = rmfield(tmp_obj.StatTool,'customDaysOfWeek');  % get rid of fields that contain arrays of values, since I don't actually know how to handle this
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
        
        % -----------------------------------------------------------------
        % =================================================================
        %> @brief saves all of the fields in saveStruct to the file filename
        %> as a .txt file
        %
        %
        %> @param obj instance of PASettings class.
        %> @param dataStruct2Save (optional) structure of parameters and values
        %> to save to the text file identfied by obj property filename or
        %> the input paramater filename.  Enter empty (i.e., []) to save
        %> all available fields
        %> @param filename (optional) name of file to save parameters to.
        %> If it is not included then the save file is taken from the
        %> instance variables rootpathname and parameters_filename
        % =================================================================
        % -----------------------------------------------------------------
        function saveParametersToFile(obj,dataStruct2Save,filename)
            if(nargin<3)
                filename = fullfile(obj.rootpathname,obj.parameters_filename);
                if(nargin<2)
                    dataStruct2Save = [];
                end
            end
            
            if(isempty(dataStruct2Save))
                fnames = obj.fieldNames;
                for f=1:numel(fnames)
                    dataStruct2Save.(fnames{f}) = obj.(fnames{f});
                end
            end
            
            fid = fopen(filename,'w');
            if(fid<0)
                [~, fname, ext]  = fileparts(filename);
                fid = fopen(fullfile(pwd,[fname,ext]));
            end
            if(fid>0)
                fprintf(fid,'-Last saved: %s\r\n\r\n',datestr(now)); %want to include the '-' sign to prevent this line from getting loaded in the loadFromFile function (i.e. it breaks the regular expression pattern that is used to load everything else).
                
                PASettings.saveStruct(fid,dataStruct2Save)
                %could do this the other way also...
                %                     %saves all of the fields in inputStruct to a file
                %                     %filename as a .txt file
                %                     fnames = fieldnames(saveStruct);
                %                     for k=1:numel(fnames)
                %                         fprintf(fid,'%s\t%s\n',fnames{k},num2str(saveStruct.(fnames{k})));
                %                     end
                fclose(fid);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief sets default values for the class parameters listed in
        %> the input argument <i>fieldNames</i>.
        %> @param obj instance of PASettings.
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
                    case 'EXPORT'
                        obj.EXPORT = PACentroid.getExportDefaultParameters();                    
                    case 'IMPORT'
                        obj.IMPORT = PADataImport.getDefaultParameters();
                    case 'StatTool'
                        obj.StatTool = PAStatTool.getDefaultParameters();
                    case 'DATA'
                        obj.DATA = PAData.getDefaultParameters();
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
        %> @brief create a new PASettings object with the same property
        %> values as this one (i.e. of obj)
        %> @param obj instance of PASettings
        %> @retval copyObj a new instance of PASettings having the same
        %> property values as obj.
        % -----------------------------------------------------------------
        function copyObj = copy(obj)
            copyObj = PASettings();
            
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

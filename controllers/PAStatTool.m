% ======================================================================
%> @file PAStatTool.cpp
%> @brief PAStatTool serves as Padaco's controller for visualization and
%> analysis of batch results.
% ======================================================================
classdef PAStatTool < PAViewController
    events
        UserCancel_Event;
        ProfileFieldSelectionChange_Event;
    end
    
    properties(Constant)
        viewTag = 'results';
        RESULTS_CACHE_FILENAME = 'results.tmp';
        COLOR_MEMBERSHAPE = [0.5 0.45 0.65];
        COLOR_LINESELECTION = [0.8 0.1 0.1];
        COLOR_MEMBERID = [0.1 0.1 0.8];
        MAX_DAYS_PER_STUDY = 7;
        DISTRIBUTION_TYPES = {'loadshape_membership','participant_membership','nonwear_membership','weekday_scores','weekday_membership','performance_progression'}
    end
    
    properties
        %> struct of fields to use when profiling/describing clusters.
        %> These are names of database fields extracted which are keyed on
        %> the subject id's that are members of the cluster of interest.
        profileFields;
        maxNumDaysAllowed;
        minNumDaysAllowed;
    end
    
    properties(SetAccess=protected)
    
        featuresDirectory;
        
        %> structure loaded features which is as current or as in sync with the gui settings
        %> as of the last time the 'Calculate' button was
        %> pressed/manipulated.
        featureStruct;
        
        %> instance of PACluster class
        clusterObj;
        
        %> @brief Struct with key value pairs for clustering:
        %> - @c clusterMethod Cluster method employed {'kmeans','kmedoids'}
        %> - @c useDefaultRandomizer = widgetSettings.useDefaultRandomizer;
        %> - @c initClusterWithPermutation = settings.initClusterWithPermutation;
        %> @note Initialized in the setWidgetSettings() method
        clusterSettings;

        nonwear;
        
        % boolean
        % useCache; --> migrated to a setting, which can be accessed via
        % same named function
        useDatabase = 0;
        useOutcomes = 0;
        
        %> @brief Struct with fields consisting of summary statistics for
        %> field names contained in the subject info table of the goals
        %> database for all clusters.
        %> @note Database must be developed and maintained externally
        %> to Padaco.
        globalProfile;
        
        %> @brief Struct with fields consisting of summary statistics for
        %> field names contained in the subject info table of the goals
        %> database for the cluster of interest.
        %> @note Database must be developed and maintained externally
        %> to Padaco.
        coiProfile;
        
        %> @brief Fx3xC matrix where N is the number of covariate fields
        %> to be analyzed and C is the number of clusters.  '3' represents
        %> the columns: n, mean, and standard error of the mean for the
        %> subjects in cluster c with values found in covariate f.
        allProfiles;
        
        profileTableData;
        
        % Stores last used settings, from plot settings or settings property
        % (when headless), following successful feature calculation.  This
        % is used to determine if additional cacluations need to be done,
        % such as refreshing nonwear exclusion ranges for times/days
        lastUsedSettings = struct();
        
    end
    
    properties(Access=protected)
        cacheDirectory;
        
        %> Structure of original loaded features, that are a direct
        %> replication of the data obtained from disk (i.e. without further
        %> filtering).
        originalFeatureStruct;        
        
        bootstrapParamNames = {'bootstrapIterations','bootstrapSampleName'};
        bootstrapIterations;
        bootstrapSampleName;
        
        %> structure containing Usage Activity feature output by padaco's batch tool.
        %> This is used to obtain removal indices when loading data (i.e.
        %> non-wear/study over state)
        usageStateStruct;
        
        %> Struct for holding choi nonwear results.        
        choiNonwearStruct;

        % Changing to a setting - use getSetting('exclusionsFilename')
        % exclusionsFilename = PAFilenameParam();
        
        % holdPlots;  --> refactored to a method

        %> struct of handles that PAStatTool interacts with.  Inherited from PABase
        %>  See initHandles()
        %> Includes contextmenu
        % handles;
        
        %> struct of toolbar handles that PAStatTool interacts with.
        toolbarH;
        
        buttongroup;
        %> Struct of java component peers to some graphic handles listed
        %> under @c handles.  Currently only table_profileFields (under the
        %> analysis figure) is included.
        jhandles;
        
        %> struct of base (all possible) parameter values that can be set
        base;
        featureTypes;
        featureDescriptions;
        %> @brief boolean set to true if result data is found.
        canPlot;
        %> @brief Struct to keep track of settings from previous plot type
        %> selections to make transitioning back and forth between cluster
        %> plotting and others easier to stomach.  Fields include:
        %> - @c normalizeValues The value of the check_normalizevalues widget
        %> - @c plotType The tag of the current plot type
        %> - @c colorMap - colormap of figure;
        %> These are initialized in the initWidgets() method.
        previousState;
        
    end
    
    properties(Access=private)
        %> @brief Bool (true: has icon/false: does not have icon)
        hasIcon;
        iconData;
        iconCMap;
        iconFilename;
        
        %> Booleans
        outcomesObj;
        
        databaseObj;
        %> handle of scatter plot figure.
        analysisFigureH;
        
        featureInputFilePattern;
        featureInputFileFieldnames;
        %> Structure initialized to input widget settings when passed to
        %> the constructor (and is empty otherwise).  This is used to
        %> 'reset' parameters and keep track of time start and stop
        %> selection fields which are not initialized until after data has
        %> been load (i.e. and populates the dropdown menus.  These are the
        %> settings that were applied to the most recently cluster object.
        originalSettings;
        nonwearRequiresUpdate = false;
    end
    
    
    methods
        
        % ======================================================================
        %> @brief Constructor for PAStatTool
        %> @param padaco_fig_h Handle to figure to be instantiated with
        %> @param featuresPathname
        %> @param optional struct with field value pairs for initializing
        %> user settings.  See getSaveParameters
        %> @retval this Instance of PAStatTool
        % ======================================================================
        function this = PAStatTool(varargin)
            this@PAViewController(varargin{1:2});
            
            this.hasIcon = false;
            this.iconData = [];
            this.iconCMap = [];
            this.iconFilename = '';
            this.globalProfile  = [];
            this.coiProfile = [];
            this.allProfiles = [];
            
            % filesep on PC is '\' which acts as an escape character in the
            % context that we are using the file pattern here, so don't
            % bother and instead stick with '/' which works for all cases
            % here anway.  4/7/2022 @hyatt
            % this.featureInputFilePattern = ['%s',filesep,'%s',filesep,'features.%s.accel.%s.%s.txt'];
            this.featureInputFilePattern = ['%s','/','%s','/','features.%s.accel.%s.%s.txt'];
            this.featureInputFileFieldnames = {'inputPathname','displaySeletion','processType','curSignal'};
            
            this.originalFeatureStruct = [];
            this.canPlot = false;
            this.featuresDirectory = [];            
            this.featureStruct = [];
                        
            if isempty(this.figureH)
                this.initBase();
                
                % Necessary b/c weekday tag is updated from gui in
                % getPlotSettings otherwise, but necessary for
                % calculateFeatureStructures at the moment 2/2/2022
                this.settings.weekdayTag = this.base.weekdayTags{this.getSetting('weekdaySelection')};
                this.settings.clusterDurationHours = this.base.clusterHourlyDurations(this.getSetting('clusterDurationSelection'));
                this.settings.preclusterReduction = this.base.preclusterReductions{this.getSetting('preclusterReductionSelection')}; 
            end
            
            
            this.featureTypes = this.base.featureTypes;
            
            discardMethod = this.getSettingsParam('discardMethod');            
            this.nonwear = struct();            
            for c = 1:numel(discardMethod.categories)                
                % include categories: {'padaco'  'choi'  'imported_file'}
                this.nonwear.(discardMethod.categories{c}) = struct('filename', 'none'); % struct('rows',[]);
            end
            
            featuresPathname = this.getSetting('featuresPathname');
            if this.getSetting('startWithLastPath')      
                
                if(isdir(featuresPathname))
                    this.setFeaturesDirectoryAndUpdate(featuresPathname); % a lot of initialization code in side this call.                    
                else                    
                    fprintf('%s does not exist!\n',featuresPathname);
                end
            else
                this.setFeaturesDirectory(featuresPathname);
            end
        end
        
        % ======================================================================
        %> @brief Returns plot settings that can be used to initialize a
        %> a PAStatTool with the same settings.
        %> @param this Instance of PAStatTool
        %> @retval Structure of current plot settings.
        % ======================================================================
        function saveParams = getSaveParameters(this)
            paramStruct = this.getPlotSettings();            
            saveParams = getSaveParameters@PAViewController(this);
            
            saveParams = mergeStruct(saveParams, paramStruct);
            
            % These fields are based on other, existing settings and are removed
            % to avoid complication on loading.  showAnalysisFigure: I just don't want to have it show up initially on loading
            % Removing these also helps with vertical length scrolling with the settings editor.
            rmFields = {'processType','baseFeature','plotType','weekdayTag',...
                'clusterDurationHours','preclusterReduction', 'numShades',...
                'showAnalysisFigure', 'curSignal', 'titleStr'};            
            
            %             plotOnlyFields = {
            %                 'primaryAxis_yLimMode'
            %                 'primaryAxis_nextPlot'
            %                 'showAnalysisFigure'
            %                 'numShades'
            %                 'showTimeOfDayAsBackgroundColor'
            %                 'showClusterSummary'
            %                 'plotTypeSelection'
            %                 'clusterDistributionType'
            %                 };
            
            saveParams = rmfield(saveParams, rmFields);
        end
        
        % ======================================================================
        %> @brief Returns plot settings that can be used to initialize a
        %> a PAStatTool with the same settings.
        %> @param this Instance of PAStatTool
        %> @retval Structure of current plot settings.
        % ======================================================================
        %         function paramStruct = getSaveParameters(this)
        %             paramStruct = this.getPlotSettings();
        %
        %             paramStruct.exportShowNonwear = this.originalSettings.exportShowNonwear;
        %             paramStruct.exportPathname = this.originalSettings.exportPathname;
        %
        %             % These parameters not stored in figure widgets
        %             paramStruct.useDatabase = this.useDatabase;
        %             paramStruct.useOutcomes = this.useOutcomes;
        %             paramStruct.profileFieldIndex = this.getProfileFieldIndex();
        %             % paramStruct.minDaysAllowed =    this.minNumDaysAllowed;  % Remove after 4/26/2019 @hyatt if no bugs
        %             paramStruct.minNumDaysAllowed = this.minNumDaysAllowed;
        %             paramStruct.maxNumDaysAllowed = this.maxNumDaysAllowed;
        %             paramStruct.databaseClass = this.originalSettings.databaseClass;
        %
        %             paramStruct.useCache = this.useCache;
        %             paramStruct.cacheDirectory = this.cacheDirectory;
        %
        %             paramStruct.bootstrapIterations = this.bootstrapIterations;
        %             paramStruct.bootstrapSampleName = this.bootstrapSampleName;
        %         end
        
        function useIt = useCache(this)
            useIt = this.getSetting('useCache');
        end
        
        % Callable for getting same named setting - added 1/12/2022
        function filename = exclusionsFilename(this)
            filename = this.getSetting('exclusionsFilename');
        end
        
        % More like "syncSettings"
        function didSet = setSettings(this, inputSettings)
            didSet = setSettings@PAFigureController(this, inputSettings);
            if(didSet)
                this.useOutcomes = this.getSetting('useOutcomes');
                this.bootstrapIterations =  this.getSetting('bootstrapIterations');
                this.bootstrapSampleName = this.getSetting('bootstrapSampleName');
                this.maxNumDaysAllowed = this.getSetting('maxNumDaysAllowed');
                this.minNumDaysAllowed = this.getSetting('minNumDaysAllowed');
                
                
                % useCache property deprecated on 1/12/2022
                % this.useCache = this.getSetting('useCache');                
                this.cacheDirectory = this.getSetting('cacheDirectory');
                
                clusterFields = {'clusterMethod', 'distanceMetric', 'useDefaultRandomizer', 'initClusterWithPermutation'};
                for c=1:numel(clusterFields)
                    fname = clusterFields{c};
                    this.clusterSettings.(fname) = this.getSetting(fname);
                end
                
                this.originalSettings = paparamsToValues(inputSettings);
            end
        end
        
        % ======================================================================
        %> @brief Overload delete method to ensure we get rid of the
        %> analysis figure
        % ======================================================================
        function delete(this)
            if(ishandle(this.analysisFigureH))
                delete(this.analysisFigureH)
            end
            
            % call the parent/superclass method
            delete@PAViewController(this);
        end
        
        function didSet = setFeaturesDirectory(this, resultsPath)
            if(~isdir(resultsPath))
                this.logWarning('Not a valid directory');
                didSet = false;
            else
                featuresPath = fullfile(resultsPath,'features');
                
                % We are allowing user to pick a folder that contains
                % 'features' as a subfolder, or the folder whose subfolders
                % are in fact the feature subfolders.  This will give a
                % little more flexibility to the user and hopefully hide
                % some of the more mundane parts of loading a path.
                if(~isdir(featuresPath))
                    featuresPath = resultsPath;
                    % fprintf('Assuming features pathFeatures pathname (%s) does not exist!\n',featuresPath);
                end
                if this.setSetting('featuresPathname', featuresPath)
                    this.featuresDirectory = featuresPath;
                    didSet = true;
                end
            end
        end
        
        function didSet = setFeaturesDirectoryAndUpdate(this, resultsPath)
            didSet = false;
            if (this.setFeaturesDirectory(resultsPath))
                didUpdate = false;
                if(exist(this.getFullClusterCacheFilename(),'file') && this.useCache)
                    
                    try
                        validFields = {'clusterObj';
                            'featureStruct';
                            'originalFeatureStruct'
                            'usageStateStruct'
                            'choiNonwearStruct'
                            'featuresDirectory'
                            'nonwear'};
                        tmpStruct = load(this.getFullClusterCacheFilename(),'-mat',validFields{:});
                        
                        % Double check that the cached data is still there in
                        % the expected features directory. We give the
                        % features directory of the current object precendence
                        % over that found in the cache (e.g. we don't overwrite
                        % this.featuresDirectory with tmpStruct.featuresDirectory
                        
                        if ~strcmpi(tmpStruct.featuresDirectory,this.featuresDirectory)                           
                            warnmsg = sprintf('The cached features path (%s) is different than the one currently selected (%s).', tmpStruct.featuresDirectory,this.featuresDirectory);
                            this.logWarning(warnmsg);
                            cachePrompt = sprintf('%s\nWould you like to disable caching and use the current features path instead?', warnmsg);
                            disableCaching = confirmDlg(cachePrompt);
                            if disableCaching
                                this.setSetting('useCache', false);
                            end
                        else
                            
                            for f = 1:numel(validFields)
                                curField = validFields{f};
                                if(isfield(tmpStruct,curField))
                                    curValue = tmpStruct.(curField);
                                    if((strcmp(curField,'clusterObj') && isa(curValue,'PACluster'))||...
                                            (~strcmpi(curField,'clusterObj') && isstruct(curValue)))
                                        this.(curField) = curValue;
                                    end
                                end
                            end
                            
                            if(this.hasValidCluster())
                                exportPathname = this.getSetting('exportPathname');
                                
                                % Corner case to separate these items
                                % which currently are not synced well
                                % enough in the gui to enable easy update
                                previousSettingsFromClusterObj = this.clusterObj.settings;
                                previousSettingsFromClusterObj.useDatabase = this.useDatabase;
                                previousSettingsFromClusterObj.useOutcomes = this.useOutcomes;
                                previousSettingsFromClusterObj.exportPathname = exportPathname;
                                this.updateOriginalWidgetSettings(previousSettingsFromClusterObj);
                                
                                this.setUseDatabase(this.getSetting('useDatabase'));  %sets this.useDatabase to false if it was initially true and then fails to open the database
                                this.setUseOutcomesTable(this.getSetting('useOutcomes'));
                                didUpdate = this.updateWidgets();  % want to refresh the current view as well...
                                
                                this.clusterObj.setExportPath(exportPathname);
                                this.clusterObj.addlistener('DefaultParameterChange',@this.clusterParameterChangeCb);
                            end
                            
                            % updates our features and start/stop times
                            this.setStartTimes(this.originalFeatureStruct.startTimes);
                            
                            % Updates our scatter plot as applicable.
                            this.refreshGlobalProfile();
                            
                            % Imported exclusion data requires a merge with the current
                            % dataset, once it has been loaded.
                            try
                                if exist(this.exclusionsFilename,'file')
                                    this.importExclusions(this.exclusionsFilename);
                                end
                            catch me
                                this.logError(me, 'Failed to import exclusion data from %s', this.exclusionsFilename);
                            end                         
                            
                        end
                    catch me
                        showME(me);
                    end
                end
                
                
                
                
                % This happens most often when we are switching to a new
                % directory for the first time which has not been cached
                % yet.
                if ~didUpdate && ~this.updateWidgets()  %initializes previousstate.plotType on success and calls plot selection change cb for sync.
                    this.logWarning('Unable to update controls');
                end
                
                this.clearPlots();
                
                
                if(this.getCanPlot())
                    if(this.isClusterMode())
                        this.switch2clustering();
                    else
                        this.switchFromClustering();
                    end
                end
                didSet = true;
            end
        end
        
        function clearStatus(this)
            this.setStatus('');
        end
        
        %> @brief Returns boolean indicator if the current plot type is
        %> is showing clusters or not.
        %> @brief or if the passed plotType matches the clustering mode
        %> label.
        function isMode = isClusterMode(this, plotType)
            if(nargin<2 || isempty(plotType))
                plotType = this.getPlotType();
            end
            isMode = strcmpi(plotType,'clustering');
        end
        
        function plotType = getPlotType(this)
            plotType = getMenuUserData(this.handles.menu_plottype);
        end
        
        % ======================================================================
        %> @brief Get method for clusterObj instance variable.
        %> @param this Instance of PAStatTool
        %> @retval Instance of PACluster or []
        % ======================================================================
        function clusterObj = getClusterObj(this)
            clusterObj = this.clusterObj;
        end
        
        % ======================================================================
        % ======================================================================
        function clusterExists = hasCluster(this)
            clusterExists = ~isempty(this.clusterObj) && isa(this.clusterObj,'PACluster');
        end
        
        % ======================================================================
        %> @brief Get method for canPlot instance variable.
        %> @param this Instance of PAStatTool
        %> @retval canPlot Boolean (true if results are loaded and displayable).
        % ======================================================================
        function canPlotValue = getCanPlot(this)
            canPlotValue = this.canPlot;
        end        
        
        function nonwearStruct = getExclusionsStruct(this, nonwearMethods, nonwearStruct)
            narginchk(1,3);
            if nargin<3
                nonwearStruct = this.nonwear;
                if nargin<2
                    nonwearMethods = this.getSetting('discardMethod');
                end
            end
            nonwearStruct.methods = nonwearMethods;
            ind2keep = this.originalFeatureStruct.ind2keep1Week;  % logical index for subject days that are part of 1 week or less.
            ind2keepExactly1Week = this.originalFeatureStruct.ind2keepExactly1Week; % logical index for subject days that are part of 1 week exactly (each day is covered).
            
            ind2keepExactly1WeekAndNonwearExcluded = ind2keepExactly1Week;
            ind2keepAndNonwearExcluded = ind2keep;
            oneWeekDayInd = this.originalFeatureStruct.indFirstLast1Week;
            
            [nonwear_rows, malfunctionRows] = this.getNonwearRows(nonwearMethods, nonwearStruct);
            
            % Make all week long data nonwear.  Then check and change
            % all week entries found without nonwear.
            nonwearStruct.week_exactly_rows = true(size(nonwear_rows));
            
            % go through our indices of first and last days of week
            % again, and check if there are discards here.
            
            individualsMissingCompleteWeekAfterNonWearExclusion = 0;
                        
            % It is possible for nonwear_rows to be empty;
            % e.g. if a user tries to overwrite previous usage state
            % by running a batch job and then stopping before it finishes.
            if ~isempty(nonwear_rows)
                for d=1:size(oneWeekDayInd,1)
                    if any(nonwear_rows(oneWeekDayInd(d,1):oneWeekDayInd(d,2)))
                        % This is a conservative approach as it could be that a subject only has one or two days of nonwear over the course
                        % of 10 days of data and still has a week left to be evaluated with.
                        day_ind = oneWeekDayInd(d,1):oneWeekDayInd(d,2);
                        ind2keepAndNonwearExcluded(day_ind) = false;
                        if(this.originalFeatureStruct.numDays(d)>=7)
                            ind2keepExactly1WeekAndNonwearExcluded(day_ind) = false;
                            individualsMissingCompleteWeekAfterNonWearExclusion = individualsMissingCompleteWeekAfterNonWearExclusion + 1;
                        end
                        nonwearStruct.week_exactly_rows(day_ind) = true;
                    end
                end
            end
            nonwearStruct.ind2keepAndNonwearExcluded = ind2keepAndNonwearExcluded;
            nonwearStruct.ind2keepExactly1WeekAndNonwearExcluded = ind2keepExactly1WeekAndNonwearExcluded;
            nonwearStruct.individualsMissingCompleteWeekAfterNonWearExclusion = individualsMissingCompleteWeekAfterNonWearExclusion;
        end
        
        
        %> @brief Feature data path must be loaded prior to calling
        %> importExclusions which attempts to merge studyIDs and date time
        %> stamps of feature data with exclusion data from the import file.
        %> This is checked internally and a warning dialog is shown in the
        %> event the check fails
        function didImport = importExclusions(this, importFilename)
            didImport = false;
            
            if nargin<2
                importFilename = [];
            else
                importFilename = char(importFilename);
            end
            if isempty(this.originalFeatureStruct)
                warndlg(sprintf('Feature data path must be loaded before importing exclusion data.\nHint: File->Open->Features Directory Path'), 'Cannot Import')
            else
                if isempty(importFilename)
                    lastImportFilename = this.exclusionsFilename;
                    if isempty(lastImportFilename)
                        curCluster = this.getClusterObj();
                        if ~isempty(curCluster)
                            lastImportFilename = curCluster.getExportPath();
                        end
                    end
                    importFilename = uigetfullfile({'*.mat', 'Exclusion file (*.mat)'},...
                        'Select nonwear/bad data exclusion data to import',...
                        lastImportFilename,'off');
                end
                
                if isempty(importFilename)
                    this.logStatus('User canceled');
                elseif ~exist(importFilename,'file')
                    this.logStatus('Import filename does not exist: %s', importFilename);
                else
                    try
                        tmp = load(importFilename);
                        if isfield(tmp, 'nonwear')
                            nonwearStruct = tmp.nonwear;
                        elseif isfield(tmp,'nonwearFeatures')
                            nonwearStruct = tmp.nonwearFeatures;
                        else
                            error('Import file (%s) is malformed and does not include ''nonwear'' field', importFilename);
                        end                        
                        nonwearStruct = this.matchExclusionsToContent(nonwearStruct, this.originalFeatureStruct);
                        
                        this.nonwear.imported_file = nonwearStruct;
                        this.nonwear.imported_file.filename = importFilename;
                        % Merge the rows now ...
                        current_keys = [this.originalFeatureStruct.studyIDs(:), this.originalFeatureStruct.startDatenums(:)];
                        imported_keys = [nonwearStruct.studyIDs(:), nonwearStruct.startDatenums(:)];
                        [~, a, b] = intersect(current_keys, imported_keys, 'rows', 'stable');
                        
                        % this.nonwear.imported_file.rows = false(size(this.originalFeatureStruct.startDatenums));
                        % this.nonwear.imported_file.rows(a) = nonwearStruct.rows(b);
                        this.nonwear.imported_file.rows = nonwearStruct.rows(b);
                        this.nonwear.startDatenums = nonwearStruct.startDatenums(b);
                        this.nonwear.studyIDs = nonwearStruct.studyIDs(b);
                        % fieldsToMerge = {'ind2keep1week','ind2keepExactly1Week','startDatenums','studyIDs','week_exactly_rows','ind2keepAndNonwearExcluded'
                        this.setSetting('discardMethod', [this.getSetting('discardMethod'),'imported_file']);
                        this.nonwearRequiresUpdate = true;
                        this.setSetting('exclusionsFilename', importFilename);

                        didImport = true;

                    catch me
                        showME(me);
                        fprintf('\nThe above exception was caught while trying to load %s\n', importFilename);
                    end
                end
            end
            if didImport
                this.enableClusterRecalculation();
            end
        end
        
                
        % Exclusions are those days which are excluded from analysis either because of sensor malfunction,
        % nonwear identification, imcomplete wear time, etc.
        % like exportNonwear - this is the more general case.
        function didExport = exportExclusions(this, exportFmt)
            didExport = false;
            exclusionsStruct = this.nonwear;
            curCluster = this.getClusterObj();
            if isempty(exclusionsStruct) || isempty(curCluster)
                msg = 'No nonwear features exist.  Try clustering first.  Nothing to save.';
                pa_msgbox(msg,'Warning');
            else
                % UI issue: All known nonwear methods are presented,
                % however, there is not a filter to remove methods which do
                % not exist for the current setup (e.g. a file may not have
                % been imported, choi may not have been run, a usage state
                % may not have been run, etc.                
                [validNonwearOptions, nonwearOptions] = this.getValidNonwearOptions();        
                currentSelections = this.getSetting('discardMethod');
                selections = nonwearDlg(validNonwearOptions, currentSelections);
                
                if ~isempty(selections) && curCluster.updateExportPath() % false if user cancels
                    nonwearMethods = validNonwearOptions(selections);
                    [nonwear_rows, malfunctionRows] = this.getNonwearRows(nonwearMethods, this.nonwear); 
                    exclusionsStruct = this.getExclusionsStruct(nonwearMethods, exclusionsStruct);
                    originalFeatures = this.originalFeatureStruct;
                    exclusionsStruct = rmfield(exclusionsStruct, 'featureStruct');
                    fieldsToCopy = {'studyIDs','startDatenums','indFirstLast', 'srcDataType',...
                        'indFirstLast1Week', 'ind2keep1Week', 'ind2keepExactly1Week',...
                        'ind2keepAndNonwearExcluded', 'ind2keepExactly1WeekAndNonwearExcluded'};
                    for f=1:numel(fieldsToCopy)
                        field = fieldsToCopy{f};
                        exclusionsStruct.(field) = originalFeatures.(field);
                    end
                    
                    fieldsToKeep = nonwearMethods; 
                    fieldsToRemove = setdiff(nonwearOptions, fieldsToKeep); % nonwearOptions(fieldsToKeep) = [] --> another way to get the fields to remove
                    for f=1:numel(fieldsToRemove)
                        field = fieldsToRemove{f};
                        if isfield(exclusionsStruct, field)
                            exclusionsStruct = rmfield(exclusionsStruct, field);
                        end
                    end
                    
                    exportPath = curCluster.getExportPath();
                    description = strjoin(fieldsToKeep,'_and_');
                    exclusionsStruct.description = description;
                    saveFilename = sprintf('%s_%s_exclusions.mat',description, exclusionsStruct.srcDataType);
                    saveFile = fullfile(exportPath, saveFilename);
                    if ~exist(saveFile, 'file') || confirmDlg(sprintf('A file named "%s"\nalready exists in "%s"\n\nWould you like to overwrite it?', saveFilename, exportPath),'Confirm overwrite')
                        nonwear = exclusionsStruct; %#ok<PROPLC>
                        save(saveFile, 'nonwear');
                        this.setSetting('exclusionsFilename', saveFile);
                        fprintf(1,'nonwearFeatures saved to %s\n', saveFile);
                        didExport = true;
                    end
                else
                    fprintf(1,'Cancelled\n');
                end
            end
        end
        
        function didExport = exportClusters(this, exportFmt)
            if(nargin<2)
                exportFmt = 'csv';
            end
            
            % Migrated now to a gui setting ('exportShowNonWear')
            %             if nargin<3 || isempty(loadShapesOnly)
            %                 loadShapesOnly = false;
            %             end
            
            didExport = false;
            
            curCluster = this.getClusterObj();
            if(isempty(curCluster) || ~isa(curCluster,'PACluster'))
                msg = 'No cluster object exists.  Nothing to save.';
                pa_msgbox(msg,'Warning');
                
                % If this is not true, then we can just leave this
                % function since the user would have cancelled.
            elseif(curCluster.updateExportPath())
                try
                    lastClusterSettings.StatTool = this.getStateAtTimeOfLastClustering();
                    exportPath = curCluster.getExportPath();
                    % original widget settings are kept track of using a
                    % separate gui
                    exportNonwearFeatures = this.getSetting('exportShowNonwear');
                    
                    this.logWarning('Not exporting nonwear flags');
                    exportNonwearFeatures = false;
                    if(exportNonwearFeatures)
                        nonwearFeatures = this.nonwear;
                    else
                        nonwearFeatures = [];
                    end
                    
                    if(strcmpi(exportFmt,'xls'))
                        didExport = false;
                        msg = '.xls export not yet supported';
                        %                         pa_msgbox();
                    else
                        [didExport, msg] = curCluster.exportToDisk(lastClusterSettings, nonwearFeatures);
                    end
                    
                    %                     if(~lastClusterSettings.discardNonwearFeatures)
                    %                         [didExport, msg] = curCluster.exportToDisk(exportPath, lastClusterSettings, nonwearFeatures{:});
                    %                     else
                    %                         [didExport, msg] = curCluster.exportToDisk(exportPath, lastClusterSettings, nonwearFeatures{:});
                    %                     end
                    
                catch me
                    msg = 'An error occurred while trying to save the data to disk.  A thousand apologies.  I''m very sorry.';
                    showME(me);
                end
                
                % Give the option to look at the files in their saved folder.
                if(didExport)
                    dlgName = 'Export complete';
                    closeStr = 'Close';
                    showOutputFolderStr = 'Open output folder';
                    options.Default = closeStr;
                    options.Interpreter = 'none';
                    buttonName = questdlg(msg,dlgName,closeStr,showOutputFolderStr,options);
                    if(strcmpi(buttonName,showOutputFolderStr))
                        openDirectory(exportPath)
                    end
                else
                    makeModal = true;
                    pa_msgbox(msg,'Export',makeModal);
                end
            end
        end
        
        function clusterParameterChangeCb(this, clusterObj, paramEventData)
            if(isfield(this.settings,paramEventData.fieldName))
                this.setSetting(paramEventData.fieldName, paramEventData.changedTo);
            end
        end
        
        %Don't know that this is used anymore ... @hm 1/16/2020
        function loadSettings(obj, settingsFilename)
            fprintf('Hey, I''m still here.\n');
            if(nargin<2 || ~exist(settingsFilename,'file'))
                path2check = getSavePath();
                filename=uigetfullfile({'*.txt;*.exp','All Settings Files';
                    '*.exp','Export Settings'},...
                    'Select a settings file',path2check);
                try
                    if(~isempty(filename))
                        this.settings = PASettings.loadParametersFromFile(filename);
                        this.settings = mergeStruct(obj.getDefaults(),this.settings);
                        obj.setWidgetSettings(this.settings);
                    end
                catch me
                    showME(me);
                end
            end
        end
        
        function updateOriginalWidgetSettings(this, updatedSettings)
            % Updating original widget settings ensures that the
            % cluster object is not emptied if it exists, which is helpful
            % since this method was made when trying to sync cached cluster
            % results, where a cluster exists and may have been loaded already,
            % but the settings have not been updated in this class yet.
            this.originalSettings = mergeStruct(this.originalSettings,updatedSettings); % keep a record of our most recent settings.
            
            % Convoluted somewhere - but originalSettings do not have the
            % PAParam classes for the most part, and so we cannot simply
            % pass original widget settings to the setWidgetSettings()
            % method below as is because it throws off many of the
            % callbacks which, e.g. buttons that rely on the
            % clusterDistributionType
            this.settings = mergeStruct(this.settings, this.originalSettings);
        end
        
        % ======================================================================
        %> @brief Sets the widget settings.  In particular, set the
        %> originalSettings property to the input struct.
        %> @param this Instance of PAStatTool
        %> @param Struct of settings for the Stat tool.  Should conform to
        %> getDefaults
        %> @param initializeOnSet Optional flag that defaults to {True}.
        %> When true, initWidgets() is called using the input widgetSettings.
        %> When false, initWidgets is not called (helpful on construction)
        % ======================================================================
        function setWidgetSettings(this,widgetSettings, updateOnSet)
            if(nargin<3 || isempty(updateOnSet) || ~islogical(updateOnSet))
                updateOnSet = true;
            end
            
            if(~isequal(paparamsToValues(this.originalSettings),paparamsToValues(widgetSettings)))
                if(~isempty(this.clusterObj))
                    this.clusterObj = [];
                    this.logWarning('Cluster results were just cleared.');
                end
            end
            
            % Also updates originalSettings ... :( <> :)
            this.setSettings( widgetSettings );
            
            % Merge the defaults with what is here otherwise.
            % setUseDatabase() is problematic in that the profileFields
            % property is emptied if it is not used, which would wipe out
            % the outcomesTable profileFields if it is called after
            % setUseOutcomesTable.  The preference at this point is given
            % to the outcomesTable.  2/14/2019 @hyatt
            this.setUseDatabase(this.getSetting('useDatabase'));  %sets this.useDatabase to false if it was initially true and then fails to open the database
            this.setUseOutcomesTable(this.getSetting('useOutcomes'));
            
            if(updateOnSet)
                this.updateWidgets();
            end
        end
        
        % ======================================================================
        %> @brief Sets the start and stop time dropdown menu content and
        %> returns the selection.
        %> @param this Instance of PAStatTool
        %> @param Cell string of times that can be selected to define a
        %> range of time to calculate cluster profiles from.
        %> @retval Selection value for the menu_clusterStartTime menu.
        %> @retval Selection value for the menu_clusterStopTime menu.
        % ======================================================================
        function [startTimeSelection, stopTimeSelection ] = setStartTimes(this,startTimeCellStr)
            if(~isempty(this.originalSettings))
                stopTimeSelection = this.originalSettings.stopTimeSelection;
                if(stopTimeSelection <= 1)
                    stopTimeSelection = numel(startTimeCellStr);
                end
                startTimeSelection = this.originalSettings.startTimeSelection;
                if(startTimeSelection>numel(startTimeCellStr) || stopTimeSelection>numel(startTimeCellStr))
                    startTimeSelection = 1;
                    stopTimeSelection = numel(startTimeCellStr);
                end
            else
                startTimeSelection = 1;
                stopTimeSelection = numel(startTimeCellStr);
            end
            
            if ~isempty(this.figureH)
                stopTimeCellStr = circshift(startTimeCellStr(:),-1);
                set(this.handles.menu_clusterStartTime,'string',startTimeCellStr,'value',startTimeSelection);
                set(this.handles.menu_clusterStopTime,'string',stopTimeCellStr,'value',stopTimeSelection);
            end
        end
        
        function isIt = isShowingWeekLong(this, pSettings)
            
            if nargin < 2 || isempty(pSettings)
                pSettings = this.getPlotSettings();
            end
            isIt = strcmpi(pSettings.weekdayTag,'weeklong');
        end
        
        function didCalc = calcFeaturesFromFile(this, featuresFilename)
            indicesToUse = [];
            didCalc = this.calcFeatureStruct(indicesToUse, featuresFilename);            
        end
        
        function isIt = isNonwearUpdateRequired(this, curSettings, lastSettings)
            isIt = true;
            if nargin < 3
                lastSettings = this.lastUsedSettings;
            end
            if ~isempty(lastSettings) && isstruct(lastSettings) && isstruct(curSettings) ...
                    && isfield(lastSettings, 'startTimeSelection') && isfield(curSettings, 'startTimeSelection')
                if curSettings.startTimeSelection == lastSettings.startTimeSelection ...
                        && curSettings.stopTimeSelection == lastSettings.stopTimeSelection ...
                        && strcmpi(curSettings.weekdayTag, lastSettings.weekdayTag)
                    if ~strcmpi(curSettings.weekdayTag, 'custom') ...
                            || isequal(curSettings.customDaysOfWeek, lastSettings.customDaysOfWeek)
                        isIt = false;                    
                    end
                end
            end
        end
        
        % ======================================================================
        %> @brief Loads feature struct from disk using the current features
        %> directory.
        %> @param this Instance of PAStatTool
        %> @retval success Boolean: true if features are loaded from file.  False if they are not.
        % ======================================================================
        function didCalc = calcFeatureStruct(this, indicesToUse, inputFilename)
            
            if nargin<3
                inputFilename = [];
            end
            if(nargin<2)
                indicesToUse = [];
                %                 if(~isempty(this.originalFeatureStruct))
                %                     indicesToUse = randn(size(this.originalFeatureStruct.studyIDs))>0;
                %                 end
            else
                if(ischar(indicesToUse))
                    switch lower(indicesToUse)
                        case 'bootstrap'
                            
                        otherwise
                            fprintf(1,'Unknown indices flag for refreshClustersAndPlot: ''%s''\n',indicesToUse);
                            indicesToUse = [];
                    end
                end
            end
            
            if ~isempty(this.figureH)
                pSettings = this.getPlotSettings();
            else
                pSettings = this.getSettings();
                fields = fieldnames(pSettings);
                for f=1:numel(fields)
                    key = fields{f};
                    if isa(pSettings.(key), 'PAParam')
                        pSettings.(key) = pSettings.(key).value;
                    end
                end
            end
            
            % True if certain things have changed.
            this.nonwearRequiresUpdate = this.nonwearRequiresUpdate || this.isNonwearUpdateRequired(pSettings);
            
            
            countProcessType = this.base.processedTypes{1};
            rawProcessType = this.base.processedTypes{2};
            unknownProcessType = '*'; %anyProcessType ?
            
            isCountData = false;
            isRawData = false;
                
            if isempty(inputFilename)
                inputCountFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,countProcessType,pSettings.curSignal);
                inputRawFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,rawProcessType,pSettings.curSignal);
                inputUnknownFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,unknownProcessType,pSettings.curSignal);
                if(exist(inputCountFilename,'file'))
                    inputFilename = inputCountFilename;
                    isCountData = 1;
                elseif(exist(inputRawFilename,'file'))
                    inputFilename = inputRawFilename;
                    isRawData = 1;
                else
                    inputFilename = inputUnknownFilename;
                end
            else
                [~, baseName]  = fileparts(inputFilename);  %/features/sum/features.sum.accel.count.vecMag.txt' --> 'features.sum.accel.count.vecMag'
                filenameStruct = cell2struct(strsplit(baseName,'.'),{'collection','baseFeature','source','processType','signal'},2);
                pSettings.baseFeature = filenameStruct.baseFeature;
                pSettings.curSignal = filenameStruct.signal;
                isRawData = strcmpi(filenameStruct.processType,rawProcessType);
                isCountData = strcmpi(filenameStruct.processType,countProcessType);
            end
            
            if(isRawData || isCountData)
                usageFeature = 'usagestate';
                choiFeature = 'nonwear_choi';
                
                if isRawData
                    srcDataType = 'raw';
                else
                    srcDataType = 'count';
                end
                
                usageFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory, usageFeature, usageFeature, srcDataType, 'vecMag');
                choiFilename = sprintf(this.featureInputFilePattern, this.featuresDirectory, choiFeature, choiFeature, srcDataType, 'vecMag');
                
                % Usage state previously based on count data, but now supporting both.  However, the states are not fully overlapping, so some are supported by
                % one form but not the other (e.g. not_working for raw, and nonwear for count)
                
                % Double check that we haven't switched paths somewhere and
                % are still using a previous copy of usageStateStruct (i.e.
                % check usageFilename against this.usageStateStruct.filename)
                if(isempty(this.usageStateStruct) || ~strcmpi(usageFilename,this.usageStateStruct.filename))
                    if(exist(usageFilename,'file'))
                        this.usageStateStruct = this.loadAlignedFeatures(usageFilename);
                        this.usageStateStruct.srcDataType = srcDataType;
                    end
                end
                
                % Check for choi data
                if(isempty(this.choiNonwearStruct) || ~strcmpi(choiFilename,this.choiNonwearStruct.filename))
                    if(exist(choiFilename,'file'))
                        this.choiNonwearStruct = this.loadAlignedFeatures(choiFilename);
                        this.choiNonwearStruct.srcDataType = srcDataType;
                    end
                end
                
                loadFileRequired = isempty(this.originalFeatureStruct) ...
                    || ~strcmpi(inputFilename,this.originalFeatureStruct.filename) ...
                    || nargin > 2;  % an input filename was provided from the start
                
                if(loadFileRequired)
                    this.originalFeatureStruct = this.loadAlignedFeatures(inputFilename);
                    if(isfield(this.originalFeatureStruct,'studyIDs'))
                        [this.originalFeatureStruct.uniqueIDs,iaFirst] = unique(this.originalFeatureStruct.studyIDs,'first');
                        [~,iaLast,~] = unique(this.originalFeatureStruct.studyIDs,'last');
                        this.originalFeatureStruct.indFirstLast = [iaFirst, iaLast];  % can be more than one week
                        this.originalFeatureStruct.numDays = iaLast - iaFirst+1;  % can be more than one week
                        
                        this.originalFeatureStruct.indFirstLast1Week = [iaFirst, min(iaLast, iaFirst+this.MAX_DAYS_PER_STUDY-1)];  % cannot be more than one week, but can be less ...
                        
                        ind2keepExactly1Week = false(size(this.originalFeatureStruct.shapes,1),1);
                        ind2keep = false(size(this.originalFeatureStruct.shapes,1),1);
                        oneWeekDayInd = this.originalFeatureStruct.indFirstLast1Week;
                        for d=1:size(oneWeekDayInd,1)
                            ind2keep(oneWeekDayInd(d,1):oneWeekDayInd(d,2))= true;  % could be less than a week, but not more
                            if(this.originalFeatureStruct.numDays(d)>=7)
                                % exactly 1 week
                                ind2keepExactly1Week(oneWeekDayInd(d,1):oneWeekDayInd(d,2)) = true;
                            end
                        end
                        this.originalFeatureStruct.ind2keep1Week = ind2keep;  % logical index for subject days that are part of 1 week or less.
                        this.originalFeatureStruct.ind2keepExactly1Week = ind2keepExactly1Week; % logical index for subject days that are part of 1 week exactly (each day is covered).
                    end
                    
                    % The call to setStartTimes here is necessary to
                    % updating the start/stop GUI times just loaded.
                    [pSettings.startTimeSelection, pSettings.stopTimeSelection] = this.setStartTimes(this.originalFeatureStruct.startTimes);
                end
                
                this.originalFeatureStruct.srcDataType = srcDataType;
                tmpFeatureStruct = this.originalFeatureStruct;
                
                % Make sure we actually have a usage state struct
                if(~isempty(this.usageStateStruct))
                    tmpUsageStateStruct = this.usageStateStruct;
                else
                    tmpUsageStateStruct = this.originalFeatureStruct;
                    tmpUsageStateStruct.shapes(:) = 7;%just make everything magically 7 for right now to avoid having refactor further.
                    tmpUsageStateStruct.method = 'usagestate';
                    tmpUsageStateStruct.filename = 'none';
                    tmpUsageStateStruct.srcDataType = srcDataType;
                    tmpUsageStateStruct.methodDescription = 'Padaco nonwear';
                end
                
                this.nonwear.padaco = tmpUsageStateStruct;
                
                if(~isempty(this.choiNonwearStruct))
                    tmpChoiStruct = this.choiNonwearStruct;
                else
                    tmpChoiStruct = this.originalFeatureStruct;
                    %just make everything magically 0 (False for nonwear - meaning everything is wear) for right now to avoid having refactor further.
                    % When you are ready to refactor, see the remaining
                    % portions of this function; start times and such
                    tmpChoiStruct.shapes(:) = 0; 
                    tmpChoiStruct.method = 'nonwear_choi';
                    tmpChoiStruct.methodDescription = 'Choi nonwear';
                    tmpChoiStruct.filename = 'none';
                    tmpChoiStruct.srcDataType = srcDataType;
                end
                
                this.nonwear.choi = tmpChoiStruct;
                
                
                % update to here to make sure we are covered for the one
                % week case now.  So we can exclude based on the days
                % collected.                
                if loadFileRequired || this.nonwearRequiresUpdate
                    nonwearMethods = this.getSetting('discardMethod');
                    if any(strcmpi(nonwearMethods, 'imported_file')) && exist(this.exclusionsFilename,'file') && ...
                        (~isfield(this.nonwear.imported_file, 'rows') || isempty(this.nonwear.imported_file.rows))
                        try
                            this.importExclusions(this.exclusionsFilename);
                        catch me
                            this.logError(me, 'Failed to import exclusion data from %s', this.exclusionsFilename);
                        end
                    end
                    
                    this.nonwear = this.getExclusionsStruct();
                    
                    this.originalFeatureStruct.ind2keepAndNonwearExcluded = this.nonwear.ind2keepAndNonwearExcluded;
                    this.originalFeatureStruct.ind2keepExactly1WeekAndNonwearExcluded = this.nonwear.ind2keepExactly1WeekAndNonwearExcluded;
                    
                    fprintf(1, 'Number of individuals who will be removed from weeklong analysis if discarding nonwear: %d\n', this.nonwear.individualsMissingCompleteWeekAfterNonWearExclusion);
                    this.nonwearRequiresUpdate = false;
                end
                
                if(~isempty(indicesToUse))
                    fieldsToParse = {'studyIDs','startDatenums','startDaysOfWeek','shapes'};
                    for f=1:numel(fieldsToParse)
                        fname = fieldsToParse{f};
                        tmpUsageStateStruct.(fname) = tmpUsageStateStruct.(fname)(indicesToUse,:);
                        tmpChoiStruct.(fname) = tmpChoiStruct.(fname)(indicesToUse,:);
                        tmpFeatureStruct.(fname) = tmpFeatureStruct.(fname)(indicesToUse,:);
                    end
                end
                startTimeSelection = pSettings.startTimeSelection;
                stopTimeSelection = pSettings.stopTimeSelection;
                
                % Do nothing; this means, that we started at rayday and
                % will go 24 hours
                if(stopTimeSelection == startTimeSelection)
                    if(this.isClusterMode())
                        warndlg('Only one time epoch selected - defaulting to all epochs instead.');
                    end
                    
                elseif(startTimeSelection < stopTimeSelection)
                    
                    tmpFeatureStruct.startTimes = tmpFeatureStruct.startTimes(startTimeSelection:stopTimeSelection);
                    tmpFeatureStruct.shapes = tmpFeatureStruct.shapes(:,startTimeSelection:stopTimeSelection);
                    tmpFeatureStruct.totalCount = numel(tmpFeatureStruct.startTimes);
                    
                    tmpUsageStateStruct.startTimes = tmpUsageStateStruct.startTimes(startTimeSelection:stopTimeSelection);
                    tmpUsageStateStruct.shapes = tmpUsageStateStruct.shapes(:,startTimeSelection:stopTimeSelection);
                    tmpUsageStateStruct.totalCount = numel(tmpUsageStateStruct.startTimes);
                    
                    tmpChoiStruct.startTimes = tmpChoiStruct.startTimes(startTimeSelection:stopTimeSelection);
                    tmpChoiStruct.shapes = tmpChoiStruct.shapes(:,startTimeSelection:stopTimeSelection);
                    tmpChoiStruct.totalCount = numel(tmpChoiStruct.startTimes);                    
                    
                    % For example:  22:00 to 04:00 is ~ stopTimeSelection = 22 and
                    % startTimeSelection = 81
                elseif(stopTimeSelection < startTimeSelection)
                    tmpFeatureStruct.startTimes = [tmpFeatureStruct.startTimes(startTimeSelection:end),tmpFeatureStruct.startTimes(1:stopTimeSelection)];
                    tmpFeatureStruct.shapes = [tmpFeatureStruct.shapes(:,startTimeSelection:end),tmpFeatureStruct.shapes(:,1:stopTimeSelection)];
                    tmpFeatureStruct.totalCount = numel(tmpFeatureStruct.startTimes);
                    
                    tmpUsageStateStruct.startTimes = [tmpUsageStateStruct.startTimes(startTimeSelection:end), tmpUsageStateStruct.startTimes(1:stopTimeSelection)];
                    tmpUsageStateStruct.shapes = [tmpUsageStateStruct.shapes(:,startTimeSelection:end), tmpUsageStateStruct.shapes(:,1:stopTimeSelection)];
                    tmpUsageStateStruct.totalCount = numel(tmpUsageStateStruct.startTimes);
                    
                    tmpChoiStruct.startTimes = [tmpChoiStruct.startTimes(startTimeSelection:end), tmpChoiStruct.startTimes(1:stopTimeSelection)];
                    tmpChoiStruct.shapes = [tmpChoiStruct.shapes(:,startTimeSelection:end), tmpChoiStruct.shapes(:,1:stopTimeSelection)];
                    tmpChoiStruct.totalCount = numel(tmpChoiStruct.startTimes);                    
                else
                    warndlg('Well this is unexpected.');
                end
                
                this.nonwear.padaco = tmpUsageStateStruct;
                this.nonwear.choi = tmpChoiStruct;                
                nonwearMethods = this.getSetting('discardMethod');
                startEndTimes = this.originalFeatureStruct.startTimes([startTimeSelection, stopTimeSelection]);
                [this.nonwear.rows, malfunctionRows] = this.getNonwearRows(nonwearMethods, this.nonwear, startEndTimes);
                % this.nonwear.rows = this.nonwear.rows | malfunctionRows;
                if this.isShowingWeekLong(pSettings)
                    maxDaysAllowed = 7;
                    minDaysAllowed = 7;
                else
                    maxDaysAllowed = this.maxNumDaysAllowed;
                    minDaysAllowed = this.minNumDaysAllowed;
                end
                
                % logical() ensures type casting of PABoolParam if we get pSettings from somewhere else
                if pSettings.discardNonwearFeatures
                    % min and max days allowed interpeted in one of three ways
                    % 1.  both exactly 7
                    % 2.  either more than 0
                    % 3.  both exactly 0
                    if (maxDaysAllowed > 0 || minDaysAllowed > 0) && isempty(indicesToUse)
                        % Determine nonwear rows and then determine how much is excess for one week values and exclude those next.  
                        % [this.featureStruct, this.nonwear.featureStruct] = this.discardNonwearFeatures(tmpFeatureStruct, this.nonwear.week_exactly_rows);
                        
                        % will NO LONGER handle this case below actually
                        this.featureStruct = tmpFeatureStruct;
                        this.nonwear.featureStruct = [];
                        
                    else
                        [this.featureStruct, this.nonwear.featureStruct] = this.discardNonwearFeatures(tmpFeatureStruct, this.nonwear.rows);
                    end
                else
                    this.featureStruct = tmpFeatureStruct;
                    this.nonwear.featureStruct = [];
                end
                
                % min and max days allowed interpeted in one of three ways
                % 1.  both exactly 7
                % 2.  either more than 0
                % 3.  both exactly 0
                if(maxDaysAllowed>0 || minDaysAllowed>0)
                    if(isempty(indicesToUse))
                        % Handling exactly 1 week
                        if(maxDaysAllowed==7 && minDaysAllowed==7)
                            if pSettings.discardNonwearFeatures
                                ind2keep = this.originalFeatureStruct.ind2keepExactly1WeekAndNonwearExcluded;
                            else
                                ind2keep = this.originalFeatureStruct.ind2keepExactly1Week;
                            end
                            
                            % otherwise, universally handling the case of 1
                            % week or less.
                        else
                            if pSettings.discardNonwearFeatures
                                % ind2keep = this.originalFeatureStruct.ind2keepAndNonwearExcluded;
                                ind2keep = ~this.nonwear.rows;
                            else
                                ind2keep = this.originalFeatureStruct.ind2keep1Week;
                            end
                        end
                    else
                        % Otherwise, go off of what was passed in.
                        ind2keep = false(size(this.featureStruct.shapes,1),1);
                        [c, iaFirst,ic] = unique(this.featureStruct.studyIDs,'first'); %#ok<*ASGLU>
                        [c, iaLast, ic] = unique(this.featureStruct.studyIDs,'last');
                        oneWeekDayInd = [iaFirst, min(iaLast, iaFirst+this.MAX_DAYS_PER_STUDY-1)];
                        for d=1:size(oneWeekDayInd,1)
                            ind2keep(oneWeekDayInd(d,1):oneWeekDayInd(d,2))= true;
                        end
                    end
                    
                    fieldsToParse = {'studyIDs','startDatenums','startDaysOfWeek','shapes'};
                    for f=1:numel(fieldsToParse)
                        fname = fieldsToParse{f};
                        this.featureStruct.(fname)(~ind2keep,:)=[];
                    end
                    
                    try
                        if ~pSettings.discardNonwearFeatures
                            this.nonwear.rows(~ind2keep)=[];
                        end
                    catch me
                        showME(me);
                    end
                end
                
                loadFeatures = this.featureStruct.shapes;
                
                if(pSettings.clusterDurationHours~=24)
                    
                    % cluster duration hours will always be integer
                    % values; whole numbers
                    featureVecDuration_hour = this.getFeatureVecDurationInHours();
                    featuresPerVec = this.featureStruct.totalCount;
                    % features per hour should also, always be whole
                    % numbers...
                    featuresPerHour = round(featuresPerVec/featureVecDuration_hour);
                    %featureDuration_hour = 1/featuresPerHour;
                    
                    hoursPerCluster = pSettings.clusterDurationHours;
                    featuresPerCluster = featuresPerHour*hoursPerCluster;
                    
                    clustersPerVec = floor(featuresPerVec/featuresPerCluster);
                    
                    excessFeatures = mod(featuresPerVec,featuresPerCluster);
                    if(excessFeatures>0)
                        loadFeatures = loadFeatures(:,1:clustersPerVec*featuresPerCluster);
                        this.featureStruct.totalCount = this.featureStruct.totalCount - excessFeatures;
                    end
                    
                    this.featureStruct.totalCount = this.featureStruct.totalCount/clustersPerVec;
                    this.featureStruct.startTimes = this.featureStruct.startTimes(1:this.featureStruct.totalCount);  % use the first time series for any additional clusters created from the same feature vector reshaping.
                    
                    % This will put the start days of week in the same
                    % order as the loadFeatures after their reshaping below
                    % (which causes the interspersion).
                    reshapeFields = {'startDaysOfWeek','startDatenums','studyIDs'};
                    for r= 1:numel(reshapeFields)
                        fname = reshapeFields{r};
                        if(isfield(this.featureStruct,fname))
                            tmp = repmat(this.featureStruct.(fname),1,clustersPerVec)';
                            this.featureStruct.(fname) = tmp(:);
                        end
                    end
                    %                     this.featureStruct.startDaysOfWeek = repmat(this.featureStruct.startDaysOfWeek,1,clustersPerVec)';
                    %                     this.featureStruct.startDaysOfWeek = this.featureStruct.startDaysOfWeek(:);
                    
                    
                    [nrow,ncol] = size(loadFeatures);
                    newRowCount = nrow*clustersPerVec;
                    newColCount = ncol/clustersPerVec;
                    loadFeatures = reshape(loadFeatures',newColCount,newRowCount)';
                    
                    %  durationHoursPerFeature = 24/this.featureStruct.totalCount;
                    % featuresPerHour = this.featureStruct.totalCount/24;
                    % featuresPerCluster = hoursPerCluster*featuresPerHour;
                end
                % If there is precluster reduction
                if ~strcmpi(pSettings.preclusterReduction,'none')
                    numChunks = double(pSettings.numChunks);  
                    
                    if pSettings.chunkShapes && numChunks>1
                        % The other transformation will reduce the number
                        % of columns, so we need to account for that here.
                        [numRows, numCols] = size(loadFeatures);
                        if(~strcmpi(pSettings.preclusterReduction,'sort'))
                            numCols = numChunks;
                        end
                        splitLoadFeatures = nan(numRows,numCols);
                        
                        % 1. Reshape the loadFeatures by segments
                        % 2. Sort the loadfeatures
                        % 3. Resahpe the load features back to the original                        % 
                        % way
                        
                        % Or make a for loop and sort along the way ...
                        sections = round(linspace(0,size(loadFeatures,2), numChunks+1));  %Round to give integer indices
                        for s=1:numel(sections)-1
                            sectionInd = sections(s)+1:sections(s+1); % Create consecutive, non-overlapping sections of column indices.
                            if(numCols == numChunks)
                                % Case 1: we are we reducing the output, so
                                % only 1 column per s
                                splitLoadFeatures(:,s) = PAStatTool.featureSetAdjustment(loadFeatures(:,sectionInd),pSettings.preclusterReduction);
                            else
                                % otherwise do not reduce the output
                                splitLoadFeatures(:,sectionInd) = PAStatTool.featureSetAdjustment(loadFeatures(:,sectionInd),pSettings.preclusterReduction);
                            end
                            %                             sort(loadFeatures(:,sectionInd),2,'descend');
                        end
                        loadFeatures = splitLoadFeatures;
                    else
                        if ~strcmpi(pSettings.preclusterReduction,'sort') || pSettings.chunkShapes
                            loadFeatures = PAStatTool.featureSetAdjustment(loadFeatures,pSettings.preclusterReduction);
                        end
                    end
                    
                    % Account for new times.
                    % if we had a precluster feature set reduction
                    if(~strcmpi(pSettings.preclusterReduction,'sort'))
                        
                        if pSettings.chunkShapes
                            initialCount = this.featureStruct.totalCount;
                            this.featureStruct.totalCount = pSettings.numChunks;
                            indicesToUse = floor(linspace(1,initialCount,this.featureStruct.totalCount));
                            % intervalToUse = floor(initialCount/(pSettings.numChunks+1));
                            % indicesToUse = linspace(intervalToUse,intervalToUse*pSettings.numChunks,pSettings.numChunks);
                        else
                            %
                            try
                                this.featureStruct.totalCount = size(loadFeatures, 2);
                                indicesToUse = 1:this.featureStruct.totalCount;
                            catch me
                                showME(me);
                                this.featureStruct.totalCount = 1;
                                indicesToUse = 1;
                            end
                            
                        end
                        this.featureStruct.startTimes = this.featureStruct.startTimes(indicesToUse);
                    end
                end

                if pSettings.trimResults
                    pctValues = prctile(loadFeatures,pSettings.trimToPercent);
                    pctValuesMat = repmat(pctValues,size(loadFeatures,1),1);
                    adjustInd = loadFeatures>pctValuesMat;
                end
                
                % floor below
                if(pSettings.cullResults)
                    culledInd = loadFeatures<=pSettings.cullToValue;
                    %                     pctValues = prctile(loadFeatures,pSettings.cullToValue);
                    %                     pctValuesMat = repmat(pctValues,size(loadFeatures,1),1);
                    %                     culledInd = loadFeatures<pctValuesMat;
                end
                
                % Trim values to a maximum ceiling
                if(pSettings.trimResults)
                    loadFeatures(adjustInd) = pctValuesMat(adjustInd);
                end
                
                % Set values below a certain range to 0.  Not good for
                % classification rules.
                if(pSettings.cullResults)
                    loadFeatures(culledInd) = 0;
                end
                
                if(pSettings.normalizeValues)
                    [loadFeatures, nzi] = PAStatTool.normalizeLoadShapes(loadFeatures);
                    removeZeroSums = false;
                    removeZeroSums = true;
                    if(removeZeroSums)
                        this.featureStruct.features = loadFeatures(nzi,:);
                        this.featureStruct.studyIDs(~nzi) = [];
                        this.featureStruct.startDatenums = this.featureStruct.startDatenums(nzi);
                        this.featureStruct.startDaysOfWeek = this.featureStruct.startDaysOfWeek(nzi);
                    else
                        this.featureStruct.features = loadFeatures;
                    end
                else
                    this.featureStruct.features = loadFeatures;
                end
                
                this.lastUsedSettings = pSettings;
                didCalc = true;
            else
                this.featureStruct = [];
                didCalc = false;
            end
        end
        
        % ======================================================================
        %> @brief Initializes widget using current plot settings and
        %> refreshes the view.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function didInit = init(this, initSettings)
            if(nargin<2 || isempty(initSettings))
                % initSettings = this.getPlotSettings();
            end
            this.logWarning('init() is deprecated');
            didInit = false;
            % didInit = this.initWidgets(initSettings);
            % this.initCallbacks();
        end
        
        function updateSettingsFromGUI(this)
            pStruct = this.getPlotSettings();
            keys = fieldnames(pStruct);
            for k=1:numel(keys)
                key = keys{k};
                value = pStruct.(key);
                this.setSetting(key, value);
            end
        end
        
        % didUpdate will be false in the event of an exception.
        function didUpdate = updateWidgets(this, varargin)
            didUpdate = false;
            try
                
                if ~isempty(this.figureH)
                    this.updateWidgets@PAViewController(varargin{:});
                    featuresPathname = this.featuresDirectory;
                    % this.hideClusterControls();
                    
                    this.canPlot = false;    %changes to true if we find data that can be processed in featuresPathname
                    
                    set(this.handles.result_widgets_selection,'enable','off');
                    
                    clusterMethods = PACluster.getClusterMethods();
                    cmIndex = find(strcmpi(clusterMethods,this.getSetting('clusterMethod')),1);
                    if(isempty(cmIndex))
                        cmIndex = 1;
                    end
                    set(this.handles.menu_clusterMethod,'string',clusterMethods,'value',cmIndex);
                    if(isdir(featuresPathname))
                        % find allowed features which are in our base parameter and
                        % also get their description.
                        featureNames = getPathnames(featuresPathname);
                        if(~isempty(featureNames))
                            [this.featureTypes,~,ib] = intersect(featureNames,this.base.featureTypes);
                            
                            if(~isempty(this.featureTypes))
                                % clear results text
                                set(this.handles.text_clusterResultsOverlay,'string',[]);
                                
                                % Use to enable everything and then shut things down as needed.
                                % set(findall(this.handles.panels_sansClusters,'enable','off'),'enable','on');
                                
                                % now disable and then enable as eeded
                                this.disable();
                                this.canPlot = true;
                                
                                this.featureDescriptions = this.base.featureDescriptions(ib);
                                set(this.handles.menu_feature,'string',this.featureDescriptions,'userdata',this.featureTypes,'value',this.getSetting('baseFeatureSelection'));
                                
                                % Checkboxes
                                % This is good for a true false checkbox value
                                % Checked state has a value of 1
                                % Unchecked state has a value of 0
                                set(this.handles.check_discardNonwear,'value',this.getSetting('discardNonwearFeatures'));
                                set(this.handles.check_segment,'value',this.getSetting('chunkShapes'));
                                set(this.handles.check_trim,'value',this.getSetting('trimResults'));
                                set(this.handles.check_cull,'value',this.getSetting('cullResults'));
                                set(this.handles.check_normalizevalues,'value',this.getSetting('normalizeValues'));
                                
                                % This should be updated to parse the actual output feature
                                % directories for signal type (count) or raw and the signal
                                % source (vecMag, x, y, z)
                                set(this.handles.menu_signalsource,'value',this.getSetting('signalSelection'));
                                set(this.handles.menu_plottype,'value',this.getSetting('plotTypeSelection'));
                                
                                % Cluster widgets
                                set(this.handles.menu_precluster_reduction,'value',this.getSetting('preclusterReductionSelection'));
                                set(this.handles.menu_number_of_data_segments,'value',this.getSetting('numDataSegmentsSelection'));
                                
                                if(strcmpi(this.base.weekdayTags{this.getSetting('weekdaySelection')},'custom'))
                                    customIndex = this.getSetting('weekdaySelection');
                                    tooltipString = cell2str(this.base.daysOfWeekDescriptions(this.base.weekdayValues{customIndex}+1));
                                elseif(strcmpi(this.base.weekdayTags{this.getSetting('weekdaySelection')},'weeklong'))
                                    tooltipString = 'Concatenates days, Sunday through Saturday, into a single week';
                                else
                                    tooltipString = '';
                                end
                                
                                set(this.handles.menu_weekdays,'value',this.getSetting('weekdaySelection'),'tooltipstring',tooltipString);
                                set(this.handles.menu_duration,'value',this.getSetting('clusterDurationSelection'));
                                
                                % Trim results
                                if(this.getSetting('trimResults'))
                                    enableState = 'on';
                                else
                                    enableState = 'off';
                                end
                                set(this.handles.edit_trimToPercent,'string',num2str(this.getSetting('trimToPercent')),'enable',enableState);
                                
                                % Cull results
                                if(this.getSetting('cullResults'))
                                    enableState = 'on';
                                else
                                    enableState = 'off';
                                end
                                set(this.handles.edit_cullToValue,'string',num2str(this.getSetting('cullToValue')),'enable',enableState);
                                
                                % Check results
                                if(this.getSetting('chunkShapes'))
                                    enableState = 'on';
                                else
                                    enableState = 'off';
                                end
                                set(this.handles.menu_number_of_data_segments,'enable',enableState);
                                
                                this.setClusterDistributionType(this.getSetting('clusterDistributionType'));
                            end
                        end
                    end
                    
                    customIndex = strcmpi(this.base.weekdayTags,'custom');
                    this.base.weekdayValues{customIndex} = this.getSetting('customDaysOfWeek');
                    
                    % These are required by follow-on calls, regardless if the gui
                    % can be shown or not.
                    
                    % Previous state initialization - set to current state.
                    this.previousState.normalizeValues = this.getSetting('normalizeValues');
                    this.previousState.weekdaySelection = this.getSetting('weekdaySelection');
                    
                    % Set previous plot type to 'clustering' which is how it look
                    % in the guide figure on startup, and is dynamically when
                    % switching from clustering.
                    if(~isfield(this.previousState,'plotType') || isempty(this.previousState.plotType))
                        this.previousState.plotType = 'clustering';  % don't refresh here, as we may want to use a cached result.
                    else
                        this.refreshPlotType();
                    end
                    
                    % disable everything
                    if(~this.canPlot)
                        set(findall(this.handles.panel_results,'enable','on'),'enable','off');
                    end
                    didUpdate = true;
                end
            catch me
                this.logError(me, 'Display update failed');
                didUpdate = false;
            end
        end
        
        function shouldIt = holdPlots(this)
            shouldIt = strcmpi(this.getSetting('primaryAxis_nextPlot'),'add');
        end
        
        % ======================================================================
        %> @brief Clears the primary and secondary axes.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function clearPlots(this)
            if(~isempty(intersect(get(this.handles.axes_primary,'nextplot'),{'replacechildren','replace'})))
                cla(this.handles.axes_primary);
                title(this.handles.axes_primary,'');
                ylabel(this.handles.axes_primary,'');
                xlabel(this.handles.axes_primary,'');
            end
            
            cla(this.handles.axes_secondary);
            title(this.handles.axes_secondary,'');
            ylabel(this.handles.axes_secondary,'');
            xlabel(this.handles.axes_secondary,'');
            set([this.handles.axes_primary
                this.handles.axes_secondary],'xgrid','off','ygrid','off',...
                'xtick',[],'ytick',[],...
                'fontsize',11);
        end
        
        % ======================================================================
        %> @brief Clears the primary axes.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function clearPrimaryAxes(this)
            if(~isempty(intersect(get(this.handles.axes_primary,'nextplot'),{'replacechildren','replace'})))
                currentChildren = get(this.handles.axes_primary,'children');
                %                 set(currentChildren,'visible','off');
                currentYLimMode = get(this.handles.axes_primary,'ylimmode');
                currentXLimMode = get(this.handles.axes_primary,'xlimmode');
                currentNextPlot = get(this.handles.axes_primary,'nextplot');
                
                set(this.handles.axes_primary,'xlimmode','manual');
                set(this.handles.axes_primary,'ylimmode','manual');
                set(this.handles.axes_primary,'nextplot','replacechildren');
                
                delete(currentChildren);
                title(this.handles.axes_primary,'');
                ylabel(this.handles.axes_primary,'');
                xlabel(this.handles.axes_primary,'');
                
                set(this.handles.axes_primary,'ylimmode',currentYLimMode);
                set(this.handles.axes_primary,'xlimmode',currentXLimMode);
                set(this.handles.axes_primary,'nextplot',currentNextPlot);
            end
        end
        
        % ======================================================================
        %> @brief Clears the secondary axes.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function clearSecondaryAxes(this)
            cla(this.handles.axes_secondary);
            title(this.handles.axes_secondary,'');
            ylabel(this.handles.axes_secondary,'');
            xlabel(this.handles.axes_secondary,'');
            set(this.handles.axes_secondary,'xgrid','off','ygrid','off','xtick',[],'ytick',[]);
        end
        
        % ======================================================================
        %> @brief Updates the plot according to gui settings.  The method
        %> is assigned as the callback function to most of the gui widgets,
        %> but can called from the instance object anytime a refresh is desired.
        %> @param this Instance of PAStatTool
        %> @param varargin Handle of callback parent and associated event
        %> data.  Neither are used, but required by MATLAB gui callbacks
        % ======================================================================
        function refreshPlot(this,varargin)
            if(this.canPlot)
                
                pSettings = this.getPlotSettings();
                
                switch(pSettings.plotType)
                    case 'clustering' % typically this is not reached because the clustering class is handled in switch2clustering method
                        this.plotClusters(pSettings);
                        this.enableClusterRecalculation();
                    otherwise
                        
                        this.showBusy();
                        this.clearPlots();
                        this.calcFeatureStruct();
                        if(~isempty(this.featureStruct))
                            pSettings.ylabelstr = sprintf('%s of %s %s activity',pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
                            pSettings.xlabelstr = 'Days of Week';
                            
                            this.plotSelection(pSettings);
                        else
                            warndlg(sprintf('Could not find %s',inputFilename));
                        end
                end
                this.showReady();
            else
                fprintf('PAStatTool.m cannot plot (refreshPlot)\n');
            end
        end
        
        function fullFilename = getFullClusterCacheFilename(this)
            fullFilename = fullfile(this.cacheDirectory,this.RESULTS_CACHE_FILENAME);
        end
        
        % ======================================================================
        %> @brief Checks if a cluster object member (instance of
        %> PACluster) exists and converged.
        %> @param this Instance of PAStatTool
        %> @retval isValid (boolean) True if a cluster object (instance of
        %> PACluster) exists and converged; False otherwise
        % ======================================================================
        function isValid = hasValidCluster(this)
            isValid = ~(isempty(this.clusterObj) || this.clusterObj.failedToConverge());
        end
        
        function didSet = setIcon(this, iconFilename)
            if(nargin>1 && exist(iconFilename,'file'))
                this.iconFilename = iconFilename;
                [icoData, icoMap] = imread(iconFilename);
                didSet = this.setIconData(icoData,icoMap);
            else
                didSet = false;
            end
        end
        
        function didSet = setOutcomesTable(this, outcomesController)
            didSet = false;
            if(isa(outcomesController,'PAOutcomesTableData'))
                this.outcomesObj = outcomesController;
                % refresh it ...
                this.setUseOutcomesTable(this.getSetting('useOutcomes'));
            end
        end
        
        function selectNonwear(this)
            [validNonwearOptions, nonwearOptions] = this.getValidNonwearOptions();        
            currentSelections = this.getSetting('discardMethod');
            selections = nonwearDlg(validNonwearOptions, currentSelections);
            selections = validNonwearOptions(selections);
                       
            % Was something selected and (if so) was it different from the original selection
            if ~isempty(selections) && ~isequal(sort(currentSelections), sort(selections))
                this.setSetting('discardMethod', selections);
                this.nonwearRequiresUpdate = true;
                this.enableClusterRecalculation();            
            end            
        end
        
        function [validNonwearOptions, nonwearOptions] = getValidNonwearOptions(this)
            
            nonwearOptions = this.settings.discardMethod.categories(:);
            validOptions = false(size(nonwearOptions));
            for n=1:numel(nonwearOptions)
                option = nonwearOptions{n};
                if isfield(this.nonwear, option) && ~isempty(this.nonwear.(option))
                    if ~strcmpi(this.nonwear.(option).filename, 'none')
                        validOptions(n) = true;
                    end
                end
            end
            validNonwearOptions = nonwearOptions(validOptions);
        end
        
    end
    
    methods(Access=private)
        % Methods are interfacing with membershape lines of a cluster.
        %> @brief Selected membershape's contextmenu callback for drawing
        %> all membershapes associated with the ID.
        function showSelectedMemberShapesCallback(this, ~,~)
            lineH = get(this.figureH,'currentObject');
            memberID = get(lineH,'userdata');
            [memberLoadShapes, memberLoadShapeDayOfWeek, memberClusterInd, memberClusterShapes] = this.clusterObj.getMemberShapesForID(memberID);
            
            nextPlot = get(this.handles.axes_primary,'nextplot');
            set(this.handles.axes_primary,'nextplot','add');
            if(size(memberLoadShapes,2)==1)
                fields = {'marker','markeredgecolor','linestyle'};
                lineProps = get(lineH,fields);
                x = get(lineH,'xdata');
                lineStruct = cell2struct(lineProps',fields);
                plot(this.handles.axes_primary,x,memberLoadShapes,lineStruct);
            else
                plot(this.handles.axes_primary,memberLoadShapes','--','linewidth',1,'color', this.COLOR_MEMBERID);
            end
            
            set(this.handles.axes_primary,'nextplot',nextPlot);
            this.setStatus('%d selected',get(lineH,'userdata'));
            
            %            msgbox(sprintf('Member ID: %u',memberID));
        end
        
        %> @brief Selected membershape's line selection callback for when a user clicks
        %> on the line handle with the mouse.
        %> @param Instance of PAStatTool
        %> @param Handle to the line
        %> @param Event data (not used)
        %> @param Numeric identifier for the member shape (i.e. of the
        %> subject, or subjectID it is associated with).
        function memberLineButtonDownCallback(this,lineH,~, memberID)
            ax = get(lineH,'parent');
            if(strcmpi(get(lineH,'selected'),'off'))
                set(findobj(get(ax,'children'),'flat','selected','on'),'selected','off','color',this.COLOR_MEMBERSHAPE,'linewidth',1);
                set(lineH,'selected','on','color',this.COLOR_LINESELECTION,'linewidth',1.5,'displayname',num2str(get(lineH,'userdata')));
                this.setStatus('%d selected',get(lineH,'userdata'));
                legend(ax,lineH);
                
                % Toggle off
            else
                set(lineH,'selected','off','color',this.COLOR_MEMBERSHAPE);
                this.clearStatus();
                legend(ax,'off');
            end
        end
        
        function didSet = setIconData(this, iconData, iconCMap)
            if(nargin==3)
                didSet = true;
                this.hasIcon = true;
                this.iconData = iconData;
                this.iconCMap = iconCMap;
            else
                didSet = false;
            end
            
        end
        
        %> @brief Database functionality
        function didSet = setUseDatabase(this, willSet)
            if(nargin>1)
                this.useDatabase = willSet && true;
                % Convoluted way of doing this, but it works out, see
                % initDatabaseObj below ... which shows that the database
                % object is actually cleared if not to be used.
                this.useDatabase = this.initDatabaseObj();% initDatabase returns false if it fails to initialize and is supposed to.
                if(this.canUseDatabase())
                    this.initProfileTable();
                end
                didSet = true;
                this.refreshAnalysisFigureAvailability();
            else
                didSet = false;
            end
        end
        
        %> @brief Database functionality
        function didSet = setUseOutcomesTable(this, willSet)
            if nargin>1 && ~isempty(willSet)
                this.useOutcomes = willSet && true;
                if(this.useOutcomes && isa(this.outcomesObj,'PAOutcomesTableData') && this.outcomesObj.isValid)
                    this.profileFields = this.outcomesObj.getColumnNames('subjects');
                    this.initProfileTable(this.outcomesObj.getSelectedIndex());
                end
                didSet = true;
                this.refreshAnalysisFigureAvailability();
                
            else
                didSet = false;
            end
        end
        function doesIt = supportsAnalysisFigure(this)
            doesIt = (this.useOutcomes && ~isempty(this.profileTableData)) || ...
                (~isempty(this.profileFields) && this.useDatabase);
        end
        
        function refreshAnalysisFigureAvailability(this)
            if(this.supportsAnalysisFigure())
                visibility = 'on';
            else
                visibility = 'off';
            end
            % this.logStatus('Analysis figure availability: %s',visibility);
            set(this.toolbarH.cluster.toggle_analysisFigure,'visible',visibility);
        end
        
        function hasIt = hasProfileData(this)
            hasIt = ~isempty(this.profileFields) && ~isempty(this.profileTableData);
        end
        
        function didInit = initDatabaseObj(this)
            didInit = false;
            try
                if(this.useDatabase)
                    databaseValue = this.getSetting('databaseClass');
                    this.databaseObj = feval(databaseValue);
                    %this.databaseObj = feval(this.originalSettings.databaseClass.value);
                    
                    if isunix
                        this.profileFields = this.databaseObj.getColumnNames('subjectinfo_t');
                    else
                        this.profileFields = this.databaseObj.getColumnNames('subjectInfo_t');    
                    end
                    
                    didInit = true;
                else
                    this.databaseObj = [];
                    this.profileFields = {};
                end
            catch me
                showME(me);
                this.databaseObj = [];
                this.useDatabase = false;
                this.profileFields = {};
            end
            
        end
        
        % ======================================================================
        %> @brief Plot dropdown selection menu callback.
        %> @param this Instance of PAStatTool
        %> @param Handle of the dropdown menu.
        %> @param unused
        % ======================================================================
        function plotSelectionChangeCb(this, varargin)
            plotType = this.getPlotType();
            this.setPlotType(plotType);
        end
        function refreshPlotType(this)
            forceSet = true;
            this.setPlotType(this.getPlotType(),forceSet);
        end
        
        function setPlotType(this, plotType, forceSet)
            if(nargin<3 || isempty(forceSet))
                forceSet = false;
            end
            if(~isempty(plotType) && (~isequal(plotType, this.previousState.plotType) || forceSet))
                this.clearPlots();
                set(this.handles.menu_plottype,'tooltipstring',this.base.tooltipstring.(plotType));
                
                switch(plotType)
                    case 'clustering'
                        this.switch2clustering();
                    otherwise
                        if(strcmpi(this.previousState.plotType,'clustering'))
                            this.switchFromClustering();
                        else
                            set(this.handles.axes_secondary,'visible','off');
                            this.refreshPlot();
                        end
                end
                this.previousState.plotType = plotType;
            end
        end
        
        % ======================================================================
        %> @brief Window key press callback for cluster view changes
        %> @param this Instance of PAStatTool
        %> @param figH Handle to the callback figure
        %> @param eventdata Struct of key press parameters.  Fields include
        % ======================================================================
        function mainFigureKeyPressFcn(this,figH,eventdata)
            key=eventdata.Key;
            if(any(strcmpi('shift',eventdata.Modifier)))
                toggleOn = true;
            else
                toggleOn = false;
            end
            switch(key)
                case 'rightarrow'
                    set(this.toolbarH.cluster.push_right,'enable','off');
                    this.showNextCluster(toggleOn);
                    pause(0.1);
                    set(this.toolbarH.cluster.push_right,'enable','on');
                    drawnow();
                case 'leftarrow'
                    set(this.toolbarH.cluster.push_left,'enable','off');
                    this.showPreviousCluster(toggleOn);
                    pause(0.1);
                    set(this.toolbarH.cluster.push_left,'enable','on');
                    drawnow();
                case 'uparrow'
                    if(figH == this.analysisFigureH)
                        this.decreaseProfileFieldSelection();
                    elseif(figH == this.figureH)
                        this.showNextCluster(toggleOn);
                    end
                case 'downarrow'
                    if(figH == this.analysisFigureH)
                        this.increaseProfileFieldSelection();
                    elseif(figH == this.figureH)
                        this.showPreviousCluster(toggleOn);
                    end
                otherwise
            end
        end
        
        % ======================================================================
        %> @brief Mouse button callback when clicking on the cluster
        %> day-of-week distribution histogram. Clicking on this will add/remove
        %> the selected day of the week from the plot
        %> @param this Instance of PAStatTool
        %> @param hObject Handle to the bar graph.
        %> @param eventdata Struct of 'hit' even data.
        % ======================================================================
        function clusterDayOfWeekHistogramButtonDownFcn(this,histogramH,eventdata, overlayingPatchHandles)
            xHit = eventdata.IntersectionPoint(1);
            barWidth = 1;  % histogramH.BarWidth is 0.8 by default, but leaves 0.2 of ambiguity between adjancent bars.
            xStartStop = [histogramH.XData(:)-barWidth/2, histogramH.XData(:)+barWidth/2];
            selectedBarIndex = find( xStartStop(:,1)<xHit & xStartStop(:,2)>xHit ,1);
            selectedDayOfInterest = selectedBarIndex-1;
            this.clusterObj.toggleDayOfInterestOrder(selectedDayOfInterest);
            
            daysOfInterest = this.clusterObj.getDaysOfInterest();
            if(daysOfInterest(selectedBarIndex))
                set(overlayingPatchHandles(selectedBarIndex),'visible','off');
            else
                set(overlayingPatchHandles(selectedBarIndex),'visible','on');
            end
            this.plotClusters();
        end
        
        % ======================================================================
        %> @brief Mouse button callback when clicking on the cluster
        %> distribution histogram.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle to the bar graph.
        %> @param eventdata Struct of 'hit' even data.
        % ======================================================================
        function clusterHistogramButtonDownFcn(this,histogramH,eventdata)
            xHit = eventdata.IntersectionPoint(1);
            barWidth = 1;  % histogramH.BarWidth is 0.8 by default, but leaves 0.2 of ambiguity between adjancent bars.
            xStartStop = [histogramH.XData(:)-barWidth/2, histogramH.XData(:)+barWidth/2];
            selectedBarIndex = find( xStartStop(:,1)<xHit & xStartStop(:,2)>xHit ,1);
            this.toggleHistogramSelection(selectedBarIndex);
        end
        
        % ======================================================================
        %> @brief Mouse button callback when clicking a patch overlay of the cluster histogram.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle to the patch overlay.
        %> @param eventdata Struct of 'hit' even data.
        %> @param coiSortOrder - Index of the patch being clicked on.
        % ======================================================================
        function clusterHistogramPatchButtonDownFcn(this,hObject,eventData,coiSortOrder)
            this.toggleHistogramSelection(coiSortOrder);
        end
        
        % ======================================================================
        %> @brief Mouse button callback when clicking on a scatter plot entry.
        %> @param this Instance of PAStatTool
        %> @param lineH Handle to the scatterplot line.
        %> @param eventData Struct of 'hit' even data.
        % ======================================================================
        function scatterplotButtonDownFcn(this,lineH,eventData) %#ok<*INUSL>
            xHit = eventData.IntersectionPoint(1);
            selectedSortOrder = round(xHit);
            this.toggleHistogramSelection(selectedSortOrder);
        end
        
        % ======================================================================
        %> @brief Mouse button callback when clicking on a highlighted member (coi)
        %> of the cluster-profile scatter plot.
        %> @param this Instance of PAStatTool
        %> @param lineH Handle to the scatterplot line.
        %> @param eventData Struct of 'hit' even data.
        % ======================================================================
        function scatterPlotCOIButtonDownFcn(this,lineH,eventData)
            xHit = eventData.IntersectionPoint(1);
            coiSortOrder = round(xHit);
            this.toggleHistogramSelection(coiSortOrder);
        end
        
        function toggleHistogramSelection(this, selectedIndex)
            if(~this.holdPlots() && strcmpi(get(this.figureH,'selectiontype'),'normal'))
                this.clusterObj.setCOISortOrder(selectedIndex);
            else
                this.clusterObj.toggleCOISortOrder(selectedIndex);
            end
            this.plotClusters();
        end
        
        function buttondownfcn(this, hobject, evtdata) %#ok<*INUSD>
            this.logStatus('Button %s', get(hobject,'tag'));
        end
        
        function distributionChangeCb(this, hObject, evtData)
            newH = evtData.NewValue;
            cdata = get(newH,'userdata');
            this.setClusterDistributionType(cdata.label);
            this.plotClusters();
        end
        
        function initRefreshClusterButton(this,enableState)
            if(nargin<2 || ~strcmpi(enableState,'off'))
                enableState = 'on';
            end
            fgColor = get(0,'FactoryuicontrolForegroundColor');
            defaultBackgroundColor = get(0,'FactoryuicontrolBackgroundColor');
            set(this.handles.push_refreshClusters,'callback',@this.refreshClustersAndPlotCb,...
                'enable',enableState,'string','Recalculate',...
                'backgroundcolor',defaultBackgroundColor,...
                'foregroundcolor',fgColor,...
                'fontweight','normal',...
                'fontsize',12);
        end
        
        % ======================================================================
        %> @brief Configure gui handles for non cluster/clusting viewing
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switchFromClustering(this)
            % set(this.handles.check_normalizevalues,'value',this.previousState.normalizeValues,'enable','on');
            disableHandles(this.handles.panel_clusterSettings);
            this.hideClusterControls();
            
            set(this.figureH,'WindowKeyPressFcn',[]);
            set(this.analysisFigureH,'visible','off');
            
            this.refreshPlot();
        end
        
        % ======================================================================
        %> @brief Configure gui handles for cluster analysis and viewing.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switch2clustering(this)
            
            this.previousState.normalizeValues = get(this.handles.check_normalizevalues,'value');
            % set(this.handles.check_normalizevalues,'value',1,'enable','off');
            set(this.handles.axes_primary,'ydir','normal');  %sometimes this gets changed by the heatmap displays which have the time shown in reverse on the y-axis
            
            this.showClusterControls();
            
            if(this.getCanPlot())
                if(this.hasValidCluster())
                    try
                        this.featureStruct = this.clusterObj.featureStruct;
                    catch me
                        showME(me);
                    end
                    % Need this because we will skip our x tick and
                    % labels refresh otherwise.
                    this.drawClusterXTicksAndLabels();
                    
                    this.enableClusterControls();
                    
                    this.plotClusters();
                else
                    % this.disableClusterControls()                    
                    % this.refreshClustersAndPlot();
                    this.enableClusterControls();                    
                end
                
                set(findall(this.handles.panel_clusterSettings,'-property','enable'),'enable','on');
                
                if(this.hasValidCluster())
                    validColor = [1 1 1];
                    keyPressFcn = @this.mainFigureKeyPressFcn;
                else
                    validColor = [0.75 0.75 0.75];
                    keyPressFcn = [];
                end
                
                
                % This is handled in the plot cluster method, right before tick marks are down on
                % set(this.handles.axes_primary,'color',validColor);
                set(this.handles.axes_secondary,'color',validColor);
                set([this.handles.axes_secondary
                    this.handles.btngrp_clusters],'visible','on');
                
                set(this.figureH,'WindowKeyPressFcn',keyPressFcn);
                
                if(this.shouldShowAnalysisFigure())
                    set(this.analysisFigureH,'visible','on');
                end
            else
                set(this.handles.panel_clusterInfo,'visible','off');
            end
        end
        
        
        function decreaseProfileFieldSelection(this)
            curProfileFieldIndex = this.getProfileFieldIndex();
            this.setProfileFieldIndex(curProfileFieldIndex-1);
        end
        
        function increaseProfileFieldSelection(this)
            curProfileFieldIndex = this.getProfileFieldIndex();
            this.setProfileFieldIndex(curProfileFieldIndex+1);
        end
        
        
        function setClusterDistributionType(this, distType)
            if(~ismember(distType,this.DISTRIBUTION_TYPES))
                distType = 'loadshape_membership';
            end
            if(~strcmpi(distType,this.getSetting('clusterDistributionType')))
                oldH = this.buttongroup.cluster.(this.getSetting('clusterDistributionType'));
                cdata = get(oldH,'userdata');
                set(oldH,'cdata',cdata.Off,'value',0);
            end
            
            this.setSetting('clusterDistributionType', distType);
            newH = this.buttongroup.cluster.(distType);
            cdata = get(newH,'userdata');
            set(newH,'cdata',cdata.On,'value',1);
        end
        %> @brief Software driven callback trigger for
        %> profileFieldMnenuSelectionChangeCallback.  Used as a wrapper for
        %> handling non-menu_ySelection menu changes to the profile field
        %> index (e.g. using up or down arrow keys).
        %> @param this Instance of PAStatTool
        %> @param profileFieldIndex
        function didSet = setProfileFieldIndex(this, profileFieldIndex)
            selections = get(this.handles.menu_ySelection,'string');
            if(iscell(selections) && profileFieldIndex > 0 && profileFieldIndex <= numel(selections))
                set(this.handles.menu_ySelection,'value',profileFieldIndex);
                this.notify('ProfileFieldSelectionChange_Event',EventData_ProfileFieldSelectionChange(selections{profileFieldIndex},profileFieldIndex));
                didSet = true;
            else
                didSet = false;
            end
        end
        
        
        %> @brief Callback for the profile selection menu widget found in
        %> the analysis figure.  Results in changing the scatter plot and
        %> highlighting the newly selected field of interest in the
        %> cluster profile table.
        %> @param this Instance of PAStatTool
        %> @param hObject
        %> @param eventData
        function profileFieldMenuSelectionChangeCallback(this,hObject,eventData)
            this.setProfileFieldIndex(get(hObject,'value'));
        end
        
        function profileField = getProfileFieldSelection(this)
            profileField = getMenuString(this.handles.menu_ySelection);
        end
        
        function shouldShow = shouldShowAnalysisFigure(this)
            shouldShow = strcmpi(get(this.toolbarH.cluster.toggle_analysisFigure,'state'),'on');
        end
        
    end
    
    methods(Access=protected)
        
        
        % Called from constructor.
        function didInit = initFigure(this)
            
            this.initBase();
            

            
            didInit = initFigure@PAViewController(this); % calls: obj.designateHandles(); obj.initWidgets();  obj.initCallbacks();
            if(didInit)
                try
                    set([this.handles.panel_results
                        this.handles.panel_shapeSettings
                        this.handles.panel_clusterSettings],'units','pixels');
                    
                    this.initToolbar();
                    
                    % initializeOnSet = false;
                    % this.setWidgetSettings(this.settings, initializeOnSet);
                    this.initScatterPlotFigure();
                    
                    % Create property/event listeners
                    this.addlistener('ProfileFieldSelectionChange_Event',@this.profileFieldSelectionChangeCallback);
                    addlistener(this.handles.check_segment,'Value','PostSet',@this.checkSegmentPropertyChgCallback);
                    addlistener(this.handles.menu_number_of_data_segments,'Enable','PostSet',@this.checkSegmentPropertyChgCallback);
                    
                    % Profile Summary and analysis figure
                    this.setUseDatabase(this.getSetting('useDatabase'));  %sets this.useDatabase to false if it was initially true and then fails to open the database
                    this.setUseOutcomesTable(this.getSetting('useOutcomes'));
                    
                    % Now handled inside of the calls to setUseDatabase and
                    % setUseOutcomesTable()
                    % if(this.useDatabase || this.useOutcomes)
                    %    this.initProfileTable();
                    % end
                    
                    % update our text handle so it has the same background
                    % colors as the figure.
                    figColor = get(this.figureH,'color');
                    set(this.handles.text_clusterResultsOverlay,'backgroundcolor',figColor);
                    didInit = true;
                catch me
                    this.logError(me);
                    didInit = false;
                end
            end
        end
        
        function designateHandles(this)
            this.designateHandles@PAViewController();
            
            this.handles.panels_sansClusters = [
                this.handles.panel_shapeSettings
                ];
            
            this.handles.result_widgets_selection = [
                this.handles.check_normalizevalues
                this.handles.menu_feature
                this.handles.menu_signalsource
                this.handles.menu_plottype
                this.handles.menu_weekdays
                this.handles.menu_clusterMethod
                this.handles.menu_clusterStartTime
                this.handles.menu_clusterStopTime
                this.handles.menu_duration
                this.handles.push_refreshClusters
                this.handles.check_trim
                this.handles.edit_trimToPercent
                this.handles.check_cull
                this.handles.check_discardNonwear
                this.handles.edit_cullToValue
                this.handles.check_segment
                this.handles.menu_precluster_reduction
                this.handles.menu_number_of_data_segments];
        end
        
        
        function enablePrimaryContextMenus(this)
            set(this.handles.axes_primary,'uicontextmenu', this.handles.contextmenu.primaryAxes.uicontextmenu);
        end
        
        function disablePrimaryContextMenus(this)
            set(this.handles.axes_primary,'uicontextmenu', []);
        end
        
        function enableSecondaryContextMenus(this)
            set(this.handles.axes_secondary,'uicontextmenu', this.handles.contextmenu.secondaryAxes.uicontextmenu);
        end
        
        function disableSecondaryContextMenus(this)
            set(this.handles.axes_secondary,'uicontextmenu', []);
        end
        
        function didInit = initCallbacks(this)
            
            didInit = false;
            %% set callbacks
            if(ishandle(this.figureH))
                
                set(this.handles.btngrp_clusters,'SelectionChangedFcn',@this.distributionChangeCb);
                
                set(this.handles.menu_weekdays,'callback',@this.menuWeekdaysCallback);
                set(this.handles.menu_number_of_data_segments, 'callback',@this.updateNumChunksCb);

                
                set([
                    this.handles.menu_feature;
                    this.handles.menu_signalsource;
                    ],'callback',@this.refreshPlot);
                
                set([
                    this.handles.check_normalizevalues;
                    this.handles.menu_precluster_reduction;                    
                    this.handles.menu_clusterMethod;
                    this.handles.check_segment
                    this.handles.menu_clusterStartTime
                     this.handles.menu_clusterStopTime
                    this.handles.edit_minClusters
                    this.handles.edit_clusterConvergenceThreshold
                    this.handles.menu_duration],'callback',@this.enableClusterRecalculation);
                
                % Delete commented code after 2/22/2022
                %                 set([this.handles.menu_clusterStartTime
                %                      this.handles.menu_clusterStopTime
                %                     this.handles.edit_minClusters
                %                     this.handles.edit_clusterConvergenceThreshold
                %                     this.handles.menu_duration
                %                     ],'callback',@this.enableClusterRecalculation);
                
                set(this.handles.menu_plottype,'callback',@this.plotSelectionChangeCb);
                
                set(this.handles.check_trim,'callback',@this.checkTrimCallback);
                set(this.handles.edit_trimToPercent,'callback',@this.editTrimToPercentChange);
                
                set(this.handles.check_cull,'callback',@this.checkCullCallback);
                set(this.handles.edit_cullToValue,'callback',@this.editCullToValueChange);                
                
                % Push buttons
                % this should not normally be enabled if plotType
                % is not clusters.  However, this will be
                % taken care of by the enable/disabling of the
                % parent cluster panel based on the menu selection
                % change callback which is called after initWidgets
                % in the constructor.
                this.initRefreshClusterButton('off');
                
                drawnow();

                
                % add a context menu now to figureH in order to use with cluster load
                % shape line handles.
                this.handles.contextmenu.clusterLineMember = uicontextmenu('parent',this.figureH);
                uimenu(this.handles.contextmenu.clusterLineMember,'Label','Show all from this subject',...
                    'callback',@this.showSelectedMemberShapesCallback);
                
                % add a context menu now to primary axes
                contextmenu_primaryAxes = uicontextmenu('parent',this.figureH);
                this.handles.contextmenu.primaryAxes = struct('uicontextmenu', contextmenu_primaryAxes);
                
                horizontalGridMenu = uimenu(contextmenu_primaryAxes,'Label','Horizontal grid','callback',@this.primaryAxesHorizontalGridContextmenuCallback);
                this.handles.contextmenu.horizontalGridLines.on = uimenu(horizontalGridMenu,'Label','On','callback',{@this.primaryAxesHorizontalGridCallback,'on'});
                this.handles.contextmenu.horizontalGridLines.off = uimenu(horizontalGridMenu,'Label','Off','callback',{@this.primaryAxesHorizontalGridCallback,'off'});
                
                axesScalingMenu = uimenu(contextmenu_primaryAxes,'Label','y-Axis scaling','callback',@this.primaryAxesScalingContextmenuCallback);
                this.handles.contextmenu.axesYLimMode.auto = uimenu(axesScalingMenu,'Label','Auto','callback',{@this.primaryAxesScalingCallback,'auto'});
                this.handles.contextmenu.axesYLimMode.manual = uimenu(axesScalingMenu,'Label','Hold','callback',{@this.primaryAxesScalingCallback,'manual'});
                this.handles.contextmenu.axesYLimMode.manual = uimenu(axesScalingMenu,'Label','User Set','callback',{@this.primaryAxesScalingCallback,'user'});
                
                nextPlotmenu = uimenu(contextmenu_primaryAxes,'Label','Next plot','callback',@this.primaryAxesNextPlotContextmenuCallback);
                this.handles.contextmenu.nextPlot.add = uimenu(nextPlotmenu,'Label','Add','callback',{@this.primaryAxesNextPlotCallback,'add'});
                this.handles.contextmenu.nextPlot.replace = uimenu(nextPlotmenu,'Label','Replace','callback',{@this.primaryAxesNextPlotCallback,'replace'});
                this.handles.contextmenu.nextPlot.replacechildren = uimenu(nextPlotmenu,'Label','Replace children','callback',{@this.primaryAxesNextPlotCallback,'replacechildren'});
                
                % create a context menu now for the secondary axes
                contextmenu_secondaryAxes = uicontextmenu('callback',@this.contextmenu_secondaryAxesCallback,'parent',this.figureH);
                this.handles.contextmenu.secondaryAxes.uicontextmenu = contextmenu_secondaryAxes;
                this.handles.contextmenu.secondaryAxes.loadshape_membership = uimenu(contextmenu_secondaryAxes,'Label','Loadshapes per cluster','callback',{@this.clusterDistributionCb,'loadshape_membership'});
                this.handles.contextmenu.secondaryAxes.participant_membership = uimenu(contextmenu_secondaryAxes,'Label','Participants per cluster','callback',{@this.clusterDistributionCb,'participant_membership'});
                this.handles.contextmenu.secondaryAxes.nonwear_membership = uimenu(contextmenu_secondaryAxes,'Label','Nonwear per cluster','callback',{@this.clusterDistributionCb,'nonwear_membership'});
                this.handles.contextmenu.secondaryAxes.weekday_scores = uimenu(contextmenu_secondaryAxes,'Label','Weekday scores by cluster','callback',{@this.clusterDistributionCb,'weekday_scores'},'separator','on');
                this.handles.contextmenu.secondaryAxes.performance_progression = uimenu(contextmenu_secondaryAxes,'Label','Adaptive separation performance progression','callback',{@this.clusterDistributionCb,'performance_progression'},'separator','on');
                this.handles.contextmenu.secondaryAxes.weekday_membership = uimenu(contextmenu_secondaryAxes,'Label','Current cluster''s weekday distribution','callback',{@this.clusterDistributionCb,'weekday_membership'});
                
                this.handles.contextmenu.secondaryAxes.performance_progression = uimenu(contextmenu_secondaryAxes,'Label','Summary','callback',@this.clusterSummaryCb,'separator','on');
                
                didInit = true;
            end
        end
        
        % ======================================================================
        %> @brief Initialize gui handles using input parameter or default
        %> parameters.  Does not initalize callbacks (see initCallbacks)
        %> @param this Instance of PAStatTool
        %> @param widgetSettings GUI setting parameters (optional).  If
        %> this is not included or is empty, then the default parameters are
        %> used to initialize the gui (See getDefaults).
        % ======================================================================
        function didInit = initWidgets(this, widgetSettings)
            if(nargin>1)
                this.logError([],'settings are not used in initialization!');
            end
            
            try
                btnProps = {'loadshape_membership','Loadshapes per cluster'
                    'participant_membership','Participants per cluster'
                    'nonwear_membership','Nonwear per cluster'
                    'weekday_scores','Weekday scores by cluster'
                    'weekday_membership','Current cluster''s weekday distribution'
                    'performance_progression','Adaptive separation performance progression'
                    };
                
                this.buttongroup.cluster = struct();
                for row=1:size(btnProps,1)
                    label = btnProps{row,1};
                    tip = btnProps{row,2};
                    tag = ['toggle_',label];
                    h = this.handles.(tag);
                    cdata.Off = get(h,'cdata');
                    cdata.On = max(cdata.Off-0.2,0);
                    cdata.On(isnan(cdata.Off)) = nan;
                    cdata.label = label;
                    set(h,'tooltipstring',tip,'userdata',cdata);
                    this.buttongroup.cluster.(label) = h;
                    
                    if row==1
                        % Select the first item to be the SelectedObject
                        % for this.handles.btngrp_clusters
                        set(h,'value',1);
                    end
                end
                
                set(this.handles.edit_clusterConvergenceThreshold,...
                    'string', num2str(this.getSetting('clusterThreshold')),...
                    'tooltipstring','Hint: Enter ''inf'' to fix the number of clusters to the min value');
                
                set(this.handles.menu_duration,'value', this.getSetting('clusterDurationSelection')); 
                
                % Cluster settings
                set(this.handles.edit_minClusters,'string', num2str(this.getSetting('minClusters')));                
                
                set(this.handles.result_widgets_selection,'units','normalized'); % had been : 'points',...
                
                set(this.handles.check_discardNonwear,'min',0,'max',1,'value', this.getSetting('discardNonwearFeatures'));
                set(this.handles.check_segment,'min',0,'max',1,'value', this.getSetting('chunkShapes'));
                set(this.handles.check_trim,'min',0,'max',1,'value', this.getSetting('trimResults'));
                set(this.handles.check_cull,'min',0,'max',1,'value', this.getSetting('cullResults'));
                set(this.handles.check_normalizevalues,'min',0,'max',1,'value', this.getSetting('normalizeValues'));
                
                
                set(this.handles.menu_signalsource,'string',this.base.signalDescriptions,'userdata',this.base.signalTypes);
                set(this.handles.menu_plottype,'userdata',this.base.plotTypes,'string',this.base.plotTypeDescriptions);
                
                % Cluster widgets
                set(this.handles.menu_precluster_reduction,'string',this.base.preclusterReductionDescriptions,'userdata',this.base.preclusterReductions);
                if isunix
                   cur_pos = get(this.handles.menu_precluster_reduction,'position'); 
                   wider_pos = cur_pos+[0 0 cur_pos(3) 0]*0.5; % 50% wider
                   set(this.handles.menu_precluster_reduction, 'position', wider_pos);
                end
                set(this.handles.menu_number_of_data_segments,'string',this.base.numDataSegmentsDescriptions,'userdata',this.base.numDataSegments);
                
                set(this.handles.menu_weekdays,'string',this.base.weekdayDescriptions,'userdata',this.base.weekdayTags);
                set(this.handles.menu_duration,'string',this.base.clusterDurationDescriptions);
                
                didInit = true;
            catch me
                showME(me);
                didInit = false;
            end
        end
        
        function enable(obj)
            obj.setEnableState('on');
        end
        
        function disable(obj)
            obj.setEnableState('off');
        end
        
        % Enable state should be 'on','off', or empty (defaults to 'off').
        function setEnableState(obj, enableState)
            
            if(strcmpi( enableState, 'on') &&  obj.isClusterMode())
                obj.enableClusterControls();
            else
                obj.disableClusterControls();
            end
        end
        
        % ======================================================================
        %> @brief Shows busy state: Disables all non-cluster panel widgets
        %> and mouse pointer becomes a watch.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function showBusy(this)
            set(findall(this.handles.panels_sansClusters,'enable','on'),'enable','off');
            % For some reason, this does not catch them all the first time
            set(findall(this.handles.panels_sansClusters,'enable','on'),'enable','off');
            showBusy@PAViewController(this);
        end
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status: enables all non cluster panels and mouse becomes the default arrow pointer.
        %> @param obj Instance of PAStatTool
        % --------------------------------------------------------------------
        function showReady(this, varargin)
            set(findall(this.handles.panels_sansClusters,'enable','off'),'enable','on');
            % for some reason, this does not catch them all the first time
            set(findall(this.handles.panels_sansClusters,'enable','off'),'enable','on');
            
            showReady@PAViewController(this, varargin{:});
        end
        
        
        %         function bgColorClickOnCb(this, hToggle, e)
        %             % curState = get(hToggle,'state');
        %             this.setStatus(e.EventName);
        %         end
        %         function bgColorClickOffCb(this, hToggle, e)
        %             % curState = get(hToggle,'state');
        %             this.setStatus(e.EventName);
        %         end
        
        function showBg = isBgColorDisplayOn(this)
            showBg = istoggled(this.toolbarH.cluster.toggle_backgroundColor);
            
        end
        
        % Called by something that wants a refreshed plot.  If it is done
        % the settings from the plotClusters call are pulled from the user
        % interface, so this is a good generic call for many purposes.
        function plotCb(this, varargin)
            this.plotClusters();
        end
        
        function updateNumChunksCb(this, hObject, varargin)            
            curTag = getMenuString(hObject);            
            if(strcmpi(curTag,'custom'))
                curValue = getMenuUserData(hObject);
                prompt='Enter the number of chunks to split the selected time frame into:';
                name='Custom number of chunks';
                numlines=1;
                defaultanswer={num2str(curValue)};
                answer=inputdlg(prompt,name,numlines,defaultanswer);
                answerValue = round(str2double(answer{1}));
                if isnan(answerValue)
                    this.logWarning('Custom value cannot be ''%s''.  Using 1 instead', answer{1});
                    set(hObject, 'value', 1);                    
                else
                    userData = get(hObject, 'userdata');
                    userData(end) = answerValue;
                    set(hObject, 'userdata', userData)
                end
                
            end
            this.enableClusterRecalculation();
        end
        
        % ======================================================================
        %> @brief Callback to enable the push_refreshClusters button.  The button's
        %> background color is switched to green to highlight the change and need
        %> for recalculation.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function enableClusterRecalculation(this,varargin)
            %             bgColor = 'green';
            
            % Set a variable to keep track that new calculation is needed,
            % or just check current settings versus last settings when it
            % is time to actually calculate again...
            if ~isempty(this.figureH) && this.isClusterMode()
                % bgColor = [0.2 0.8 0.1];
                % fgColor = [ 0 0 0];
                
                fgColor = get(0,'FactoryuicontrolForegroundColor');
                bgColor = get(0,'FactoryuicontrolBackgroundColor');
                
                set(this.handles.push_refreshClusters,'enable','on',...
                    'backgroundcolor',bgColor,'string','Recalculate',...
                    'foregroundcolor',fgColor,...
                    'fontweight','bold',...
                    'fontsize',13,...
                    'callback',@this.refreshClustersAndPlotCb);
            else
                
            end
        end
        
        function enableClusterCancellation(this, varargin)
            bgColor = [0.8 0.2 0.1];
            %             fgColor = get(0,'FactoryuicontrolForegroundColor');
            %             bgColor = get(0,'FactoryuicontrolBackgroundColor');
            %             fgColor = [0.94 0.94 0.94 ];
            fgColor = [1 1 1];
            
            set(this.handles.push_refreshClusters,'enable','on',...
                'fontsize',12,'fontweight','bold',...
                'backgroundcolor',bgColor,'string','Cancel',...
                'foregroundcolor',fgColor,...
                'callback',@this.cancelClustersCalculationCallback);
        end
        
        function cancelClustersCalculationCallback(this,hObject,eventdata)
            %             bgColor = [0.6 0.4 0.3];
            bgColor = [0.6 0.1 0.1];
            set(this.handles.push_refreshClusters,'enable','off','callback',[],...
                'backgroundcolor',bgColor,'string','Cancelling',...
                'fontsize',12,'fontweight','normal');
            this.notify('UserCancel_Event');
            
            cobj = this.getClusterObj();
            if(~isempty(cobj))
                this.setStatus('Cancelling calcuations');
                cobj.cancelCalculations();
                this.clearStatus();
            else
                this.logStatus('No cluster object exists to cancel');
            end
        end
        

        function menuWeekdaysCallback(this, hObject, eventData)
            curTag = getMenuUserData(hObject);
            curValue = get(hObject,'value');
            if(strcmpi(curTag,'custom'))
                listString = this.base.daysOfWeekDescriptions(:);
                listSize = [200, 100];
                customIndex = strcmpi(this.base.weekdayTags,'custom');
                initialValue = this.base.weekdayValues{customIndex}+1;
                name = 'Custom selection';
                
                promptString = 'Select day(s) of week to use in clustering';
                selectionMode = 'multiple';
                
                [selection, okayChecked] = listdlg('liststring',listString,...
                    'name',name,'promptString',promptString,...
                    'listSize',listSize,...
                    'initialValue',initialValue,'selectionMode',selectionMode);
                
                if(okayChecked && ~isempty(selection) && ~isequal(selection,initialValue))
                    this.base.weekdayValues{customIndex} = selection-1;  %return to 0 based indexing for day of week fields.
                    this.previousState.weekdaySelection = curValue;
                    set(hObject,'tooltipstring',cell2str(listString(selection)));
                    this.enableClusterRecalculation();
                else
                    set(hObject,'value',this.previousState.weekdaySelection);
                end
            else
                this.previousState.weekdaySelection = curValue;
                set(hObject,'tooltipstring','');
                this.enableClusterRecalculation();
            end
        end
        
        function analysisFigurePlotHistogramCb(this, hObject,eventData)
            %  this.setTimedStatus(5,'Plotting!');
            cs = this.clusterObj.getCovariateStruct();
            pData = this.getProfileData(cs.memberIDs,this.getProfileFieldSelection());
            fname = fieldnames(pData);
            figName = 'Covariate distribution';
            f = findobj(0,'name',figName);
            if(isempty(f))
                f = figure('name',figName,'visible','off','numbertitle','off','menubar','none','toolbar','none');
            else
                f = f(1);
            end
            figure(f); % make it current;
            numPlots = numel(fname);
            numBins = 100;
            for p=1:numPlots()
                subplot(numPlots,1,p);
                field = fname{p};
                hist(pData.(field), numBins);                 %#ok<*HIST>
                fieldLabel = strrep(field,'_',' ');
                ylabel('Subjects (n)');
                title(fieldLabel);
                xlabel(fieldLabel)
            end
            
            set(f,'visible','on');
        end
        
        function plotClusterMembershipVsCovariate(self)
            
        end
        
        function analyzeClustersCallback(this, hObject,eventData)
            % Get my cluster Object
            % Take in all of the clusters, or the ones selected
            % Apply to see how well it splits the data...
            % Requires: addpath('/users/unknown/Google Drive/work/Stanford - Pediatrics/code/models');
            initString = get(hObject,'string');
            
            % modelSelections = {'Membership Proportion','Proportion+isWeekend','Daily','Daily+isWeekend'};
            % userdata =        {'model_1a',              'model_1aw',            'model_1b','model_1bw'};
            userdata =          {'model_1',              'model_2',            'model_2_w'};

            modelSelection = getMenuUserData(this.handles.menu_model);
            try
                set(hObject,'enable','off','String','Analyzing ...');
                dependentVar = this.getProfileFieldSelection();
                
                %                'bmi_zscore'
                %                'bmi_zscore+'  %for logistic regression modeling
                %
                % --all--
                covariateStruct = this.clusterObj.getCovariateStruct();
                covariateStruct.id.memberIDs = covariateStruct.memberIDs;
                
                % current selection
                coiSortOrders = this.clusterObj.getAllCOISortOrders();
                
                ANALYZE_ALL_CLUSTERS = any(strcmpi(modelSelection, userdata));
                if ANALYZE_ALL_CLUSTERS
                    if numel(coiSortOrders)>1
                        coiSortOrders = coiSortOrders(1);
                    end
                    if any(strcmpi(modelSelection,{'model_2','model_2_w'})) % binary approach and binary approach with weekednd (2w)
                        varnames = covariateStruct.id.varnames(2:end);
                        colnames = covariateStruct.id.colnames(2:end);
                        covariateStruct = covariateStruct.loadshape;
                        covariateStruct.memberIDs = covariateStruct.id;
                        clusters = covariateStruct.cluster';
                        clusters = clusters(:, 2:end);
                        
                        if strcmpi(modelSelection, 'model_2')
                            isWeekendCluster = repmat(covariateStruct.weekend, 1, size(clusters, 2));
                            weekendClusters = clusters.*isWeekendCluster;
                            covariateStruct.values = [clusters, weekendClusters];
                            
                            weekendVarnames = cellfun(@(c) ['w', c], varnames, 'uniformoutput',false);
                            weekendColnames = cellfun(@(c) ['w', c], colnames, 'uniformoutput',false);
                            
                            covariateStruct.colnames = [colnames, weekendColnames];
                            covariateStruct.varnames = [varnames, weekendVarnames];
                        else
                            covariateStruct.values = clusters;
                            covariateStruct.colnames = colnames;
                            covariateStruct.varnames = varnames;
                        end
                        % covariateStruct.values = covariateStruct.values(:, 2:end);
                    elseif any(strcmpi(modelSelection,{'model_1'}))
                        covariateStruct = covariateStruct.id;
                        
                        % Normalize values
                        values = covariateStruct.values;
                        covariateStruct.values = diag(sum(values,2))*values;
                    end
                else
                    covariateStruct = covariateStruct.id;
                    % Analyze selections of clusters versus the remaining clusters.
                    if numel(coiSortOrders)>1
                        
                        % If we have multiple elements selected then group
                        % together and add as an extra element to the other
                        % group.
                        nonCoiInd = true(size(covariateStruct.colnames));
                        nonCoiInd(coiSortOrders) = false;
                        coiColname = {cell2str(covariateStruct.colnames(coiSortOrders),' AND ')};
                        coiVarname = {cell2str(covariateStruct.varnames(coiSortOrders),'_AND_')};
                        coiOccurrences =  sum(covariateStruct.values(:,coiSortOrders),2); %sum across each row
                        
                        covariateStruct.values = [covariateStruct.values(:,nonCoiInd), coiOccurrences];
                        covariateStruct.colnames = [covariateStruct.colnames(nonCoiInd), coiColname];
                        covariateStruct.varnames = [covariateStruct.varnames(nonCoiInd), coiVarname];
                        coiSortOrders = numel(covariateStruct.varnames);
                        %                    covariateStruct = this.clusterObj.getCovariateStruct(coiSortOrders);
                        %                    covariateStruct.colnames = {cell2str(covariateStruct.colnames,' AND ')};
                        %                    covariateStruct.varnames = {cell2str(covariateStruct.varnames,'_AND_')};
                        %                    covariateStruct.values = sum(covariateStruct.values,2); %sum each row
                    end
                end 
                
                % Normalize values
                % values = covariateStruct.values;
                % covariateStruct.values = diag(sum(values,2))*values;
                % [resultStr, resultStruct] = gee_model(covariateStruct,dependentVar,{'age'; '(sex=1) as male'});
                

                %covariateStruct = this.clusterObj.getCovariateStruct();
                
                include_age_and_gender = false;
                if include_age_and_gender
                    covariates = {'age'; '(sex=1) as male'};
                else
                    covariates = {};
                end

                %                 if ANALYZE_ALL_CLUSTERS
                %                     [resultStr, resultStruct, mdl, dataSet] = gee_model(covariateStruct,dependentVar,covariates, coiSortOrders);
                %                     % dataSet = [id,Y,time,X];
                %                     % fprintf(1,'\nResults from <strong>%s</strong>.\n', modelSelection);
                %                 else
                %                     [resultStr, resultStruct] = gee_model(covariateStruct,dependentVar,covariates, coiSortOrders);
                %                 end
                %                [resultStr, resultStruct] = gee_model(this.clusterObj.getCovariateStruct(this.clusterObj.getCOISortOrder()),dependentVar,{'age'; '(sex=1) as male'});
                [resultStr, resultStruct, mdl, dataSet] = gee_model(covariateStruct,dependentVar,covariates, coiSortOrders);   

                label = sprintf('Results for <strong>%s</strong> (%s)', getModelDescription(modelSelection), modelSelection);
                fprintf(1, '%s\n', label);
                featureName = sprintf('%s_%s', this.featureStruct.method, this.featureStruct.signal.name);
                results = struct(dependentVar, struct(featureName, struct('summary_string', resultStr,'struct', resultStruct,...
                    'model',mdl, 'data', dataSet)));
                displayResults(results);
                
                showMsgBox = false;
                if showMsgBox && ~isempty(resultStr)
                    if(this.hasIcon)
                        CreateStruct.WindowStyle='replace';
                        CreateStruct.Interpreter='tex';
                        resultStr = strrep(resultStr,'_',' ');
                        resultStr = strrep(resultStr,'B=','\beta = ');
                        msgbox(sprintf('%s',resultStr),resultStruct.covariateName,'custom',this.iconData,this.iconCMap,CreateStruct);
                    else
                        msgbox(resultStr,resultStruct.covariateName);
                    end
                end
                
                % Show a plot of the number of times the same person was in a cluster vs the outcome
                PLOT_SUMMARY = false;
                if PLOT_SUMMARY
                    [~,~, dependentVarStruct] = this.databaseObj.getSubjectInfoSummary(covariateStruct.memberIDs, dependentVar);
                    dependentVarValues = dependentVarStruct.(dependentVar);
                    for c=1:numel(coiSortOrders)
                        dependentVar(1) = upper(dependentVar(1));
                        coi = coiSortOrders(c);
                        titleStr = sprintf('Cluster #%d occurrences vs %s', coi, dependentVar);
                        f = figure('name', titleStr);
                        coiOccurrences = covariateStruct.values(:, coi);
                        maxDaysConsidered = max(coiOccurrences);
                        x = 0:maxDaysConsidered;
                        y = nan(size(x));
                        num_subjects = zeros(size(x));
                        for d = 1:numel(x)
                            days = x(d);
                            occurrences_idx = coiOccurrences==days;
                            num_subjects(d) = sum(occurrences_idx);  % the number of unique contributors here who had 'days' occurrences for the current cluster of interest (coi)
                            value = dependentVarValues(occurrences_idx);
                            if ~isempty(value)
                                y(d) = mean(value);
                            end
                        end
                        a= axes('parent',f);
                        plot(a, x, y, 'marker','o');
                        ylabel(a, dependentVar, 'interpreter', 'none');
                        max(y)
                        xlabel(a, 'Number of days a subject was in this cluster (with number of unique subjects)');
                        xticklabels = sprintf('%d (%d)\n', [x; num_subjects]);
                        set(a,'xlim', [min(x), max(x)], 'xtick', x, 'xticklabel', xticklabels);
                        title(a, titleStr, 'interpreter', 'none');
                        set(a, 'ygrid', 'on')
                    end
                end
                
            catch me
                set(hObject,'string','Error!');
                showME(me);
                pause(1);
            end
            set(hObject,'enable','on','string',initString);
        end
        
        function exportTableResultsCallback(this, hObject,eventData)
            tableData = get(this.handles.table_clusterProfiles,'data');
            copy2workspace(tableData,'clusterProfilesTable');
        end
        
        function showAnalysisFigure(this)
            this.setAnalysisFigureVisibility('on');
        end
        function hideAnalysisFigure(this)
            this.setAnalysisFigureVisibility('off');
        end
        
        function setAnalysisFigureVisibility(this, onOrOff)
            set(this.toolbarH.cluster.toggle_analysisFigure,'state',onOrOff);
            set(this.analysisFigureH,'visible',onOrOff);
        end
        
        function hideAnalysisFigureCb(this,varargin)
            this.hideAnalysisFigure();
        end
        function toggleAnalysisFigureCb(this, varargin)
            if(this.shouldShowAnalysisFigure())
                this.showAnalysisFigure();
            else
                this.hideAnalysisFigure();
            end
        end
        
        function primaryAxesHorizontalGridContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');
            set(this.handles.contextmenu.horizontalGridLines.(get(this.handles.axes_primary,'ygrid')),'checked','on');
        end
        
        function primaryAxesHorizontalGridCallback(this,hObject,~,gridState)
            this.setPrimaryAxesHorizontalGrid(gridState);
        end
        function setPrimaryAxesHorizontalGrid(this, gridState)
            if(~isempty(intersect(lower(gridState),{'on','off'})))
                this.setSetting('primaryAxis_horizontalGrid', gridState);
                set(this.handles.axes_primary,'ygrid',gridState);
            end
        end
        
        % This is a parent contextmenu callback which updates check marks
        % for submenus
        function primaryAxesScalingContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');
            set(this.handles.contextmenu.axesYLimMode.(get(this.handles.axes_primary,'ylimmode')),'checked','on');
        end
        
        function setPrimaryAxesYMode(this, yScalingMode)
            if strcmpi(yScalingMode, 'user')
                y_limits = ylim(this.handles.axes_primary);
                prompt={'Enter y-min:','Enter y-max:'};
                name='Set y-axis limits';
                numlines=1;
                defaultanswer={num2str(y_limits(1)),num2str(y_limits(2))};
                options.Resize='on';
                options.WindowStyle='normal';
                options.Interpreter='tex';
                answer=inputdlg(prompt,name,numlines,defaultanswer, options);
                if ~isempty(answer)
                    y_min = str2double(answer{1});
                    y_max = str2double(answer{2});
                    try
                        set(this.handles.axes_primary,'ylim',[y_min, y_max], 'ylimmode','manual',...
                            'ytickmode','auto',...
                            'yticklabelmode','auto');
                        this.plotClusters();
                    catch me
                        showME(me);
                    end
                    
                end
            else
                
                set(this.handles.axes_primary,'ylimmode',yScalingMode,...
                    'ytickmode',yScalingMode,...
                    'yticklabelmode',yScalingMode);
                
                this.setSetting('primaryAxis_yLimMode', yScalingMode);
                if(strcmpi(yScalingMode,'auto'))
                    this.plotClusters();
                else
                    %manual selection means do not auto adjust
                end
            end
        end
        
        function primaryAxesScalingCallback(this,hObject,~,yScalingMode)
            this.setPrimaryAxesYMode(yScalingMode);
        end
        
        function toggleBackgroundColorCb(this, hObject, ~)
            this.setTimeOfDayAsBackgroundColor(istoggled(hObject));
        end
        
        function setTimeOfDayAsBackgroundColor(this, shouldSet)
            narginchk(2,2);
            this.setSetting('showTimeOfDayAsBackgroundColor', shouldSet);
            this.plotClusters();
        end
        
        %> @brief A 'checked' "Hold y-axis" checkbox infers 'manual'
        %> yllimmode for the primary (upper) axis.  An unchecked box
        %> indicates auto-scaling for the y-axis.
        function togglePrimaryAxesYCb(this,hObject,~)
            % Is it checked?
            isManual =  istoggled(hObject);
            if(isManual)
                yScalingMode = 'manual';
            else
                yScalingMode = 'auto';
            end
            this.setPrimaryAxesYMode(yScalingMode);
        end
        
        function primaryAxesNextPlotContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');
            set(this.handles.contextmenu.nextPlot.(get(this.handles.axes_primary,'nextplot')),'checked','on');
        end
        
        function setNextPlotBehavior(this, nextPlot)
            set(this.handles.axes_primary,'nextplot',nextPlot);
            this.setSetting('primaryAxis_nextPlot', nextPlot);
        end
        
        function primaryAxesNextPlotCallback(this,hObject,~,nextPlot)
            this.setNextPlotBehavior(nextPlot);
        end
        
        function checkHoldPlotsCb(this,hObject,~)
            % Is it checked?
            if(istoggled(hObject))
                nextPlot = 'add';
            else
                nextPlot = 'replaceChildren';
            end
            this.setNextPlotBehavior(nextPlot);
        end
        
        function contextmenu_secondaryAxesCallback(this,varargin)
            % This may be easier to maintain ...
            contextMenus = this.handles.contextmenu.secondaryAxes;
            if(isfield(contextMenus,'nextPlot'))
                contextMenus = rmfield(contextMenus,'nextPlot');
            end
            
            %Not sure how this one got in here.  @hyatt 4/27/2020
            if(isfield(contextMenus,'uicontextmenu'))
                contextMenus = rmfield(contextMenus,'uicontextmenu');
            end
            
            set(struct2array(contextMenus),'checked','off');
            set(contextMenus.(this.getSetting('clusterDistributionType')),'checked','on');
            
            % Than this
            %             set([this.handles.contextmenu.performance
            %                 this.handles.contextmenu.weekday
            %                 this.handles.contextmenu.membership
            %                 this.handles.contextmenu.profile],'checked','off');
            %             set(this.handles.contextmenu.(this.getSetting('clusterDistributionType')),'checked','on');
        end
        
        function clusterSummaryCb(this,hObject,eventdata)
            
            clusterDistributionType = this.getSetting('clusterDistributionType');
            [y, memberIds] = this.clusterObj.getHistogram(clusterDistributionType);
            fprintf('Summarizing %s in order of cluster popularity:\n\n',clusterDistributionType);
            for k=1:numel(y)
                n = y(k);
                if n==0
                    fprintf('Cluster %d has %d IDs.\n', k, n);
                elseif n==1
                    fprintf('Cluster %d has %d ID:\n', k, n);
                else
                    fprintf('Cluster %d has %d IDs:\n', k, n);
                end
                disp(memberIds{k});
            end
        end
        
        function clusterDistributionCb(this,hObject,eventdata,selection)
            this.setClusterDistributionType(selection);
            this.plotClusters();
        end
        
        function refreshScatterPlot(this)
            displayStrings = get(this.handles.line_coiInScatterPlot,'displayname');
            
            this.initScatterPlotAxes();
            
            figSource = 'unset';
            if(this.useDatabase)
                figSource = 'MySQL';
            elseif(this.useOutcomes)
                figSource = 'Outcome .txt files';
            end
            set(this.analysisFigureH,'name',sprintf('Cluster Analysis (%s)',figSource));
            
            if(~isempty(this.clusterObj))
                numClusters = this.clusterObj.getNumClusters();  %or numel(globalStruct.colnames).
                sortOrders = find( this.clusterObj.getCOIToggleOrder() );
                curProfileFieldIndex = this.getProfileFieldIndex();
                % get the current profile's ('curProfileIndex' row) mean ('2' column) for all clusters
                % (':').
                x = 1:numClusters;
                y = this.allProfiles(curProfileFieldIndex, 2, :);  % rows (1) =
                y = y(this.clusterObj.popularity2index());
                
                % columns (2) =
                % dimension (3) = cluster popularity (1 to least popular index)
                
                globalMean = repmat(this.profileTableData{curProfileFieldIndex,5},size(x));
                profileSEM = this.profileTableData{curProfileFieldIndex,6};
                upper95 = globalMean+1.96*profileSEM;
                lower95 = globalMean-1.96*profileSEM;
                
                set(this.handles.line_allScatterPlot,'xdata',x(:),'ydata',y(:));
                set(this.handles.line_meanScatterPlot,'xdata',x(:),'ydata',globalMean(:));
                set(this.handles.line_upper95PctScatterPlot,'xdata',x(:),'ydata',upper95(:));
                set(this.handles.line_lower95PctScatterPlot,'xdata',x(:),'ydata',lower95(:));
                
                % The sort order indices will not change on a refresh like
                % this, but the y values at these indices will; so update them
                % here.
                %             coiSortOrders = get(this.handles.line_coiInScatterPlot,'xdata');
                %             set(this.handles.line_coiInScatterPlot,'ydata',y(coiSortOrders));
                
                set(this.handles.line_coiInScatterPlot,'xdata',sortOrders,'ydata',y(sortOrders));%,'displayName','blah');
                if(isempty(displayStrings))
                    legend(this.handles.axes_scatterplot,'off');
                else
                    legend(this.handles.axes_scatterplot,this.handles.line_coiInScatterPlot,displayStrings,'location','southwest');
                end
            end
        end
        
        % only extract the handles we are interested in using for the stat tool.
        % ======================================================================
        %> @brief Initialize the analysis figure, which holds the scatter
        %> plot axes and the profile table containing subject information
        %> contained in subjects grouped together by the current cluster of
        %> interest.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initScatterPlotFigure(this)
            this.analysisFigureH = clusterAnalysisFig('visible','off',...
                'name','Cluster Analysis',...
                'WindowKeyPressFcn',@this.mainFigureKeyPressFcn,...
                'CloseRequestFcn',@this.hideAnalysisFigureCb);
            
            % Create handle place holders and initialize
            this.initHandles();
            
            % Initialize the scatter plot axes
            this.initScatterPlotAxes();
            modelSelections = {'Membership Proportion','Daily (binary)','Daily (binary) +isWeekend'};
            userdata = {'model_1','model_2','model_2_w'};
            set(this.handles.menu_model,'string',modelSelections, 'userdata',userdata);
            set(this.handles.push_plotHistogram,'string','Histogram','callback',@this.analysisFigurePlotHistogramCb);
            set(this.handles.push_analyzeClusters,'string','Analyze Selection','callback',@this.analyzeClustersCallback);
            set(this.handles.push_exportTable,'string','Export Table','callback',@this.exportTableResultsCallback);
            set(this.handles.text_analysisTitle,'string','','fontsize',12);
            %             set(this.toolbarH.cluster.toggle_analysisFigure,'visible','on');
        end
        
        % Creates an empty table (cell) with column and row names for the profile data associated with studies being analyzed
        function [tableData, rowNames, columnNames] = createProfileTable(this, profileFieldSelection)
            % intialize the cluster profile table
            columnNames = {'n','mx','sem','n (global)','mx (global)','sem (global)'};
            rowNames = this.profileFields;
            numRows = numel(rowNames);
            tableData = cell(numRows,numel(columnNames));
            this.profileTableData = tableData;  %array2table(tableData,'VariableNames',profileColumnNames,'RowNames',rowNames);
            
            % intialize the cluster profile table
            if(nargin<2 || isempty(profileFieldSelection))
                profileFieldSelection = this.getSetting('profileFieldSelection');
            end
            
            if isempty(profileFieldSelection) || profileFieldSelection>numel(this.profileFields)
                profileFieldSelection = 1;
            end
            
            set(this.handles.menu_ySelection,'string',this.profileFields,'value',profileFieldSelection,'callback',@this.profileFieldMenuSelectionChangeCallback);
            
            numRows = numel(rowNames);
            backgroundColor = repmat([1 1 1; 0.94 0.94 0.94],ceil(numRows/2),1); % possibly have one extra if numRows is odd.
            backgroundColor = backgroundColor(1:numRows,:);  %make sure we only get as many rows as we actually have.
            userData.defaultBackgroundColor = backgroundColor;
            userData.rowOfInterestBackgroundColor = [0.5 0.5 0.5];
            
            this.jhandles.table_clusterProfiles.setSelectionBackground(java.awt.Color(0.5,0.5,0.5));
            this.jhandles.table_clusterProfiles.setSelectionForeground(java.awt.Color(0.0,0.0,0.0));
            
            backgroundColor(profileFieldSelection,:) = userData.rowOfInterestBackgroundColor;
            
            % legend(this.handles.axes_scatterPlot,'off');
            
            
            % Could use the DefaultTableModel instead of the, otherwise,
            % DefaultUIStyleTableModel which does not provide the same
            % functionality (namely setRowData)
            %             this.jhandles.table_clusterProfiles.setModel(javax.swing.table.DefaultTableModel(tableData,profileColumnNames));
            
            %             curStack = dbstack;
            %             fprintf(1,'Skipping cluster profile table initialization on line %u of %s\n',curStack(1).line,curStack(1).file);
            set(this.handles.table_clusterProfiles,'rowName',rowNames,'columnName',columnNames,...
                'units','pixels','fontname','arial','fontsize',12,'fontunits','pixels','visible','on',...
                'backgroundColor',backgroundColor,'rowStriping','on',...
                'data',tableData,...
                'userdata',userData,'CellSelectionCallback',@this.analysisTableCellSelectionCallback);
            
        end
        
        % ======================================================================
        %>  @brief Initializes the row table and menu_ySelection menu
        %> handle which indicates the profile field selected by the user.
        %> The row corresponding to the selected profile field is highlighed
        %> by using a darker background color
        %> @param this Instance of PAStatTool
        %> @param profileFieldSelection Index of the profile field
        %> currently selected.  If not entered, it is set to '1', the first
        %> profile field available.
        % ======================================================================
        function initProfileTable(this, profileFieldSelection)
            this.createProfileTable();
            if nargin < 2 || isempty(profileFieldSelection)
                profileFieldSelection = 1;
            end
            
            % May or may not occur depending on state of cached values, but
            % if there are loaded table or database values, go ahead and
            % load these up now.
            if(this.refreshGlobalProfile())
                if(~this.refreshCOIProfile())
                    % this will clear it out to a blank table.
                    this.refreshProfileTableData();
                end
            end
            
            fitTableWidth(this.handles.table_clusterProfiles);
            this.setProfileFieldIndex(profileFieldSelection);
        end
        
        % ======================================================================
        %> @brief Initialize the scatter plot axes (of the analysis
        %> figure).
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initScatterPlotAxes(this)
            cla(this.handles.axes_scatterplot);
            set(this.handles.axes_scatterplot,'box','on');
            this.handles.line_coiInScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','r','linestyle','none','markerFaceColor','g','marker','o','markersize',6,'buttondownfcn',@this.scatterPlotCOIButtonDownFcn);
            this.handles.line_meanScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','b','linestyle','--');
            this.handles.line_upper95PctScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','b','linestyle',':');
            this.handles.line_lower95PctScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','b','linestyle',':');
            
            this.handles.line_allScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','k','linestyle','none','marker','.','buttondownfcn',@this.scatterplotButtonDownFcn);
            
            [~,profileFieldName] = this.getProfileFieldIndex();
            ylabel(this.handles.axes_scatterplot,profileFieldName,'interpreter','none');
            xlabel(this.handles.axes_scatterplot,'Cluster popularity');
            
            
            % REmove any existing contextmenus from previous
            % initializations
            delete(findobj(this.analysisFigureH,'type',{'uicontextmenu','uimenu'}))
            % add a context menu now to primary axes
            contextmenu_ScatterPlotAxes = uicontextmenu('parent',this.analysisFigureH);
            this.handles.contextmenu.toggleLegend = uimenu(contextmenu_ScatterPlotAxes,'Label','Toggle legend','callback',{@this.toggleLegendCallback,this.handles.axes_scatterplot});
            set(this.handles.axes_scatterplot,'uicontextmenu',contextmenu_ScatterPlotAxes);
        end
        
        
        function initToolbar(this)
            toolbarTags.cluster = {
                'toggle_backgroundColor'
                'toggle_holdPlots'
                'toggle_yLimit'
                'toggle_membership'
                'toggle_summary'
                'toggle_analysisFigure'
                'push_right'
                'push_left'
                };
            
            fnames = fieldnames(toolbarTags);
            this.toolbarH = mkstruct(fnames);
            for f=1:numel(fnames)
                fname = fnames{f};
                %                 this.toolbarH.(fname) = mkstruct(toolbarHandles.(fname));
                for h=1:numel(toolbarTags.(fname))
                    tagName = toolbarTags.(fname){h};
                    tH = this.handles.(tagName);
                    this.toolbarH.(fname).(tagName) = tH;
                    
                    if(isa(tH,'matlab.ui.container.toolbar.ToggleTool'))
                        cdata.Off = get(tH,'cdata');
                        cdata.On = max(cdata.Off-0.2,0);
                        cdata.On(isnan(cdata.Off)) = nan;
                        set(tH,'userdata',cdata,'oncallback',@this.toggleOnOffCb,'offcallback',@this.toggleOnOffCb,'state','Off');
                    end
                end
            end
            
            %             cdata.Off = get(this.toolbarH.cluster.toggle_membership,'cdata');
            %             cdata.On = cdata.Off;
            %             cdata.On(cdata.Off==1) = 0.7;
            %             set(this.toolbarH.cluster.toggle_membership,'userdata',cdata,'oncallback',@this.toggleOnOffCb,'offcallback',@this.toggleOnOffCb);
            %             sethandles(this.handles.toolbar_results,'handlevisibility','callback');
            %             set(this.toolbarH.cluster.toggle_backgroundColor,'handlevisibility','off');
            %             set(this.handles.toolbar_results,'handlevisibility','off');
            
            set(this.toolbarH.cluster.toggle_membership,'clickedcallback',@this.checkShowClusterMembershipCallback);
            set(this.toolbarH.cluster.toggle_summary,'clickedcallback',@this.plotCb);
            
            set(this.toolbarH.cluster.toggle_holdPlots,'clickedcallback',@this.checkHoldPlotsCb);
            set(this.toolbarH.cluster.toggle_yLimit,'clickedcallback',@this.togglePrimaryAxesYCb);
            set(this.toolbarH.cluster.toggle_analysisFigure,'clickedcallback',@this.toggleAnalysisFigureCb);
            set(this.toolbarH.cluster.toggle_backgroundColor,'ClickedCallback',@this.toggleBackgroundColorCb); %'OffCallback',@this.toggleBgColorCb,'OnCallback',@this.toggleBgColorCb);
            
            set(this.toolbarH.cluster.push_right,'clickedcallback',@this.showNextClusterCallback);
            set(this.toolbarH.cluster.push_left,'clickedcallback',@this.showPreviousClusterCallback);
            
            % Refactoring for toolbars
            offOnState = {'off','on'}; % 0 -> 'off', 1 -> 'on'  and then +1 to get matlab 1-based so that 1-> 'off' and 2-> 'on'
            
            set(this.toolbarH.cluster.toggle_holdPlots,'state',offOnState{this.holdPlots()+1});
            set(this.toolbarH.cluster.toggle_yLimit,'state',offOnState{strcmpi(this.getSetting('primaryAxis_yLimMode'),'manual')+1});
            
            % set(this.toolbarH.cluster.toggle_analysisFigure,'state',offOnState{this.getSetting('showAnalysisFigure')+1});
            this.hideAnalysisFigure();
            set(this.toolbarH.cluster.toggle_backgroundColor,'state',offOnState{this.getSetting('showTimeOfDayAsBackgroundColor')+1}); %'OffCallback',@this.toggleBgColorCb,'OnCallback',@this.toggleBgColorCb);
            
        end
        
        
        % only extract the handles we are interested in using for the stat tool.
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initHandles(this)
            % get handles of interest from our analysis figure
            tmpAnalysisHandles = guidata(this.analysisFigureH);
            analysisHandlesOfInterest = {
                'axes_scatterplot'
                'table_clusterProfiles'
                'menu_ySelection'
                'push_exportTable'
                'push_analyzeClusters'
                'push_plotHistogram'
                'panel_model'
                'menu_model'
                'text_analysisTitle'
                };
            
            for f=1:numel(analysisHandlesOfInterest)
                fname = analysisHandlesOfInterest{f};
                this.handles.(fname) = tmpAnalysisHandles.(fname);
            end
            
            %             h=uitable();
            %             hFig = ancestor(h,'figure');
            %             hFig = this.analysisFigureH;
            %             jFrame = get(hFig,'JavaFrame');
            %             mde = com.mathworks.mde.desk.MLDesktop.getInstance;
            %             figName = get(this.analysisFigureH,'name');
            %             jFig = mde.getClient(figName); %Get the underlying JAVA object of the figure.
            %             jFrame = jFig.getRootPane.getParent();
            
            % warning off MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
            warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');            
            jAnalysisFrame = get(this.analysisFigureH, 'JavaFrame');
            jAnalysisFigPanel = get(jAnalysisFrame,'FigurePanelContainer');
            %             this.jhandles.table_clusterProfiles=jFigPanel.getComponent(0).getComponent(0).getComponent(0).getComponent(0).getComponent(0);
            
            this.jhandles.table_clusterProfiles = javaObjectEDT(jAnalysisFigPanel.getComponent(0).getComponent(5).getComponent(0).getComponent(0).getComponent(0));
            scrollPane =        javaObjectEDT(jAnalysisFigPanel.getComponent(0).getComponent(5).getComponent(0));
            scrollPane.setVerticalScrollBarPolicy(scrollPane.VERTICAL_SCROLLBAR_AS_NEEDED);
            vPort =              jAnalysisFigPanel.getComponent(0).getComponent(5).getComponent(0).getComponent(0);
            jTable =             jAnalysisFigPanel.getComponent(0).getComponent(5).getComponent(0).getComponent(0).getComponent(0);
            verticalScrollPane = jAnalysisFigPanel.getComponent(0).getComponent(5).getComponent(0).getComponent(1);
            
            this.jhandles.scrollPane = scrollPane;
            this.jhandles.vPort = vPort;
            this.jhandles.verticalScrollPane = verticalScrollPane;
            this.jhandles.table = jTable;
            %             j.getUIClassID=='TableUI';
            
            %countComponents(jFigPanel.getComponent(0))
            %getName(this.jhandles.table_clusterProfiles)) -->
            %table_clusterProfiles
            
            %jStatToolFrame = get(this.figureH,'JavaFrame');
            %jStatToolFigPanel = get(jStatToolFrame,'FigurePanelContainer');
            
            % allocate line handle names here for organizational consistency
            this.handles.line_allScatterPlot = [];
            this.handles.line_coiInScatterPlot = [];
            this.handles.line_meanScatterPlot = [];
            this.handles.line_upper95PctScatterPlot = [];
            this.handles.line_lower95PctScatterPlot = [];
        end
        
        function toggleOnOffCb(this, toggleH, evtData)
            cdataStruct = get(toggleH,'userdata');
            set(toggleH,'cdata',cdataStruct.(evtData.EventName));
        end
        
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initBase(this)
            this.base = this.getBaseSettings();
        end
        
        % ======================================================================
        %> @brief Display a selection of results organized by day of the
        %> week.
        %> @param this Instance of PAStatTool
        %> @param plotOptions struct of options for how to plot
        %> featureStruct instance variable values.
        % ======================================================================
        function plotSelection(this,plotOptions)
            axesHandle = this.handles.axes_primary;
            daysofweek = this.featureStruct.startDaysOfWeek;
            
            % daysofweekStr = this.base.daysOfWeekShortDescriptions; %{'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekStr = this.base.daysOfWeekDescriptions; %{'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekOrder = this.base.daysOfWeekOrder; %1:7;
            features = this.featureStruct.shapes;  % this.featureStruct.features;
            divisionsPerDay = size(features,2);
            
            % Set this here to auto perchance it is not with our cluster
            % option.
            if(~strcmpi(plotOptions.primaryAxis_yLimMode,'auto'))
                set(axesHandle,'ylimmode','auto');
            end
            
            if(~strcmpi(plotOptions.primaryAxis_nextPlot,'replace'))
                set(axesHandle,'nextplot','replace');
            end
            
            switch(plotOptions.plotType)
                case {'clustering','quantile'}  % passthrough - the plotSelection is plots selections other than these in practice
                case 'dailyaverage'
                    imageMap = nan(7,1);
                    for dayofweek=0:6
                        dayofweekIndex = daysofweekOrder(dayofweek+1);
                        numSubjects = sum(dayofweek==daysofweek);
                        if(numSubjects==0)
                            imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));
                        else
                            imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1))/numSubjects;
                        end
                        daysofweekStr{dayofweekIndex} = sprintf('%s (n=%u)',daysofweekStr{dayofweekIndex},numSubjects);
                    end
                    
                    bar(axesHandle,imageMap);
                    weekdayticks = linspace(1,7,7);
                    
                case 'dailytally'
                    imageMap = nan(7,1);
                    for dayofweek=0:6
                        imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));
                        
                        dayofweekIndex = daysofweekOrder(dayofweek+1);
                        numSubjects = sum(dayofweek==daysofweek);
                        daysofweekStr{dayofweekIndex} = sprintf('%s (n=%u)',daysofweekStr{dayofweekIndex},numSubjects);
                    end
                    
                    bar(axesHandle,imageMap);
                    weekdayticks = linspace(1,7,7);
                    
                case 'morningheatmap'  %note: I use 24 to represent the first 6 hours of the morning (24 x 15 minute blocks = 6 hours)
                    imageMap = nan(7,24);
                    for dayofweek=0:6
                        imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,1:24),1);
                        numSubjects = sum(dayofweek==daysofweek);
                        if(numSubjects~=0)
                            imageMap(dayofweek+1,:) = imageMap(dayofweek+1,:)/numSubjects;
                        end
                    end
                    
                    imageMap=imageMap/max(imageMap(:));
                    imageMap = round(imageMap*plotOptions.numShades);
                    imagesc(imageMap','parent',axesHandle);
                    weekdayticks = 1:1:7; %linspace(0,6,7);
                    dailyDivisionTicks = 1:2:24;
                    set(axesHandle,'ytick',dailyDivisionTicks,'yticklabel',this.featureStruct.startTimes(1:2:24));
                    
                    
                case 'heatmap'
                    imageMap = nan(7,divisionsPerDay);
                    for dayofweek=0:6
                        imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
                        numSubjects = sum(dayofweek==daysofweek);
                        if(numSubjects~=0)
                            imageMap(dayofweek+1,:) = imageMap(dayofweek+1,:)/numSubjects;
                        end
                    end
                    
                    imageMap=imageMap/max(imageMap(:));
                    imageMap = round(imageMap*plotOptions.numShades);
                    imagesc(imageMap','parent',axesHandle);
                    weekdayticks = 1:1:7; %linspace(0,6,7);
                    dailyDivisionTicks = 1:8:this.featureStruct.totalCount;
                    set(axesHandle,'ytick',dailyDivisionTicks,'yticklabel',this.featureStruct.startTimes(1:8:end));
                    
                    
                case 'rolling'
                    imageMap = nan(7,divisionsPerDay);
                    for dayofweek=0:6
                        imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
                    end
                    %            imageMap=imageMap/max(imageMap(:));
                    rollingMap = imageMap';
                    plot(axesHandle,rollingMap(:));
                    weekdayticks = linspace(0,divisionsPerDay*6,7);
                    set(axesHandle,'ygrid','on');
                    
                case 'morningrolling'
                    imageMap = nan(7,24);
                    for dayofweek=0:6
                        imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,1:24),1);
                    end
                    %            imageMap=imageMap/max(imageMap(:));
                    rollingMap = imageMap';
                    plot(axesHandle,rollingMap(:));
                    weekdayticks = linspace(0,24*6,7);
                    set(axesHandle,'ygrid','on');
                    
                otherwise
                    disp Oops! Uknown plot type;
            end
            if isunix
                fontsize = 12;
            else
                fontsize = 14;
            end
            hT = title(axesHandle,plotOptions.titleStr,'fontsize',fontsize);%,'units','normalized','visible','off');
            
            xlimits = minmax(weekdayticks);
            
            if(strcmpi(plotOptions.plotType,'dailytally')||strcmpi(plotOptions.plotType,'dailyaverage'))
                xlimits = xlimits+[-1,1]*0.75;
            end
            set(axesHandle,'xtick',weekdayticks,'xticklabel',daysofweekStr,'xlim',xlimits);
        end
        
        
        % ======================================================================
        %> @brief Callback for trim percent change edit box
        %> @param this Instance of PAStatTool
        %> @param editHandle handle to edit box.
        %> @param eventdata (req'd by matlab, but unset)
        % ======================================================================
        function editTrimToPercentChange(this,editHandle,~)
            percent = str2double(get(editHandle,'string'));
            if(isempty(percent) || isnan(percent) || percent<=0 || percent>100)
                percent = 0;
                warndlg('Percent value should be in the range: (0, 100]');
            end
            set(editHandle,'string',num2str(percent));
            this.refreshPlot();
        end
        
        % ======================================================================
        %> @brief Check button callback for enabling/disbling load shape trimming.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle of the checkbutton that is calling back.
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function checkTrimCallback(this,hObject,~)
            if(get(hObject,'value'))
                enableState = 'on';
            else
                enableState = 'off';
            end
            set(this.handles.edit_trimToPercent,'enable',enableState);
            this.refreshPlot();
        end
        % ======================================================================
        %> @brief Callback for cull value change edit widget
        %> @param this Instance of PAStatTool
        %> @param editHandle handle to edit box.
        %> @param eventdata (req'd by matlab, but unset)
        % ======================================================================
        function editCullToValueChange(this,editHandle,~)
            value = str2double(get(editHandle,'string'));
            if(isempty(value) || isnan(value) || value<0)
                value = 0;
                warndlg('Cull value must be non-negative');
            end
            set(editHandle,'string',num2str(value));
            this.refreshPlot();
        end
        
        % ======================================================================
        %> @brief Check button callback for enabling/disbling load shape culling.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle of the checkbutton that is calling back.
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function checkCullCallback(this,hObject,~)
            if(get(hObject,'value'))
                enableState = 'on';
            else
                enableState = 'off';
            end
            set(this.handles.edit_cullToValue,'enable',enableState);
            this.refreshPlot();
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the next cluster.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function showNextClusterCallback(this, varargin)
            this.showNextCluster();
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the next cluster.
        %> @param this Instance of PAStatTool
        %> @param toggleOn Optional boolean:
        %> - @c true Results in increaseing the COI sort order, and all
        %> other toggle sort order indices are turned off. (default)
        %> - @c false Results in increaseing the COI sort order, and all
        %> other toggle sort indices are left as is.
        % ======================================================================
        function showNextCluster(this,toggleOn)
            if(nargin<2 || ~islogical(toggleOn))
                toggleOn = this.holdPlots(); %0/1
            end
            if(~isempty(this.clusterObj))
                if(toggleOn)
                    didChange = this.clusterObj.toggleOnNextCOI();
                else
                    didChange = this.clusterObj.increaseCOISortOrder();
                end
                if(didChange)
                    this.plotClusters();
                end
            end
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the previous cluster.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function showPreviousClusterCallback(this,varargin)
            this.showPreviousCluster();
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the next cluster.
        %> @param this Instance of PAStatTool
        %> @param toggleOn Optional boolean:
        %> - @c true Results in increaseing the COI sort order, and all
        %> other toggle sort order indices are turned off. (default)
        %> - @c false Results in increaseing the COI sort order, and all
        %> other toggle sort indices are left as is.
        % ======================================================================
        function showPreviousCluster(this,toggleOn)
            if(nargin<2 || ~islogical(toggleOn))
                toggleOn = this.holdPlots();
            end
            if(toggleOn)
                didChange = this.clusterObj.toggleOnPreviousCOI();
            else
                didChange = this.clusterObj.decreaseCOISortOrder();
            end
            % Don't refresh if there was no change.
            if(didChange)
                this.plotClusters();
            end
        end
        
        
        % ======================================================================
        %> @brief Check button callback to refresh cluster display.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        %> @note The ygrid is turned on or off here: on when show
        %> membership is checked, and off when it is unchecked.
        % ======================================================================
        function checkShowClusterMembershipCallback(this,hObject,varargin)
            this.plotClusters();
            % Is it checked?
            if(istoggled(hObject))
                set(this.handles.axes_primary,'ygrid','on');
                [~, uniqueIDs] = this.clusterObj.getClustersOfInterestMemberIDs();
                %disp(uniqueIDs);
            else
                set(this.handles.axes_primary,'ygrid','off');
            end
        end
        
    end
    
    methods
        
        %> @brief Creates a matlab struct with pertinent fields related to
        %> the current cluster and its calculation, and then saves the
        %> struct in a matlab binary (.mat) file.  Fields include
        %> - clusterObj (sans handle references)
        %> - featureStruct
        %> - originalFeatureStruct
        %> - usageStateStruct
        %> - featuresDirectory
        function didCache = cacheCluster(this)
            didCache = false;
            if(this.useCache)
                if(isdir(this.cacheDirectory) || mkdir(this.cacheDirectory))
                    try
                        tmpStruct.clusterObj = this.getClusterObj();
                        tmpStruct.clusterObj.removeHandleReferences();
                        tmpStruct.featureStruct = this.featureStruct;
                        tmpStruct.originalFeatureStruct = this.originalFeatureStruct;
                        tmpStruct.usageStateStruct = this.usageStateStruct;
                        tmpStruct.choiNonwearStruct = this.choiNonwearStruct;
                        tmpStruct.featuresDirectory = this.featuresDirectory;
                        tmpStruct.nonwear = this.nonwear;
                        fnames = fieldnames(tmpStruct);
                        save(this.getFullClusterCacheFilename(),'-mat','-struct','tmpStruct',fnames{:});
                        didCache = true;
                    catch me
                        showME(me);
                        didCache = false;
                    end
                end
            end
        end
        
        function featureStruct = getFeatureStruct(this)
            featureStruct = this.featureStruct;
        end
        
        function durHours=  getFeatureVecDurationInHours(this)
            [~,startEndDatenums] = this.getStartEndTimes();
            durHours = 24*diff(startEndDatenums);
            if(durHours==0)
                durHours = 24;
            elseif(durHours<0)
                durHours = durHours+24;
            end
        end
        
        function [startEndTimeStr, startEndDatenums] = getStartEndTimes(this)
            startEndTimeStr = {getMenuString(this.handles.menu_clusterStartTime);
                getMenuString(this.handles.menu_clusterStopTime)};
            startEndDatenums = datenum(startEndTimeStr);
        end
        
        function startTimes = getStartTimesCell(this)
            if(isfield(this.featureStruct,'startTimes'))
                startTimes = this.featureStruct.startTimes;
            else
                startTimes = {};
            end
        end
        
        
        function bootstrapCallback(this,varargin)
            
            bootSettings = struct();
            defaultSettings = struct();
            defaults  = this.getDefaults();
            for f=1:numel(this.bootstrapParamNames)
                pName = this.bootstrapParamNames{f};
                bootSettings.(pName) = this.(pName);
                defaultSettings.(pName) = defaults.(pName);
            end
            bootSettings = PASimpleSettings(bootSettings, defaultSettings);
            if(~isempty(bootSettings))
                % update the parameters for next time and for use in the
                % upcoming bootstrap call
                for f=1:numel(this.bootstrapParamNames)
                    pName = this.bootstrapParamNames{f};
                    this.(pName) = bootSettings.ouputStruct.(pName);
                end
                this.bootstrap();
            end
        end
        
        function bootstrap(this, numBootstraps)
            if(nargin<2)
                numBootstraps = this.bootstrapIterations;
            end
            % configure progress bar
            didCancel = false;
            function cbFcn(hObject,evtData)
                waitbar(1,h,'Cancelling ...');
                didCancel = true;
            end
            
            h = waitbar(0,'Preparing for bootstrap','CreateCancelBtn',@cbFcn);
            try
                
                % configure bootstrap
                
                paramNames = {'clusterCount','silhouetteIndex','calinskiIndex'};
                params = mkstruct(paramNames,nan(1,numBootstraps));
                
                bootstrapUsing = this.bootstrapSampleName; % 'studyID';  % or 'days'
                
                if(strcmpi(bootstrapUsing,'days'))
                    sample_size = numel(this.originalFeatureStruct.studyIDs);
                    boot_daysInd = randi(sample_size,[sample_size,numBootstraps]);
                else
                    sample_size = numel(this.originalFeatureStruct.uniqueIDs);
                    boot_studyInd = randi(sample_size,[sample_size,numBootstraps]);
                end
                
                allowUserCancel = false;
                startTime = now;
                for n=1:numBootstraps
                    
                    if(~didCancel && ishandle(h))
                        %featureStruct = this.StatTool.getFeatureStruct();
                        timeElapsedStr = getTimeElapsedStr(startTime);
                        msg = sprintf('Bootstrapping %d of %d  (%s)',n,numBootstraps,timeElapsedStr);
                        waitbar(n/numBootstraps,h,msg);
                        this.setStatus(msg);
                        if(strcmpi(bootstrapUsing,'days'))
                            ind2use = boot_daysInd(:,n);
                        else
                            studyInd2use = boot_studyInd(:,n);  % these are indices of the study IDs to use
                            indFirstLast = this.originalFeatureStruct.indFirstLast(studyInd2use,:);
                            daysPerStudy = indFirstLast(:,2)-indFirstLast(:,1)+1;
                            
                            numVectors = sum(daysPerStudy);
                            % numVectors = sum(diff(indFirstLast'))+size(indFirstLast,1);
                            
                            ind2use = nan(numVectors,1);
                            curVecInd = 1;
                            for row=1:size(indFirstLast,1)
                                
                                ind2use(curVecInd:curVecInd+daysPerStudy(row)-1) = indFirstLast(row,1):indFirstLast(row,2);
                                curVecInd = curVecInd+daysPerStudy(row);
                            end
                        end
                        if(this.refreshClustersAndPlot(allowUserCancel,ind2use))
                            for f=1:numel(paramNames)
                                pName = paramNames{f};
                                params.(pName)(n) = this.clusterObj.getParam(pName);
                            end
                        end
                        drawnow();
                    else
                        break;
                    end
                end
                
                % If you stop early, we still want results, I think.
                if(n>1)
                    if(ishandle(h))
                        delete(h);
                    end
                    
                    
                    CI = 95;  %i.e. we want the 95% confidence interval
                    CI_alpha = 100-CI;
                    CI_range = [CI_alpha/2, 100-CI_alpha/2];  %[2.5, 97.5]
                    
                    message = cell(numel(paramNames)+1,1);
                    message{1} = sprintf('95%% Confidence Interval(s) using\n\tbootstrap iterations = %i\n\tsample size = %i\nComputation Time: %s\n',n,sample_size,getTimeElapsedStr(startTime));
                    for f=1:numel(paramNames)
                        pName = paramNames{f};
                        values = params.(pName)(1:n);
                        param_CI_percentile = prctile(values,CI_range);
                        stdVal = std(values);
                        meanVal = mean(values);
                        stdCI = meanVal+stdVal*[-1.96, +1.96];
                        message{f+1} = sprintf('%s mean = %0.4f\tSD = %0.4f\tMean+/-1.96*SD = [%0.4f, %0.4f]\t95%% CI = [%0.4f, %0.4f]' ,pName,meanVal,stdVal, stdCI(1), stdCI(2),param_CI_percentile(1),param_CI_percentile(2));
                    end
                    
                    for m=1:numel(message)
                        fprintf(1,'%s\n',message{m});
                    end
                    
                    msgbox(message,'Bootstrap results');
                    %message{k+1} = [paramCell(k).label,' [ ',num2str(config_CI_percentile(1,k),decimal_format),', ',num2str(config_CI_percentile(2,k),decimal_format),']'];
                end
                
            catch me
                showME(me);
            end
            if(ishandle(h))
                delete(h);
            end
            this.clearStatus();
            %             if(ishandle(h))
            %                 waitbar(100,h,'Bootstrap complete');
            %             end
            
        end
        
        function refreshClustersAndPlotCb(this, varargin)
            try
                enableUserCancel = true;
                evaluateK = this.isEvaluateKSelection();
                this.refreshClustersAndPlot(enableUserCancel, evaluateK);
            catch me
                showME(me);
                errordlg(sprintf('An error occurred:\n%s', me.message));
                this.enable()
            end
            % Save settings ?
            % saveParams = this.getSaveParameters
            % cSettings = this.getClusterSettings();
        end
        
        function isIt = isEvaluateKSelection(this)
            isIt = get(this.handles.radio_evaluate_k, 'value');
        end
        
        function isIt = isClusterKSelection(this)
            isIt = get(this.handles.radio_cluster_k, 'value');
        end
        
        % ======================================================================
        %> @brief Push button callback for updating the clusters being displayed.
        %> @param this Instance of PAStatTool
        %> @param enableUserCancel Boolean flag indicating whether user cancel
        %> button is provided [True].
        %> @param evaluateK Evaluate optimal K using Tibshirani's prediction strength
        %> method instead clustering [False].
        %> @param Optional Indices of study IDs and shapes to use or string
        %> 'bootstrap' indicating a random configuration can be used.
        %> @note clusterObj is cleared at the beginning of this function.
        %> If it is empty after the function call, then the clustering
        %> failed.
        % ======================================================================
        function didConverge = refreshClustersAndPlot(this,enableUserCancel, evaluateK, varargin)
            didConverge = false;
            if nargin<3
                evaluateK = false;
            end
            
            if(nargin<2)
                enableUserCancel = true;
            end
            this.clearPrimaryAxes();
            this.showBusy();
            set(this.handles.panel_clusterInfo,'visible','off');
            pSettings= this.getPlotSettings();
            
            this.clusterObj = [];
            this.disable();
            this.disableWidgets();
            %this.disableClusterControls();  % disable further interaction with our cluster panel
            
            resultsTextH = this.handles.text_clusterResultsOverlay; % an alias
            % clear the analysis figure
            
            
            if(this.calcFeatureStruct(varargin{:}))
                % does not converge well if not normalized as we are no longer looking at the shape alone
                
                % @b weekdayTag String to identify how/if data should be
                % filtered according to when it was recorded during the week.
                % Values include
                % - @c all (default) Returns all recorded data (Sunday to
                % Saturday)
                % - @c weekdays Returns only data recorded on the weekdays (Monday
                % to Friday)
                % - @c weekends Returns data recored on the weekend
                % (Saturday-Sunday)
                weekdayIndex = strcmpi(this.base.weekdayTags,pSettings.weekdayTag);
                daysOfInterest = this.base.weekdayValues{weekdayIndex};
                
                %                 switch(pSettings.weekdayTag)
                %                     case 'weekdays'
                %                         daysOfInterest = 1:5;
                %                     case 'weekends'
                %                         daysOfInterest = [0,6];
                %                     case 'all'
                %                         daysOfInterest = [];
                %                     case 'custom'
                %                         daysOfInterest = getMenuUserData(this.handles.menu_weekdays);
                %                     otherwise
                %                         daysOfInterest = [];
                %                         %this is the default case with 'all'
                %                 end
                
                if(~isempty(daysOfInterest))
                    rowsOfInterest = ismember(this.featureStruct.startDaysOfWeek,daysOfInterest);
                    % fieldsOfInterest = {'startDatenums','startDaysOfWeek','shapes','features'};
                    fieldsOfInterest = {'startDaysOfWeek','features','studyIDs'};
                    for f=1:numel(fieldsOfInterest)
                        fname = fieldsOfInterest{f};
                        this.featureStruct.(fname) = this.featureStruct.(fname)(rowsOfInterest,:);
                    end
                    if this.isShowingWeekLong(pSettings)
                        % CAUTION - This works because we are guaranteed to
                        % have 7 days per study, and studies are in order
                        % at this point, as of 25APR2019.  However, a more
                        % complex rule and sorting approach may need to be
                        % employed if changes are made to the code above
                        % (@hyatt) % days may not be in order however.
                        for k=1:7:numel(this.featureStruct.studyIDs) % size(this.featureStruct.features,1)
                            curRange = k:k+6;
                            [~,sortInd] = sort(this.featureStruct.startDaysOfWeek(curRange),'ascend');
                            fieldsOfInterest = {'startDaysOfWeek','features'};
                            for f=1:numel(fieldsOfInterest)
                                fname = fieldsOfInterest{f};
                                this.featureStruct.(fname)(curRange,:) = this.featureStruct.(fname)(curRange(sortInd),:);
                            end
                            %this.featureStruct.startDaysOfWeek(curRange) = startDays;
                        end
                        % reshape poc: tmp = [1:2:7;2:2:8]';
                        % tmp = [tmp;tmp];
                        % reshape(tmp',8,[])'
                        this.featureStruct.totalCount = 7*this.featureStruct.totalCount;
                        
                        this.featureStruct.daysOfWeek = reshape(this.featureStruct.startDaysOfWeek',7,[])'; % should be all 0 - 6
                        this.featureStruct.startDaysOfWeek = this.featureStruct.startDaysOfWeek(1:7:end); % should be all 0 (sunday)
                        % this.featureStruct.startDaysOfWeek = 0:6;
                        this.featureStruct.startDaysOfWeek = this.featureStruct.daysOfWeek;
                        this.featureStruct.studyIDs = this.featureStruct.studyIDs(1:7:end);
                        
                        % Make it into rows
                        numStartTimes = numel(this.featureStruct.startTimes);
                        this.featureStruct.startTimes = repmat(this.featureStruct.startTimes,1,7);
                        for day_index=1:7
                            % day_label = PACluster.WEEKDAY_SHORT_LABELS{day_index};
                            day_label = PACluster.WEEKDAY_LABELS{day_index};
                            update_index = (day_index-1)*numStartTimes+1;
                            this.featureStruct.startTimes{1,update_index} = sprintf('%s %s',day_label,this.featureStruct.startTimes{1,update_index});
                        end
                        
                        this.featureStruct.features = reshape(this.featureStruct.features',this.featureStruct.totalCount,[])';% [] should result to sum(this.featureStruct.numDays==7)
                        
                        % Special case to sort the entire week - b/c too
                        % difficult to place into calcFeatureStruct()
                        if strcmpi(pSettings.preclusterReduction,'sort') && ~pSettings.chunkShapes
                            this.featureStruct.features = sort(this.featureStruct.features,2,'descend'); %sort rows from high to low
                        end
                        
                        try
                            if ~pSettings.discardNonwearFeatures
                                this.nonwear.rows = reshape(this.nonwear.rows',7,[])';
                                this.nonwear.num_days = sum(this.nonwear.rows,2);
                                this.nonwear.rows = this.nonwear.num_days>0;
                                
                                % 53 of 268 had a week with 0 nonwear days.
                                % 15 had nonwear each day of 7.
                            end
                            
                        catch me
                            showME(me);
                        end
                    end
                end
                
                set(this.handles.axes_primary,'color',[1 1 1],'xlimmode','auto','ylimmode',pSettings.primaryAxis_yLimMode,'xtickmode','auto',...
                    'ytickmode',pSettings.primaryAxis_yLimMode,'xticklabelmode','auto','yticklabelmode',pSettings.primaryAxis_yLimMode,'xminortick','off','yminortick','off');
                set(resultsTextH,'visible','on','foregroundcolor',[0.1 0.1 0.1],'string','');
                
                % % set(this.handles.text_primaryAxes,'backgroundcolor',[0 0 0],'foregroundcolor',[1 1 0],'visible','on');
                this.showClusterControls();
                drawnow();
                
                % This means we will create the cluster object, but not
                % calculate the clusters in the constructor.  The reason
                % for this is because I want to register a mouse listener
                % so users can cancel.  And I chose to do that here, rather
                % than in the constructor.
                delayedStart = true;
                cSettings = this.getClusterSettings(pSettings);
                tmpClusterObj = PACluster(this.featureStruct.features,cSettings,this.handles.axes_primary,resultsTextH,this.featureStruct.studyIDs, this.featureStruct.startDaysOfWeek, delayedStart);
                tmpClusterObj.setExportPath(this.getSetting('exportPathname'));
                tmpClusterObj.addlistener('DefaultParameterChange',@this.clusterParameterChangeCb);
                
                % This creates multiple, unused listeners unless we
                % specifically track and delete them use the event.listener
                % constructor.  Let's forgo that and just call
                % this.clusterObj.cancelCalculation when we do our
                % notification.
                %                 this.addlistener('UserCancel_Event',@tmpClusterObj.cancelCalculations);
                if(~tmpClusterObj.setShapeTimes(this.featureStruct.startTimes))
                    this.setStatus('Shape times not set!');
                else
                    this.setStatus('');
                end
                
                if ~tmpClusterObj.setNonwearRows(this.nonwear.rows) && ~pSettings.discardNonwearFeatures
                    this.logWarning('Could not set nonwear rows');
                end
                
                if evaluateK
                    minK = this.getSetting('predictionStrength_minK');
                    maxK = this.getSetting('predictionStrength_maxK');
                    iterations = this.getSetting('predictionStrength_iterations');
                    showProgress = ~isdeployed;
                    predictionStrength(tmpClusterObj.loadShapes, 'mink', minK, 'maxk', maxK, 'M', iterations, 'showprogress', showProgress,'gui',true);
                else
                    if(enableUserCancel)
                        this.enableClusterCancellation();
                    end
                    this.clusterObj = tmpClusterObj;
                    this.clusterObj.calculateClusters();
                    
                    if(this.clusterObj.failedToConverge())
                        warnMsg = {'Failed to converge.',[]};
                        if(isempty(this.featureStruct.features))
                            warnMsg = {[warnMsg{1}, ' No features found.'];
                                '';
                                '  Hint: Try altering input settings:';
                                '';
                                '  - Changing days of week for analysis';
                                '  - Reduce minimum number of clusters';
                                '  - Include non-wear sections instead of discarding them';
                                ''};
                        else
                            warnMsg{end} = 'See console for possible explanations';
                        end
                        warndlg(warnMsg,'Warning','modal');
                        this.clusterObj = [];
                    else
                        this.refreshGlobalProfile();
                        this.clusterObj.featureStruct = this.featureStruct;
                        this.cacheCluster();
                    end
                end
            else
                inputFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
                wrnMsg = sprintf('Could not find the input file required (%s)!',inputFilename);
                fprintf(1,'%s\n',wrnMsg);
                if(this.hasIcon)
                    CreateStruct.WindowStyle='modal';
                    CreateStruct.Interpreter='tex';
                    warndlg(wrnMsg,'Warning',CreateStruct); %'custom',this.iconData,this.iconCMap,
                else
                    warndlg(wrnMsg,'Warning','modal');
                end
            end
            if evaluateK
                this.enableClusterControls();
            else
                if(this.hasValidCluster()) % ~isempty(this.clusterObj))
                    didConverge = true;
                    % Prep the x-axis here since it will not change when going from one cluster to the
                    % next, but only (though not necessarily) when refreshing clusters.
                    this.drawClusterXTicksAndLabels();
                    
                    if(this.clusterObj.getUserCancelled())
                        this.initRefreshClusterButton('on');
                    else
                        this.initRefreshClusterButton('off');
                    end
                    
                    if this.isBgColorDisplayOn()
                        dissolveIn = 0;
                    else
                        
                    end
                    dissolveIn = 2.5;
                    dissolve(resultsTextH,dissolveIn);
                    this.plotClusters(pSettings);
                    this.enableClusterControls();
                else
                    set(resultsTextH,'visible','off');
                    this.initRefreshClusterButton('on');  % want to initialize the button again so they can try again perhaps.
                end
            end
            this.enable();
            this.showReady();
        end
        
        % Removes plot only fields
        function cSettings = getClusterSettings(this, pSettings)
            if(nargin<2 || isempty(pSettings))
                pSettings = this.getPlotSettings();
            end
            
            plotOnlyFields = {
                'primaryAxis_yLimMode'
                'primaryAxis_nextPlot'
                'showAnalysisFigure'
                'numShades'
                'showTimeOfDayAsBackgroundColor'
                'showClusterSummary'
                'plotTypeSelection'
                'clusterDistributionType'
                };
            
            allFields = fieldnames(pSettings);
            fieldsToRemove = intersect(plotOnlyFields,allFields);
            cSettings = rmfield(pSettings,fieldsToRemove);
        end
        
        % Original widget settings from when the last cluster calculation
        % was performed.
        function widgetState = getStateAtTimeOfLastClustering(this)
            widgetState = this.originalSettings;
        end
        
        function drawClusterXTicksAndLabels(this)
            plotSettings = this.getPlotSettings();
            
            %isShowingWeekLong = strcmpi(this.originalSettings.weekdayTag,'weeklong');
            featureS = this.featureStruct;
            if isempty(featureS)
                featureS = struct();
                featureS.startTimes = this.clusterObj.loadShapeTimes;
                featureS.totalCount = numel(this.clusterObj.loadShapeTimes);
            end
            if this.isShowingWeekLong(plotSettings)
                segmentsPerDay = plotSettings.stopTimeSelection-plotSettings.startTimeSelection+1;
                everyNthTick = segmentsPerDay;
            else
                everyNthTick = 6;
            end
            if featureS.totalCount>18
                xTicks = 1:everyNthTick:featureS.totalCount;
            else
                xTicks = 1:featureS.totalCount;
            end
            
            % This is nice to place a final tick matching the end time on
            % the graph, but it sometimes gets too busy and the tick
            % separation distance is non-linear which can be an eye soar.
            %             if(xTicks(end)~=featureS.totalCount)
            %                 xTicks(end+1)=featureS.totalCount;
            %             end
            
            xTickLabels = featureS.startTimes(xTicks);
            featureLen = featureS.totalCount;
            xlimit = [1, featureLen];
            if(numel(xTicks)>70)
                xLabelRot = -90;
                xTicks = xTicks(1:10:end);
                xTickLabels = xTickLabels(1:10:end);
            elseif(numel(xTicks)>10)
                xLabelRot = -45;
            else
                xLabelRot = 0;
                
                if featureLen<2
                    % Prevents xlimit errors being raised about otherwise non increasing
                    xlimit = [featureLen-1, featureLen+1];
                end
            end
            
            set(this.handles.axes_primary,'xlim',xlimit,'xtick',xTicks,'xticklabel',char(xTickLabels(:)),...
                'XTickLabelRotation',xLabelRot);%,...
            
            %                 'fontsize',11);
        end
        
        %> @brief Hides the panel of cluster interaction controls.  For
        %> example, the forward and back buttons that appear in between the
        %> two axes.
        %> @param Instance of PAStatTool
        function hideClusterControls(this)
            set([
                this.handles.panel_clusterSettings
                this.handles.panel_clusterInfo
                this.handles.axes_secondary
                this.handles.btngrp_clusters
                ],'visible','off');
            
            % Also in disableClusterControls, but the whole figure changes
            % size when the toolbar's visibility changes, so decided to
            % just enable/disable it instead here, and only hide/show when
            % swapping between time series and results views.
            disableHandles(this.handles.toolbar_results);
            
            containerPos = get(this.handles.panel_results,'position');  % contains shape and cluster panels
            shapePos = get(this.handles.panel_shapeSettings,'position');  % shape panel sits above the cluster panel on screen
            clusterPos = get(this.handles.panel_clusterSettings,'position'); %
            
            hDelta = sum(clusterPos([2,4]));
            
            % only resize if necessary...
            if(containerPos(4)>hDelta+shapePos(4))
                shapePos(2) = shapePos(2)-hDelta;
                set(this.handles.panel_shapeSettings,'position',shapePos);
                
                containerPos(2) = containerPos(2)+hDelta;
                containerPos(4) = containerPos(4)-hDelta;
                set(this.handles.panel_results,'position',containerPos);
            end
            
            % remove anycontext menu on the primary and secondary axes
            set(this.handles.axes_primary,'uicontextmenu',[]);
            this.disableSecondaryContextMenus();
        end
        
        function toggleLegendCallback(this, hObject,eventData, axesHandle)
            legend(axesHandle,'toggle');
        end
        
        function showClusterControls(this)
            
            containerPos = get(this.handles.panel_results,'position');
            shapePos = get(this.handles.panel_shapeSettings,'position');
            clusterPos = get(this.handles.panel_clusterSettings,'position');
            
            hDelta = sum(clusterPos([2,4]));
            
            % only resize if necessary...
            if(containerPos(4)<hDelta+shapePos(4))
                
                shapePos(2) = shapePos(2)+hDelta;
                set(this.handles.panel_shapeSettings,'position',shapePos);
                
                containerPos(2) = containerPos(2)-hDelta;
                containerPos(4) = containerPos(4)+hDelta;
                set(this.handles.panel_results,'position',containerPos);
            end
            
            
            set([
                this.handles.panel_clusterSettings
                this.handles.axes_secondary
                this.handles.btngrp_clusters
                ],'visible','on');
            
        end
        
        %> @brief Enables panel_clusterSettings controls.
        function enableClusterControls(this)
            enableHandles([
                this.handles.panel_results
                this.handles.toolbar_results
                this.handles.btngrp_clusters]);
            
            this.enablePrimaryContextMenus();
            this.enableSecondaryContextMenus();
            
            % --------
            % I don't think this does anything anymore @hyatt 5/11/2017
            %             this.handles.contextmenu.showMenu = uimenu(contextmenu_primaryAxes,'Label','Show'); %,'callback',@this.primaryAxesClusterSummaryContextmenuCallback);
            %
            %             % Possibly use this.originalSettings.
            %             if(this.originalSettings.get('showClusterSummary)
            %                 checkedState = 'on';
            %             else
            %                 checkedState = 'off';
            %             end
            %
            %             this.handles.contextmenu.show.clusterSummary = uimenu( this.handles.contextmenu.showMenu,...
            %                 'Label','Cluster summary','callback',@this.primaryAxesClusterSummaryContextmenuCallback,...
            %                 'checked',checkedState);
            % --------
            
        end
        
        %> @brief Does not alter panel_clusterSettings controls, which we want to
        %> leave avaialbe to the user to manipulate settings in the event
        %> that they have excluded loadshapes and need to alter the settings
        %> to included them in a follow-on calculation.
        function disableClusterControls(this)
            disableHandles([this.handles.toolbar_results
                this.handles.btngrp_clusters
                % this.handles.panel_results -> don't want to disable the
                % cancel button, nor want it to flash though ... see
                % designateHandles for alias that could be used instead if
                % you really want, otherwise solution is handled already
                % @hyatt 2/8/2020
                ]);
            
            set(this.handles.panel_clusterInfo,'visible','off');
            set(this.handles.text_clusterResultsOverlay,'enable','on');
            % add a context menu now to primary axes
            this.disablePrimaryContextMenus();
            this.disableSecondaryContextMenus();
            
            this.clearPlots();
            set([this.handles.axes_primary
                this.handles.axes_secondary],'color',[0.75 0.75 0.75]);
        end
        
        % ======================================================================
        %> @brief Displays most recent cluster data according to gui
        %> setttings.
        %> @param this Instance of PAStatTool
        %> @param plotSettings Structure of GUI parameters for configuration and
        %> display of cluster data.
        % ======================================================================
        function plotClusters(this,clusterAndPlotSettings)
            fontsize = 14;
            if isunix
                fontsize = 12;
            end
            this.clearPrimaryAxes();
            
            %  this.clearPlots();
            % this.showMouseBusy();
            try
                if(isempty(this.clusterObj)|| this.clusterObj.failedToConverge())
                    % clear everything and give a warning that the cluster is empty
                    this.logWarning('Clustering results were empty');
                else
                    numClusters = this.clusterObj.numClusters();
                    
                    distributionAxes = this.handles.axes_secondary;
                    clusterAxes = this.handles.axes_primary;
                    
                    set(clusterAxes,'color',[1 1 1]);
                    
                    % draw the x-ticks and labels - Commented out on
                    % 10/14/2016 because this appears to be called in
                    % refreshClustersAndPlot(), with the assumption it is
                    % no longer needed.  Is this not true?
                    % @No, this is still needed if we are using a cached
                    % load.  Add drawClusterXTicksAndLabels() to the lite
                    % method for refreshClustersAndPlot when
                    % switching2clusters is invoked.
                    % this.drawClusterXTicksAndLabels();
                    
                    if(nargin<2)
                        clusterAndPlotSettings = this.getPlotSettings();
                    end
                    
                    
                    %% Show clusters on primary axes
                    cois = this.clusterObj.getClustersOfInterest();
                    numCOIs = numel(cois);
                    clusterHandles = nan(numCOIs,1);
                    coiSortOrders = nan(numCOIs,1);
                    coiMemberIDs = [];
                    
                    % coiMarkers = '+o*xv^.';
                    
                    % Clever ...ymcrgbwk  c and y are too hard for me to
                    % see.
                    coiColors = 'kbgrkbm';
                    coiMarkers= '+o*.xv^';
                    coiStyles = repmat('-:',size(coiColors));
                    coiColors = [coiColors, fliplr(coiColors)];
                    coiMarkers = [coiMarkers, fliplr(coiMarkers)];
                    maxColorStyles = numel(coiColors);
                    % coiMarkers = [coiMarkers,coiMarkers];
                    
                    yLimMode = clusterAndPlotSettings.primaryAxis_yLimMode;
                    set(clusterAxes,'ytickmode',yLimMode,...
                        'ylimmode',yLimMode,...
                        'yticklabelmode',yLimMode);
                    
                    originalNextPlot = get(clusterAxes,'nextplot');
                    if(clusterAndPlotSettings.showClusterMembers || numCOIs>1)
                        hold(clusterAxes,'on');
                        % set(clusterAxes,'ygrid','on');
                    else
                        set(clusterAxes,'nextplot','replacechildren');
                        % set(clusterAxes,'ygrid','off');
                    end
                    
                    for c=1:numCOIs
                        coi = cois{c};
                        coiSortOrders(c) = coi.sortOrder;
                        coiMemberIDs = [coi.memberIDs(:);coiMemberIDs(:)];
                        profileLength = numel(coi.shape);
                        if(clusterAndPlotSettings.showClusterMembers)
                            if(profileLength==1)
                                markerType = '.';
                                midPoint = mean(get(clusterAxes,'xlim'));
                                membersLineH = plot(clusterAxes,midPoint,coi.dayOfWeek.memberShapes,'-','linewidth',1,'color',this.COLOR_MEMBERSHAPE,'marker',markerType);
                            else
                                membersLineH = plot(clusterAxes,coi.dayOfWeek.memberShapes','-','linewidth',1,'color',this.COLOR_MEMBERSHAPE);
                            end
                            numLines = numel(membersLineH);
                            if(numLines<50)
                                for m=1:numLines
                                    set(membersLineH(m),'uicontextmenu',this.handles.contextmenu.clusterLineMember,'userdata',coi.memberIDs(m),'buttondownfcn',{@this.memberLineButtonDownCallback,coi.memberIDs(m)});
                                end
                            end
                        end
                        
                        % This changes my axes limit mode if nextplot is set to
                        % 'replace' instead of 'replacechildren'
                        colorStyleIndex = mod(coi.sortOrder-1,maxColorStyles)+1;  %b/c MATLAB is one based, and 'mod' is not.
                        
                        markerType = 'none';
                        if profileLength==1
                            markerType = coiMarkers(colorStyleIndex);
                            midPoint = mean(get(clusterAxes,'xlim'));
                            clusterHandles(c) = plot(clusterAxes,midPoint,coi.shape,'linestyle','none',...
                                'marker',markerType,'markerfacecolor','none',...
                                'markeredgecolor',coiColors(colorStyleIndex),'markersize',20);
                        elseif profileLength <= 5
                            markerType = coiMarkers(colorStyleIndex);
                            clusterHandles(c) = plot(clusterAxes,coi.shape,'linestyle',coiStyles(colorStyleIndex),...
                                'color',coiColors(colorStyleIndex),'linewidth', 2, ...
                                'marker',markerType,'markerfacecolor','none',...
                                'markeredgecolor',coiColors(colorStyleIndex),'markersize',10);
                        else
                            clusterHandles(c) = plot(clusterAxes,coi.shape,'linewidth',2,'linestyle',coiStyles(colorStyleIndex),'color',coiColors(colorStyleIndex),'marker',markerType,'markerfacecolor','none','markeredgecolor','k'); %[0 0 0]);
                        end
                        
                        if(coi.numMembers==1)
                            set(clusterHandles(c),'uicontextmenu',this.handles.contextmenu.clusterLineMember,...
                                'userdata',coi.memberIDs,...
                                'buttondownfcn',{@this.memberLineButtonDownCallback,coi.memberIDs});
                        else
                            %set(clusterHandles(c),'visible','off');
                        end
                    end
                    
                    set(clusterAxes,'nextplot',originalNextPlot);
                    
                    legendStrings = this.displayClusterSummary(coiMemberIDs, coiSortOrders);
                    
                    if(numCOIs>1)
                        legend(clusterAxes,clusterHandles,legendStrings,'box','on','fontsize',12);
                    else
                        legend(clusterAxes,'off');
                    end
                    
                    if(clusterAndPlotSettings.showTimeOfDayAsBackgroundColor)
                        % Finally Add daylight to the top.
                        maxDaylight = 1;
                        verticalOffset = 0;
                        height = 1;
                        axesH = this.handles.axes_primary;
                        
                        datenumVec = datenum(this.getStartTimesCell,'HH:MM');
                        numShades = 1;
                        daylightOverlay = getDaylightEstimate(numShades,datenumVec);
                        
                        xdata = linspace(1,this.featureStruct.totalCount,numel(daylightOverlay)+1);
                        
                        % use a proxy for the actual start stop date nums,
                        % since we don't actually use it for display in
                        % this case, but the indexing of the content, which
                        % is already provided in the 'xdata' property of
                        % our axes handle.
                        startStopXData = [xdata(1:end-1);xdata(2:end)]';
                        
                        [~, overlayPatchH] = addOverlayToAxes(axesH, daylightOverlay, startStopXData, height, verticalOffset,maxDaylight);
                        set(overlayPatchH,'hittest','off');
                        uistack(overlayPatchH,'bottom');
                    end
                    
                    % Analysis figure and scatter plot - highlight the
                    % selected point; the cluster of interest (coi)
                    if(this.useDatabase || this.useOutcomes)
                        yData = get(this.handles.line_allScatterPlot,'ydata');
                        if(~isempty(yData))
                            set(this.handles.line_coiInScatterPlot,'xdata',coiSortOrders,'ydata',yData(coiSortOrders));
                        end
                    end
                    
                    oldVersion = verLessThan('matlab','7.14');
                    
                    yLabelStr = '';
                    titleStr = '';
                    %%  Show distribution on secondary axes
                    clusterDistributionType = this.getSetting('clusterDistributionType');
                    switch(clusterDistributionType)
                        
                        % plots the Calinski-Harabasz indices obtained during
                        % adaptve k-means filtering.
                        case 'performance_progression'
                            [~, yLabelStr, titleStr]=this.clusterObj.plotPerformance(distributionAxes);
                            
                            % plots the distribution of weekdays on x-axis
                            % and the loadshape count (for the cluster of
                            % interest) on the y-axis.
                            
                        case 'weekday_membership'
                            daysofweekStr = this.base.daysOfWeekShortDescriptions;%{'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
                            daysofweekOrder = this.base.daysOfWeekOrder;  %1:7;
                            
                            coiDaysOfWeek = [];
                            numMembers = 0;
                            for c=1:numCOIs
                                coi = cois{c};
                                % +1 to adjust startDaysOfWeek range from [0,6] to [1,7]
                                coiDaysOfWeek = [coiDaysOfWeek;this.featureStruct.startDaysOfWeek(coi.memberIndices)+1];
                                numMembers = numMembers+coi.numMembers;
                            end
                            coiDaysOfWeekCount = histc(coiDaysOfWeek,daysofweekOrder); %#ok<*HISTC>
                            coiDaysOfWeekPct = coiDaysOfWeekCount/sum(coiDaysOfWeekCount(:));
                            h = bar(distributionAxes,coiDaysOfWeekPct);%,'buttonDownFcn',@this.clusterDayOfWeekHistogramButtonDownFcn);
                            barWidth = get(h,'barwidth');
                            x = get(h,'xdata');
                            y = get(h,'ydata');
                            pH = nan(max(daysofweekOrder),1);
                            daysOfInterestVec = this.clusterObj.getDaysOfInterest();  %on means that we show the original bar, and that the day is 'on'; while the visibility of the overlay is off.
                            for d=1:numel(daysofweekOrder)
                                dayOrder = daysofweekOrder(d);
                                daysofweekStr{dayOrder} = sprintf('%s (n=%u)',daysofweekStr{dayOrder},coiDaysOfWeekCount(dayOrder));
                                
                                if(~oldVersion)
                                    onColor = [1 1 1];
                                    if(daysOfInterestVec(dayOrder)) % don't draw the cover-up patches for days we are interested in.
                                        visibility = 'off';
                                    else
                                        visibility = 'on';
                                    end
                                    pH(dayOrder) = patch(repmat(x(dayOrder),1,4)+0.5*barWidth*[-1 -1 1 1],1*[y(dayOrder) 0 0 y(dayOrder)],onColor,'parent',distributionAxes,'facecolor',onColor,'edgecolor',onColor,'pickableparts','none','hittest','off','visible',visibility);
                                end
                            end
                            
                            set(h,'buttonDownFcn',{@this.clusterDayOfWeekHistogramButtonDownFcn,pH});
                            
                            if(numCOIs==1)
                                titleStr = sprintf('Cluster #%u weekday distribution (%u members)',coi.index,numMembers);
                            else
                                titleStr = sprintf('Weekday distribution for %u selected clusters (%u members)',numCOIs,numMembers);
                            end
                            
                            yLabelStr = 'Relative occurrence';
                            xlabel(distributionAxes,'Days of week');
                            xlim(distributionAxes,[daysofweekOrder(1)-0.75 daysofweekOrder(end)+0.75]);
                            set(distributionAxes,'ylim',[0,1],'ygrid','on','ytickmode','auto','xtick',daysofweekOrder,'xticklabel',daysofweekStr);
                            
                            % plots clusters id's (sorted by membership in ascending order) on x-axis
                            % and the count of loadshapes (i.e. membership count) on the y-axis.
                        case {'loadshape_membership','participant_membership','weekday_scores','nonwear_membership'}
                            set(distributionAxes,'ylimmode','auto');
                            barWidth = 0.8;
                            
                            if(strcmpi(clusterDistributionType,'loadshape_membership'))
                                y = this.clusterObj.getHistogram('loadshapes');
                                yLabelStr = 'Loadshapes (n)';
                                distTitle = 'Loadshapes by cluster';
                            elseif(strcmpi(clusterDistributionType,'participant_membership'))
                                yLabelStr = 'Unique participants (n)';
                                distTitle = 'Unique participants by cluster';
                                y = this.clusterObj.getHistogram('participants');
                            elseif(strcmpi(clusterDistributionType,'weekday_scores'))
                                sortLikeHistogram = true;
                                yLabelStr = 'Score';
                                y = this.clusterObj.getWeekdayScores(sortLikeHistogram);
                                distTitle = 'Weekday distribution scores';
                            elseif(strcmpi(clusterDistributionType,'nonwear_membership'))
                                yLabelStr = 'Loadshapes with nonwear (n)';
                                %y = this.clusterObj.getHistogram('loadshapes');
                                y = this.clusterObj.getHistogram('nonwear');
                                if isempty(this.nonwear.rows)
                                    nonwear_occurrences = 0;
                                    unique_subjects_with_nonwear = 0;
                                else
                                    try
                                        nonwear_occurrences = sum(this.nonwear.rows);
                                        unique_subjects_with_nonwear = numel(unique(this.originalFeatureStruct.studyIDs(this.nonwear.rows)));
                                    catch me
                                        showME(me);
                                        nonwear_occurrences = -1;
                                        unique_subjects_with_nonwear = -1;
                                    end
                                end
                                
                                distTitle = sprintf('Nonwear Occurrences - Total = %d, Unique individuals = %d', nonwear_occurrences, unique_subjects_with_nonwear);
                            end
                            titleStr = distTitle;
                            
                            x = 1:numel(y);
                            highlightColor = [0.75 0.75 0];
                            barH = bar(distributionAxes,y,barWidth,'buttonDownFcn',@this.clusterHistogramButtonDownFcn);
                            
                            if(strcmpi(this.getSetting('clusterDistributionType'),'weekday_scores'))
                                set(distributionAxes,'ylim',[-1 1]);
                            end
                            
                            if(oldVersion)
                                %barH = bar(distributionAxes,y,barWidth);
                                defaultColor = [0 0 9/16];
                                faceVertexCData = repmat(defaultColor,numClusters,1);
                            end
                            
                            for c=1:numCOIs
                                coi = cois{c};
                                if(oldVersion)
                                    faceVertexCData(coi.sortOrder,:) = highlightColor;
                                    patchH = get(barH,'children');
                                    if(numClusters>100)
                                        %  set(patchH,'edgecolor',[0.4 0.4 0.4]);
                                        set(patchH,'edgecolor','none','buttonDownFcn',{@this.clusterHistogramPatchButtonDownFcn,coi.sortOrder});
                                    end
                                    set(patchH,'facevertexcdata',faceVertexCData);
                                else
                                    pH = patch(repmat(x(coi.sortOrder),1,4)+0.5*barWidth*[-1 -1 1 1],1*[y(coi.sortOrder) 0 0 y(coi.sortOrder)],highlightColor,'parent',distributionAxes,'facecolor',highlightColor,'edgecolor',highlightColor,'buttonDownFcn',{@this.clusterHistogramPatchButtonDownFcn,coi.sortOrder});
                                end
                            end
                            
                            %title(distributionAxes,sprintf('%s. Clusters: %u Load shapes: %u',distTitle,this.clusterObj.numClusters(), this.clusterObj.numLoadShapes()),'fontsize',14);
                            
                            %ylabel(distributionAxes,sprintf('Load shape count'));
                            xlabel(distributionAxes,'Cluster popularity','fontsize',fontsize);
                            xlim(distributionAxes,[0.25 numClusters+.75]);
                            set(distributionAxes,'ygrid','on','ytickmode','auto','xtick',[]);
                            %                     case 'globalprofile'
                            %                         globalProfile = this.getGlobalProfile();
                            %                     case 'localVsGlobalProfile'
                            %                         globalProfile = this.getGlobalProfile();
                            %                         primaryKeys = coi.memberIDs;
                            %                         ` = this.getProfileCell(primaryKeys);
                            %                     case 'clusterprofile'
                            %                         primaryKeys = coi.memberIDs;
                            %                         coiProfile = this.getProfileCell(primaryKeys);
                        otherwise
                            warndlg(sprintf('Distribution type (%s) is unknonwn and or not supported',this.getSetting('clusterDistributionType')));
                    end
                    
                    ylabel(distributionAxes,yLabelStr,'fontsize',fontsize);
                    hT = title(distributionAxes,titleStr,'fontsize',fontsize,'units','normalized','visible','off');
                    hPos = get(hT,'position');
                    set(hT,'position',[hPos(1) 0.9 hPos(3)],'visible','on');
                    this.refreshCOIProfile();
                end
            catch me
                showME(me);
                this.clearPrimaryAxes();
            end
            this.showMouseReady();
        end
        
        function [legendStrings, clusterTitle, clusterDescription] = displayClusterSummary(this, coiMemberIDs, coiSortOrders)
            fontsize=14;
            if isunix
                fontsize=12;
            end
            % summaryTextH = this.handles.text_clusterResultsOverlay;
            clusterAxes = this.handles.axes_primary;
            
            numClusters = this.clusterObj.numClusters();
            numLoadShapes = this.clusterObj.numLoadShapes();
            %             numNonwear
            % The cluster of interest will change according to user
            % selection or interaction with the gui.  It is updated
            % internally within clusterObj.
            cois = this.clusterObj.getClustersOfInterest();
            numCOIs = numel(cois);
            
            legendStrings = cell(numCOIs,1);
            summaryStrings = cell(numCOIs,1);
            coiPctOfLoadShapes = zeros(numCOIs,1);
            coiNumNonwear = zeros(numCOIs,1);
            % summaryTextH = this.handles.text_clusterResultsOverlay;
            
            for c=1:numCOIs
                coi = cois{c};
                
                numCOILoadShapes = coi.numMembers;  %total load shape counts;
                coiNumNonwear(c) = coi.numNonwear;
                coiPctOfLoadShapes(c) = numCOILoadShapes/numLoadShapes*100;
                legendStrings{c} = sprintf('Cluster #%u (Popularity: #%d, %0.2f%%)',coi.index, coi.sortOrder,coiPctOfLoadShapes(c));
                summaryStrings{c} = sprintf('#%u (%0.2f%%) Sum=%0.2f\tMean=%0.2f',coi.index, coiPctOfLoadShapes(c),sum(coi.shape),mean(coi.shape));
                
            end
            
            % Tallied here for all load coi's - may be 1, in which case it
            % is the same value as above
            numCOILoadShapes = numel(coiMemberIDs);  % member IDs need not be unique here
            pctOfLoadShapes = numCOILoadShapes/numLoadShapes*100;
            
            numCOINonwear = sum(coiNumNonwear);
            pctCOINonwear = numCOINonwear/numCOILoadShapes*100;
            
            %want to figure out unique individuals that may be
            %contributing to a particular load shape.
            uniqueMemberIDs = unique(coiMemberIDs);
            numUniqueMemberIDs = numel(uniqueMemberIDs);
            
            totalMemberIDsCount = this.clusterObj.getUniqueLoadShapeIDsCount();
            pctOfTotalMemberIDs = numUniqueMemberIDs/totalMemberIDsCount*100;
            weekdayScore = coi.dayOfWeek.score;
            clusterDescription = sprintf('Loadshapes: %u of %u (%0.2f%%)\nIndividuals: %u of %u (%0.2f%%)\nNonwear: %u of %u (%0.2f%%)',...
                numCOILoadShapes, numLoadShapes, pctOfLoadShapes, numUniqueMemberIDs, totalMemberIDsCount, pctOfTotalMemberIDs,...
                numCOINonwear, numCOILoadShapes,pctCOINonwear);
            
            if(numCOIs>1)
                coiSortOrdersString = num2str(coiSortOrders(:)','%d,');
                coiSortOrdersString(end)=[]; %remove trailing ','
                clusterID = sprintf('Clusters #{%s}',coiSortOrdersString);
                clusterTitle = sprintf('Clusters #{%s}. Loadshapes: %u of %u (%0.2f%%).  Individuals: %u of %u (%0.2f%%)',coiSortOrdersString,...
                    numCOILoadShapes, numLoadShapes, pctOfLoadShapes, numUniqueMemberIDs, totalMemberIDsCount, pctOfTotalMemberIDs);
            else
                % Use when show most popular first, on left side
                clusterID = sprintf('Cluster #%u',coi.index);
                clusterTitle = sprintf('Cluster #%u (%s). Popularity %u of %u. Loadshapes: %u of %u (%0.2f%%).  Individuals: %u of %u (%0.2f%%)',coi.index,...
                    this.featureStruct.method, coi.sortOrder,numClusters, coi.dayOfWeek.numMembers, numLoadShapes, pctOfLoadShapes, numUniqueMemberIDs, totalMemberIDsCount, pctOfTotalMemberIDs);
                % Use when show most popular last, (right most side)
                % clusterTitle = sprintf('Cluster #%u (%s). Popularity %u of %u. Loadshapes: %u of %u (%0.2f%%).  Individuals: %u of %u (%0.2f%%)',coi.sortOrder,...
                %   this.featureStruct.method, numClusters-coi.sortOrder+1,numClusters, coi.dayOfWeek.numMembers, numLoadShapes, pctMembership, numUniqueMemberIDs, totalMemberIDsCount, pctOfTotalMemberIDs);
                
                clusterDescription = sprintf('%s\nPopularity: %u of %u\nWeekday Score: %+0.2f',clusterDescription,coi.sortOrder,numClusters,weekdayScore);
            end
            
            set(this.handles.text_clusterID,'string',clusterID);
            set(this.handles.text_clusterDescription,'string',clusterDescription);
            
            if(istoggled(this.toolbarH.cluster.toggle_summary) && isempty(intersect(this.getSetting('clusterDistributionType'),{'performance_progression','weekday_scores'})))
                set(this.handles.panel_clusterInfo,'visible','on');
                % the title is cleared automatically already.
                %title(clusterAxes,clusterTitle,'fontsize',14,'interpreter','none','visible','off');
            else
                set(this.handles.panel_clusterInfo,'visible','off');
                title(clusterAxes,clusterTitle,'fontsize',fontsize,'interpreter','none','visible','on');
            end
            
            if(this.useDatabase || this.useOutcomes)
                set(this.handles.text_analysisTitle,'string',clusterTitle);
            end
            
            
            % Analysis figure and scatter plot
            % title(this.handles.axes_scatterplot,clusterTitle,'fontsize',12);
            if(this.useDatabase || this.useOutcomes)
                displayName = sprintf('Cluster #%u (%0.2f%%)\n',[coiSortOrders(:),coiPctOfLoadShapes(:)]');
                displayName(end)=[];  %remove the final new line character
                set(this.handles.line_coiInScatterPlot,'displayName',displayName);
            end
            
            % Additional ways to display/update summary text
            %   set(summaryTextH,'string',summaryStrings);
            %   summaryStrings = strrep(summaryStrings,'%','%%');
            %   this.setStatus(cell2str(summaryStrings,' - '));
            %   this.logStatus(cell2str(summaryStrings,' - '));
            
        end
        
        % Refresh the user settings from current GUI configuration.
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        %> @retval userSettings Struct of GUI parameter value pairs
        % ======================================================================
        function userSettings = getPlotSettings(this)
            
            userSettings.showClusterMembers = istoggled(this.toolbarH.cluster.toggle_membership);
            userSettings.showClusterSummary = istoggled(this.toolbarH.cluster.toggle_summary);
            
            userSettings.processedTypeSelection = 1;  %defaults to count!
            userSettings.exclusionsFilename = this.getSetting('exclusionsFilename');
            userSettings.baseFeatureSelection = get(this.handles.menu_feature,'value');
            userSettings.signalSelection = get(this.handles.menu_signalsource,'value');
            userSettings.plotTypeSelection = get(this.handles.menu_plottype,'value');
            
            userSettings.chunkShapes = get(this.handles.check_segment,'value'); % returns 0 for unchecked, 1 for checked
            
            userSettings.numChunks = getMenuUserData(this.handles.menu_number_of_data_segments);   % can be a custom value for index value 9 (last selection);
            userSettings.numDataSegmentsSelection = get(this.handles.menu_number_of_data_segments,'value');
            
            userSettings.normalizeValues = get(this.handles.check_normalizevalues,'value');  %return 0 for unchecked, 1 for checked
            
            userSettings.discardNonwearFeatures = get(this.handles.check_discardNonwear,'value'); %this.originalSettings.get('discardNonwearFeatures;
            userSettings.processType = this.base.processedTypes{userSettings.processedTypeSelection};
            
            
            if isempty(this.featureTypes)
                % had an issue with this.featureTypes when it was initialized to empty on an incorrect path load
                userSettings.baseFeature = this.base.featureTypes{userSettings.baseFeatureSelection};
            else
                % had an issue with this.base.featureTypes when only a subset of features were available for the current path
                userSettings.baseFeature = this.featureTypes{userSettings.baseFeatureSelection}; 
            end
            
            userSettings.curSignal = this.base.signalTypes{userSettings.signalSelection};
            userSettings.plotType = this.base.plotTypes{userSettings.plotTypeSelection};
            userSettings.titleStr = this.base.plotTypeTitles{userSettings.plotTypeSelection};
            userSettings.numShades = this.base.numShades;
            
            userSettings.trimResults = get(this.handles.check_trim,'value'); % returns 0 for unchecked, 1 for checked
            userSettings.trimToPercent = str2double(get(this.handles.edit_trimToPercent,'string'));
            userSettings.cullResults = get(this.handles.check_cull,'value'); % returns 0 for unchecked, 1 for checked
            userSettings.cullToValue = str2double(get(this.handles.edit_cullToValue,'string'));
            
            userSettings.weekdaySelection = get(this.handles.menu_weekdays,'value');
            
            userSettings.startTimeSelection = get(this.handles.menu_clusterStartTime,'value');
            userSettings.stopTimeSelection = get(this.handles.menu_clusterStopTime,'value');
            
            % Plot settings
            userSettings.primaryAxis_yLimMode = get(this.handles.axes_primary,'ylimmode');
            userSettings.primaryAxis_nextPlot = get(this.handles.axes_primary,'nextplot');
            userSettings.showAnalysisFigure = istoggled(this.toolbarH.cluster.toggle_analysisFigure);
            userSettings.showTimeOfDayAsBackgroundColor = strcmpi(get(this.toolbarH.cluster.toggle_backgroundColor,'state'),'on');
            userSettings.profileFieldSelection = get(this.handles.menu_ySelection,'value');
            %             userSettings.clusterStartTime = getSelectedMenuString(this.handles.menu_clusterStartTime);
            %             userSettings.clusterStopTime = getSelectedMenuString(this.handles.menu_clusterStopTime);
            
            userSettings.weekdayTag = this.base.weekdayTags{userSettings.weekdaySelection};
            customIndex = strcmpi(this.base.weekdayTags,'custom');
            userSettings.customDaysOfWeek = this.base.weekdayValues{customIndex};
            
            userSettings.clusterDurationSelection = get(this.handles.menu_duration,'value');
            userSettings.clusterDurationHours = this.base.clusterHourlyDurations(userSettings.clusterDurationSelection);
            
            userSettings.clusterDistributionType = this.getSetting('clusterDistributionType');
            
            % Cluster settings
            userSettings.minClusters = str2double(get(this.handles.edit_minClusters,'string'));
            userSettings.clusterThreshold = str2double(get(this.handles.edit_clusterConvergenceThreshold,'string'));
            userSettings.clusterMethod = getSelectedMenuString(this.handles.menu_clusterMethod);%this.clusterSettings.clusterMethod;
            userSettings.distanceMetric = this.clusterSettings.distanceMetric;
            userSettings.initClusterWithPermutation = this.clusterSettings.initClusterWithPermutation;
            userSettings.useDefaultRandomizer = this.clusterSettings.useDefaultRandomizer;
            
            % Cluster reduction settings
            userSettings.preclusterReductionSelection = get(this.handles.menu_precluster_reduction,'value');
            userSettings.preclusterReduction = this.base.preclusterReductions{userSettings.preclusterReductionSelection};  %singular entry now.    %  = getuserdata(this.handles.menu_precluster_reduction);
            % userSettings.reductionTransformationFcn = getMenuUserData(this.handles.menu_precluster_reduction);
            
        end
        
        %> @brief Refreshes the cluster profile table based on current
        %> profile statistics found in member variable @c profileTableData.
        %> @param this Instance of PAStatTool.
        %> @retval didRefresh True on successful refresh, false otherwise.
        function didRefresh = refreshProfileTableData(this)
            %             curStack = dbstack;
            %             fprintf(1,'Skipping %s on line %u of %s\n',curStack(1).name,curStack(1).line,curStack(1).file);
            try
                sRow = this.getProfileFieldIndex()-1;  % Java is 0-based, MATLAB is 1-based
                sCol = max(0,this.jhandles.table_clusterProfiles.getSelectedColumn());  %give us the first column if nothing is selected)
                
                jViewPort = this.jhandles.table_clusterProfiles.getParent();
                initViewPos = jViewPort.getViewPosition();
                
                %colNames = get(this.handles.table_clusterProfiles,'columnname');
                %jTable = this.jhandles.table_clusterProfiles;
                %this.jhandles.table_clusterProfiles.setModel(javax.swing.table.DefaultTableModel(this.profileTableData,colNames));
                
                set(this.handles.table_clusterProfiles,'data',this.profileTableData);
                
                strData= cellfun(@num2str,this.profileTableData,'uniformoutput',false);
                % set(this.handles.
                [R,C] = size(this.profileTableData);
                set(this.handles.table_clusterProfiles,'columnEditable',true(1,C));
                for r=1:R
                    for c=1:C
                        strValue = strData{r,c};
                        if isempty(strValue)
                            strValue = 'n/a';
                        end
                        try
                            % this.jhandles.table.setValueAt(strValue,r-1,c-1);
                        catch me
                            showME(me);
                        end
                    end
                end
                set(this.handles.table_clusterProfiles,'columnEditable',false(1,C));
                %
                %             colNames = get(this.handles.table_clusterProfiles,'columnname');
                %             this.jhandles.table_clusterProfiles.getModel.setDataVector(this.profileTableData, colNames); % data = java.util.Vector
                %             %             data = this.jhandles.table_clusterProfiles.getModel.getDataVector;
                
                % drawnow();
                % this.jhandles.table_clusterProfiles.changeSelection(sRow,sCol,false,false);
                % jViewPort.setViewPosition(initViewPos);
                % drawnow();
                
                %             jViewPort.repaint();
                
                %this.jhandles.table_clusterProfiles.repaint();
                
                %             this.jhandles.table_clusterProfiles.clearSelection();
                %              this.jhandles.table_clusterProfiles.setRowSelectionInterval(sRow,sRow);
                %
                didRefresh = true;
            catch me
                showME(me);
                didRefresh = false;
            end
        end
        
        function analysisTableCellSelectionCallback(this, hObject, eventdata)
            if(~isempty(eventdata.Indices))
                rowSelectionIndex = eventdata.Indices(1);
                % If we clicked on a different row than where we were before,
                % then adjust to the new row.
                if(rowSelectionIndex~=this.getProfileFieldIndex())
                    this.setProfileFieldIndex(rowSelectionIndex);
                end
            end
        end
        
        %> @brief Refreshes profile statistics for the current cluster of interest (COI).
        %> This method should be called whenever the COI changes.
        %> @param this Instance of PAStatTool.
        %> @retval didRefresh True on successful refresh, false otherwise.
        function didRefresh = refreshCOIProfile(this)
            try
                if(this.hasProfileData() && this.hasCluster())
                    
                    % This gets the memberIDs attached to each cluster.
                    % This gives us all
                    coiStruct = this.clusterObj.getClusterOfInterest();
                    this.coiProfile = this.getProfileCell(coiStruct.memberIDs,this.profileFields);
                    
                    % place the local profile at the beginning (first few
                    % columns).
                    this.profileTableData(:,1:size(this.coiProfile,2)) = this.coiProfile;
                    this.refreshProfileTableData();
                    didRefresh = true;
                else
                    didRefresh = false;
                end
            catch me
                showME(me);
                didRefresh = false;
            end
        end
        
        function canIt = canUseDatabase(this)
            canIt = this.useDatabase && ~isempty(this.databaseObj) && this.hasValidCluster();
        end
        function canIt = canUseOutcomes(this)
            canIt = this.useOutcomes && ~isempty(this.outcomesObj) && this.hasValidCluster();
        end
        
        % ======================================================================
        %> @brief Refreshes the global profile statistics based on the
        %> current clusters available.  This method should be called
        %> whenever the clusters are changed or updated.
        %> @param this Instance of PAStatTool.
        %> @retval didRefresh True on successful refresh, false otherwise.
        % ======================================================================
        function didRefresh = refreshGlobalProfile(this)
            try
                if(this.canUseDatabase() || this.canUseOutcomes())
                    
                    % This gets the memberIDs attached to each cluster.
                    % This gives us all values with clusters interpreted
                    % in sort order (1 is most popular)
                    globalStruct = this.clusterObj.getCovariateStruct();
                    
                    % globalProfile is an Nx3 mat, where N is the number of
                    % profile fields (one per row), and the columns are
                    % ordered as {number of subjects (n), mean of subjects for row's variable, sem for subject values for the profile field associated with the current row}
                    [this.globalProfile, ~] = this.getProfileCell(globalStruct.memberIDs,this.profileFields);
                    
                    % place the global profile at the end.
                    if isempty(this.profileTableData)
                        this.createProfileTable();
                        %    this.initProfileTable  - this will be infinitely recursive if the tableData does not initialize :(
                    end
                    this.profileTableData(:,end-size(this.globalProfile,2)+1:end) = this.globalProfile;
                    this.refreshProfileTableData();
                    numClusters = this.clusterObj.getNumClusters();  %or numel(globalStruct.colnames).
                    xlim(this.handles.axes_scatterplot,[0 numClusters+1]);
                    
                    %                     numFields = numel(this.profileFields);
                    %                     numSubjects = numel(globalStruct.memberIDs);
                    this.allProfiles = nan([size(this.globalProfile),numClusters]);
                    %                     this.allCOIProfiles = nan(numFields,3,numClusters);
                    
                    % I would like to arrange the data in terms of the sort
                    % order.  The data from PA_Cluster.getCovariateStruct uses
                    % the coiSortOrder for identifying clusters;
                    % Previously a remapping would occur because the getCovariateStruct returned the coi index.
                    % Now this is no longer necessary.
                    for coiSO=1:numClusters
                        coiMemberIDs = globalStruct.memberIDs(globalStruct.id.values(:,coiSO)>0);  % pull out the members contributing to index of the current cluster of interest (coi)
                        
                        %sortOrder = this.clusterObj.getCOISortOrder(coiSO);
                        %                         if(sortOrder==21)
                        %                            disp(sortOrder);
                        %                         end
                        this.allProfiles(:,:,coiSO) = cell2mat(this.getProfileCell(coiMemberIDs, this.profileFields));
                    end
                    
                    this.refreshScatterPlot();
                    
                    didRefresh = true;
                else
                    didRefresh = false;
                end
            catch me
                showME(me);
                didRefresh = false;
            end
        end
        
        function [fieldIndex, fieldName] = getProfileFieldIndex(this)
            fieldIndex = 1;
            fieldName = '';
            try
                [fieldName, fieldIndex] = getSelectedMenuString(this.handles.menu_ySelection);
            catch me
                % this.logError(me);
            end
        end
        
        function dataStruct = getProfileData(this,primaryKeys,fieldsOfInterest)
            if(isempty(primaryKeys))
                primaryKeys = 1;
            end
            if(this.useOutcomes())
                [~,~,dataStruct]=this.outcomesObj.getSubjectInfoSummary(primaryKeys,fieldsOfInterest);
            elseif(this.useDatabase())
                [~,~,dataStruct]=this.databaseObj.getSubjectInfoSummary(primaryKeys,fieldsOfInterest);
            else
                dataStruct = struct();
            end
        end
        
        % ======================================================================
        %> @brief Returns a profile for the primary database keys provided.
        %> @param Obtained from <PACluster>.getClusterOfInterest()
        %> or <PACluster>.getCovariateStruct() for all subjects.
        %> @param Primary ID's to extract from the database.
        %> @param Field names to extract from the database.
        %  @retval coiProfile 3xN cell where column 1 contains primary key,
        %  column 2 contains mean value, column 3 contains the standard
        %  error of the mean.
        %> @param dataSummaryStruct A struct with field names naming the
        %> statistical information about that field to include: n, mean, SEM,
        %> var, and a string display)
        % ======================================================================
        function [coiProfile, dataSummaryStruct] = getProfileCell(this,primaryKeys,fieldsOfInterest)
            
            if(nargin<3 || isempty(fieldsOfInterest))
                if(this.useOutcomes())
                    fieldsOfInterest = this.outcomesObj.getColumnNames('subjects');
                elseif(this.useDatabase())
                    
                    if isunix
                        fieldsOfInterest = this.databaseObj.getColumnNames('subjectinfo_t');
                    else
                        fieldsOfInterest = this.databaseObj.getColumnNames('subjectInfo_t');    
                    end
                    
                end
                %                 fieldsOfInterest = {'bmi_zscore';
                %                     'insulin'};
            end
            
            statOfInterest = 'AVG';
            if(this.canUseOutcomes())
                [dataSummaryStruct, ~]=this.outcomesObj.getSubjectInfoSummary(primaryKeys,fieldsOfInterest,statOfInterest);
            elseif(this.canUseDatabase())
                [dataSummaryStruct, ~]=this.databaseObj.getSubjectInfoSummary(primaryKeys,fieldsOfInterest,statOfInterest);
            else
                dataSummaryStruct = [];
            end
            if(isempty(dataSummaryStruct))
                coiProfile = [];
            else
                coiProfile = PAStatTool.profile2cell(dataSummaryStruct);
            end
        end
        
        %> @brief Listening and checking for changes to the split checkbox.
        %> If it is enabled or disabled by a global enable or disable 'all'
        %> call, then we want to make sure that
        %> checkSegmentPropertyChgCallback also remains disabled.
        function checkSegmentPropertyChgCallback(this,~, ~)
            check_handle = this.handles.check_segment;
            if(get(check_handle,'value')==1 && strcmpi(get(check_handle,'enable'),'on'))
                enableState = 'on';
            else
                enableState = 'off';
            end
            set(this.handles.menu_number_of_data_segments,'enable',enableState);
        end
    end
    
    methods (Static)
        
        %> @note This is function is being overly clever to try and get
        %> away from the prototype profileFieldSelectionChangeCallback(this,
        %>thisAgain, eventData) which would exist if it was a non-static
        %> method convention.
        function profileFieldSelectionChangeCallback(statToolObj,eventData)
            curSetting = eventData.fieldName;
            curIndex = eventData.fieldIndex;
            ylabel(statToolObj.handles.axes_scatterplot,curSetting);
            
            % highlight the newly selected field of interest in the
            % cluster profile table.
            userData = get(statToolObj.handles.table_clusterProfiles,'userdata');
            backgroundColor = userData.defaultBackgroundColor;
            backgroundColor(curIndex,:) = userData.rowOfInterestBackgroundColor;
            set(statToolObj.handles.table_clusterProfiles,'backgroundColor',backgroundColor,'rowStriping','on');
            drawnow();
            %             pause(0.2);
            sRow = curIndex-1;  %java is 0 based
            sCol = max(0,statToolObj.jhandles.table_clusterProfiles.getSelectedColumn());  %give us the first column if nothing is selected)
            %             this.jhandles.table_clusterProfiles.setRowSelectionInterval(sRow,sRow);
            %             this.jhandles.table_clusterProfiles.setSelectionBackground()
            statToolObj.jhandles.table_clusterProfiles.changeSelection(sRow,sCol,false,false);
            statToolObj.jhandles.table_clusterProfiles.repaint();
            statToolObj.refreshScatterPlot();
            if(statToolObj.useOutcomes && ~isempty(statToolObj.outcomesObj) && statToolObj.hasValidCluster)
                statToolObj.outcomesObj.setSelectedField(eventData.fieldName);
            end
            
        end
        
        % ======================================================================
        % Obtains the intersection of exclusion structs A and B and then returns
        % the structs of each for the locations where they intersect based on same studyID and startDatenum values.        
        function [excA, excB] = intersectExclusions(exclusionsA, exclusionsB)
            a = exclusionsA;
            b = exclusionsB;
            
            a_keys = [a.studyIDs(:), a.startDatenums(:)];
            b_keys = [b.studyIDs(:), b.startDatenums(:)];
            [~, a_idx, b_idx] = intersect(a_keys, b_keys, 'rows', 'stable');
            
            fields = {'rows','startDatenums','studyIDs','startDaysOfWeek','shapes'};
            for f=1:numel(fields)
                field = fields{f};
                if isfield(a, field) && isfield(b, field)
                    if strcmpi(field, 'shapes') % 2d array
                        a.(field) = a.(field)(a_idx,:);
                        b.(field) = b.(field)(b_idx,:);
                    else
                        a.(field) = a.(field)(a_idx);
                        b.(field) = b.(field)(b_idx);
                    end
                else
                    fprintf('"%s" field does not exist in one or both structures.  Skipped this field.\n', field);
                end
            end
            
            excA = a;
            excB = b;

        end
        
        
        % Recursively attempts to match the id's and start datenums from the exclusions
        % struct to the second structure (contentToMatch).          
        function exclusions = matchExclusionsToContent(exclusions, contentToMatch)
            narginchk(2,2);
            %if nargin<3
            %    contentToMatch = this.originalFeatureStruct;
            %end
            methods = exclusions.methods;
            % match exclusions --> like intersect exclusions,
            % but only keep it to match the second entry
            for m=1:numel(methods)
                method = methods{m};
                if strcmpi(method, 'imported_file')
                    exclusions.imported_file = PAStatTool.matchExclusionsToContent(exclusions.imported_file, contentToMatch);
                else
                    exclusions.(method) = PAStatTool.intersectExclusions(exclusions.(method), contentToMatch);
                end
            end
        end
        
        % ======================================================================
        function [featureStruct, discardedFeatureStruct] = discardNonwearFeatures(featureStructIn,nonwearRows)
            %         function featureStruct = getValidFeatureStruct(originalFeatureStruct,usageStateStruct)
            featureStruct = featureStructIn;
            foi = {'startDatenums','startDaysOfWeek','shapes','studyIDs'};
            discardedFeatureStruct = mkstruct(foi);
            if(~isempty(nonwearRows) && ~isempty(featureStructIn) && any(nonwearRows))
                for f=1:numel(foi)
                    fname = foi{f};
                    discardedFeatureStruct.(fname) = featureStruct.(fname)(nonwearRows,:);
                    featureStruct.(fname)(nonwearRows,:) = [];
                end
            end
        end
        
        % nonwearMethod - A string or cell of strings representing the method(s)
        % to apply to determine which rows should be considered nonwear.
        % nonwearStruct - struct with field names keyed on the nonwearMethod
        %  - 'import' == nonwearStruct that was imported.
        %  - 'padaco' == usageStage struct (from Padaco)
        % nonwearRows = logical vector indicating which feature vectors of the second argument
        % are considered as nonwear or having data from a malfunctioning device.
        % malfunctionRows = logical vector indicating which feature vectors of the second argument
        % are considered to be due to a malfunctioning device.  This is a
        % subset of nonwearRows (i.e. a malfunction is also considered
        % nonwear, but nonwear is not necessarily due to malfunction).
        function [nonwearRows, malfunctionRows] = getNonwearRows(nonwearMethod, nonwearStruct, startEndTimes)
            nonwearRows = [];
            malfunctionRows = [];
            if nargin<3
                startEndTimes = {'0:00','24:00'};
            end
            
            if ~isempty(startEndTimes) && ~isa(startEndTimes,'duration')
                startEndTimes = duration(startEndTimes,'inputformat','hh:mm');
            end
            
            if iscell(nonwearMethod)
                for c=1:numel(nonwearMethod)
                    [tmpNonwearRows, tmpMalfunctionRows] = PAStatTool.getNonwearRows(nonwearMethod{c}, nonwearStruct, startEndTimes);
                    if isempty(nonwearRows)
                        nonwearRows = tmpNonwearRows;
                    elseif ~isempty(tmpNonwearRows)
                        nonwearRows = nonwearRows | tmpNonwearRows;
                    end
                    if isempty(malfunctionRows)
                        malfunctionRows = tmpMalfunctionRows;
                    elseif ~isempty(tmpMalfunctionRows)
                        malfunctionRows = malfunctionRows | tmpMalfunctionRows;
                    end
                end
            else
                nonwearRows = [];
                malfunctionRows = [];
                
                nonwearMethod = lower(nonwearMethod);
                nonwearStruct = getfieldi(nonwearStruct, nonwearMethod);
                switch(nonwearMethod)
                    case 'choi'
                        choiStruct = nonwearStruct;                        
                        validIdx = arrayfun(@(c) c>=startEndTimes(1) & c<=startEndTimes(2), duration(nonwearStruct.startTimes,'inputformat','hh:mm'));
                        if strcmpi(choiStruct.srcDataType, 'count')
                            nonwearRows = any(choiStruct.shapes(:, validIdx),2);
                        end
                        
                    case {'import','imported_file'}
                        if isstruct(nonwearStruct) && isfield(nonwearStruct, 'rows')
                            nonwearRows = PAStatTool.getNonwearRows(nonwearStruct.methods, nonwearStruct, startEndTimes);
                        else
                            fprintf('Imported exclusion data not found.\n');
                        end
                    case 'padaco'
                        usageStateStruct = nonwearStruct;
                        if(isstruct(usageStateStruct))
                            tagStruct = PASensorData.getActivityTags();
                            validIdx = arrayfun(@(c) c>=startEndTimes(1) & c<=startEndTimes(2), duration(nonwearStruct.startTimes,'inputformat','hh:mm'));
                        
                            % count data
                            if strcmpi(usageStateStruct.srcDataType, 'count')
                                nonwearRows = any(usageStateStruct.shapes(:, validIdx)<=tagStruct.NONWEAR,2);
                            elseif strcmpi(usageStateStruct.srcDataType, 'raw')
                                zeroDuringRows = any(usageStateStruct.shapes(:,validIdx)==tagStruct.NOT_WORKING, 2);
                                zeroStartRows = any(usageStateStruct.shapes(:,validIdx)==tagStruct.STUDY_NOT_STARTED, 2);
                                zeroEndRows = any(usageStateStruct.shapes(:,validIdx)==tagStruct.STUDYOVER, 2);
                                
                                zeroRows = zeroDuringRows| zeroStartRows| zeroEndRows;
                                stuckRows = any(usageStateStruct.shapes(:,validIdx)==tagStruct.SENSOR_STUCK,2);
                                burstRows = any(usageStateStruct.shapes(:,validIdx)==tagStruct.SENSOR_BURST, 2); % one sensor showing excessive readings for 5+ minutes.
                                malfunctionRows = stuckRows | burstRows;
                                
                                % raw data?
                                nonwearRows = zeroRows | malfunctionRows;
                                % malfunctionRows = burstRows | stuckRows;
                                %nonwearRows = nonwearRows | malfunctionRows;
                            end
                        end
                    otherwise
                end
            end
        end
        
        % ======================================================================
        %> @brief Loads and aligns features from a padaco batch process
        %> results output file.
        %> @param filename Full filename (i.e. contains absolute pathname)
        %> of features file produced by padaco's batch processing mode.
        %> @retval featureStruct A structure of aligned features obtained
        %> from filename.  Fields include:
        %> - @c filename The source filename data was loaded from.
        %> - @c method
        %> - @c signal
        %> - @c methodDescription
        %> - @c totalCount
        %> - @c startTimes
        %> - @c studyIDs
        %> - @c startDatenums
        %> - @c startDaysOfWeek
        %> - @c shapes
        %     filename='/Volumes/SeaG 1TB/accelerometer/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
        % ======================================================================
        function featureStruct = loadAlignedFeatures(filename)
            featureStruct.filename = filename;
            
            [~,fileN, ~] = fileparts(filename);
            [~, remain] = strtok(fileN,'.');
            
            [method, remain] = strtok(remain,'.');
            featureStruct.method = method;
            featureStruct.signal.tag = remain(2:end);
            
            [signalGroup, remain] = strtok(remain,'.');
            [signalSource, remain] = strtok(remain,'.');
            signalName = strtok(remain,'.');
            
            featureStruct.signal.group = signalGroup;
            featureStruct.signal.source = signalSource;
            featureStruct.signal.name = signalName;
            
            fid = fopen(filename,'r');
            
            featureStruct.methodDescription = strrep(strrep(fgetl(fid),'# Feature:',''),char(9),'');
            featureStruct.totalCount = str2double(strrep(strrep(fgetl(fid),'# Length:',''),char(9),''));
            startTimes = fgetl(fid);
            % Not necessary to remove the other headers here.
            % startTimes = strrep(fgetl(fid),sprintf('# Study_ID\tStart_Datenum\tStart_Day'),'');
            pattern = '\s+(\d+:\d+)+';
            
            result = regexp(startTimes,pattern,'tokens');
            
            startTimes = cell(size(result));
            numCols = numel(startTimes);
            
            if(numCols~=featureStruct.totalCount)
                fprintf('Warning!  The number of columns listed and the number of columns found in %s do not match.\n',filename);
            end
            for c=1:numCols
                startTimes{c} = result{c}{1};
            end
            
            featureStruct.startTimes = startTimes;
            %     urhere = ftell(fid);
            %     fseek(fid,urhere,'bof');
            
            % +3 because of study id, datenum, and start date of the week that precede the
            % time stamps.
            scanStr = repmat(' %f',1,numCols+3);
            
            C = textscan(fid,scanStr,'commentstyle','#','delimiter','\t');
            featureStruct.studyIDs = cell2mat(C(:,1));
            featureStruct.startDatenums = cell2mat(C(:,2));
            featureStruct.startDaysOfWeek = cell2mat(C(:,3));
            featureStruct.shapes = cell2mat(C(:,4:end));
            fclose(fid);
        end
        
        % ======================================================================
        %> @brief Normalizes each load according to the sum of its parts.
        %> @param loadShapes NxM array of N load shapes, each of dimension M.
        %> @retval normalizedLoadShapes NxM array of normalized load
        %> shapes, where N is the number of load shapes.
        %> normalizedLoadShapes(n,:) = loadShapes(n,:)/sum(loadShapes(n,:))
        %> @retval nzi Indices of non-zero sum load shapes.
        %> @note normalizedLoadShapes(n,:) = 0 in the case of
        %> sum(loadShapes(n,:)) is a zero sum.
        % ======================================================================
        function [normalizedLoadShapes, nzi] = normalizeLoadShapes(loadShapes)
            % normalizedLoadShapes = loadShapes;
            % a= sum(loadShapes,2);
            % %nzi = nonZeroIndices
            %nzi = a~=0;
            % normalizedLoadShapes(nzi,:) = loadShapes(nzi,:)./repmat(a(nzi),1,size(loadShapes,2));
            
            filterOrder = 10;
            if filterOrder>0
                n = filterOrder;
                b = repmat(1/n,1,n);
                % Sometimes 'single' data is loaded, particularly with raw
                % accelerations.  We need to convert to double in such
                % cases for filtfilt to work.
                if(~isa(loadShapes,'double'))
                    loadShapes = double(loadShapes);
                end
                
                % ensure we are filtering along the individual loadshapes
                % which are organized by row.  filtfilt works down columns
                % however so need to transpose, filter, and transpose back.
                loadShapes = filtfilt(b,1,loadShapes')';
            end
            
            % normalize our results...
            loadShapes = loadShapes-min(loadShapes,[],2);
            a= sum(loadShapes,2);
            nzi = a~=0;
            loadShapes(nzi,:) = loadShapes(nzi,:)./max(loadShapes(nzi,:),[],2);
            normalizedLoadShapes = loadShapes;
            
        end
        
        % ======================================================================
        %> @brief Applies a reduction or sorting method along each row of the
        %> input data and returns the result.
        %> @param featureSet NxM array of N feature sets, each of dimension M.
        %> @param reductionMethod String specifying the reduction or
        %> transformation method to apply across each row.  Recognized
        %> values include:
        %> - 'sort' sort rows from high to low
        %> - 'sum'
        %> - 'mean'
        %> - 'median'
        %> @param featureSet NxK array of N feature sets, each of dimension
        %> K, where K is 1 when reductionMethod is 'mean','median', or 'sum', and K is
        %> equal to M otherwise (eg. 'sort','none', or unrecognized)
        % ======================================================================
        function featureSet = featureSetAdjustment(featureSet, reductionMethod)
            switch(lower(reductionMethod))
                case 'sort'
                    featureSet = sort(featureSet,2,'descend'); %sort rows from high to low
                case 'mean'
                    featureSet = mean(featureSet,2);
                case 'sum'
                    featureSet = sum(featureSet,2);
                case 'median'
                    featureSet = median(featureSet,2);
                case 'max'
                    featureSet = max(featureSet,[],2);
                case 'above_50'
                    featureSet = sum(featureSet>50,2);
                case 'above_100'
                    featureSet = sum(featureSet>100,2);
                case 'above_500'
                    featureSet = sum(featureSet>500,2);
                case 'above_1000'
                    featureSet = sum(featureSet>1000,2);
                case {'romanzini_sb','romanzini_lpa','romanzini_mvpa','romanzini_mpa','romanzini_vpa','romanzini_all'}
                    fprintf(1,'Romanzini cutpoints assume Vector Magnitude counts calculated with a 1 minute epoch.\n');
                    [rziStruct, fnames, cutpoints] = getRomanziniCutpoints();
                    if strcmpi(reductionMethod, 'romanzini_all')
                        % Activity categories are ordered as [sedentary, light, moderate, vigorous]
                        reducedFeatureSet = zeros(size(featureSet,1), numel(fnames));
                        for f=1:numel(fnames)
                            reducedFeatureSet(:, f) = sum(featureSet>=cutpoints{f}(1) & featureSet<=cutpoints{f}(2),2);
                        end
                        featureSet = reducedFeatureSet;
                    else
                        rziCP = rziStruct.(lower(reductionMethod));
                        featureSet = sum(featureSet>=rziCP(1) & featureSet<=rziCP(2),2);
                    end
                case 'hours_to_80pct'
                    c = cumsum(featureSet,2);
                    total = c(:,end);
                    p_thresh = total*0.8;
                    num_features = size(featureSet,2);
                    p_index = repmat(num_features, size(p_thresh));
                    for k=1:numel(p_thresh)
                        p_index(k) = find(c(k,:)>=p_thresh(k),1,'first');
                    end
                    hrs_per_index = 24/num_features;
                    featureSet = p_index*hrs_per_index;
                case 'hours_to_50pct'
                    c = cumsum(featureSet,2);
                    total = c(:,end);
                    p_thresh = total*0.5;
                    num_features = size(featureSet,2);
                    p_index = repmat(num_features, size(p_thresh));
                    for k=1:numel(p_thresh)
                        p_index(k) = find(c(k,:)>=p_thresh(k),1,'first');
                    end
                    hrs_per_index = 24/num_features;
                    featureSet = p_index*hrs_per_index;
                case 'hours_until_50000'
                    c = cumsum(featureSet,2);
                    c_thresh = 50000;
                    num_features = size(featureSet,2);
                    p_index = repmat(num_features, size(featureSet,1),1);
                    for k=1:numel(p_index)
                        ind_k = find(c(k,:)>=c_thresh,1,'first');
                        if ~isempty(ind_k)
                            p_index(k) = ind_k;
                        end
                    end
                    hrs_per_index = 24/num_features;
                    featureSet = p_index*hrs_per_index;
                case 'none'
                otherwise
            end
        end
        
        % ======================================================================
        %> @brief Gets parameters for default initialization of a
        %> PAStatTool object.
        %> @retval Struct of default paramters.  Fields include
        %> - @c trimResults
        %> - @c cullResults
        %> - @c sortValues
        %> - @c normalizeValues
        %> - @c processedTypeSelection
        %> - @c baseFeatureSelection
        %> - @c signalSelection
        %> - @c plotTypeSelection
        %> - @c preclusterReductionSelection
        %> - @c trimToPercent
        %> - @c cullToValue
        %> - @c showClusterMembers
        %> - @c minClusters
        %> - @c clusterThreshold
        %> - @c weekdaySelection
        %> - @c startTimeSelection
        %> - @c stopTimeSelection
        %> - @c clusterDurationSelection
        % ======================================================================
        function paramStruct = getDefaults()
            % Cache directory is for storing the cluster object to
            % so it does not have to be reloaded each time when the
            % PAStatTool is instantiated.
            if(~isdeployed)
                workingPath = fileparts(mfilename('fullpath'));
            else
                workingPath = fileparts(mfilename('fullpath'));
            end
            
            baseSettings = PAStatTool.getBaseSettings();
            % Prime with cluster parameters.
            paramStruct = PACluster.getDefaults();
            
            %> Foldername of last features path selected
            paramStruct.featuresPathname = PAPathParam('default','','description','Feature-set path','help','Foldername of featurized dataset');           
            paramStruct.startWithLastPath = PABoolParam('default',false,'description','Start with last used feature set');
            
            
            paramStruct.maxNumDaysAllowed = PANumericParam('default',0,'Description','Maximum number of days allowed per subject.','help','Leave 0 to include all days.','min',0);
            paramStruct.minNumDaysAllowed = PANumericParam('default',0,'Description','Minimum number of days allowed per subject.','help','Leave 0 for no minimum.  Currently variable has no effect at all.','min',0);
            
            paramStruct.normalizeValues = PABoolParam('default',false,'description','Normalize values');
            paramStruct.discardNonwearFeatures = PABoolParam('default',true,'description','Discard nonwear features prior to clustering');
            
            paramStruct.discardMethod = PAEnumListParam('default',{'padaco'},'categories',{{'padaco','choi','imported_file'}},'description','Data exclusion method');
            paramStruct.exclusionsFilename = PAFilenameParam('default','','Description', '.mat file of times to exclude for a study group','help',sprintf('This is created using the menubar:\n File-->Export-->Clusters-->Nonwear (.mat)'));
            
            paramStruct.trimResults = PABoolParam('default',false,'description','Trim results');
            paramStruct.trimToPercent = PANumericParam('default',100,'description','Trim to percent');
            paramStruct.cullResults = PABoolParam('default',false,'description','Cull results');
            paramStruct.cullToValue = PANumericParam('default',0,'description','Cull to');
            
            paramStruct.chunkShapes = PABoolParam('default',false,'description','Chunk feature vectors prior to clustering');
            numChunks = 6;
            paramStruct.numChunks = PANumericParam('default',numChunks,'description','Number of chunks');
            paramStruct.numDataSegmentsSelection = PAIndexParam('default',find(baseSettings.numDataSegments==numChunks,1),'description','Data segments selection'); %results in number six
            
            % If we no longer have 6 as a choice, then just take the first
            % choice that is available
            if(isempty(paramStruct.numDataSegmentsSelection))
                paramStruct.numDataSegmentsSelection = PAIndexParam('default',1,'description','Data chunk size selection');
                paramStruct.numChunks.setValue(baseSettings.numDataSegments(paramStruct.numDataSegmentsSelection));
            end
            
            paramStruct.preclusterReductionSelection = PAIndexParam('default',1,'description','Preclustering data reduction method'); % defaults to 'none'
            
            paramStruct.processedTypeSelection = PAIndexParam('default',1,'description','Processed type');
            paramStruct.baseFeatureSelection =  PAIndexParam('default',1,'description','Base feature');
            paramStruct.signalSelection =       PAIndexParam('default',1,'description','Signal');
            paramStruct.plotTypeSelection =     PAIndexParam('default',1,'description','Plot type');
            
            paramStruct.startTimeSelection =    PAIndexParam('default',1,'description','Start time selection');
            paramStruct.stopTimeSelection =     PAIndexParam('default',-1,'description','Stop time selection');
            paramStruct.showTimeOfDayAsBackgroundColor = PABoolParam('default',false,'description','Show time of day visual indicator'); % do not display at first
            paramStruct.weekdaySelection =      PAIndexParam('default',1,'description','Weekday selection');
            paramStruct.customDaysOfWeek =      PANumericListParam('default',[],'min',0,'max',6,'Description','Day of week','help','0 = Sunday, 1 = Monday, ... 6 = Saturday');
            
            paramStruct.clusterDurationSelection = PAIndexParam('default',1,'description','Cluster duration');
            paramStruct.showClusterMembers =    PABoolParam('default',false,'description','Show cluster members');
            paramStruct.showClusterSummary =    PABoolParam('default',false,'description','Show cluster summary');
            paramStruct.showAnalysisFigure =            PABoolParam('default',false,'description','Show analysis figure'); % do not display the other figure at first
            
            paramStruct.primaryAxis_yLimMode =          PAEnumParam('default','auto','categories',{'auto','manual'},'description','y-axis range');
            % PACategoricalParam('default',categorical({'auto'},{'auto','manual'},'protected',true),'description','y-axis range');
            
            paramStruct.primaryAxis_nextPlot =          PAEnumParam('default','replace','categories',{{'replace','hold'}},'description','Next plot');
            
            paramStruct.primaryAxis_horizontalGrid =    PAEnumParam('default','on','categories',{{'on','off'}},'description','Horizontal grid lines');
            
            % plots clusters id's (sorted by membership in ascending order) on x-axis
            % and the count of loadshapes (i.e. membership count) on the y-axis.
            %> @brief Cluster distribution mode, which is updated from the ui
            %> contextmenu of the secondary axes.  Valid tags include
            %> - @c weekday
            %> - @c membership [default]
            
            paramStruct.clusterDistributionType = PAEnumParam('default','loadshape_membership','categories',{{'loadshape_membership','participant_membership','nonwear_membership','weekday_scores','performance_progression','weekday_membership'}},'description','Cluster distribution selection');
            
            paramStruct.useOutcomes = PABoolParam('default',false,'description','Use outcomes table');
            paramStruct.useDatabase = PABoolParam('default',false,'description','Use MySQL database');
            
            paramStruct.databaseClass = PAStringParam('default','CLASS_database_goals','description','Database classname');
            paramStruct.profileFieldSelection = PAIndexParam('default',1,'description','Profile field selection');
            paramStruct.profileFieldIndex =     PAIndexParam('default',1,'description','Profile field index'); % is one for database and the other for outcomes table?  looks redundant.
            
            paramStruct.bootstrapIterations = PANumericParam('default',100,'description','Bootstrap iterations');
            paramStruct.bootstrapSampleName = PAEnumParam('default','studyID','categories',{'studyID','days'},'description','Bootstrap sample name');
            paramStruct.exportPathname =      PAPathParam('default',getSavePath(),'Description','Export path');
            paramStruct.exportShowNonwear = PABoolParam('default',true,'description','Include nonwear with export');
            
            paramStruct.useCache = PABoolParam('default',true,'description','Use file caching','help','Turn on file caching to improve startup times.');
            paramStruct.cacheDirectory = PAPathParam('default',fullfile(workingPath,'cache'),'description','Caching directory');
            
            
            paramStruct.predictionStrength_minK = PANumericParam('default',2,'min',2,'description','Prediction strength: minimum K',...
                'help','The initial value of K evaluated determining prediction strength for a range of K.');
            paramStruct.predictionStrength_maxK = PANumericParam('default',10,'min',2,'description','Prediction strength: maximum K',...
                'help','The final value of K evaluated when determining prediction strength for a range of K.');
            paramStruct.predictionStrength_iterations = PANumericParam('default',20,'min',1,'description','Prediction strength: bootstrap iterations per K',...
                'help','The number of iterations performed to evaluate the prediction strength for each value of K considered.');
            
            %             paramStruct.exportShowNonwear = true;
            %             paramStruct.cacheDirectory = fullfile(workingPath,'cache');
            %             paramStruct.useCache = 1;
            %
            %             paramStruct.useOutcomes = 0;
            %             paramStruct.useDatabase = 0;
            %             paramStruct.profileFieldIndex = 1;
            %             paramStruct.databaseClass = 'CLASS_database_goals';
            %             paramStruct.discardNonwearFeatures = 1;
            %             paramStruct.trimResults = 0;
            %             paramStruct.cullResults = 0;
            %             paramStruct.chunkShapes = 0;
            %             paramStruct.numChunks = 6;
            %             paramStruct.numDataSegmentsSelection = find(baseSettings.numDataSegments==paramStruct.numChunks,1); %results in number six
            %
            %             % If we no longer have 6 as a choice, then just take the first
            %             % choice that is available
            %             if(isempty(paramStruct.numDataSegmentsSelection))
            %                 paramStruct.numDataSegmentsSelection = 1;
            %                 paramStruct.numChunks=baseSettings.numDataSegments(paramStruct.numDataSegmentsSelection);
            %             end
            %
            %             paramStruct.preclusterReductionSelection = 1; % defaults to 'none'
            %
            %             paramStruct.maxNumDaysAllowed = 0; % Maximum number of days allowed per subject.  Leave 0 to include all days.
            %             paramStruct.minNumDaysAllowed = 0; % Minimum number of days allowed per subject.  Leave 0 for no minimum.  Currently variable has no effect at all.
            %
            %             paramStruct.normalizeValues = 0;
            %             paramStruct.processedTypeSelection = 1;
            %             paramStruct.baseFeatureSelection = 1;
            %             paramStruct.signalSelection = 1;
            %             paramStruct.plotTypeSelection = 1;
            %             paramStruct.trimToPercent = 100;
            %             paramStruct.cullToValue = 0;
            %             paramStruct.showClusterMembers = 0;
            %             paramStruct.showClusterSummary = 0;
            %
            %             paramStruct.weekdaySelection = 1;
            %             paramStruct.startTimeSelection = 1;
            %             paramStruct.stopTimeSelection = -1;
            %             paramStruct.customDaysOfWeek = 0;  %for sunday.
            %
            %             paramStruct.clusterDurationSelection = 1;
            %
            %             paramStruct.primaryAxis_yLimMode = 'auto';
            %             paramStruct.primaryAxis_nextPlot = 'replace';
            %             paramStruct.showAnalysisFigure = 0; % do not display the other figure at first
            %             paramStruct.showTimeOfDayAsBackgroundColor = 0; % do not display at first
            %             paramStruct.clusterDistributionType = 'loadshape_membership';  %{'loadshape_membership','participant_membership','performance_progression','membership','weekday_membership'}
            %             paramStruct.profileFieldSelection = 1;
            %
            %             paramStruct.bootstrapIterations =  100;
            %             paramStruct.bootstrapSampleName = 'studyID';  % or 'days'
            %
            %             paramStruct.exportPathname = '';
            %
        end
        
        % ======================================================================
        %> @brief Gets default parameter selection values for GUI dropdown menus
        %> used in conjunction with PAStatTool.
        %> @retval Struct of default menu selection values.  Fields include
        %> - @c featureDescriptions
        %> - @c featureTypes
        %> - @c signalTypes
        %> - @c signalDescriptions
        %> - @c plotTypes
        %> - @c plotTypeDescription
        %> - @c processedTypes
        %> - @c numShades
        %> - @c weekdayDescriptions
        %> - @c weekdayTags
        % ======================================================================
        function baseSettings = getBaseSettings()
            featureDescriptionStruct = PASensorData.getFeatureDescriptionStructWithPSDBands();
            
            featureDescriptionStruct.nonwear_choi = 'Nonwear (choi)';
            baseSettings.featureDescriptions = struct2cell(featureDescriptionStruct);
            baseSettings.featureTypes = fieldnames(featureDescriptionStruct);
            baseSettings.signalTypes = {'x','y','z','vecMag'};
            baseSettings.signalDescriptions = {'X','Y','Z','VecMag'};
            
            reduction_dictionary = {'none','None';
                'sort','Sort (high->low)';
                'sum','Sum';
                'mean','Mean';
                'median','Median';
                'max','Maximum';
                'romanzini_sb','Minutes of SB (Romanzini)';
                'romanzini_lpa','Minutes of LPA (Romanzini)';
                'romanzini_mvpa','Minutes of MVPA (Romanzini)';
                'romanzini_mpa','Minutes of MPA (Romanzini)';
                'romanzini_vpa','Minutes of VPA (Romanzini)';
                'romanzini_all','Minutes of [SB, LPA, MPA, VPA] (Romanzini)';
                'above_1000','Occurrences > 1000';
                'above_500','Occurrences > 500';
                'above_100','Occurrences > 100';
                'above_50','Occurrences > 50';
                'hours_to_80pct','Hours until 80%';
                'hours_to_50pct','Hours until 50%';
                'hours_until_50000','Hours until 50000 counts';
                };
            
            baseSettings.preclusterReductions = reduction_dictionary(:,1);
            baseSettings.preclusterReductionDescriptions = reduction_dictionary(:,2);
            
            % numChunks.  nan indicates a custom selection
            baseSettings.numDataSegments = [1,2,3,4,6,8,12,24, nan]';
            baseSettings.numDataSegmentsDescriptions = cellstr(num2str(baseSettings.numDataSegments(:)));
            baseSettings.numDataSegmentsDescriptions{end} = 'Custom';
            
            baseSettings.plotTypes = {'clustering','dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling'};
            baseSettings.plotTypeTitles = {'';
                'Average Daily Tallies (total daily tally divided by number of subjects that day)';
                'Total Daily Tallies';
                'Heat map (early morning)';
                'Heat map';
                'Rolling Map';
                'Morning Rolling Map (00:00-06:00AM daily)';
                };
            
            baseSettings.plotTypeDescriptions = {'Clusters','Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)'};
            baseSettings.plotTypeToolTipStrings = {
                sprintf('Clustering view present the adaptive clustering results (clusters or medoids) for the selected\n features and clustering parameters given in the controls below.');
                sprintf('The daily average is calculated by taking the average feature sum per subject taken by day of the week.\n  The results should not be as biased by the number of subjects participating in any particular day.');
                sprintf('The daily tally is calculated by summing together the feature sums of each subject taken by day of the week.\n  Days with more subjects have a much greater chance of having higher sums.');
                sprintf('The morning heat map presents the average sum of early morning activity as color intensity instead of height on the y-axis.\n  It focuses on the early part of each day.');
                sprintf('The heat map presents the average sum of daily activity\n as color intensity instead of height on the y-axis.');
                sprintf('The rolling map shows the linear progression of the\n sum of subject activity by day of the week.');
                sprintf('The early morning rolling map shows the linear progression\n of the sum of subject activity for the early part of each day of the week.');
                };
            
            for b=1:numel(baseSettings.plotTypes)
                plotType = baseSettings.plotTypes{b};
                baseSettings.tooltipstring.(plotType) = baseSettings.plotTypeToolTipStrings{b};
            end
            
            baseSettings.processedTypes = {'count','raw'};
            baseSettings.numShades = 1000;
            
            baseSettings.weekdayDescriptions = {'All days','Sun-Sat (week)','Mon-Fri','Weekend','Custom'};
            baseSettings.weekdayTags = {'all','weeklong','weekdays','weekends','custom'};
            baseSettings.weekdayValues = {0:6,0:6,1:5,[0,6],[]};
            baseSettings.daysOfWeekShortDescriptions = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            baseSettings.daysOfWeekDescriptions = {'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};
            baseSettings.daysOfWeekOrder = 1:7;
            
            
            baseSettings.clusterDurationDescriptions = {'1 day'   ,'12 hours','6 hours','4 hours','3 hours','2 hours','1 hour'};
            baseSettings.clusterDurationDescriptions = {'24 hours','12 hours','6 hours','4 hours','3 hours','2 hours','1 hour'};
            
            baseSettings.clusterHourlyDurations = [24
                12
                6
                4
                3
                2
                1];
        end
        
        % ======================================================================
        %> @bretval Profile cell is output as follows
        %> - @c 'n'
        %> - @c 'n_above'
        %> - @c 'n_below'
        %> - @c 'mx'
        %> - @c 'var'
        %> - @c 'sem'
        %> - @c 'string'
        % ======================================================================
        function profileCell = profile2cell(profileStruct)
            rowNames = fieldnames(profileStruct);
            numRows = numel(rowNames);
            colNames = fieldnames(profileStruct.(rowNames{1}));
            numCols = numel(colNames);
            profileCell = cell(numRows,numCols);
            for row = 1:numRows
                profileCell(row,:) = struct2cell(profileStruct.(rowNames{row}))';
            end
            
            indicesOfInterest = [1,4,6];  %n, mx, sem
            profileCell = profileCell(:,indicesOfInterest);
        end
    end
end
% ======================================================================
%> @file PAStatTool.cpp
%> @brief PAStatTool serves as Padaco's batch results analysis controller
% ======================================================================
classdef PAStatTool < handle
    events
       UserCancel_Event;
       ProfileFieldSelectionChange_Event;
    end
    
    properties(Constant)
       RESULTS_CACHE_FILENAME = 'results.tmp';
       COLOR_MEMBERSHAPE = [0.85 0.85 0.85];
       COLOR_LINESELECTION = [0.8 0.1 0.1];
       COLOR_MEMBERID = [0.1 0.1 0.8];
    end
    properties(Access=private)
        resultsDirectory;
        featuresDirectory;
        cacheDirectory;
        
        %> @brief Struct with key value pairs for clustering:
        %> - @c clusterMethod Cluster method employed {'kmeans','kmedoids'}
        %> - @c useDefaultRandomizer = widgetSettings.useDefaultRandomizer;
        %> - @c initCentroidWithPermutation = settings.initCentroidWithPermutation;
        %> @note Initialized in the setWidgetSettings() method
        clusterSettings;
        
        %> Booleans
        useCache;
        useDatabase;
        
        databaseObj;
        %> handle of scatter plot figure.
        analysisFigureH;
        
        %> handle of the main parent figure
        figureH;
        featureInputFilePattern;
        featureInputFileFieldnames;
        %> Structure of original loaded features, that are a direct
        %> replication of the data obtained from disk (i.e. without further
        %> filtering).
        originalFeatureStruct;
        %> Structure initialized to input widget settings when passed to
        %> the constructor (and is empty otherwise).  This is used to
        %> 'reset' parameters and keep track of time start and stop
        %> selection fields which are not initialized until after data has
        %> been load (i.e. and populates the dropdown menus.
        originalWidgetSettings;
        %> structure loaded features which is as current or as in sync with the gui settings 
        %> as of the last time the 'Calculate' button was
        %> pressed/manipulated.
        featureStruct;
        
        %> structure containing Usage Activity feature output by padaco's batch tool.
        %> This is used to obtain removal indices when loading data (i.e.
        %> non-wear/study over state)
        usageStateStruct;
        
        %> struct of handles that PAStatTool interacts with.  See
        %> initHandles()
        %> Includes contextmenu
        handles; 
        
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
        %> - @c sortValues The value of the check_sortvalues widget
        %> - @c normalizeValues The value of the check_normalizevalues widget
        %> - @c plotType The tag of the current plot type 
        %> - @c colorMap - colormap of figure;
        %> These are initialized in the initWidgets() method.
        previousState;
        %> instance of PACentroid class
        centroidObj;  
        %> @brief Centroid distribution mode, which is updated from the ui
        %> contextmenu of the secondary axes.  Valid tags include
        %> - @c weekday
        %> - @c membership [default]        
        centroidDistributionType;
        
        %> @brief Struct with fields consisting of summary statistics for
        %> field names contained in the subject info table of the goals
        %> database for all centroids. 
        %> @note Database must be developed and maintained externally
        %> to Padaco.
        globalProfile;

        %> @brief Struct with fields consisting of summary statistics for
        %> field names contained in the subject info table of the goals
        %> database for the centroid of interest. 
        %> @note Database must be developed and maintained externally
        %> to Padaco.
        coiProfile;
        
        
        %> @brief Fx3xC matrix where N is the number of covariate fields
        %> to be analyzed and C is the number of centroids.  '3' represents
        %> the columns: n, mean, and standard error of the mean for the
        %> subjects in centroid c with values found in covariate f.
        allProfiles;
        profileTableData;
    end
    
    properties
        %> struct of fields to use when profiling/describing centroids.
        %> These are names of database fields extracted which are keyed on
        %> the subject id's that are members of the centroid of interest.
        profileFields;
    end
    
    methods        

        
        % ======================================================================
        %> @brief Constructor for PAStatTool
        %> @param padaco_fig_h Handle to figure to be instantiated with
        %> @param resultsPathname
        %> @param optional struct with field value pairs for initializing
        %> user settings.  See getSaveParameters
        %> @retval this Instance of PAStatTool
        % ======================================================================
        function this = PAStatTool(padaco_fig_h, resultsPathname, widgetSettings)
            if(nargin<3 || isempty(widgetSettings))
                widgetSettings = PAStatTool.getDefaultParameters();
            end
            
                
            % This call ensures that we have at a minimum, the default parameter field-values in widgetSettings.
            % And eliminates later calls to determine if a field exists
            % or not in the input widgetSettings parameter
            widgetSettings = PAData.mergeStruct(PAStatTool.getDefaultParameters,widgetSettings);
            
            if(~isfield(widgetSettings,'useDatabase'))
                widgetSettings.useDatabase = false;
            end
            
            
            
            
%             catch me
%                 showME(me);
%                 this.databaseObj = [];
%                 this.profileFields = {
%                     'bmi_zscore';
%                     'insulin'
%                     };
%             end
            
            this.globalProfile  = [];
            this.coiProfile = [];
            this.allProfiles = [];
            
            % variable names for the table
            %             this.profileMetrics = {''};

            initializeOnSet = false;
            this.setWidgetSettings(widgetSettings, initializeOnSet);
            
            this.originalFeatureStruct = [];
            this.canPlot = false;
            this.featuresDirectory = [];

            
            this.figureH = padaco_fig_h;
            this.featureStruct = [];
            
            this.initScatterPlotFigure();
            
            this.initHandles();            
            this.initBase();
            this.centroidDistributionType = widgetSettings.centroidDistributionType;  % {'performance','membership','weekday'}
            
            this.featureInputFilePattern = ['%s',filesep,'%s',filesep,'features.%s.accel.%s.%s.txt'];
            this.featureInputFileFieldnames = {'inputPathname','displaySeletion','processType','curSignal'};       
            
            if(isdir(resultsPathname))
                this.resultsDirectory = resultsPathname;
                featuresPath = fullfile(resultsPathname,'features');
                
                % We are allowing user to pick a folder that contains
                % 'features' as a subfolder, or the folder whose subfolders
                % are in fact the feature subfolders.  This will give a
                % little more flexibility to the user and hopefully hide
                % some of the more mundane parts of loading a path.
                if(~isdir(featuresPath))
                    featuresPath = resultsPathname;
                    % fprintf('Assuming features pathFeatures pathname (%s) does not exist!\n',featuresPath);
                end
                this.featuresDirectory = featuresPath;
                
                this.initWidgets(widgetSettings);  %initializes previousstate.plotType on success

                plotType = this.base.plotTypes{get(this.handles.menu_plottype,'value')};
                this.clearPlots();
                
                if(exist(this.getFullCentroidCacheFilename(),'file') && this.useCache)

                    try
                        validFields = {'centroidObj';
                            'featureStruct';
                            'originalFeatureStruct'
                            'usageStateStruct'
                            'resultsDirectory'
                            'featuresDirectory'};
                        tmpStruct = load(this.getFullCentroidCacheFilename(),'-mat',validFields{:});
                        
                        % Double check that the cached data is still there in
                        % the expected results directory. We give results and
                        % features directory of the current object precendence
                        % over that found in the cache (e.g. we don't overwrite
                        % this.featuresDirectory with tmpStruct.featuresDirectory
                        if(strcmpi(tmpStruct.featuresDirectory,this.featuresDirectory))
                            for f = 1:numel(validFields)
                                curField = validFields{f};
                                if(isfield(tmpStruct,curField))
                                    curValue = tmpStruct.(curField);
                                    if((strcmp(curField,'centroidObj') && isa(curValue,'PACentroid'))||...
                                            (~strcmpi(curField,'centroidObj') && isstruct(curValue)))
                                        this.(curField) = curValue;
                                    end
                                end
                            end
                            % updates our features and start/stop times
                            this.setStartTimes(this.originalFeatureStruct.startTimes);
                                                        
                            % Updates our scatter plot as applicable.
                            this.refreshGlobalProfile();
                        end
                    catch me
                        showME(me);
                    end
                    
                end
                
                set(padaco_fig_h,'visible','on');                

                if(this.getCanPlot())
                    switch(plotType)
                        case 'centroids'
                            this.switch2clustering();
                        otherwise
                            this.switchFromClustering();
                    end
                end
            else
                fprintf('%s does not exist!\n',resultsPathname); 
            end
            this.addlistener('ProfileFieldSelectionChange_Event',@this.profileFieldSelectionChangeCallback);
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
            delete@handle(this);
        end

        %> @brief Returns boolean indicator if results view is showing
        %> clusters (plot type 'centroids') or not.
        function clusterView = inClusterView(this)
            clusterView = strcmpi(this.getPlotType(),'centroids');
        end
        
        function plotType = getPlotType(this)
            plotType = getMenuUserData(this.handles.menu_plottype);
        end
        
        % ======================================================================
        %> @brief Get method for centroidObj instance variable.
        %> @param this Instance of PAStatTool
        %> @retval Instance of PACentroid or []
        % ======================================================================
        function centroidObj = getCentroidObj(this)
            centroidObj = this.centroidObj;
        end
        
        % ======================================================================
        % ======================================================================
        function centroidExists = hasCentroid(this)
            centroidExists = ~isempty(this.centroidObj) && isa(this.centroidObj,'PACentroid');
        end
        
        % ======================================================================
        %> @brief Get method for canPlot instance variable.
        %> @param this Instance of PAStatTool
        %> @retval canPlot Boolean (true if results are loaded and displayable).
        % ======================================================================
        function canPlotValue = getCanPlot(this)
            canPlotValue = this.canPlot;
        end
        
        % ======================================================================
        %> @brief Returns plot settings that can be used to initialize a
        %> a PAStatTool with the same settings.
        %> @param this Instance of PAStatTool
        %> @retval Structure of current plot settings.
        % ======================================================================
        function paramStruct = getSaveParameters(this)
            paramStruct = this.getPlotSettings();            
            
            % Parameters not stored in figure widgets
            paramStruct.useDatabase = this.useDatabase;
            paramStruct.databaseClass = this.originalWidgetSettings.databaseClass;
            paramStruct.useCache = this.useCache;
            paramStruct.cacheDirectory = this.cacheDirectory;            
        end
        
        % ======================================================================
        %> @brief Sets the widget settings.  In particular, set the
        %> originalWidgetSettings property to the input struct.
        %> @param this Instance of PAStatTool
        %> @param Struct of settings for the Stat tool.  Should conform to
        %> getDefaultParameters
        %> @param initializeOnSet Optional flag that defaults to {True}.
        %> When true, initWidgets() is called using the input widgetSettings.
        %> When false, initWidgets is not called (helpful on construction)
        % ======================================================================
        function setWidgetSettings(this,widgetSettings, initializeOnSet)
            if(nargin<3 || isempty(initializeOnSet) || ~islogical(initializeOnSet))
                initializeOnSet = true;
            end
            this.originalWidgetSettings = widgetSettings;
            
            % Merge the defaults with what is here otherwise.  
            this.setUseDatabase(widgetSettings.useDatabase);
            this.useCache = widgetSettings.useCache;
            this.cacheDirectory = widgetSettings.cacheDirectory;
            this.clusterSettings.clusterMethod = widgetSettings.clusterMethod;
            this.clusterSettings.useDefaultRandomizer = widgetSettings.useDefaultRandomizer;
            this.clusterSettings.initCentroidWithPermutation = widgetSettings.initCentroidWithPermutation;
            if(initializeOnSet)
                this.initWidgets(this.originalWidgetSettings);
%                 this.refreshPlot();
            end
        end
        
        % ======================================================================
        %> @brief Sets the start and stop time dropdown menu content and
        %> returns the selection.  
        %> @param this Instance of PAStatTool
        %> @param Cell string of times that can be selected to define a
        %> range of time to calculate centroid profiles from.
        %> @retval Selection value for the menu_centroidStartTime menu.
        %> @retval Selection value for the menu_centroidStopTime menu.
        % ======================================================================
        function [startTimeSelection, stopTimeSelection ] = setStartTimes(this,startTimeCellStr)
            if(~isempty(this.originalWidgetSettings))
                stopTimeSelection = this.originalWidgetSettings.stopTimeSelection;
                if(stopTimeSelection<=0 || stopTimeSelection == 1)
                    stopTimeSelection = numel(startTimeCellStr);
                end
                startTimeSelection = this.originalWidgetSettings.startTimeSelection;
                if(startTimeSelection>numel(startTimeCellStr) || stopTimeSelection>numel(startTimeCellStr))
                    startTimeSelection = 1;
                    stopTimeSelection = numel(startTimeCellStr);                
                end
            else
                startTimeSelection = 1;
                stopTimeSelection = numel(startTimeCellStr);
            end
            
            stopTimeCellStr = circshift(startTimeCellStr(:),-1);
            set(this.handles.menu_centroidStartTime,'string',startTimeCellStr,'value',startTimeSelection);
            set(this.handles.menu_centroidStopTime,'string',stopTimeCellStr,'value',stopTimeSelection);
        end
        
        % ======================================================================
        %> @brief Loads feature struct from disk using results feature
        %> directory.
        %> @param this Instance of PAStatTool
        %> @retval success Boolean: true if features are loaded from file.  False if they are not.
        % ======================================================================
        function didCalc = calcFeatureStruct(this)
            pSettings = this.getPlotSettings();
            inputFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);

            if(exist(inputFilename,'file'))

                usageFeature = 'usagestate';
                usageFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,usageFeature,usageFeature,'count','vecMag');
                
                % Double check that we haven't switched paths somewhere and
                % are still using a previous copy of usageStateStruct (i.e.
                % check usageFilename against this.usageStateStruct.filename)
                if(isempty(this.usageStateStruct) || ~strcmpi(usageFilename,this.usageStateStruct.filename))
                    if(exist(usageFilename,'file'))
                        this.usageStateStruct= this.loadAlignedFeatures(usageFilename);
                    end
                end
                
                loadFileRequired = isempty(this.originalFeatureStruct) || ~strcmpi(inputFilename,this.originalFeatureStruct.filename);                    
                if(loadFileRequired)
                    this.originalFeatureStruct = this.loadAlignedFeatures(inputFilename);                    
                    
                    % The call to setStartTimes here is no longer
                    % necessary here, if it ever was.  It results in
                    % updating the start/stop GUI times with the original
                    % widget settings that PAStatTool was constructed with,
                    % which may very well be different than those loaded
                    % now.  The problem of having a directory or file with
                    % start/stop times outside the GUI range may still need
                    % to be addressed at some point, somehow.
                    %[pSettings.startTimeSelection, pSettings.stopTimeSelection] = this.setStartTimes(this.originalFeatureStruct.startTimes);
                end
                
                tmpFeatureStruct = this.originalFeatureStruct;
                tmpUsageStateStruct = this.usageStateStruct;
                startTimeSelection = pSettings.startTimeSelection;
                stopTimeSelection = pSettings.stopTimeSelection;
%                 if(stopTimeSelection<1)
                    % Do nothing; this means, that we started at rayday and
                    % will go 24 hours
                if(stopTimeSelection== startTimeSelection)
                    if(this.inClusterView())
                        warndlg('Only one time epoch selected - defaulting to all epochs instead.');
                    end
                    %startTimeSelection = 1;
                    %stopTimeSelection = 
                    
                elseif(startTimeSelection < stopTimeSelection)
                    tmpFeatureStruct.startTimes = tmpFeatureStruct.startTimes(startTimeSelection:stopTimeSelection);
                    tmpFeatureStruct.shapes = tmpFeatureStruct.shapes(:,startTimeSelection:stopTimeSelection);      
                    tmpFeatureStruct.totalCount = numel(tmpFeatureStruct.startTimes);
                
                    tmpUsageStateStruct.startTimes = tmpUsageStateStruct.startTimes(startTimeSelection:stopTimeSelection);
                    tmpUsageStateStruct.shapes = tmpUsageStateStruct.shapes(:,startTimeSelection:stopTimeSelection);      
                    tmpUsageStateStruct.totalCount = numel(tmpUsageStateStruct.startTimes);
                
                % For example:  22:00 to 04:00 is ~ stopTimeSelection = 22 and
                % startTimeSelection = 81
                elseif(stopTimeSelection < startTimeSelection)
                    tmpFeatureStruct.startTimes = [tmpFeatureStruct.startTimes(startTimeSelection:end),tmpFeatureStruct.startTimes(1:stopTimeSelection)];
                    tmpFeatureStruct.shapes = [tmpFeatureStruct.shapes(:,startTimeSelection:end),tmpFeatureStruct.shapes(:,1:stopTimeSelection)];
                    tmpFeatureStruct.totalCount = numel(tmpFeatureStruct.startTimes);
                
                    tmpUsageStateStruct.startTimes = [tmpUsageStateStruct.startTimes(startTimeSelection:end),tmpUsageStateStruct.startTimes(1:stopTimeSelection)];
                    tmpUsageStateStruct.shapes = [tmpUsageStateStruct.shapes(:,startTimeSelection:end),tmpUsageStateStruct.shapes(:,1:stopTimeSelection)];
                    tmpUsageStateStruct.totalCount = numel(tmpUsageStateStruct.startTimes);
                else
                    warndlg('Something unexpected happened');
                end
                if(pSettings.discardNonWearFeatures)
                    this.featureStruct = this.discardNonWearFeatures(tmpFeatureStruct,tmpUsageStateStruct);
                else
                    this.featureStruct = tmpFeatureStruct;                    
                end
                
                loadFeatures = this.featureStruct.shapes;

                if(pSettings.centroidDurationHours~=24)

                    hoursPerCentroid = pSettings.centroidDurationHours;
                    repRows = featureDurationInHours/hoursPerCentroid;
                    
                    this.featureStruct.totalCount = this.featureStruct.totalCount/repRows;
                    
                    % This will put the start days of week in the same
                    % order as the loadFeatures after their reshaping below
                    % (which causes the interspersion).
                    this.featureStruct.startDaysOfWeek = repmat(this.featureStruct.startDaysOfWeek,1,repRows)';
                    this.featureStruct.startDaysOfWeek = this.featureStruct.startDaysOfWeek(:);
                    
                    [nrow,ncol] = size(loadFeatures);
                    newRowCount = nrow*repRows;
                    newColCount = ncol/repRows;
                    loadFeatures = reshape(loadFeatures',newColCount,newRowCount)';
                    
                    %  durationHoursPerFeature = 24/this.featureStruct.totalCount;
                    % featuresPerHour = this.featureStruct.totalCount/24;
                    % featuresPerCentroid = hoursPerCentroid*featuresPerHour;
                end
                
                if(pSettings.sortValues)
                    
                    if(pSettings.segmentSortValues && pSettings.numSortedSegments>1)
                        % 1. Reshape the loadFeatures by segments
                        % 2. Sort the loadfeatures
                        % 3. Resahpe the load features back to the original
                        % way
                        
                        % Or make a for loop and sort along the way ...
                        sections = round(linspace(0,size(loadFeatures,2),pSettings.numSortedSegments+1));  %Round to give integer indices
                        for s=1:numel(sections)-1
                            sectionInd = sections(s)+1:sections(s+1); % Create consecutive, non-overlapping sections of column indices.
                            loadFeatures(:,sectionInd) = sort(loadFeatures(:,sectionInd),2,'descend');  %sort rows from high to low
                        end
                        
                    else
                        loadFeatures = sort(loadFeatures,2,'descend');  %sort rows from high to low
                    end
                end
                
                if(pSettings.trimResults)
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
        function init(this)
            this.initWidgets(this.getPlotSettings);
            this.plotSelectionChange(this.handles.menu_plottype);
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
                    case 'centroids'
                        this.plotCentroids(pSettings);
                        this.enableCentroidRecalculation();
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
        
        function enable(obj)
            obj.setEnableState('on');
        end
        
        function disable(obj)
            obj.setEnableState('off');
        end
        
        % Enable state should be 'on','off', or empty (defaults to 'off').
        function setEnableState(obj, enableState)
            
            resultPanels = [
                obj.handles.panel_results;
                obj.handles.panel_controlCentroid;
                ];
            
            switch( enableState )
                case 'off'
                    set(findall(resultPanels,'enable','on'),'enable','off');
                case 'on'
                    set(findall(resultPanels,'enable','off'),'enable','on');
            end
            
            if(obj.inClusterView())
                set(resultPanels,'visible','on');
            else
                set(resultPanels(1),'visible','on');
                set(resultPanels(2),'visible','off');
            end
        end
        
        
        function fullFilename = getFullCentroidCacheFilename(this)
            fullFilename = fullfile(this.cacheDirectory,this.RESULTS_CACHE_FILENAME);
        end
        
        % ======================================================================
        %> @brief Checks if a centroid object member (instance of
        %> PACentroid) exists and converged.
        %> @param this Instance of PAStatTool
        %> @retval isValid (boolean) True if a centroid object (instance of
        %> PACentroid) exists and converged; False otherwise
        % ======================================================================
        function isValid = hasValidCentroid(this)
            isValid = ~(isempty(this.centroidObj) || this.centroidObj.failedToConverge());
        end 


    end
    
    methods(Access=private)
        % Methods are interfacing with membershape lines of a cluster.
        %> @brief Selected membershape's contextmenu callback for drawing
        %> all membershapes associated with the ID.
        function showSelectedMemberShapesCallback(this, ~,~)
            lineH = get(this.figureH,'currentObject');
            memberID = get(lineH,'userdata');
            [memberLoadShapes, memberLoadShapeDayOfWeek, memberCentroidInd, memberCentroidShapes] = this.centroidObj.getMemberShapesForID(memberID);
            
            nextPlot = get(this.handles.axes_primary,'nextplot');
            set(this.handles.axes_primary,'nextplot','add');
            plot(this.handles.axes_primary,memberLoadShapes','--','linewidth',1,'color', this.COLOR_MEMBERID);
            set(this.handles.axes_primary,'nextplot',nextPlot);
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
            if(strcmpi(get(lineH,'selected'),'off'))
                set(lineH,'selected','on','color',this.COLOR_LINESELECTION);
                

            % Toggle off
            else
                set(lineH,'selected','off','color',this.COLOR_MEMBERSHAPE);
            end
        end
        
        %> @brief Database functionality
        function didSet = setUseDatabase(this, willSet)
            if(nargin>1)
                this.useDatabase = willSet && true;
                this.useDatabase = this.initDatabaseObj();% initDatabase returns false if it fails to initialize and is supposed to.
            else
                didSet = false;
            end
        end
        function didInit = initDatabaseObj(this)
            didInit = false;
            try
                if(this.useDatabase)
                    this.databaseObj = feval(this.originalWidgetSettings.databaseClass);
                    this.profileFields = this.databaseObj.getColumnNames('subjectInfo_t');
                    addpath('/users/unknown/Google Drive/work/Stanford - Pediatrics/code/models');
                    addpath('/Users/unknown/Google Drive/work/Informaton/code/matlab/gee');
                    didInit = true;
                else
                    this.databaseObj = [];
                    this.profileFields = {''};                    
                end
            catch me
                showME(me);
                this.databaseObj = [];
                this.useDatabase = false;
                this.profileFields = {''};
            end
            
        end
        % ======================================================================
        %> @brief Shows busy state: Disables all non-centroid panel widgets
        %> and mouse pointer becomes a watch.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function showBusy(this)
            set(findall(this.handles.panels_sansCentroids,'enable','on'),'enable','off');
            set(this.figureH,'pointer','watch');
            drawnow();
        end
        
        % ======================================================================
        %> @brief Shows busy state (mouse pointer becomes a watch)
        %> @param this Instance of PAStatTool
        % ======================================================================        
        function showMouseBusy(this)
            set(this.figureH,'pointer','watch');
            drawnow();            
        end
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param obj Instance of PAStatTool
        % --------------------------------------------------------------------
        function showMouseReady(this)
            set(this.figureH,'pointer','arrow');
            drawnow();
        end     
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status: enables all non centroid panels and mouse becomes the default arrow pointer.
        %> @param obj Instance of PAStatTool
        % --------------------------------------------------------------------
        function showReady(this)
            set(findall(this.handles.panels_sansCentroids,'enable','off'),'enable','on');
            set(this.figureH,'pointer','arrow');
            
            %             set(this.handles.panel_results,'enable','on');
            drawnow();
        end
                
        % ======================================================================
        %> @brief Plot dropdown selection menu callback.
        %> @param this Instance of PAStatTool
        %> @param Handle of the dropdown menu.
        %> @param unused
        % ======================================================================
        function plotSelectionChange(this, menuHandle, ~)
            this.clearPlots();
            plotType = this.getPlotType();  %this.base.plotTypes{get(menuHandle,'value')};
            set(menuHandle,'tooltipstring',this.base.tooltipstring.(plotType));
            switch(plotType)
                case 'centroids'
                    this.switch2clustering();
                otherwise
                    if(strcmpi(this.previousState.plotType,'centroids'))
                        this.switchFromClustering();
                    else
                        this.refreshPlot();
                    end
            end
            this.previousState.plotType = plotType;
        end
        

        
        % ======================================================================
        %> @brief Window key press callback for centroid view changes
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
                    set(this.handles.push_nextCentroid,'enable','off');
                    this.showNextCentroid(toggleOn);
                    set(this.handles.push_nextCentroid,'enable','on');
                    drawnow();
                case 'leftarrow'
                    set(this.handles.push_previousCentroid,'enable','off');                    
                    this.showPreviousCentroid(toggleOn);               
                    set(this.handles.push_previousCentroid,'enable','on'); 
                    drawnow();
                case 'uparrow'
                    if(figH == this.analysisFigureH)
                        this.decreaseProfileFieldSelection();
                    elseif(figH == this.figureH)
                        this.showNextCentroid(toggleOn);
                    end
                case 'downarrow'
                    if(figH == this.analysisFigureH)
                        this.increaseProfileFieldSelection();
                    elseif(figH == this.figureH)
                        this.showPreviousCentroid(toggleOn);
                    end
                otherwise                
            end
        end
        
        

        % ======================================================================
        %> @brief Mouse button callback when clicking on the centroid
        %> day-of-week distribution histogram. Clicking on this will add/remove
        %> the selected day of the week from the plot
        %> @param this Instance of PAStatTool
        %> @param hObject Handle to the bar graph.
        %> @param eventdata Struct of 'hit' even data.
        % ======================================================================
        function centroidDayOfWeekHistogramButtonDownFcn(this,histogramH,eventdata, overlayingPatchHandles)
            xHit = eventdata.IntersectionPoint(1);
            barWidth = 1;  % histogramH.BarWidth is 0.8 by default, but leaves 0.2 of ambiguity between adjancent bars.
            xStartStop = [histogramH.XData(:)-barWidth/2, histogramH.XData(:)+barWidth/2];
            selectedBarIndex = find( xStartStop(:,1)<xHit & xStartStop(:,2)>xHit ,1);
            selectedDayOfInterest = selectedBarIndex-1;
            this.centroidObj.toggleDayOfInterestOrder(selectedDayOfInterest);
            
            daysOfInterest = this.centroidObj.getDaysOfInterest();
            if(daysOfInterest(selectedBarIndex))
                set(overlayingPatchHandles(selectedBarIndex),'visible','off');
            else
                set(overlayingPatchHandles(selectedBarIndex),'visible','on');
            end
            this.plotCentroids();
        end

                
        % ======================================================================
        %> @brief Mouse button callback when clicking on the centroid
        %> distribution histogram.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle to the bar graph.
        %> @param eventdata Struct of 'hit' even data.
        % ======================================================================
        function centroidHistogramButtonDownFcn(this,histogramH,eventdata)
            xHit = eventdata.IntersectionPoint(1);
            barWidth = 1;  % histogramH.BarWidth is 0.8 by default, but leaves 0.2 of ambiguity between adjancent bars.
            xStartStop = [histogramH.XData(:)-barWidth/2, histogramH.XData(:)+barWidth/2];
            selectedBarIndex = find( xStartStop(:,1)<xHit & xStartStop(:,2)>xHit ,1);
            
            
            holdOn = get(this.handles.check_holdPlots,'value');

            if(~holdOn && strcmpi(get(this.figureH,'selectiontype'),'normal'))
                this.centroidObj.setCOISortOrder(selectedBarIndex);
            else
                this.centroidObj.toggleCOISortOrder(selectedBarIndex);                
            end
            this.plotCentroids();         
        end
        
        
        
        % ======================================================================
        %> @brief Mouse button callback when clicking a patch overlay of the centroid histogram.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle to the patch overlay.
        %> @param eventdata Struct of 'hit' even data.
        %> @param coiSortOrder - Index of the patch being clicked on.
        % ======================================================================
        function centroidHistogramPatchButtonDownFcn(this,hObject,eventData,coiSortOrder)
            holdOn = get(this.handles.check_holdPlots,'value');

            if(~holdOn && strcmpi(get(this.figureH,'selectiontype'),'normal'))
                this.centroidObj.setCOISortOrder(coiSortOrder);
            else
                this.centroidObj.toggleCOISortOrder(coiSortOrder);
            end
            this.plotCentroids();
        end

        
        % ======================================================================
        %> @brief Mouse button callback when clicking on a scatter plot entry.
        %> @param this Instance of PAStatTool
        %> @param lineH Handle to the scatterplot line.
        %> @param eventData Struct of 'hit' even data.
        % ======================================================================
        function scatterplotButtonDownFcn(this,lineH,eventData)
            xHit = eventData.IntersectionPoint(1);
            selectedSortOrder = round(xHit);
            holdOn = get(this.handles.check_holdPlots,'value');

            if(~holdOn && strcmpi(get(this.analysisFigureH,'selectiontype'),'normal'))
                this.centroidObj.setCOISortOrder(selectedSortOrder);
            else
                this.centroidObj.toggleCOISortOrder(selectedSortOrder);                
            end
            this.plotCentroids();         
        end
        
        
        
        % ======================================================================
        %> @brief Mouse button callback when clicking on a highlighted member (coi) 
        %> of the centroid-profile scatter plot.
        %> @param this Instance of PAStatTool
        %> @param lineH Handle to the scatterplot line.
        %> @param eventData Struct of 'hit' even data.
        % ======================================================================
        function scatterPlotCOIButtonDownFcn(this,lineH,eventData)
            xHit = eventData.IntersectionPoint(1);
            coiSortOrder = round(xHit);
            holdOn = get(this.handles.check_holdPlots,'value');
            if(~holdOn && strcmpi(get(this.analysisFigureH,'selectiontype'),'normal'))
                this.centroidObj.setCOISortOrder(coiSortOrder);
            else
                this.centroidObj.toggleCOISortOrder(coiSortOrder);
            end
            this.plotCentroids();
        end

    end
    
    methods
            
        
        % ======================================================================
        %> @brief Initialize gui handles using input parameter or default
        %> parameters.  Initalizes callbacks where applicable.
        %> @param this Instance of PAStatTool
        %> @param widgetSettings GUI setting parameters (optional).  If
        %> this is not included or is empty, then the default parameters are
        %> used to initialize the gui (See getDefaultParameters).
        % ======================================================================        
        function initWidgets(this, widgetSettings)
            if(nargin<2 || isempty(widgetSettings))
                widgetSettings = this.getDefaultParameters();                
            end

            customIndex = strcmpi(this.base.weekdayTags,'custom');
            this.base.weekdayValues{customIndex} = widgetSettings.customDaysOfWeek;
            
            featuresPathname = this.featuresDirectory;
            this.hideCentroidControls();

            this.canPlot = false;    %changes to true if we find data that can be processed in featuresPathname
            set([this.handles.check_sortvalues                
                this.handles.check_normalizevalues
                this.handles.menu_feature
                this.handles.menu_signalsource
                this.handles.menu_plottype
                this.handles.menu_weekdays
                this.handles.menu_centroidStartTime
                this.handles.menu_centroidStopTime                
                this.handles.menu_duration
                this.handles.check_showCentroidMembers
                this.handles.push_refreshCentroids
                this.handles.push_nextCentroid
                this.handles.push_previousCentroid
                this.handles.check_trim
                this.handles.edit_trimToPercent
                this.handles.check_cull
                this.handles.edit_cullToValue
                this.handles.check_segment],'units','points',...
                'callback',[],...
                'enable','off');

            if(isdir(featuresPathname))
                % find allowed features which are in our base parameter and
                % also get their description.
                featureNames = getPathnames(featuresPathname);
                if(~isempty(featureNames))
                    [this.featureTypes,~,ib] = intersect(featureNames,this.base.featureTypes);
                    
                    if(~isempty(this.featureTypes))
                        % clear results text
                        set(this.handles.text_resultsCentroid,'string',[]);
                        
                        % Enable everything and then shut things down as needed. 
                        set(findall(this.handles.panels_sansCentroids,'enable','off'),'enable','on');
                        this.canPlot = true;
                        
                        this.featureDescriptions = this.base.featureDescriptions(ib);
                        set(this.handles.menu_feature,'string',this.featureDescriptions,'userdata',this.featureTypes,'value',widgetSettings.baseFeatureSelection);

                        % Checkboxes
                        % This is good for a true false checkbox value
                        % Checked state has a value of 1
                        % Unchecked state has a value of 0
                        
                        set(this.handles.check_segment,'min',0,'max',1,'value',widgetSettings.segmentSortValues);
                        set(this.handles.check_trim,'min',0,'max',1,'value',widgetSettings.trimResults);
                        set(this.handles.check_cull,'min',0,'max',1,'value',widgetSettings.cullResults);
                        set(this.handles.check_showCentroidMembers,'min',0,'max',1,'value',widgetSettings.showCentroidMembers);
                        
                        set(this.handles.check_sortvalues,'min',0,'max',1,'value',widgetSettings.sortValues);                        
                        set(this.handles.check_normalizevalues,'min',0,'max',1,'value',widgetSettings.normalizeValues);
                        
                        % This should be updated to parse the actual output feature
                        % directories for signal type (count) or raw and the signal
                        % source (vecMag, x, y, z)
                        set(this.handles.menu_signalsource,'string',this.base.signalDescriptions,'userdata',this.base.signalTypes,'value',widgetSettings.signalSelection);
                        set(this.handles.menu_plottype,'userdata',this.base.plotTypes,'string',this.base.plotTypeDescriptions,'value',widgetSettings.plotTypeSelection);
                        
                        % Centroid widgets                        
                        if(strcmpi(this.base.weekdayTags{widgetSettings.weekdaySelection},'custom'))
                            customIndex = widgetSettings.weekdaySelection;
                            tooltipString = cell2str(this.base.daysOfWeekDescriptions(this.base.weekdayValues{customIndex}+1));
                        else
                            tooltipString = '';
                        end
                        set(this.handles.menu_weekdays,'string',this.base.weekdayDescriptions,'userdata',this.base.weekdayTags,...
                            'value',widgetSettings.weekdaySelection,'callback',@this.menuWeekdaysCallback,'tooltipstring',tooltipString);

                        %                         set(this.handles.menu_centroidStartTime,'userdata',[],'string',{'Start times'},'value',1);
                        %                         set(this.handles.menu_centroidStopTime,'userdata',[],'string',{'Stop times'},'value',1);
                        
                        
                        %                         startStopTimesInDay= 0:1/4:24;
                        %                         hoursInDayStr = datestr(startStopTimesInDay/24,'HH:MM');
                        %                         set(this.handles.menu_centroidStartTime,'userdata',startStopTimesInDay(1:end-1),'string',hoursInDayStr(1:end-1,:),'value',widgetSettings.startTimeSelection);
                        %                         set(this.handles.menu_centroidStopTime,'userdata',startStopTimesInDay(2:end),'string',hoursInDayStr(2:end,:),'value',widgetSettings.stopTimeSelection);
                        
                        set(this.handles.menu_duration,'string',this.base.centroidDurationDescriptions,'value',widgetSettings.centroidDurationSelection);
                        set(this.handles.edit_centroidMinimum,'string',num2str(widgetSettings.minClusters));
                        set(this.handles.edit_centroidThreshold,'string',num2str(widgetSettings.clusterThreshold)); 
                        
                        %% set callbacks
                        set([
                            this.handles.check_sortvalues;
                            this.handles.check_normalizevalues;                            
                            this.handles.menu_feature;                            
                            this.handles.menu_signalsource],'callback',@this.refreshPlot);                        
                        set(this.handles.menu_plottype,'callback',@this.plotSelectionChange);
                       
                        set(this.handles.check_showCentroidMembers,'callback',@this.checkShowCentroidMembershipCallback);
                        
                        % Trim results
                        if(widgetSettings.trimResults)
                            enableState = 'on';
                        else
                            enableState = 'off';
                        end
                        set(this.handles.check_trim,'callback',@this.checkTrimCallback);
                        set(this.handles.edit_trimToPercent,'string',num2str(widgetSettings.trimToPercent),'callback',@this.editTrimToPercentChange,'enable',enableState);
                        
                        % Cull results
                        if(widgetSettings.cullResults)
                            enableState = 'on';
                        else
                            enableState = 'off';
                        end
                        set(this.handles.check_cull,'callback',@this.checkCullCallback);
                        set(this.handles.edit_cullToValue,'string',num2str(widgetSettings.cullToValue),'callback',@this.editCullToValueChange,'enable',enableState);
                        set(this.handles.check_segment,'callback',@this.checkSegmentHistogramsCallback);
                        
                        
                        % Push buttons
                        % this should not normally be enabled if plotType
                        % is not centroids.  However, this will be
                        % taken care of by the enable/disabling of the
                        % parent centroid panel based on the menu selection
                        % change callback which is called after initWidgets
                        % in the constructor.
                        this.initRefreshCentroidButton('off');
                        set(this.handles.push_previousCentroid,'callback',@this.showPreviousCentroidCallback);
                        set(this.handles.push_nextCentroid,'callback',@this.showNextCentroidCallback);
                        
                        set(this.handles.push_nextCentroid,'units','pixels');
                        set(this.handles.push_previousCentroid,'units','pixels');
                        
                        % Correct arrow positions - they seem to shift in
                        % MATLAB R2014b from their guide set position.
                        %                         pos = get(this.handles.push_nextCentroid,'position');
                        %                         set(this.handles.push_nextCentroid,'position',pos.*[1 -1 1 1]);
                        %                         pos = get(this.handles.push_previousCentroid,'position');
                        %                         set(this.handles.push_previousCentroid,'position',pos.*[1 -1 1 1]);
                        
                        % Correct primary axes control widgets - they seem to shift in
                        % MATLAB R2014b from their guide set position.
                        %                         parentH = get(this.handles.check_holdYAxes,'parent');  %both widgets share the same parent panel here.
                        %                         parentPos = get(parentH,'position');
                        %                         pos = get(this.handles.check_holdYAxes,'position');
                        %                         pos(2) = 0; %parentPos(4)/2-pos(4)/2; % get the lower position that results in the widget being placed in the center of the panel.
                        %                         set(this.handles.check_holdYAxes,'position',pos);
                        
                        %                         pos = get(this.handles.check_holdPlots,'position');
                        %                         pos(2) = 0; %parentPos(4)/2-pos(4)/2; % get the lower position that results in the widget being placed in the center of the panel.
                        %                         set(this.handles.check_holdPlots,'position',pos);
                        %
                        %                         pos = get(this.handles.check_showAnalysisFigure,'position');
                        %                         pos(2) = 0; %parentPos(4)/2-pos(4)/2; % get the lower position that results in the widget being placed in the center of the panel.
                        %                         set(this.handles.check_showAnalysisFigure,'position',pos);
                        
                        drawnow();
                        %
                        % bgColor = get(this.handles.panel_controlCentroid,'Backgroundcolor');
                        bgColor = get(this.handles.push_nextCentroid,'backgroundcolor');
                        
                        % bgColor = [0.94,0.94,0.94];
                        nextImg = imread('arrow-right_16px.png','png','backgroundcolor',bgColor);
                        previousImg = fliplr(nextImg);
                        
                        set(this.handles.push_nextCentroid,'cdata',nextImg,'string',[]);
                        set(this.handles.push_previousCentroid,'cdata',previousImg,'string',[]);
                        
                        set(this.handles.push_nextCentroid,'units','points');
                        set(this.handles.push_previousCentroid,'units','points');

                        set(this.handles.check_holdYAxes,'value',strcmpi(widgetSettings.primaryAxis_yLimMode,'manual'),'callback',@this.checkHoldYAxesCallback);
                        set(this.handles.check_holdPlots,'value',strcmpi(widgetSettings.primaryAxis_nextPlot,'add'),'callback',@this.checkHoldPlotsCallback);
                        set(this.handles.check_showAnalysisFigure,'value',widgetSettings.showAnalysisFigure,'callback',@this.checkShowAnalysisFigureCallback);
                        
                        set([
                            this.handles.menu_centroidStartTime
                            this.handles.menu_centroidStopTime
                            this.handles.edit_centroidMinimum
                            this.handles.edit_centroidThreshold
                            this.handles.menu_duration
                            ],'callback',@this.enableCentroidRecalculation);
                        
                        % add a context menu now to secondary axes
                        contextmenu_secondaryAxes = uicontextmenu('callback',@this.contextmenu_secondaryAxesCallback,'parent',this.figureH);
                        this.handles.contextmenu.secondaryAxes.performance = uimenu(contextmenu_secondaryAxes,'Label','Show adaptive separation performance progression','callback',{@this.centroidDistributionCallback,'performance'});
                        this.handles.contextmenu.secondaryAxes.weekday = uimenu(contextmenu_secondaryAxes,'Label','Show current centroid''s weekday distribution','callback',{@this.centroidDistributionCallback,'weekday'});
                        this.handles.contextmenu.secondaryAxes.membership = uimenu(contextmenu_secondaryAxes,'Label','Show membership distribution by centroid','callback',{@this.centroidDistributionCallback,'membership'});
                        set(this.handles.axes_secondary,'uicontextmenu',contextmenu_secondaryAxes);
                    end
                end                
            end
           
            % These are required by follow-on calls, regardless if the gui
            % can be shown or not.  
            
            % Previous state initialization - set to current state.
            this.previousState.sortValues = widgetSettings.sortValues;
            this.previousState.normalizeValues = widgetSettings.normalizeValues;
            this.previousState.plotType = this.base.plotTypes{widgetSettings.plotTypeSelection};
            this.previousState.weekdaySelection = widgetSettings.weekdaySelection;
            
            %% Analysis Figure
            % Profile Summary
            if(this.useDatabase)
                this.initProfileTable(widgetSettings.profileFieldSelection);
                
                % Initialize the scatter plot axes
                this.initScatterPlotAxes();
                set(this.handles.push_analyzeClusters,'string','Analyze Clusters','callback',@this.analyzeClustersCallback);
                
                set(this.handles.push_exportTable,'string','Export Table','callback',@this.exportTableResultsCallback);
                set(this.handles.text_analysisTitle,'string','','fontsize',12);
                set(this.handles.check_showAnalysisFigure,'visible','on');

            else
                set(this.handles.check_showAnalysisFigure,'visible','off');
            end
           
            % disable everything
            if(~this.canPlot)
                set(findall(this.handles.panel_results,'enable','on'),'enable','off');
                this.hideCentroidControls();
            end
        end
        
        function initRefreshCentroidButton(this,enableState)
            if(nargin<2 || ~strcmpi(enableState,'off'))
                enableState = 'on';
            end
            fgColor = get(0,'FactoryuicontrolForegroundColor');
            defaultBackgroundColor = get(0,'FactoryuicontrolBackgroundColor');
            set(this.handles.push_refreshCentroids,'callback',@this.refreshCentroidsAndPlot,...
                'enable',enableState,'string','Recalculate',...
                'backgroundcolor',defaultBackgroundColor,...
                'foregroundcolor',fgColor,...
                'fontsize',12);
        end
        

        % ======================================================================
        %> @brief Configure gui handles for non centroid/clusting viewing
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switchFromClustering(this)
            this.previousState.sortValues = get(this.handles.check_sortvalues,'value');            
            set(this.handles.check_sortvalues,'value',0,'enable','off');            
            set(this.handles.check_normalizevalues,'value',this.previousState.normalizeValues,'enable','on');
            this.hideCentroidControls();
            
            disableHandles(this.handles.panel_plotCentroid);
            set(this.handles.axes_secondary,'visible','off');
            set(this.figureH,'WindowKeyPressFcn',[]);
            set(this.analysisFigureH,'visible','off');

            this.refreshPlot();
        end    
        

        
        % ======================================================================
        %> @brief Configure gui handles for centroid analysis and viewing.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switch2clustering(this)
            set(this.handles.check_sortvalues,'value',this.previousState.sortValues,'enable','on');            
            this.previousState.normalizeValues = get(this.handles.check_normalizevalues,'value');           
            set(this.handles.check_normalizevalues,'value',1,'enable','off');
            set(this.handles.axes_primary,'ydir','normal');  %sometimes this gets changed by the heatmap displays which have the time shown in reverse on the y-axis
            
            set(this.handles.panel_controlCentroid,'visible','on');
            
            if(this.getCanPlot())
                if(this.hasValidCentroid())                    
                    % lite version of refreshCentroidsAndPlot()
                    this.showCentroidControls();
                    
                    % Need this because we will skip our x tick and
                    % labels refresh otherwise.
                    this.drawCentroidXTicksAndLabels();

                    this.plotCentroids();                     
                    this.enableCentroidControls();
                else
                    this.disableCentroidControls();
                    this.refreshCentroidsAndPlot();
                end
                
                set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','on');
                
                if(this.hasValidCentroid())
                    validColor = [1 1 1];
                    keyPressFcn = @this.mainFigureKeyPressFcn;
                else
                    validColor = [0.75 0.75 0.75];
                    keyPressFcn = [];
                end
                
                
                % This is handled in the plot centroid method, right before tick marks are down on
                % set(this.handles.axes_primary,'color',validColor); 
                set(this.handles.axes_secondary,'visible','on','color',validColor);
                set(this.figureH,'WindowKeyPressFcn',keyPressFcn);
                
                if(this.shouldShowAnalysisFigure())
                    set(this.analysisFigureH,'visible','on');
                end
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
        %> centroid profile table.
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
            shouldShow = get(this.handles.check_showAnalysisFigure,'value');
        end
        
        
    end
    
    methods(Access=protected)
        
        
        % ======================================================================
        %> @brief Callback to enable the push_refreshCentroids button.  The button's 
        %> background color is switched to green to highlight the change and need
        %> for recalculation.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function enableCentroidRecalculation(this,varargin)
            %             bgColor = 'green';
            bgColor = [0.2 0.8 0.1];
            fgColor = [1 1 1];
            set(this.handles.push_refreshCentroids,'enable','on',...
                'backgroundcolor',bgColor,'string','Recalculate',...
                'foregroundcolor',fgColor,...
                'callback',@this.refreshCentroidsAndPlot);
        end
        
        function enableCentroidCancellation(this, varargin)
            bgColor = [0.8 0.2 0.1];
            fgColor = [0 0 0];
            set(this.handles.push_refreshCentroids,'enable','on',...
                'backgroundcolor',bgColor,'string','Cancel',...
                'foregroundcolor',fgColor,...
                'callback',@this.cancelCentroidsCalculationCallback);
        end
        
        function cancelCentroidsCalculationCallback(this,hObject,eventdata)
            %             bgColor = [0.6 0.4 0.3];
            bgColor = [0.6 0.1 0.1];
            set(this.handles.push_refreshCentroids,'enable','off','callback',[],...
                'backgroundcolor',bgColor,'string','Cancelling');
            this.notify('UserCancel_Event');
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
                    this.enableCentroidRecalculation();                    
                else
                    set(hObject,'value',this.previousState.weekdaySelection);
                end
            else
                this.previousState.weekdaySelection = curValue;
                set(hObject,'tooltipstring','');
                this.enableCentroidRecalculation();
            end
        end

        

        function analyzeClustersCallback(this, hObject,eventData)
           % Get my centroid Object
           % Take in all of the clusters, or the ones selected
           % Apply to see how well it splits the data...
           % Requires: addpath('/users/unknown/Google Drive/work/Stanford - Pediatrics/code/models');
           initString = get(hObject,'string');
           try
               set(hObject,'enable','off','String','Analyzing ...');
               dependentVar = this.getProfileFieldSelection();
%                'bmi_zscore'
%                'bmi_zscore+'  %for logistic regression modeling
               resultStr = gee_model(this.centroidObj.getCovariateStruct(this.centroidObj.getCOISortOrder()),dependentVar,{'age'; '(sex=1) as male'});
               if(~isempty(resultStr))
                   msgbox(resultStr);
               end
                   
           catch me
               set(hObject,'string','Error!');
               showME(me);
               pause(1);
           end
           set(hObject,'enable','on','string',initString);
            
        end

        
        function exportTableResultsCallback(this, hObject,eventData)
            tableData = get(this.handles.table_centroidProfiles,'data');
            copy2workspace(tableData,'centroidProfilesTable');
        end
                
        % Should probably move to event listeners here pretty soon.
        function hideAnalysisFigure(this,varargin)
            set(this.handles.check_showAnalysisFigure,'value',0);
            this.checkShowAnalysisFigureCallback(varargin(:));
        end
        
        function checkShowAnalysisFigureCallback(this, hObject, eventData)    
            if(this.shouldShowAnalysisFigure())
                set(this.analysisFigureH,'visible','on');
            else
                set(this.analysisFigureH,'visible','off');                
            end
        end
        
        function primaryAxesHorizontalGridContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');            
            set(this.handles.contextmenu.horizontalGridLines.(get(this.handles.axes_primary,'ygrid')),'checked','on');
        end
        
        function primaryAxesHorizontalGridCallback(this,hObject,~,gridState)
            if(~isempty(intersect(lower(gridState),{'on','off'})))
                set(this.handles.axes_primary,'ygrid',gridState);
            end
        end

        

        function primaryAxesScalingContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');            
            set(this.handles.contextmenu.axesYLimMode.(get(this.handles.axes_primary,'ylimmode')),'checked','on');
        end
                
        function primaryAxesScalingCallback(this,hObject,~,yScalingMode)
            set(this.handles.axes_primary,'ylimmode',yScalingMode,...
            'ytickmode',yScalingMode,...
            'yticklabelmode',yScalingMode);
            if(strcmpi(yScalingMode,'auto'))
                set(this.handles.check_holdYAxes,'value',0);
                %                 this.checkHoldPlotsCallback();
                this.plotCentroids();
            else
                set(this.handles.check_holdYAxes,'value',1);  %manual selection means do not auto adjust
                
                % What is going on here?
                %                 if(strcmpi(get(this.handles.axes_primary,'nextplot'),'replace'))
                %                     set(this.handles.axes_primary,'nextplot','replaceChildren');
                %                 end
            end
        end
        
        %> @brief A 'checked' "Hold y-axis" checkbox infers 'manual'
        %> yllimmode for the primary (upper) axis.  An unchecked box
        %> indicates auto-scaling for the y-axis.
        function checkHoldYAxesCallback(this,hObject,eventData)
            if(get(hObject,'value'))
                yScalingMode = 'manual';
            else
                yScalingMode = 'auto';
            end
            
            set(this.handles.axes_primary,'ylimmode',yScalingMode,...
                'ytickmode',yScalingMode,...
                'yticklabelmode',yScalingMode);
            if(strcmpi(yScalingMode,'auto'))
                this.plotCentroids();
            else
                if(strcmpi(get(this.handles.axes_primary,'nextplot'),'replace'))
                    set(this.handles.axes_primary,'nextplot','replaceChildren');
                end
            end
        end        
        
        function primaryAxesNextPlotContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');
            set(this.handles.contextmenu.nextPlot.(get(this.handles.axes_primary,'nextplot')),'checked','on');
        end
        
        function primaryAxesNextPlotCallback(this,hObject,~,nextPlot)
            if(strcmpi(nextPlot,'add'))
                set(this.handles.check_holdPlots,'value',1);
            else
                set(this.handles.check_holdPlots,'value',0);                
            end

            set(this.handles.axes_primary,'nextplot',nextPlot);
        end
        
        function checkHoldPlotsCallback(this,hObject,eventData)
            if(get(hObject,'value'))
                nextPlot = 'add';
            else
                nextPlot = 'replaceChildren';
            end
            set(this.handles.axes_primary,'nextplot',nextPlot);
        end
        

        
        function contextmenu_secondaryAxesCallback(this,varargin)
            % This may be easier to maintain ... 
            contextMenus = this.handles.contextmenu.secondaryAxes;
            if(isfield(contextMenus,'nextPlot'))
                contextMenus = rmfield(contextMenus,'nextPlot');
            end
            set(struct2array(contextMenus),'checked','off');
            set(contextMenus.(this.centroidDistributionType),'checked','on');
            
            % Than this 
            %             set([this.handles.contextmenu.performance
            %                 this.handles.contextmenu.weekday
            %                 this.handles.contextmenu.membership
            %                 this.handles.contextmenu.profile],'checked','off');
            %             set(this.handles.contextmenu.(this.centroidDistributionType),'checked','on');
        end               
        
        function centroidDistributionCallback(this,hObject,eventdata,selection)
            this.centroidDistributionType = selection;
            this.plotCentroids();
        end   
    end
    
    methods
      
        
        function refreshScatterPlot(this)
            this.initScatterPlotAxes();
            numCentroids = this.centroidObj.getNumCentroids();  %or numel(globalStruct.colnames).
            sortOrders = find( this.centroidObj.getCOIToggleOrder() );
            curProfileFieldIndex = this.getProfileFieldIndex();
            % get the current profile's ('curProfileIndex' row) mean ('2' column) for all centroids
            % (':').
            x = 1:numCentroids;
            y = this.allProfiles(curProfileFieldIndex, 2, :);  % rows (1) = 
                        % columns (2) = 
                        % dimension (3) = centroid popularity (1 to most
                        % popular index)
            
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
            legend(this.handles.axes_scatterplot,this.handles.line_coiInScatterPlot,'location','southwest');
            
            
            
        end
        
        % only extract the handles we are interested in using for the stat tool.
        % ======================================================================
        %> @brief Initialize the analysis figure, which holds the scatter
        %> plot axes and the profile table containing subject information
        %> contained in subjects grouped together by the current centroid of
        %> interest.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initScatterPlotFigure(this)
            this.analysisFigureH = analysis('visible','off',...
                'WindowKeyPressFcn',@this.mainFigureKeyPressFcn,...
                'CloseRequestFcn',@this.hideAnalysisFigure);
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
            % intialize the centroid profile table
            profileColumnNames = {'n','mx','sem','n (global)','mx (global)','sem (global)'};
            %{'Mean (global)','Mean (centroid)','p'};
            rowNames = this.profileFields;
            if(nargin<2 || isempty(profileFieldSelection) || profileFieldSelection>numel(this.profileFields))
                profileFieldSelection = 1;
            end
            
            set(this.handles.menu_ySelection,'string',this.profileFields,'value',profileFieldSelection,'callback',@this.profileFieldMenuSelectionChangeCallback);

            numRows = numel(rowNames);
            backgroundColor = repmat([1 1 1; 0.94 0.94 0.94],ceil(numRows/2),1); % possibly have one extra if numRows is odd.
            backgroundColor = backgroundColor(1:numRows,:);  %make sure we only get as many rows as we actually have.
            userData.defaultBackgroundColor = backgroundColor;
            userData.rowOfInterestBackgroundColor = [0.5 0.5 0.5];
            
            this.jhandles.table_centroidProfiles.setSelectionBackground(java.awt.Color(0.5,0.5,0.5));
            this.jhandles.table_centroidProfiles.setSelectionForeground(java.awt.Color(0.0,0.0,0.0));
            
            backgroundColor(profileFieldSelection,:) = userData.rowOfInterestBackgroundColor;
            
            % legend(this.handles.axes_scatterPlot,'off');
            tableData = cell(numRows,numel(profileColumnNames));
            this.profileTableData = tableData;  %array2table(tableData,'VariableNames',profileColumnNames,'RowNames',rowNames);
            
            % Could use the DefaultTableModel instead of the, otherwise,
            % DefaultUIStyleTableModel which does not provide the same
            % functionality (namely setRowData)
            %             this.jhandles.table_centroidProfiles.setModel(javax.swing.table.DefaultTableModel(tableData,profileColumnNames));
                     
            %             curStack = dbstack;
            %             fprintf(1,'Skipping centroid profile table initialization on line %u of %s\n',curStack(1).line,curStack(1).file);
            set(this.handles.table_centroidProfiles,'rowName',rowNames,'columnName',profileColumnNames,...
                'units','points','fontname','arial','fontsize',12,'fontunits','pixels','visible','on',...
                'backgroundColor',backgroundColor,'rowStriping','on',...
                'userdata',userData,'CellSelectionCallback',@this.analysisTableCellSelectionCallback);
            
                        

            
            this.refreshProfileTableData();
                        
            fitTableWidth(this.handles.table_centroidProfiles);
        end

        % ======================================================================
        %> @brief I itialize the scatter plot axes (of the analysis
        %> figure).
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initScatterPlotAxes(this)
            cla(this.handles.axes_scatterplot);
            set(this.handles.axes_scatterplot,'box','on');
            this.handles.line_meanScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','b','linestyle','--');
            this.handles.line_upper95PctScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','b','linestyle',':');
            this.handles.line_lower95PctScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','b','linestyle',':');
            
            this.handles.line_allScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','k','linestyle','none','marker','.','buttondownfcn',@this.scatterplotButtonDownFcn);
            this.handles.line_coiInScatterPlot = line('parent',this.handles.axes_scatterplot,'xdata',[],'ydata',[],'color','r','linestyle','none','markerFaceColor','g','marker','o','markersize',6,'buttondownfcn',@this.scatterPlotCOIButtonDownFcn);
            [~,profileFieldName] = this.getProfileFieldIndex();
            ylabel(this.handles.axes_scatterplot,profileFieldName,'interpreter','none');
            xlabel(this.handles.axes_scatterplot,'Centroid popularity');
            
            
            % add a context menu now to primary axes
            contextmenu_ScatterPlotAxes = uicontextmenu('parent',this.analysisFigureH);
            this.handles.contextmenu.toggleLegend = uimenu(contextmenu_ScatterPlotAxes,'Label','Toggle legend','callback',{@this.toggleLegendCallback,this.handles.axes_scatterplot});
            set(this.handles.axes_scatterplot,'uicontextmenu',contextmenu_ScatterPlotAxes);  
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
                'table_centroidProfiles'
                'menu_ySelection'
                'push_exportTable'
                'push_analyzeClusters'
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
            
            warning off MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
            jFrame = get(this.analysisFigureH,'JavaFrame');
            jFigPanel = get(jFrame,'FigurePanelContainer');
%             this.jhandles.table_centroidProfiles=jFigPanel.getComponent(0).getComponent(0).getComponent(0).getComponent(0).getComponent(0);
            
            this.jhandles.table_centroidProfiles = jFigPanel.getComponent(0).getComponent(4).getComponent(0).getComponent(0).getComponent(0);
            %             j.getUIClassID=='TableUI';
        
            % allocate line handle names here for organizational consistency
            this.handles.line_allScatterPlot = [];
            this.handles.line_coiInScatterPlot = [];
            this.handles.line_meanScatterPlot = [];
            this.handles.line_upper95PctScatterPlot = [];
            this.handles.line_lower95PctScatterPlot = [];
            
            
            % get handles of interest from the main/primary figure.
            tmpHandles = guidata(this.figureH);
            handlesOfInterest = {
                'check_sortvalues'    
                'check_normalizevalues'
                'menu_feature'
                'menu_signalsource'
                'menu_plottype'
                'menu_weekdays'
                'menu_centroidStartTime'
                'menu_centroidStopTime'
                'menu_duration'
                'axes_primary'
                'axes_secondary'
                'check_trim'
                'edit_trimToPercent'
                'check_cull'
                'edit_cullToValue'
                'check_segment'
                'check_showCentroidMembers'
                'edit_centroidThreshold'
                'edit_centroidMinimum'
                'push_refreshCentroids'
                'panel_plotCentroid'
                'panel_results'
                'panel_controlCentroid'
                'push_nextCentroid'
                'push_previousCentroid'
                'text_resultsCentroid'
                'check_holdPlots'
                'check_holdYAxes'
                'check_showAnalysisFigure'

%                 'text_resultsCentroid'
%                 'table_centroidProfiles'
                };
            
            for f=1:numel(handlesOfInterest)
                fname = handlesOfInterest{f};
                this.handles.(fname) = tmpHandles.(fname);
            end
            this.handles.panels_sansCentroids = [
                    tmpHandles.panel_plotType;
                    tmpHandles.panel_plotSignal;
                    tmpHandles.panel_plotData
                ];
            
            % add a context menu now to figureH in order to use with centroid load
            % shape line handles.
            this.handles.contextmenu.clusterLineMember = uicontextmenu('parent',this.figureH);
            uimenu(this.handles.contextmenu.clusterLineMember,'Label','Show all from this subject','callback',@this.showSelectedMemberShapesCallback);
            

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
                        
            daysofweekStr = this.base.daysOfWeekShortDescriptions; %{'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekOrder = this.base.daysOfWeekOrder; %1:7;
            features = this.featureStruct.features;
            divisionsPerDay = size(features,2);
            
            % Set this here to auto perchance it is not with our centroid
            % option.
            if(~strcmpi(plotOptions.primaryAxis_yLimMode,'auto'))
                set(axesHandle,'ylimmode','auto');
            end
            
            if(~strcmpi(plotOptions.primaryAxis_nextPlot,'replace'))
                set(axesHandle,'nextplot','replace');
            end
            
            switch(plotOptions.plotType)
                
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
                    titleStr = 'Average Daily Tallies (total daily tally divided by number of subjects that day)';
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
                    titleStr ='Total Daily Tallies';
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
                    titleStr = 'Heat map (early morning)';
                    
                case 'heatmap'
                    imageMap = nan(7,size(features,2));
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
                    titleStr = 'Heat map';
                    
                case 'rolling'
                    imageMap = nan(7,size(features,2));
                    for dayofweek=0:6
                        imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
                    end
                    %            imageMap=imageMap/max(imageMap(:));
                    rollingMap = imageMap';
                    plot(axesHandle,rollingMap(:));
                    titleStr = 'Rolling Map';
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
                    titleStr = 'Morning Rolling Map (00:00-06:00AM daily)';
                    weekdayticks = linspace(0,24*6,7);
                    set(axesHandle,'ygrid','on');
                    
                case 'centroids'
                    
                    
                case 'quantile'
                    
                otherwise
                    disp Oops!;
            end
            title(axesHandle,titleStr,'fontsize',14);

            xlimits = minmax(weekdayticks);

            if(strcmpi(plotOptions.plotType,'dailytally')||strcmpi(plotOptions.plotType,'dailyaverage'))
                xlimits = xlimits+[-1,1]*0.75;
            end
            set(axesHandle,'xtick',weekdayticks,'xticklabel',daysofweekStr,'xlim',xlimits);
        end

        
        % ======================================================================
        %> @brief Check button callback for segmenting centroid histogram 
        %> distributions into intervals across the time period covered.
        %> @param this Instance of PAStatTool
        %> @param hObject Handle of the checkbutton that is calling back.
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function checkSegmentHistogramsCallback(this,hObject,~)
            %             if(get(hObject,'value'))
            %                 enableState = 'on';
            %             else
            %                 enableState = 'off';
            %             end

            this.refreshPlot();
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
        %> @brief Push button callback for displaying the next centroid.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function showNextCentroidCallback(this,varargin)
            holdOn = get(this.handles.check_holdPlots,'value');
            this.showNextCentroid(holdOn);
        end
                
        % ======================================================================
        %> @brief Push button callback for displaying the next centroid.
        %> @param this Instance of PAStatTool
        %> @param toggleOn Optional boolean:
        %> - @c true Results in increaseing the COI sort order, and all
        %> other toggle sort order indices are turned off. (default)
        %> - @c false Results in increaseing the COI sort order, and all
        %> other toggle sort indices are left as is.
        % ======================================================================
        function showNextCentroid(this,toggleOn)
            if(nargin<2 || ~islogical(toggleOn))
                toggleOn = false;
            end
            if(~isempty(this.centroidObj))
                if(toggleOn)
                    didChange = this.centroidObj.toggleOnNextCOI();
                else
                    didChange = this.centroidObj.increaseCOISortOrder();
                    
                end
                if(didChange)
                    this.plotCentroids();
                end
            end
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the previous centroid.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function showPreviousCentroidCallback(this,varargin)
            holdOn = get(this.handles.check_holdPlots,'value');
            this.showPreviousCentroid(holdOn);
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the next centroid.
        %> @param this Instance of PAStatTool
        %> @param toggleOn Optional boolean:
        %> - @c true Results in increaseing the COI sort order, and all
        %> other toggle sort order indices are turned off. (default)
        %> - @c false Results in increaseing the COI sort order, and all
        %> other toggle sort indices are left as is.
        % ======================================================================
        function showPreviousCentroid(this,toggleOn)
            if(nargin<2 || ~islogical(toggleOn))
                toggleOn = false;
            end
            if(toggleOn)
                didChange = this.centroidObj.toggleOnPreviousCOI();
            else
                didChange = this.centroidObj.decreaseCOISortOrder();
            end
            % Don't refresh if there was no change.
            if(didChange)
                this.plotCentroids();
            end
        end
        

        
        % ======================================================================
        %> @brief Check button callback to refresh centroid display.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        %> @note The ygrid is turned on or off here: on when show
        %> membership is checked, and off when it is unchecked.
        % ======================================================================
        function checkShowCentroidMembershipCallback(this,hObject,varargin)
            this.plotCentroids();
            
            % Is it checked?
            if(get(hObject,'value'))
                set(this.handles.axes_primary,'ygrid','on');
            else
                set(this.handles.axes_primary,'ygrid','off');
            end

        end
        
        %> @brief Creates a matlab struct with pertinent fields related to
        %> the current centroid and its calculation, and then saves the
        %> struct in a matlab binary (.mat) file.  Fields include
        %> - centroidObj (sans handle references)
        %> - featureStruct
        %> - originalFeatureStruct
        %> - usageStateStruct
        %> - resultsDirectory
        %> - featuresDirectory
        function didCache = cacheCentroid(this)
            didCache = false;
            if(this.useCache)
                if(isdir(this.cacheDirectory) || mkdir(this.cacheDirectory))
                    try
                        tmpStruct.centroidObj = this.getCentroidObj();  
                        tmpStruct.centroidObj.removeHandleReferences();
                        tmpStruct.featureStruct = this.featureStruct;
                        tmpStruct.originalFeatureStruct = this.originalFeatureStruct;
                        tmpStruct.usageStateStruct = this.usageStateStruct;
                        tmpStruct.resultsDirectory = this.resultsDirectory;
                        tmpStruct.featuresDirectory = this.featuresDirectory;
                        fnames = fieldnames(tmpStruct);
                        save(this.getFullCentroidCacheFilename(),'-mat','-struct','tmpStruct',fnames{:});
                        didCache = true;
                    catch me
                        showME(me);
                        didCache = false;
                    end
                end
            end
            
        end

        % ======================================================================
        %> @brief Push button callback for updating the centroids being displayed.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        %> varargin{1} may be used to disable the button after success.
        %> @note centroidObj is cleared at the beginning of this function.
        %> If it is empty after the function call, then the clustering
        %> failed.
        % ======================================================================
        function refreshCentroidsAndPlot(this,varargin)
            this.clearPrimaryAxes();
            this.showBusy();
            pSettings= this.getPlotSettings();
            
            this.centroidObj = [];
            this.disableCentroidControls();  % disable further interaction with our centroid panel
            
            % clear the analysis figure
            
            if(this.calcFeatureStruct())            
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
                end
                
                resultsTextH = this.handles.text_resultsCentroid;
                set(this.handles.axes_primary,'color',[1 1 1],'xlimmode','auto','ylimmode',pSettings.primaryAxis_yLimMode,'xtickmode','auto',...
                    'ytickmode',pSettings.primaryAxis_yLimMode,'xticklabelmode','auto','yticklabelmode',pSettings.primaryAxis_yLimMode,'xminortick','off','yminortick','off');
                set(resultsTextH,'visible','on','foregroundcolor',[0.1 0.1 0.1],'string','');

                % % set(this.handles.text_primaryAxes,'backgroundcolor',[0 0 0],'foregroundcolor',[1 1 0],'visible','on');
                this.showCentroidControls();
                
                drawnow();
                
                % This means we will create the centroid object, but not
                % calculate the centroids in the constructor.  The reason
                % for this is because I want to register a mouse listener
                % so users can cancel.  And I chose to do that here, rather
                % than in the constructor.
                delayedStart = true;
                tmpCentroidObj = PACentroid(this.featureStruct.features,pSettings,this.handles.axes_primary,resultsTextH,this.featureStruct.studyIDs, this.featureStruct.startDaysOfWeek, delayedStart);
                this.addlistener('UserCancel_Event',@tmpCentroidObj.cancelCalculations);
                this.centroidObj = tmpCentroidObj;
                this.enableCentroidCancellation();
                
                this.centroidObj.calculateCentroids();
                
                if(this.centroidObj.failedToConverge())
                    warnMsg = {'Failed to converge',[]};
                    if(isempty(this.featureStruct.features))
                        warnMsg = {[warnMsg{1}, 'No features found.'];
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
                    this.centroidObj = [];
                else
                    this.refreshGlobalProfile();
                    this.cacheCentroid();
                end
            else
                inputFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);                
                warndlg(sprintf('Could not find the input file required (%s)!',inputFilename));
            end
            
            if(this.hasValidCentroid()) % ~isempty(this.centroidObj))
                % Prep the x-axis here since it will not change when going from one centroid to the
                % next, but only (though not necessarily) when refreshing centroids.
                this.drawCentroidXTicksAndLabels();
                
                if(this.centroidObj.getUserCancelled())
                    this.initRefreshCentroidButton('on');
                else
                    this.initRefreshCentroidButton('off');                    
                end
                
                this.plotCentroids(pSettings); 
                this.enableCentroidControls();
                dissolve(resultsTextH,2.5);
            else
                set(resultsTextH,'visible','off');
                this.initRefreshCentroidButton('on');  % want to initialize the button again so they can try again perhaps.
            end
            this.showReady();
        end
        
        function drawCentroidXTicksAndLabels(this)
            xTicks = 1:6:this.featureStruct.totalCount;
            
            % This is nice to place a final tick matching the end time on
            % the graph, but it sometimes gets too busy and the tick
            % separation distance is non-linear which can be an eye soar.
            %             if(xTicks(end)~=this.featureStruct.totalCount)
            %                 xTicks(end+1)=this.featureStruct.totalCount;
            %             end
            
            xTickLabels = this.featureStruct.startTimes(xTicks);
            set(this.handles.axes_primary,'xlim',[1,this.featureStruct.totalCount],'xtick',xTicks,'xticklabel',xTickLabels);%,...
%                 'fontsize',11);
            
        end
        
        
        %> @brief Hides the panel of centroid interaction controls.  For
        %> example, the forward and back buttons that appear in between the
        %> two axes.
        %> @param Instance of PAStatTool
        function hideCentroidControls(this)
            set(this.handles.panel_controlCentroid,'visible','off'); 
            
            % remove anycontext menu on the primary axes
            set(this.handles.axes_primary,'uicontextmenu',[]);
        end
        
        function toggleLegendCallback(this, hObject,eventData, axesHandle)
            legend(axesHandle,'toggle');
        end
        
        function showCentroidControls(this)
            set(this.handles.panel_controlCentroid,'visible','on');
        end
        
        %> @brief Does not change panel_plotCentroid controls.
        function enableCentroidControls(this)
            enableHandles(this.handles.panel_controlCentroid);  
            %             set(findall(this.handles.panel_plotCentroid,'enable','off'),'enable','on');
            
            % add a context menu now to primary axes            
            contextmenu_primaryAxes = uicontextmenu('parent',this.figureH);

            horizontalGridMenu = uimenu(contextmenu_primaryAxes,'Label','Horizontal grid','callback',@this.primaryAxesHorizontalGridContextmenuCallback);
            this.handles.contextmenu.horizontalGridLines.on = uimenu(horizontalGridMenu,'Label','On','callback',{@this.primaryAxesHorizontalGridCallback,'on'});
            this.handles.contextmenu.horizontalGridLines.off = uimenu(horizontalGridMenu,'Label','Off','callback',{@this.primaryAxesHorizontalGridCallback,'off'});
            
            axesScalingMenu = uimenu(contextmenu_primaryAxes,'Label','y-Axis scaling','callback',@this.primaryAxesScalingContextmenuCallback);
            this.handles.contextmenu.axesYLimMode.auto = uimenu(axesScalingMenu,'Label','Auto','callback',{@this.primaryAxesScalingCallback,'auto'});
            this.handles.contextmenu.axesYLimMode.manual = uimenu(axesScalingMenu,'Label','Manual','callback',{@this.primaryAxesScalingCallback,'manual'});
            
            nextPlotmenu = uimenu(contextmenu_primaryAxes,'Label','Next plot','callback',@this.primaryAxesNextPlotContextmenuCallback);
            this.handles.contextmenu.nextPlot.add = uimenu(nextPlotmenu,'Label','Add','callback',{@this.primaryAxesNextPlotCallback,'add'});
            this.handles.contextmenu.nextPlot.replace = uimenu(nextPlotmenu,'Label','Replace','callback',{@this.primaryAxesNextPlotCallback,'replace'});
            this.handles.contextmenu.nextPlot.replacechildren = uimenu(nextPlotmenu,'Label','Replace children','callback',{@this.primaryAxesNextPlotCallback,'replacechildren'});
            set(this.handles.axes_primary,'uicontextmenu',contextmenu_primaryAxes);            
        end
        
        %> @brief Does not alter panel_plotCentroid controls, which we want to
        %> leave avaialbe to the user to manipulate settings in the event
        %> that they have excluded loadshapes and need to alter the settings
        %> to included them in a follow-on calculation.
        function disableCentroidControls(this)
            sethandles(this.handles.panel_controlCentroid,'enable','inactive');
            
            set(this.handles.text_resultsCentroid,'enable','on');
            % add a context menu now to primary axes           
            set(this.handles.axes_primary,'uicontextmenu',[]);
            this.clearPlots();
            set([this.handles.axes_primary
                this.handles.axes_secondary],'color',[0.75 0.75 0.75]);
        end
        
        
        
        % ======================================================================
        %> @brief Displays most recent centroid data according to gui
        %> setttings.
        %> @param this Instance of PAStatTool
        %> @param plotSettings Structure of GUI parameters for configuration and 
        %> display of centroid data.
        % ======================================================================
        function plotCentroids(this,centroidAndPlotSettings)
            
            this.clearPrimaryAxes();
%            this.clearPlots();
            this.showMouseBusy();
            try
                if(isempty(this.centroidObj)|| this.centroidObj.failedToConverge())
                    % clear everything and give a warning that the centroid is empty
                    fprintf('Clustering results are empty\n');
                else
                    if(nargin<2)
                        centroidAndPlotSettings = this.getPlotSettings();
                    end
                    
                    
                    numCentroids = this.centroidObj.numCentroids();
                    numLoadShapes = this.centroidObj.numLoadShapes();
                    
                    distributionAxes = this.handles.axes_secondary;
                    centroidAxes = this.handles.axes_primary;
                    
                    set(centroidAxes,'color',[1 1 1]);
                    
                    % draw the x-ticks and labels - Commented out on
                    % 10/14/2016 because this appears to be called in
                    % refreshCentroidsAndPlot(), with the assumption it is
                    % no longer needed.  Is this not true?
                    % @No, this is still needed if we are using a cached
                    % load.  Add drawCentroidXTicksAndLabels() to the lite
                    % method for refreshCentroidsAndPlot when
                    % switching2centroids is invoked.
                    % this.drawCentroidXTicksAndLabels();
                    
                    
                    %% Show centroids on primary axes
                    %                 coi = this.centroidObj.getCentroidOfInterest();
                    cois = this.centroidObj.getCentroidsOfInterest();
                    
                    numCOIs = numel(cois);
                    nextPlot = get(centroidAxes,'nextplot');
                    coiColors = 'kbgrycm';
                    coiStyles = repmat('-:',size(coiColors));
                    coiColors = [coiColors, fliplr(coiColors)];
                    maxColorStyles = numel(coiColors);
                    
                    yLimMode = centroidAndPlotSettings.primaryAxis_yLimMode;
                    set(centroidAxes,'ytickmode',yLimMode,...
                        'ylimmode',yLimMode,...
                        'yticklabelmode',yLimMode);
                    
                    if(centroidAndPlotSettings.showCentroidMembers || numCOIs>1)
                        hold(centroidAxes,'on');
                        % set(centroidAxes,'ygrid','on');
                    else
                        set(centroidAxes,'nextplot','replacechildren');
                        % set(centroidAxes,'ygrid','off');
                    end
                    
                    %                 % Prep the x-axis.  This should probably be done elsewhere
                    %                 % as it will not change when going from one centroid to the
                    %                 % next, but only (though not necessarily) when refreshing centroids.
                    %                 xTicks = 1:8:this.featureStruct.totalCount;
                    %                 if(xTicks(end)~=this.featureStruct.totalCount)
                    %                     xTicks(end+1)=this.featureStruct.totalCount;
                    %                 end
                    %                 xTickLabels = this.featureStruct.startTimes(xTicks);
                    %                 set(centroidAxes,'xlim',[1,this.featureStruct.totalCount],'xtick',xTicks,'xticklabel',xTickLabels);
                    
                    
                    %                 dailyDivisionTicks = 1:8:featureStruct.totalCount;
                    %                 xticks = dailyDivisionTicks;
                    %                 weekdayticks = xticks;
                    %                 xtickLabels = featureStruct.startTimes(1:8:end);
                    %                 daysofweekStr = xtickLabels;
                    
                    legendStrings = cell(numCOIs,1);
                    centroidHandles = nan(numCOIs,1);
                    coiSortOrders = centroidHandles;
                    coiPctMemberships = coiSortOrders;
                    %                 coiIndices = centroidHandles;
                    totalMembers = 0;
                    coiMemberIDs = [];
                    for c=1:numCOIs
                        coi = cois{c};
                        if(centroidAndPlotSettings.showCentroidMembers)
                            membersLineH = plot(centroidAxes,coi.dayOfWeek.memberShapes','-','linewidth',1,'color',this.COLOR_MEMBERSHAPE);
                            if(coi.numMembers<50)
                                for m=1:coi.numMembers
                                    set(membersLineH,'uicontextmenu',this.handles.contextmenu.clusterLineMember,'userdata',coi.memberIDs(m),'buttondownfcn',{@this.memberLineButtonDownCallback,coi.memberIDs(m)});
                                end
                            end
                            
                        end
                        pctMembership =  coi.dayOfWeek.numMembers/numLoadShapes*100;
                        legendStrings{c} = sprintf('Centroid #%u (%0.2f%%)',coi.sortOrder, pctMembership);
                        
                        coiSortOrders(c) = coi.sortOrder;
                        coiPctMemberships(c) =  coi.dayOfWeek.numMembers/numLoadShapes*100;
                        %                     coiIndices(c) = coi.index;
                        coiMemberIDs = [coiMemberIDs;coi.dayOfWeek.memberIDs(:)];
                        totalMembers = totalMembers+coi.numMembers;  %total load shape counts
                        
                        
                        % This changes my axes limit mode if nextplot is set to
                        % 'replace' instead of 'replacechildren'
                        colorStyleIndex = mod(c-1,maxColorStyles)+1;  %b/c MATLAB is one based, and 'mod' is not.
                        centroidHandles(c) = plot(centroidAxes,coi.shape,'linewidth',2,'linestyle',coiStyles(colorStyleIndex),'color',coiColors(colorStyleIndex)); %[0 0 0]);
                        % 'displayname',legendStrings{c};
                    end
                    
                    %want to figure out unique individuals that may be
                    %contributing to a particular load shape.
                    uniqueMemberIDs = unique(coiMemberIDs);
                    numUniqueMemberIDs = numel(uniqueMemberIDs);
                    
                    % The centroid of interest will change according to user
                    % selection or interaction with the gui.  It is updated
                    % internally within centroidObj.
                    coi = this.centroidObj.getCentroidOfInterest();
                    pctMembership =  coi.dayOfWeek.numMembers/numLoadShapes*100;
                    
                    set(centroidAxes,'nextplot',nextPlot);
                    
                    totalMemberIDsCount = this.centroidObj.getUniqueLoadShapeIDsCount();
                    pctOfTotalMemberIDs = numUniqueMemberIDs/totalMemberIDsCount*100;
                    if(numCOIs>1)
                        coiSortOrdersString = num2str(coiSortOrders(:)','%d,');
                        coiSortOrdersString(end)=[]; %remove trailing ','
                        legend(centroidAxes,centroidHandles,legendStrings,'box','on','fontsize',12);
                        centroidTitle = sprintf('Centroids #{%s}. Loadshapes: %u of %u (%0.2f%%).  Individuals: %u of %u (%0.2f%%)',coiSortOrdersString,...
                            totalMembers, numLoadShapes, sum(coiPctMemberships), numUniqueMemberIDs,totalMemberIDsCount, pctOfTotalMemberIDs);
                    else
                        legend(centroidAxes,'off');
                        centroidTitle = sprintf('Centroid #%u (%s). Popularity %u of %u. Loadshapes: %u of %u (%0.2f%%).  Individuals: %u of %u (%0.2f%%)',coi.sortOrder,...
                            this.featureStruct.method, numCentroids-coi.sortOrder+1,numCentroids, coi.dayOfWeek.numMembers, numLoadShapes, pctMembership, numUniqueMemberIDs, totalMemberIDsCount, pctOfTotalMemberIDs);
                    end
                    title(centroidAxes,centroidTitle,'fontsize',14,'interpreter','none');
                    
                    
                    %% Analysis figure and scatter plot
                    %                 title(this.handles.axes_scatterplot,centroidTitle,'fontsize',12);
                    if(this.useDatabase)
                        set(this.handles.text_analysisTitle,'string',centroidTitle);
                        
                        displayName = sprintf('Centroid #%u (%0.2f%%)\n',[coiSortOrders(:),coiPctMemberships(:)]');
                        displayName(end-1:end) = []; %remove trailing '\n'
                        yData = get(this.handles.line_allScatterPlot,'ydata');
                        if(~isempty(yData))
                            set(this.handles.line_coiInScatterPlot,'xdata',coiSortOrders,'ydata',yData(coiSortOrders),'displayName',displayName);
                        end
                    end

                    oldVersion = verLessThan('matlab','7.14');
 
                    %%  Show distribution on secondary axes
                    switch(this.centroidDistributionType)
                        
                        % plots the Calinski-Harabasz indices obtained during
                        % adaptve k-means filtering.
                        case 'performance'
                            this.centroidObj.plotPerformance(distributionAxes);
                            
                            % plots the distribution of weekdays on x-axis
                            % and the loadshape count (for the centroid of
                            % interest) on the y-axis.
                        case 'weekday'
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
                            coiDaysOfWeekCount = histc(coiDaysOfWeek,daysofweekOrder);
                            coiDaysOfWeekPct = coiDaysOfWeekCount/sum(coiDaysOfWeekCount(:));
                            h = bar(distributionAxes,coiDaysOfWeekPct);%,'buttonDownFcn',@this.centroidDayOfWeekHistogramButtonDownFcn);
                            barWidth = get(h,'barwidth');
                            x = get(h,'xdata');
                            y = get(h,'ydata');
                            pH = nan(max(daysofweekOrder),1);
                            daysOfInterestVec = this.centroidObj.getDaysOfInterest();  %on means that we show the original bar, and that the day is 'on'; while the visibility of the overlay is off.
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
                            
                            
                            set(h,'buttonDownFcn',{@this.centroidDayOfWeekHistogramButtonDownFcn,pH});
                            
                            if(numCOIs==1)
                                title(distributionAxes,sprintf('Weekday distribution for Centroid #%u (membership count = %u)',coi.sortOrder,numMembers),'fontsize',14);
                            else
                                title(distributionAxes,sprintf('Weekday distribution for selected centroids,n=%u (membership count = %u)',numCOIs,numMembers),'fontsize',14);                                
                            end
                            %ylabel(distributionAxes,sprintf('Load shape count'));
                            xlabel(distributionAxes,'Days of week');
                            xlim(distributionAxes,[daysofweekOrder(1)-0.75 daysofweekOrder(end)+0.75]);
                            set(distributionAxes,'ylim',[0,1],'ygrid','on','ytickmode','auto','xtick',daysofweekOrder,'xticklabel',daysofweekStr);
                            
                            % plots centroids id's (sorted by membership in ascending order) on x-axis
                            % and the count of loadshapes (i.e. membership count) on the y-axis.
                        case 'membership'
                            set(distributionAxes,'ylimmode','auto');
                            barWidth = 0.8;
                            
                            y = this.centroidObj.getHistogram();
                            x = 1:numel(y);
                            
                            highlightColor = [0.75 0.75 0];
                            
                            barH = bar(distributionAxes,y,barWidth,'buttonDownFcn',@this.centroidHistogramButtonDownFcn);
                            
                            if(oldVersion)
                                %barH = bar(distributionAxes,y,barWidth);
                                defaultColor = [0 0 9/16];
                                faceVertexCData = repmat(defaultColor,numCentroids,1);
                            end
                            
                            for c=1:numCOIs
                                coi = cois{c};
                                if(oldVersion)
                                    faceVertexCData(coi.sortOrder,:) = highlightColor;
                                    patchH = get(barH,'children');
                                    if(numCentroids>100)
                                        %  set(patchH,'edgecolor',[0.4 0.4 0.4]);
                                        set(patchH,'edgecolor','none','buttonDownFcn',{@this.centroidHistogramPatchButtonDownFcn,coi.sortOrder});
                                    end
                                    set(patchH,'facevertexcdata',faceVertexCData);
                                else
                                    pH = patch(repmat(x(coi.sortOrder),1,4)+0.5*barWidth*[-1 -1 1 1],1*[y(coi.sortOrder) 0 0 y(coi.sortOrder)],highlightColor,'parent',distributionAxes,'facecolor',highlightColor,'edgecolor',highlightColor,'buttonDownFcn',{@this.centroidHistogramPatchButtonDownFcn,coi.sortOrder});
                                end
                                
                            end
                            
                            title(distributionAxes,sprintf('Centroid vs Load shape count. Centroids: %u Load shapes: %u',this.centroidObj.numCentroids(), this.centroidObj.numLoadShapes()),'fontsize',14);
                            %ylabel(distributionAxes,sprintf('Load shape count'));
                            xlabel(distributionAxes,'Centroid popularity');
                            xlim(distributionAxes,[0.25 numCentroids+.75]);
                            set(distributionAxes,'ygrid','on','ytickmode','auto','xtick',[]);
                            %                     case 'globalprofile'
                            %                         globalProfile = this.getGlobalProfile();
                            %                     case 'localVsGlobalProfile'
                            %                         globalProfile = this.getGlobalProfile();
                            %                         primaryKeys = coi.memberIDs;
                            %                         ` = this.getProfileCell(primaryKeys);
                            %                     case 'centroidprofile'
                            %                         primaryKeys = coi.memberIDs;
                            %                         coiProfile = this.getProfileCell(primaryKeys);
                        otherwise
                            warndlg(sprintf('Distribution type (%s) is unknonwn and or not supported',this.centroidDistributionType));
                    end
                    
                    
                    this.refreshCOIProfile();
                    
                end
            catch me
                showME(me);
                this.clearPrimaryAxes();                
            end
            
            this.showMouseReady();
        end
        

        
        % Refresh the user settings from current GUI configuration.
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        %> @retval userSettings Struct of GUI parameter value pairs
        % ======================================================================
        function userSettings = getPlotSettings(this)
            userSettings.discardNonWearFeatures = this.originalWidgetSettings.discardNonWearFeatures;
            
            userSettings.showCentroidMembers = get(this.handles.check_showCentroidMembers,'value');
            userSettings.processedTypeSelection = 1;
            userSettings.baseFeatureSelection = get(this.handles.menu_feature,'value');
            userSettings.signalSelection = get(this.handles.menu_signalsource,'value');
            userSettings.plotTypeSelection = get(this.handles.menu_plottype,'value');
            userSettings.sortValues = get(this.handles.check_sortvalues,'value');  %return 0 for unchecked, 1 for checked            
            userSettings.segmentSortValues = get(this.handles.check_segment,'value'); % returns 0 for unchecked, 1 for checked
            userSettings.numSortedSegments = 6;
            userSettings.normalizeValues = get(this.handles.check_normalizevalues,'value');  %return 0 for unchecked, 1 for checked
            
            userSettings.processType = this.base.processedTypes{userSettings.processedTypeSelection};
            userSettings.baseFeature = this.featureTypes{userSettings.baseFeatureSelection};
            userSettings.curSignal = this.base.signalTypes{userSettings.signalSelection};            
            userSettings.plotType = this.base.plotTypes{userSettings.plotTypeSelection};            
            userSettings.numShades = this.base.numShades;
            
            userSettings.trimResults = get(this.handles.check_trim,'value'); % returns 0 for unchecked, 1 for checked            
            userSettings.trimToPercent = str2double(get(this.handles.edit_trimToPercent,'string'));
            userSettings.cullResults = get(this.handles.check_cull,'value'); % returns 0 for unchecked, 1 for checked            
            userSettings.cullToValue = str2double(get(this.handles.edit_cullToValue,'string'));
            
                        
            
            userSettings.weekdaySelection = get(this.handles.menu_weekdays,'value');

            userSettings.startTimeSelection = get(this.handles.menu_centroidStartTime,'value');
            userSettings.stopTimeSelection = get(this.handles.menu_centroidStopTime,'value');

            % Plot settings
            userSettings.primaryAxis_yLimMode = get(this.handles.axes_primary,'ylimmode');
            userSettings.primaryAxis_nextPlot = get(this.handles.axes_primary,'nextplot');
            userSettings.showAnalysisFigure = get(this.handles.check_showAnalysisFigure,'value');
            
            userSettings.profileFieldSelection = get(this.handles.menu_ySelection,'value');
            %             userSettings.centroidStartTime = getSelectedMenuString(this.handles.menu_centroidStartTime);
            %             userSettings.centroidStopTime = getSelectedMenuString(this.handles.menu_centroidStopTime);

            userSettings.weekdayTag = this.base.weekdayTags{userSettings.weekdaySelection};
            customIndex = strcmpi(this.base.weekdayTags,'custom');
            userSettings.customDaysOfWeek = this.base.weekdayValues{customIndex};
            
            userSettings.centroidDurationSelection = get(this.handles.menu_duration,'value');
            userSettings.centroidDurationHours = this.base.centroidHourlyDurations(userSettings.centroidDurationSelection);
            
            userSettings.centroidDistributionType = this.centroidDistributionType;
            
            % Cluster settings
            userSettings.minClusters = str2double(get(this.handles.edit_centroidMinimum,'string'));
            userSettings.clusterThreshold = str2double(get(this.handles.edit_centroidThreshold,'string'));
            userSettings.clusterMethod = this.clusterSettings.clusterMethod;
            userSettings.initCentroidWithPermutation = this.clusterSettings.initCentroidWithPermutation;
            userSettings.useDefaultRandomizer = this.clusterSettings.useDefaultRandomizer;
        end

        
        %> @brief Refreshes the centroid profile table based on current 
        %> profile statistics found in member variable @c profileTableData.
        %> @param this Instance of PAStatTool.
        %> @retval didRefresh True on successful refresh, false otherwise.        
        function didRefresh = refreshProfileTableData(this)
            %             curStack = dbstack;
            %             fprintf(1,'Skipping %s on line %u of %s\n',curStack(1).name,curStack(1).line,curStack(1).file);
            
            sRow = this.getProfileFieldIndex()-1;  % Java is 0-based, MATLAB is 1-based
            sCol = max(0,this.jhandles.table_centroidProfiles.getSelectedColumn());  %give us the first column if nothing is selected)
                         
            jViewPort = this.jhandles.table_centroidProfiles.getParent();
            initViewPos = jViewPort.getViewPosition();
            set(this.handles.table_centroidProfiles,'data',this.profileTableData);
            
            %
            %             colNames = get(this.handles.table_centroidProfiles,'columnname');
%             this.jhandles.table_centroidProfiles.getModel.setDataVector(this.profileTableData, colNames); % data = java.util.Vector
            %             %             data = this.jhandles.table_centroidProfiles.getModel.getDataVector;
            
            drawnow();
            this.jhandles.table_centroidProfiles.changeSelection(sRow,sCol,false,false);            
            jViewPort.setViewPosition(initViewPos);
            drawnow();
%             jViewPort.repaint();
            
            this.jhandles.table_centroidProfiles.repaint();
            
%             this.jhandles.table_centroidProfiles.clearSelection();
%              this.jhandles.table_centroidProfiles.setRowSelectionInterval(sRow,sRow);
            
%          
            didRefresh = true;
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
        
        %> @brief Refreshes profile statistics for the current centroid of interest (COI).
        %> This method should be called whenever the COI changes.
        %> @param this Instance of PAStatTool.
        %> @retval didRefresh True on successful refresh, false otherwise.        
        function didRefresh = refreshCOIProfile(this)
            try
               if(~isempty(this.databaseObj) && this.hasCentroid())
                
                    % This gets the memberIDs attached to each centroid.
                    % This gives us all 
                    coiStruct = this.centroidObj.getCentroidOfInterest();
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
        
        % ======================================================================
        %> @brief Refreshes the global profile statistics based on the
        %> current centroids available.  This method should be called
        %> whenever the centroids are changed or updated.
        %> @param this Instance of PAStatTool.
        %> @retval didRefresh True on successful refresh, false otherwise.
        % ======================================================================
        function didRefresh = refreshGlobalProfile(this)
            try
                if(this.useDatabase && this.hasCentroid())
                    
                    % This gets the memberIDs attached to each centroid.
                    % This gives us all 
                    globalStruct = this.centroidObj.getCovariateStruct();
                    
                    % globalProfile is an Nx3 mat, where N is the number of
                    % profile fields (one per row), and the columns are
                    % ordered as {number of subjects (n), mean of subjects for row's variable, sem for subject values for the profile field associated with the current row}
                    [this.globalProfile, ~] = this.getProfileCell(globalStruct.memberIDs,this.profileFields);
                    
                    % place the global profile at the end.
                    this.profileTableData(:,end-size(this.globalProfile,2)+1:end) = this.globalProfile;  
                    this.refreshProfileTableData();
                    numCentroids = this.centroidObj.getNumCentroids();  %or numel(globalStruct.colnames).
                    xlim(this.handles.axes_scatterplot,[0 numCentroids+1]);
                    
                    %                     numFields = numel(this.profileFields);
                    %                     numSubjects = numel(globalStruct.memberIDs);
                    this.allProfiles = nan([size(this.globalProfile),numCentroids]);
                    %                     this.allCOIProfiles = nan(numFields,3,numCentroids);
                    
                    % I would like to arrange the data in terms of the sort
                    % order, so a remapping of the coiIndex occurs in this
                    % loop with the call to getCOISortOrder(coiIndex).
                    for coiIndex=1:numCentroids
                        coiMemberIDs = globalStruct.memberIDs(globalStruct.values(:,coiIndex)>0);  % pull out the members contributing to index of the current centroid of interest (coi)
                        
                        sortOrder = this.centroidObj.getCOISortOrder(coiIndex);
                        %                         if(sortOrder==21)
                        %                            disp(sortOrder);
                        %                         end
                        this.allProfiles(:,:,sortOrder) = cell2mat(this.getProfileCell(coiMemberIDs, this.profileFields));
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
            [fieldName, fieldIndex] = getSelectedMenuString(this.handles.menu_ySelection);
        end
        
        % ======================================================================
        %> @param Obtained from <PACentroid>.getCentroidOfInterest()
        %> or <PACentroid>.getCovariateStruct() for all subjects.
        %> @param Primary ID's to extract from the database.
        %> @param Field names to extract from the database.
        % ======================================================================
        function [coiProfile, dataSummaryStruct] = getProfileCell(this,primaryKeys,fieldsOfInterest)
            
            if(nargin<2)
                fieldsOfInterest = this.databaseObj.getColumnNames('subjectInfo_t');
                %                 fieldsOfInterest = {'bmi_zscore';
                %                     'insulin'};
            end
            statOfInterest = 'AVG';
            if(~isempty(this.databaseObj))
                [dataSummaryStruct, ~]=this.databaseObj.getSubjectInfoSummary(primaryKeys,fieldsOfInterest,statOfInterest);
                coiProfile = PAStatTool.profile2cell(dataSummaryStruct);
            else
                dataSummaryStruct = [];
                coiProfile = [];
            end
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
            % centroid profile table.
            userData = get(statToolObj.handles.table_centroidProfiles,'userdata');
            backgroundColor = userData.defaultBackgroundColor;
            backgroundColor(curIndex,:) = userData.rowOfInterestBackgroundColor;
            set(statToolObj.handles.table_centroidProfiles,'backgroundColor',backgroundColor,'rowStriping','on');
            drawnow();
%             pause(0.2);
            sRow = curIndex-1;  %java is 0 based
            sCol = max(0,statToolObj.jhandles.table_centroidProfiles.getSelectedColumn());  %give us the first column if nothing is selected)
%             this.jhandles.table_centroidProfiles.setRowSelectionInterval(sRow,sRow);
%             this.jhandles.table_centroidProfiles.setSelectionBackground()
            statToolObj.jhandles.table_centroidProfiles.changeSelection(sRow,sCol,false,false);
            statToolObj.jhandles.table_centroidProfiles.repaint();
            statToolObj.refreshScatterPlot();
        end
        
        % ======================================================================
        % ======================================================================
        function featureStruct = discardNonWearFeatures(featureStructIn,usageStateStruct)
            %         function featureStruct = getValidFeatureStruct(originalFeatureStruct,usageStateStruct)
            featureStruct = featureStructIn;            
            if(isempty(usageStateStruct) || isempty(featureStructIn))
%                 featureStruct = originalFeatureStruct;
            else
               tagStruct = PAData.getActivityTags();
               nonWearRows = any(usageStateStruct.shapes<=tagStruct.NONWEAR,2);
               if(any(nonWearRows))
                   featureStruct.startDatenums(nonWearRows,:)=[];
                   featureStruct.startDaysOfWeek(nonWearRows,:)=[];
                   featureStruct.shapes(nonWearRows,:)=[];
                   featureStruct.studyIDs(nonWearRows)=[];                   
               else
%                    featureStruct = originalFeatureStruct;
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
        %     filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
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
            normalizedLoadShapes = loadShapes;            
            a= sum(loadShapes,2);
            %nzi = nonZeroIndices
            nzi = a~=0;
            normalizedLoadShapes(nzi,:) = loadShapes(nzi,:)./repmat(a(nzi),1,size(loadShapes,2));            
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
        %> - @c trimToPercent
        %> - @c cullToValue
        %> - @c showCentroidMembers
        %> - @c minClusters
        %> - @c clusterThreshold
        %> - @c weekdaySelection
        %> - @c startTimeSelection
        %> - @c stopTimeSelection
        %> - @c centroidDurationSelection
        % ======================================================================
        function paramStruct = getDefaultParameters()
            % Cache directory is for storing the centroid object to 
            % so it does not have to be reloaded each time when the
            % PAStatTool is instantiated.
            if(~isdeployed)
                workingPath = fileparts(mfilename('fullpath'));
            else
                workingPath = fileparts(mfilename('fullpath'));                
            end
            
            % Prime with cluster parameters.
            paramStruct = PACentroid.getDefaultParameters();
            
            paramStruct.cacheDirectory = fullfile(workingPath,'cache');
            paramStruct.useCache = 1;
            
            paramStruct.useDatabase = 0;
            paramStruct.databaseClass = 'CLASS_database_goals';
            paramStruct.discardNonWearFeatures = 1;
            paramStruct.trimResults = 0;
            paramStruct.cullResults = 0;
            paramStruct.sortValues = 0;
            paramStruct.segmentSortValues = 0;
            paramStruct.numSortedSegments = 6;
            paramStruct.normalizeValues = 0;            
            paramStruct.processedTypeSelection = 1;
            paramStruct.baseFeatureSelection = 1;
            paramStruct.signalSelection = 1;
            paramStruct.plotTypeSelection = 1;
            paramStruct.trimToPercent = 100;
            paramStruct.cullToValue = 0;
            paramStruct.showCentroidMembers = 0;
            
            paramStruct.weekdaySelection = 1;
            paramStruct.startTimeSelection = 1;
            paramStruct.stopTimeSelection = -1;
            paramStruct.customDaysOfWeek = 0;  %for sunday.
            
            paramStruct.centroidDurationSelection = 1;
                        
            paramStruct.primaryAxis_yLimMode = 'auto';
            paramStruct.primaryAxis_nextPlot = 'replace';
            paramStruct.showAnalysisFigure = 0; % do not display the other figure at first
            paramStruct.centroidDistributionType = 'membership';  %{'performance','membership','weekday'}            
            paramStruct.profileFieldSelection = 1;            
            
           
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
            featureDescriptionStruct = PAData.getFeatureDescriptionStructWithPSDBands();
            baseSettings.featureDescriptions = struct2cell(featureDescriptionStruct);
            baseSettings.featureTypes = fieldnames(featureDescriptionStruct);
            baseSettings.signalTypes = {'x','y','z','vecMag'};
            baseSettings.signalDescriptions = {'X','Y','Z','Vector Magnitude'};
            
            baseSettings.plotTypes = {'dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling','centroids'};
            baseSettings.plotTypeDescriptions = {'Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)','Centroids'};
            baseSettings.plotTypeToolTipStrings = {
                sprintf('The daily average is calculated by taking the average feature sum per subject taken by day of the week.\n  The results should not be as biased by the number of subjects participating in any particular day.');
                sprintf('The daily tally is calculated by summing together the feature sums of each subject taken by day of the week.\n  Days with more subjects have a much greater chance of having higher sums.');
                sprintf('The morning heat map presents the average sum of early morning activity as color intensity instead of height on the y-axis.\n  It focuses on the early part of each day.');
                sprintf('The heat map presents the average sum of daily activity\n as color intensity instead of height on the y-axis.');
                sprintf('The rolling map shows the linear progression of the\n sum of subject activity by day of the week.');
                sprintf('The early morning rolling map shows the linear progression\n of the sum of subject activity for the early part of each day of the week.');
                sprintf('Centroids present the adaptive k-means centroids for the selected\n features and clustering parameters given in the controls below.');
                };

            for b=1:numel(baseSettings.plotTypes)
                plotType = baseSettings.plotTypes{b};
                baseSettings.tooltipstring.(plotType) = baseSettings.plotTypeToolTipStrings{b};
            end
            
            baseSettings.processedTypes = {'count','raw'};            
            baseSettings.numShades = 1000;
            
            baseSettings.weekdayDescriptions = {'All days','Monday-Friday','Weekend','Custom'};            
            baseSettings.weekdayTags = {'all','weekdays','weekends','custom'};
            baseSettings.weekdayValues = {0:6,1:5,[0,6],[]};
            baseSettings.daysOfWeekShortDescriptions = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            baseSettings.daysOfWeekDescriptions = {'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};
            baseSettings.daysOfWeekOrder = 1:7;
                    
            
            baseSettings.centroidDurationDescriptions = {'1 day','12 hours','6 hours','4 hours','3 hours','2 hours','1 hour'};
            baseSettings.centroidDurationDescriptions = {'24 hours','12 hours','6 hours','4 hours','3 hours','2 hours','1 hour'};

            baseSettings.centroidHourlyDurations = [24
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
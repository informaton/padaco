% ======================================================================
%> @file PAStatTool.cpp
%> @brief PAStatTool serves as Padaco's batch results analsysis controller 
% ======================================================================
classdef PAStatTool < handle
    
    properties(Access=private)
        resultsDirectory;
        featuresDirectory;
        imagesDirectory;
        %> handle of parent figure
        figureH;
        featureInputFilePattern;
        featureInputFileFieldnames;
        %> structure of loaded features
        featureStruct;
        %> struct of handles that PAStatTool interacts with.  See
        %> initHandles()
        handles; 
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
        %> instance of PACentroid class
        centroidObj;
    end
    
    properties
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
            if(nargin<3)
                widgetSettings = [];
            end
            
            this.featuresDirectory = [];
            this.imagesDirectory = [];

            this.figureH = padaco_fig_h;
            this.featureStruct = [];
            this.initHandles();            
            this.initBase();
            
            this.featureInputFilePattern = ['%s',filesep,'%s',filesep,'features.%s.accel.%s.%s.txt'];
            this.featureInputFileFieldnames = {'inputPathname','displaySeletion','processType','curSignal'};
            
            if(isdir(resultsPathname))
                this.resultsDirectory = resultsPathname;
                featuresPath = fullfile(resultsPathname,'features');
                imagesPath = fullfile(resultsPathname,'features');
                if(isdir(featuresPath))
                    this.featuresDirectory = featuresPath;
                else
                    fprintf('Features pathname (%s) does not exist!\n',featuresPath);
                end
                if(isdir(imagesPath))
                    this.imagesDirectory = imagesPath;
                else
                    fprintf('Images pathname (%s) does not exist!\n',imagesPath);
                end   
                
                this.initWidgets(widgetSettings);  %initializes previousstate.plotType on success
                plotType = this.base.plotTypes{get(this.handles.menu_plottype,'value')};
                
                switch(plotType)
                    case 'centroids'
                        this.switch2clustering();
                    otherwise
                        this.switchFromClustering();
                end
                
                this.refreshPlot();                

            else
                fprintf('%s does not exist!\n',resultsPathname); 
            end
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
        end
        
        % ======================================================================
        %> @brief Loads feature struct from disk using results feature
        %> directory.
        %> @param this Instance of PAStatTool
        %> @retval success Boolean: true if features are loaded from file.  False if they are not.
        % ======================================================================
        function success = loadFeatureStruct(this)
            pSettings = this.getPlotSettings();
            inputFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
            if(exist(inputFilename,'file'))                
                this.featureStruct = this.loadAlignedFeatures(inputFilename);
                
                loadFeatures = this.featureStruct.values;
                
                if(pSettings.trimResults)
                    pctValues = prctile(loadFeatures,pSettings.trimPercent);
                    pctValuesMat = repmat(pctValues,size(loadFeatures,1),1);
                    adjustInd = loadFeatures>pctValuesMat;
                    loadFeatures(adjustInd) = pctValuesMat(adjustInd);
                end
                
                if(pSettings.normalizeValues)
                    loadFeatures = PAStatTool.normalizeLoadShapes(loadFeatures);
                end
                this.featureStruct.features = loadFeatures;
                success = true;
            else
                this.featureStruct = [];
                success = false;
            end               
        end
        
        % ======================================================================
        %> @brief Initializes widget using current plot settings and
        %> refreshes the view.
        %> @param this Instance of PAStatTool
        % ======================================================================        
        function init(this)
            this.initWidgets(this.getPlotSettings);
            this.refreshPlot();
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
                this.showBusy();
                pSettings = this.getPlotSettings();
                
                switch(pSettings.plotType)
                    case 'centroids'
                        this.plotCentroids();                        
                    otherwise
                        
                        this.loadFeatureStruct();
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

    end
    
    methods(Access=private)
        % ======================================================================
        %> @brief Shows busy state (mouse pointer becomes a watch)
        %> @param this Instance of PAStatTool
        % ======================================================================
        function showBusy(this)
            set(this.figureH,'pointer','watch');
            drawnow();
        end
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param obj Instance of PAStatTool
        % --------------------------------------------------------------------
        function showReady(obj)
            set(obj.figureH,'pointer','arrow');
            drawnow();
        end
        
        % ======================================================================
        %> @brief Plot dropdown selection menu callback.
        %> @param this Instance of PAStatTool
        %> @param Handle of the dropdown menu.
        %> @param unused
        % ======================================================================
        function plotSelectionChange(this, menuHandle, ~)
            plotType = this.base.plotTypes{get(menuHandle,'value')};
            switch(plotType)
                case 'centroids'
                    this.switch2clustering();
                otherwise
                    if(strcmpi(this.previousState.plotType,'centroids'))
                        this.switchFromClustering();
                    end
            end
            this.previousState.plotType = plotType;
            this.refreshPlot();            
        end
        
        % ======================================================================
        %> @brief Configure gui handles for centroid analysis and viewing.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switch2clustering(this)
            this.previousState.normalizeValues = get(this.handles.check_normalizevalues,'value');
            set(this.handles.check_normalizevalues,'value',1,'enable','off');
            set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','on');
        end
        
        % ======================================================================
        %> @brief Configure gui handles for non centroid/clusting viewing
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switchFromClustering(this)
            set(this.handles.check_normalizevalues,'value',this.previousState.normalizeValues,'enable','on');
            set(findall(this.handles.panel_plotCentroid,'enable','on'),'enable','off');
            %  set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','off');
        end        

        % ======================================================================
        %> @brief Initialize gui handles using input parameter or default
        %> parameters
        %> @param this Instance of PAStatTool
        %> @param widgetSettings GUI setting parameters (optional).  If
        %> this is not included or is empty, then the default parameters are
        %> used to initialize the gui (See getDefaultParameters).
        % ======================================================================        
        function initWidgets(this, widgetSettings)
            if(nargin<2 || isempty(widgetSettings))
                widgetSettings = this.getDefaultParameters();                
            end
            
            featuresPathname = this.featuresDirectory;
            
            this.canPlot = false;    %changes to true if we find data that can be processed in featuresPathname
            set([this.handles.check_normalizevalues;
                this.handles.menu_feature;
                this.handles.menu_signalsource;
                this.handles.menu_plottype;
                this.handles.check_showCentroidMembers;
                this.handles.push_refreshCentroids;
                this.handles.check_trim;
                this.handles.edit_trimPercent],'callback',[],'enable','off');

            if(isdir(featuresPathname))
                % find allowed features which are in our base parameter and
                % also get their description.
                featureNames = getPathnames(featuresPathname);
                if(~isempty(featureNames))
                    [this.featureTypes,~,ib] = intersect(featureNames,this.base.featureTypes);
                    
                    if(~isempty(this.featureTypes))
                        this.canPlot = true;

                        % This is good for a true false checkbox value
                        % Checked state has a value of 1
                        % Unchecked state has a value of 0
                        set(this.handles.check_trim,'min',0,'max',1,'value',widgetSettings.trimResults);
                        set(this.handles.check_showCentroidMembers,'min',0,'max',1,'value',widgetSettings.showCentroidMembers);
                        set(this.handles.check_normalizevalues,'min',0,'max',1,'value',widgetSettings.normalizeValues);
                        this.previousState.normalizeValues = widgetSettings.normalizeValues;
                        
                        this.featureDescriptions = this.base.featureDescriptions(ib);
                        set(this.handles.menu_feature,'string',this.featureDescriptions,'userdata',this.featureTypes,'value',widgetSettings.baseFeatureSelection);
                        
                        if(widgetSettings.trimResults)
                            enableState = 'on';
                        else
                            enableState = 'off';
                        end
                        
                        set(this.handles.edit_trimPercent,'string',num2str(widgetSettings.trimPercent),'enable',enableState);
                        
                        % This should be updated to parse the actual output feature
                        % directories for signal type (count) or raw and the signal
                        % source (vecMag, x, y, z)
                        set(this.handles.menu_signalsource,'string',this.base.signalDescriptions,'userdata',this.base.signalTypes,'value',widgetSettings.signalSelection);
                        
                        set(this.handles.menu_plottype,'userdata',this.base.plotTypes,'string',this.base.plotTypeDescriptions,'value',widgetSettings.plotTypeSelection);
                        this.previousState.plotType = this.base.plotTypes{widgetSettings.plotTypeSelection};
                        
                        % set callbacks
                        set([this.handles.check_normalizevalues;
                            this.handles.check_trim;
                            this.handles.menu_feature;                            
                            this.handles.menu_signalsource],'callback',@this.refreshPlot,'enable','on');
                        
                        % The enabling of centroid is determined based on
                        % the plot type, and that is handled elsewhere...
                        % For now it is sufficient to refreshPlot
                        set(this.handles.check_showCentroidMembers,'callback',[]);
                        set(this.handles.menu_plottype,'callback',@this.plotSelectionChange,'enable','on');   
                        
                        set(this.handles.edit_trimPercent,'callback',@this.editTrimPercentChange);
                        
                        % this should not normally be enabled if plotType
                        % is not centroids.  However, this will be
                        % taken care of by the enable/disabling of the
                        % parent centroid panel based on the menu selection
                        % change callback which is called after initWidgets
                        % in the constructor.
                        set(this.handles.push_refreshCentroids,'callback',@this.refreshCentroids,'enable','on');
                        
                        % address centroid panel                        
                        set(this.handles.edit_centroidMinimum,'string',num2str(widgetSettings.minClusters));
                        set(this.handles.edit_centroidThreshold,'string',num2str(widgetSettings.clusterThreshold));                        
                    end
                end
            end
            
            % enable everything
            if(this.canPlot)
                set(findall(this.handles.panel_results,'enable','off'),'enable','on');
            % disable everything
            else
                set(findall(this.handles.panel_results,'enable','on'),'enable','off');                
            end
        end
        
        % ======================================================================
        %> @brief Push button callback for updating the centroids being displayed.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function updateCentroids(this,varargin)
            
            if(this.loadFeatureStruct())            
                
                loadShapes = this.featureStruct.normalizedValues;    % does not converge well if not normalized as we are no longer looking at the shape alone
                this.centroidObj = PACentroid(loadShapes,plotSettings);
                this.refreshPlot();
            else
               warndlg(sprintf('Could not find the input file required (%s)!',inputFilename));
            end
        end
        
        
        function plotCentroids(this,plotSettings)
            
            ylabelstr = sprintf('Frequency of %s %s clusters', this.featureStruct.signal.tag, this.featureStruct.method);
            xlabelstr = 'Cluster index';
            
            [idx, centroids] = adaptiveKmeans(loadShapes,minClusters, maxClusters, thresholdScale);
            numCentroids = size(centroids,1);
            n = histc(idx,1:numCentroids);
            [nsorted,ind] = sort(n);
            
            bar(this.handles.axes_secondary,nsorted);
            title(this.handles.axes_secondary,sprintf('Distribution of adaptive k-means clusters (n=%u)',numel(ind)));
            ylabel(this.handles.axes_secondary,ylabelstr);
            xlabel(this.handles.axes_secondary,xlabelstr);
            
            topN = 1;
            t=1;
            
            % because centroids were sorted in ascending order, we
            % obtain the index of the most frequent centroid from
            % the end of the sorted indices here:
            topCentroidInd = ind(end-t+1);
            clusterMemberIndices = idx==topCentroidInd;
            clusterMembershipCount = sum(clusterMemberIndices);
            
            
            titleStr = sprintf('Top %u centroid (id=%u, member count = %u) centroids (%s)',topN,topCentroidInd, clusterMembershipCount, featureStruct.method);
            sortedCentroids = centroids(ind,:);
            dailyDivisionTicks = 1:8:featureStruct.totalCount;
            xticks = dailyDivisionTicks;
            weekdayticks = xticks;
            xtickLabels = featureStruct.startTimes(1:8:end);
            daysofweekStr = xtickLabels;
            
            if(plotOptions.showCentroidMembers)
                hold(axesHandle,'on');
                
                clusterMembers = loadShapes(clusterMemberIndices,:);
                plot(axesHandle,clusterMembers','-','linewidth',1,'color',[0.85 0.85 0.85]);
                plot(axesHandle,sortedCentroids(end-t+1,:),'linewidth',2,'color',[0 0 0]);
                
                hold(axesHandle,'off');
            else
                plot(axesHandle,sortedCentroids(end-t+1,:),'linewidth',2,'color',[0 0 0]);
                
            end
            
            set(axesHandle,'ylimmode','auto');
            
            % this.refreshPlot();
            set(this.refreshCentroids,'enable','off');
        end
        
        
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        %> @param
        %> @param eventdata (req'd by matlab, but unset)
        % ======================================================================
        function editTrimPercentChange(this,editHandle,~)
            percent = str2double(get(editHandle,'string'));
            if(isempty(percent) || isnan(percent) || percent<=0 || percent>100)
                percent = 0;
                warndlg('Percent value should be in the range: (0, 100]');
            end
            set(editHandle,'string',num2str(percent));
            this.refreshPlot();
        end
        
        % only extract the handles we are interested in using for the stat tool.
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initHandles(this)
            tmpHandles = guidata(this.figureH);
            handlesOfInterest = {'check_normalizevalues'
                'menu_feature'
                'menu_signalsource'
                'menu_plottype'
                'axes_primary'
                'axes_secondary'
                'check_trim'
                'edit_trimPercent'
                'check_showCentroidMembers'
                'edit_centroidThreshold'
                'edit_centroidMinimum'
                'push_refreshCentroids'
                'panel_plotCentroid'
                'panel_results'
                'push_nextCentroid'
                'push_previousCentroid'};
            
            for f=1:numel(handlesOfInterest)
                fname = handlesOfInterest{f};
                this.handles.(fname) = tmpHandles.(fname);
            end
        end
        
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        % ======================================================================
        function initBase(this)
            this.base = this.getBaseSettings();
        end
        
        
        % Refresh the user settings from current GUI configuration.
        % ======================================================================
        %> @brief
        %> @param this Instance of PAStatTool
        %> @retval
        % ======================================================================
        function userSettings = getPlotSettings(this)
            userSettings.showCentroidMembers = get(this.handles.check_showCentroidMembers,'value');
            userSettings.processedTypeSelection = 1;
            userSettings.baseFeatureSelection = get(this.handles.menu_feature,'value');
            userSettings.signalSelection = get(this.handles.menu_signalsource,'value');
            userSettings.plotTypeSelection = get(this.handles.menu_plottype,'value');
            userSettings.normalizeValues = get(this.handles.check_normalizevalues,'value');  %return 0 for unchecked, 1 for checked
            
            userSettings.processType = this.base.processedTypes{userSettings.processedTypeSelection};
            userSettings.baseFeature = this.featureTypes{userSettings.baseFeatureSelection};
            userSettings.curSignal = this.base.signalTypes{userSettings.signalSelection};            
            userSettings.plotType = this.base.plotTypes{userSettings.plotTypeSelection};            
            userSettings.numShades = this.base.numShades;
            
            userSettings.trimResults = get(this.handles.check_trim,'value'); % returns 0 for unchecked, 1 for checked            
            userSettings.trimPercent = str2double(get(this.handles.edit_trimPercent,'string'));
            
            userSettings.minClusters = str2double(get(this.handles.edit_centroidMinimum,'string'));
            userSettings.clusterThreshold = str2double(get(this.handles.edit_centroidThreshold,'string'));
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
            daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekOrder = 1:7;
            features = this.featureStruct.features;
            divisionsPerDay = size(features,2);
            
            set(axesHandle,'ytick',[],'yticklabel',[]);
            
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
                        daysofweekStr{dayofweekIndex} = sprintf('%s\n(n=%u)',daysofweekStr{dayofweekIndex},numSubjects);
                        
                    end
                    bar(axesHandle,imageMap);
                    titleStr = 'Average Daily Tallies';
                    weekdayticks = linspace(1,7,7);
                    
                case 'dailytally'
                    imageMap = nan(7,1);
                    for dayofweek=0:6
                        imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));
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
            title(axesHandle,titleStr);
            set(axesHandle,'xtick',weekdayticks,'xticklabel',daysofweekStr);
        end
    end
    
    methods (Static)
        % ======================================================================
        %> @brief
        %> @param
        %> @retval
        % ======================================================================
        function paramStruct = getDefaultParameters()
            paramStruct.trimResults = 100;
            paramStruct.normalizeValues = 0;            
            paramStruct.processedTypeSelection = 1;
            paramStruct.baseFeatureSelection = 1;
            paramStruct.signalSelection = 1;
            paramStruct.plotTypeSelection = 1;
            paramStruct.trimPercent = 0;
            paramStruct.showCentroidMembers = 0;
            paramStruct.minClusters = 40;
            paramStruct.clusterThreshold = 1.5;
        end
        
        % ======================================================================
        % ======================================================================
        function baseSettings = getBaseSettings()
            baseSettings.featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
            baseSettings.featureTypes = {'mean','mode','rms','std','sum','var'};
            baseSettings.signalTypes = {'x','y','z','vecMag'};
            baseSettings.signalDescriptions = {'X','Y','Z','Vector Magnitude'};
            
            baseSettings.plotTypes = {'dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling','centroids'};
            baseSettings.plotTypeDescriptions = {'Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)','Centroids'};
            
            baseSettings.processedTypes = {'count','raw'};            
            baseSettings.numShades = 1000;
        end
        
        
        
        %     filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
        function featureStruct = loadAlignedFeatures(filename)
            
            
            
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
            
            startTimes = strrep(fgetl(fid),sprintf('# Start Datenum\tStart Day'),'');
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
            
            % +2 because of datenum and start date of the week that precede the
            % time stamps.
            scanStr = repmat(' %f',1,numCols+2);
            
            C = textscan(fid,scanStr,'commentstyle','#','delimiter','\t');
            featureStruct.startDatenums = cell2mat(C(:,1));
            featureStruct.startDaysOfWeek = cell2mat(C(:,2));
            featureStruct.values = cell2mat(C(:,3:end));
            % featureStruct.normalizedValues =  PAStatTool.normalizeLoadShapes(featureStruct.values);
            fclose(fid);
        end
        
        function normalizedLoadShapes = normalizeLoadShapes(loadShapes)
            
            a= sum(loadShapes,2);
            %nzi = nonZeroIndices
            nzi = a~=0;
            normalizedLoadShapes(nzi,:) = loadShapes(nzi,:)./repmat(a(nzi),1,size(loadShapes,2));
            
        end
        
    end
end
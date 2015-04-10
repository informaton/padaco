classdef PAStatTool < handle
    
    properties(Access=private)
        resultsDirectory;
        featuresDirectory;
        imagesDirectory;
        figureH;
        featureInputFilePattern;
        featureInputFileFieldnames;
        handles; % struct of handles that PAStatTool interacts with
        base;  %hold all possible parameter values that can be set
        featureTypes;
        featureDescriptions;
        %> @brief boolean set to true if result data is found.
        canPlot; 
        %> @brief Struct to keep track of settings from previous plot type
        %> selections to make transitioning back and forth between cluster
        %> plotting and others easier to stomach.  Fields include:
        %> - @c normalization The value of the check_normalizevalues widget
        %> - @c plotType The tag of the current plot type 
        %> - @c colorMap - colormap of figure;
        %> These are initialized in the initWidgets() method.
        previousState;
    end
    
    properties
    end
    
    methods        
        
        function this = PAStatTool(padaco_fig_h, resultsPathname, widgetSettings)
            if(nargin<3)
                widgetSettings = [];
            end
            
            this.featuresDirectory = [];
            this.imagesDirectory = [];

            this.figureH = padaco_fig_h;
            
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
                    case 'adaptivekmeans'
                        this.switch2clustering();
                    otherwise
                        this.switchFromClustering();
                end
                
                this.refreshPlot();                

            else
                fprintf('%s does not exist!\n',resultsPathname); 
            end
        end
        
        function canPlotValue = getCanPlot(this)
            canPlotValue = this.canPlot;
        end
        

        function paramStruct = getSaveParameters(this)
            paramStruct = this.getPlotSettings();            
        end
        
        function init(this)
            this.initWidgets(this.getPlotSettings);
            this.refreshPlot();
        end
        function refreshPlot(this,varargin)
            if(this.canPlot)
                this.showBusy();
                pSettings = this.getPlotSettings();
                
                inputFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
                if(exist(inputFilename,'file'))
                    
                    featureStruct = loadAlignedFeatures(inputFilename);
                    loadFeatures = featureStruct.(pSettings.normalizationType);
                    
                    if(pSettings.trimResults)
                        trimInd = loadFeatures < prctile(loadFeatures,99);
                        features = loadFeatures(trimInd);
                        daysofweek = pSettings.daysofweek(trimInd);
                    else
                        features =  loadFeatures;
                    end
                    featureStruct.features = features;
                    pSettings.ylabelstr = sprintf('%s of %s %s activity',pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
                    pSettings.xlabelstr = 'Days of Week';
                    
                    this.plotSelection(featureStruct,pSettings);
                else
                    warndlg(sprintf('Could not find %s',inputFilename));
                end
                this.showReady();
            else
                fprintf('PAStatTool.m cannot plot (refreshPlot)\n');
            end
        end

    end
    
    methods(Access=private)
        function showBusy(obj)
            set(obj.figureH,'pointer','watch');
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
        
        function plotSelectionChange(this, menuHandle, ~)
            plotType = this.base.plotTypes{get(menuHandle,'value')};
            switch(plotType)
                case 'adaptivekmeans'
                    this.switch2clustering();
                otherwise
                    if(strcmpi(this.previousState.plotType,'adaptivekmeans'))
                        this.switchFromClustering();
                    end
            end
            this.previousState.plotType = plotType;
            this.refreshPlot();            
        end
        
        function switch2clustering(this)
            this.previousState.normalization = get(this.handles.check_normalizevalues,'value');
            set(this.handles.check_normalizevalues,'value',2,'enable','off');
            set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','on');
        end
        
        function switchFromClustering(this)
            set(this.handles.check_normalizevalues,'value',this.previousState.normalization,'enable','on');
            set(findall(this.handles.panel_plotCentroid,'enable','on'),'enable','off');
%             set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','off');

        end
        

        
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
                this.handles.push_refreshCentroids],'callback',[],'enable','off');

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

                        % This is good for using checkbox value as a
                        % selection index in MATLAB.
                        % Checked state has a value of 2
                        % Unchecked state has a value of 1
                        set(this.handles.check_normalizevalues,'min',1,'max',2,'value',widgetSettings.normalizationSelection);
                        this.previousState.normalization = widgetSettings.normalizationSelection;
                        
                        this.featureDescriptions = this.base.featureDescriptions(ib);
                        set(this.handles.menu_feature,'string',this.featureDescriptions,'userdata',this.featureTypes,'value',widgetSettings.baseFeatureSelection);
                        
                        if(widgetSettings.trimResults)
                            enableState = 'on';
                        else
                            enableState = 'off';
                        end
                        
                        set(this.handles.edit_trimPercent,'string',num2str(widgetSettings.trimPercent),'enable',enableState);
                        
                        %  set(this.handles.check_normalizevalues,'min',1,'max',2,'value',normalizationSelection);
                        % This should be updated to parse the actual output feature
                        % directories for signal type (count) or raw and the signal
                        % source (vecMag, x, y, z)
                        set(this.handles.menu_signalsource,'string',this.base.signalDescriptions,'userdata',this.base.signalTypes,'value',widgetSettings.signalSelection);
                        
                        set(this.handles.menu_plottype,'userdata',this.base.plotTypes,'string',this.base.plotTypeDescriptions,'value',widgetSettings.plotTypeSelection);
                        this.previousState.plotType = this.base.plotTypes{widgetSettings.plotTypeSelection};
                        
                        % set callbacks
                        set([this.handles.check_normalizevalues;
                            this.handles.menu_feature;
                            this.handles.menu_signalsource;
                            this.handles.check_showCentroidMembers],'callback',@this.refreshPlot,'enable','on');
                        set(this.handles.menu_plottype,'callback',@this.plotSelectionChange,'enable','on');   
                        
                        % this should not normally be enabled if plotType
                        % is not adaptivekmeans.  However, this will be
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
        
        % only extract the handles we are interested in using for the stat tool.
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
                'panel_results'};
            for f=1:numel(handlesOfInterest)
                fname = handlesOfInterest{f};
                this.handles.(fname) = tmpHandles.(fname);
            end

        end
        
        function initBase(this)
            this.base = this.getBaseSettings();
        end
        
        
        % Refresh the user settings from current GUI configuration.
        function userSettings = getPlotSettings(this)
            userSettings.showCentroidMembers = get(this.handles.check_showCentroidMembers,'value');
            userSettings.processedTypeSelection = 1;
            userSettings.baseFeatureSelection = get(this.handles.menu_feature,'value');
            userSettings.signalSelection = get(this.handles.menu_signalsource,'value');
            userSettings.plotTypeSelection = get(this.handles.menu_plottype,'value');
            userSettings.normalizationSelection = get(this.handles.check_normalizevalues,'value');  %return 1 for unchecked, 2 for checked
            
            userSettings.processType = this.base.processedTypes{userSettings.processedTypeSelection};
            userSettings.baseFeature = this.featureTypes{userSettings.baseFeatureSelection};
            userSettings.curSignal = this.base.signalTypes{userSettings.signalSelection};            
            userSettings.normalizationType = this.base.normalizationTypes{userSettings.normalizationSelection};
            userSettings.plotType = this.base.plotTypes{userSettings.plotTypeSelection};            
            userSettings.numShades = this.base.numShades;
            
            userSettings.trimResults = get(this.handles.check_trim,'value'); % returns 0 for unchecked, 1 for checked            
            userSettings.trimPercent = str2double(get(this.handles.edit_trimPercent,'string'));
            
            userSettings.minClusters = str2double(get(this.handles.edit_centroidMinimum,'string'));
            userSettings.clusterThreshold = str2double(get(this.handles.edit_centroidThreshold,'string'));
        end
        
        
        function plotSelection(this,featureStruct,plotOptions)
            axesHandle = this.handles.axes_primary;
            daysofweek = featureStruct.startDaysOfWeek;
            daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekOrder = 1:7;
            features = featureStruct.features;
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
                    set(axesHandle,'ytick',dailyDivisionTicks,'yticklabel',featureStruct.startTimes(1:2:24));
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
                    dailyDivisionTicks = 1:8:featureStruct.totalCount;
                    set(axesHandle,'ytick',dailyDivisionTicks,'yticklabel',featureStruct.startTimes(1:8:end));
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
                case 'adaptivekmeans'
                    thresholdScale = 1.5;
                    minClusters = 40;
                    loadShapes = featureStruct.normalizedValues;    % does not converge well if not normalized...
                    maxClusters = size(loadShapes,1)/2;

                    
                    ylabelstr = sprintf('Frequency of %s %s clusters', featureStruct.signal.tag, featureStruct.method);
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
                    
                    
                case 'quantile'
                    
                otherwise
                    disp Oops!;
            end
            title(axesHandle,titleStr);
            set(axesHandle,'xtick',weekdayticks,'xticklabel',daysofweekStr);
        end
    end
    
    methods (Static)
        function paramStruct = getDefaultParameters()
            paramStruct.trimResults = 0;
            paramStruct.normalizationSelection = 2;            
            paramStruct.processedTypeSelection = 1;
            paramStruct.baseFeatureSelection = 1;
            paramStruct.signalSelection = 1;
            paramStruct.plotTypeSelection = 1;
            paramStruct.trimPercent = 0;
            paramStruct.showCentroidMembers = 0;
            paramStruct.minClusters = 40;
            paramStruct.clusterThreshold = 1.5;
        end
        
        function baseSettings = getBaseSettings()
            baseSettings.featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
            baseSettings.featureTypes = {'mean','mode','rms','std','sum','var'};
            baseSettings.signalTypes = {'x','y','z','vecMag'};
            baseSettings.signalDescriptions = {'X','Y','Z','Vector Magnitude'};
            
            baseSettings.plotTypes = {'dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling','adaptivekmeans'};
            baseSettings.plotTypeDescriptions = {'Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)','Clusters (~k-means)'};
            
            baseSettings.processedTypes = {'count','raw'};
            
            baseSettings.normalizationTypes = {'values','normalizedValues'};
            baseSettings.numShades = 1000;
        end
        
    end
end
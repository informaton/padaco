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
                
                this.initWidgets(widgetSettings);
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
        
        % Refresh the user settings from current GUI configuration.
        function userSettings = getPlotSettings(this)
            
            userSettings.processedTypeSelection = 1;
            userSettings.baseFeatureSelection = get(this.handles.menu_feature,'value');
            userSettings.signalSelection = get(this.handles.menu_signalSource,'value');
            userSettings.plotTypeSelection = get(this.handles.menu_plotType,'value');
            userSettings.normalizationSelection = get(this.handles.check_normalizeValues,'value');  %return 1 for unchecked, 2 for checked
            
            userSettings.processType = this.base.processedTypes{userSettings.processedTypeSelection};
            userSettings.baseFeature = this.featureTypes{userSettings.baseFeatureSelection};
            userSettings.curSignal = this.base.signalTypes{userSettings.signalSelection};            
            userSettings.normalizationType = this.base.normalizationTypes{userSettings.normalizationSelection};
            userSettings.plotType = this.base.plotTypes{userSettings.plotTypeSelection};            
            userSettings.numShades = this.base.numShades;
            
            userSettings.trimResults = get(this.handles.check_trimValues,'value'); % returns 0 for unchecked, 1 for checked            
            userSettings.trimPercent = str2double(get(this.handles.edit_trimPercent,'string'));
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
        
        function initWidgets(this, widgetSettings)
            if(nargin<2 || isempty(widgetSettings))
                widgetSettings = this.getDefaultParameters();
                
            end
            featuresPathname = this.featuresDirectory;
            
            this.canPlot = false;    %changes to true if we find data that can be processed in featuresPathname
            set([this.handles.check_normalizeValues,this.handles.menu_feature,this.handles.menu_signalSource,this.handles.menu_plotType],'callback',[],'enable','off');

            if(isdir(featuresPathname))
                % find allowed features which are in our base parameter and
                % also get their description.
                featureNames = getPathnames(featuresPathname);
                if(~isempty(featureNames))
                    [this.featureTypes,~,ib] = intersect(featureNames,this.base.featureTypes);
                    
                    if(~isempty(this.featureTypes))
                        this.canPlot = true;

                        % Checked state has a value of 1
                        % Unchecked state has a value of 0
                        set(this.handles.check_trimValues,'min',0,'max',1,'value',widgetSettings.trimResults);
                        set(this.handles.check_normalizeValues,'min',1,'max',2,'value',widgetSettings.normalizationSelection);
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
                        set(this.handles.menu_signalSource,'string',this.base.signalDescriptions,'userdata',this.base.signalTypes,'value',widgetSettings.signalSelection);
                        
                        set(this.handles.menu_plotType,'userdata',this.base.plotTypes,'string',this.base.plotTypeDescriptions,'value',widgetSettings.plotTypeSelection);
                        set([this.handles.check_normalizeValues,this.handles.menu_feature,this.handles.menu_signalSource,this.handles.menu_plotType],'callback',@this.refreshPlot,'enable','on');
                    end
                end
            end
            
            
        end
        
        function initHandles(this)
            tmpHandles = guidata(this.figureH);
            this.handles.check_normalizeValues = tmpHandles.check_normalizevalues;
            this.handles.menu_feature = tmpHandles.menu_feature;
            this.handles.menu_signalSource = tmpHandles.menu_signalsource;
            this.handles.menu_plotType = tmpHandles.menu_plottype;   
            this.handles.axes_primary = tmpHandles.axes_primary;
            this.handles.axes_secondary = tmpHandles.axes_secondary;
            this.handles.check_trimValues = tmpHandles.check_trim;
            this.handles.edit_trimPercent = tmpHandles.edit_trimPercent;
        end
        
        function initBase(this)
            this.base = this.getBaseSettings();
        end
        
        function plotSelection(this,featureStruct,plotOptions)
            axesHandle = this.handles.axes_primary;
            daysofweek = featureStruct.startDaysOfWeek;
            daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekOrder = 1:7;
            features = featureStruct.features;
            divisionsPerDay = size(features,2);
            
            
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
                    
                case 'quantile'
                    
                otherwise
                    disp Oops!;
            end
            title(axesHandle,titleStr);
            set(axesHandle,'xtick',weekdayticks,'xticklabel',daysofweekStr,'xgrid','on');
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
        end
        
        function baseSettings = getBaseSettings()
            baseSettings.featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
            baseSettings.featureTypes = {'mean','mode','rms','std','sum','var'};
            baseSettings.signalTypes = {'x','y','z','vecMag'};
            baseSettings.signalDescriptions = {'X','Y','Z','Vector Magnitude'};
            
            baseSettings.plotTypes = {'dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling'};
            baseSettings.plotTypeDescriptions = {'Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)'};
            
            baseSettings.processedTypes = {'count','raw'};
            
            baseSettings.normalizationTypes = {'values','normalizedValues'};
            baseSettings.numShades = 1000;
        end
        
    end
end
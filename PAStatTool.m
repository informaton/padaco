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
        %> @brief Centroid distribution mode, which is updated from the ui
        %> contextmenu of the secondary axes.  Valid tags include
        %> - @c weekday
        %> - @c membership [default]        
        centroidDistributionType;
        
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
            
            this.canPlot = false;
            this.featuresDirectory = [];
            this.imagesDirectory = [];
            this.figureH = padaco_fig_h;
            this.featureStruct = [];
            this.initHandles();            
            this.initBase();
            this.centroidDistributionType = 'performance';  %{'performance','membership','weekday'}
            
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
                this.clearPlots();
                set(padaco_fig_h,'visible','on');
                switch(plotType)
                    case 'centroids'
                        this.switch2clustering();
                    otherwise
                        this.switchFromClustering();
                end

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
                loadFeatures = this.featureStruct.shapes;
                
                
                if(pSettings.centroidDurationHours~=24)
                    hoursPerCentroid = pSettings.centroidDurationHours;
                    repRows = 24/hoursPerCentroid;
                    
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
                    
                    % assumes features are provided in 24 hour intervals
                    % from batch processing mode
                    %  durationHoursPerFeature = 24/this.featureStruct.totalCount;
                    % featuresPerHour = this.featureStruct.totalCount/24;
                    % featuresPerCentroid = hoursPerCentroid*featuresPerHour;
                
                end
                
                if(pSettings.trimResults)
                    pctValues = prctile(loadFeatures,pSettings.trimToPercent);
                    pctValuesMat = repmat(pctValues,size(loadFeatures,1),1);
                    adjustInd = loadFeatures>pctValuesMat;
                    
                end
                if(pSettings.cullResults)
                    pctValues = prctile(loadFeatures,pSettings.cullToPercent);
                    pctValuesMat = repmat(pctValues,size(loadFeatures,1),1);
                    culledInd = loadFeatures<pctValuesMat;
                end
                
                if(pSettings.trimResults)
                    loadFeatures(adjustInd) = pctValuesMat(adjustInd);                    
                end
                if(pSettings.cullResults)
                    loadFeatures(culledInd) = 0;                    
                end
                
                if(pSettings.normalizeValues)
                    [loadFeatures, nzi] = PAStatTool.normalizeLoadShapes(loadFeatures);
                    removeZeroSums = false;
                    if(removeZeroSums)
                        this.featureStruct.features = loadFeatures(nzi,:);
                        this.featureStruct.startDatenums = this.featureStruct.startDatenums(nzi);
                        this.featureStruct.startDaysOfWeek = this.featureStruct.startDaysOfWeek(nzi);
                    else
                        this.featureStruct.features = loadFeatures;
                    end
                else
                    this.featureStruct.features = loadFeatures;    
                end
                
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
            this.plotSelectionChange(this.handles.menu_plottype);
        end
        
        % ======================================================================
        %> @brief Clears the primary and secondary axes.
        %> @param this Instance of PAStatTool
        % ======================================================================        
        function clearPlots(this)
            if(~isempty(intersect(get(this.handles.axes_primary,'nextplot'),{'replacechildren','replace'})))
                cla(this.handles.axes_primary);
                cla(this.handles.axes_secondary);
            end                
            title(this.handles.axes_primary,'');
            ylabel(this.handles.axes_primary,'');
            xlabel(this.handles.axes_primary,'');
            
            
            title(this.handles.axes_secondary,'');
            ylabel(this.handles.axes_secondary,'');
            xlabel(this.handles.axes_secondary,'');
            set([this.handles.axes_primary
                this.handles.axes_secondary],'xgrid','off','ygrid','off','xtick',[],'ytick',[]);

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
            plotType = this.base.plotTypes{get(menuHandle,'value')};
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
        %> @brief Configure gui handles for non centroid/clusting viewing
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switchFromClustering(this)
            set(this.handles.check_normalizevalues,'value',this.previousState.normalizeValues,'enable','on');
            
            this.hideCentroidControls();
            
            set(findall(this.handles.panel_plotCentroid,'enable','on'),'enable','off');            %  set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','off');
            set(this.handles.axes_secondary,'visible','off');
            set(this.figureH,'WindowKeyPressFcn',[]);
            this.refreshPlot();
        end    
        
        % ======================================================================
        %> @brief Configure gui handles for centroid analysis and viewing.
        %> @param this Instance of PAStatTool
        % ======================================================================
        function switch2clustering(this)
            
            this.previousState.normalizeValues = get(this.handles.check_normalizevalues,'value');
            set(this.handles.check_normalizevalues,'value',1,'enable','off');
            set(this.handles.axes_primary,'ydir','normal');  %sometimes this gets changed by the heatmap displays which have the time shown in reverse on the y-axis
            
            
            if(isempty(this.centroidObj) || this.centroidObj.failedToConverge())
                this.disableCentroidControls();
                this.refreshCentroidsAndPlot();  
            else
                this.showCentroidControls();
                this.plotCentroids();
            end
            
%             this.disableCentroidControls();
%             this.showCentroidControls();
            set(findall(this.handles.panel_plotCentroid,'-property','enable'),'enable','on');
            
            set(this.handles.axes_secondary,'visible','on','color',[1 1 1]);
            set(this.figureH,'WindowKeyPressFcn',@this.keyPressFcn);
        end
        
        % ======================================================================
        %> @brief Window key press callback for centroid view changes
        %> @param this Instance of PAStatTool
        %> @param figH Handle to the callback figure
        %> @param eventdata Struct of key press parameters.  Fields include
        % ======================================================================
        function keyPressFcn(this,figH,eventdata)
            key=eventdata.Key;
            switch(key)
                case 'rightarrow'
                    this.showNextCentroid();
                case 'uparrow'
                    this.showNextCentroid();
                case 'leftarrow'
                    this.showPreviousCentroid();
                case 'downarrow'
                    this.showPreviousCentroid();
                otherwise                
            end
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
            this.hideCentroidControls();
            
            this.canPlot = false;    %changes to true if we find data that can be processed in featuresPathname
            set([this.handles.check_normalizevalues
                this.handles.menu_feature
                this.handles.menu_signalsource
                this.handles.menu_plottype
                this.handles.menu_weekdays
                this.handles.menu_duration
                this.handles.check_showCentroidMembers
                this.handles.push_refreshCentroids
                this.handles.push_nextCentroid
                this.handles.push_previousCentroid
                this.handles.check_trim
                this.handles.edit_trimToPercent
                this.handles.check_cull
                this.handles.edit_cullToPercent],'callback',[],'enable','off');

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
                        set(this.handles.check_trim,'min',0,'max',1,'value',widgetSettings.trimResults);
                        set(this.handles.check_cull,'min',0,'max',1,'value',widgetSettings.cullResults);
                        set(this.handles.check_showCentroidMembers,'min',0,'max',1,'value',widgetSettings.showCentroidMembers);
                        set(this.handles.check_normalizevalues,'min',0,'max',1,'value',widgetSettings.normalizeValues);
                        
                        % This should be updated to parse the actual output feature
                        % directories for signal type (count) or raw and the signal
                        % source (vecMag, x, y, z)
                        set(this.handles.menu_signalsource,'string',this.base.signalDescriptions,'userdata',this.base.signalTypes,'value',widgetSettings.signalSelection);
                        
                        set(this.handles.menu_plottype,'userdata',this.base.plotTypes,'string',this.base.plotTypeDescriptions,'value',widgetSettings.plotTypeSelection);
                        
                        % Centroid widgets
                        set(this.handles.menu_weekdays,'userdata',this.base.weekdayTags,'string',this.base.weekdayDescriptions,'value',widgetSettings.weekdaySelection);
                        set(this.handles.menu_duration,'string',this.base.centroidDurationDescriptions,'value',widgetSettings.centroidDurationSelection);
                        set(this.handles.edit_centroidMinimum,'string',num2str(widgetSettings.minClusters));
                        set(this.handles.edit_centroidThreshold,'string',num2str(widgetSettings.clusterThreshold)); 
                        
                        %% set callbacks
                        set([this.handles.check_normalizevalues;                            
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
                        set(this.handles.edit_cullToPercent,'string',num2str(widgetSettings.cullToPercent),'callback',@this.editCullToPercentChange,'enable',enableState);

                        % Push buttons
                        % this should not normally be enabled if plotType
                        % is not centroids.  However, this will be
                        % taken care of by the enable/disabling of the
                        % parent centroid panel based on the menu selection
                        % change callback which is called after initWidgets
                        % in the constructor.
                        set(this.handles.push_refreshCentroids,'callback',@this.refreshCentroidsAndPlot);
                        set(this.handles.push_previousCentroid,'callback',@this.showPreviousCentroid);
                        set(this.handles.push_nextCentroid,'callback',@this.showNextCentroid);
                        
                        set([this.handles.menu_weekdays
                            this.handles.edit_centroidMinimum
                            this.handles.edit_centroidThreshold
                            this.handles.menu_duration
                            ],'callback',@this.enableCentroidRecalculation);
                        %'h = guidata(gcbf), set(h.push_refreshCentroids,''enable'',''on'');');
                        
                        
                        % add a context menu now to secondary axes                        
                        contextmenu_secondaryAxes = uicontextmenu('callback',@this.contextmenu_secondaryAxesCallback);
                        this.handles.contextmenu.performance = uimenu(contextmenu_secondaryAxes,'Label','Show adaptive separation performance progression','callback',{@this.centroidDistributionCallback,'performance'});
                        this.handles.contextmenu.weekday = uimenu(contextmenu_secondaryAxes,'Label','Show current centroid''s weekday distribution','callback',{@this.centroidDistributionCallback,'weekday'});
                        this.handles.contextmenu.membership = uimenu(contextmenu_secondaryAxes,'Label','Show membership distribution by centroid','callback',{@this.centroidDistributionCallback,'membership'});
                        set(this.handles.axes_secondary,'uicontextmenu',contextmenu_secondaryAxes);                    
                    end
                end                
            end
           
            % These are required by follow-on calls, regardless if the gui
            % can be shown or not.  
            
            % Previous state initialization - set to current state.
            this.previousState.normalizeValues = widgetSettings.normalizeValues;
            this.previousState.plotType = this.base.plotTypes{widgetSettings.plotTypeSelection};
            
            % disable everything
            if(~this.canPlot)
                set(findall(this.handles.panel_results,'enable','on'),'enable','off');                
                this.hideCentroidControls();
            end
        end

        function primaryAxesNextPlotContextmenuCallback(this,hObject,~)
            set(get(hObject,'children'),'checked','off');            
            set(this.handles.contextmenu.nextPlot.(get(this.handles.axes_primary,'nextplot')),'checked','on');
        end
        
        function primaryAxesNextPlotCallback(this,hObject,~,nextPlot)
            set(this.handles.axes_primary,'nextplot',nextPlot);
        end
        
        function contextmenu_secondaryAxesCallback(this,varargin)
            set([this.handles.contextmenu.performance
                this.handles.contextmenu.weekday
                this.handles.contextmenu.membership],'checked','off');
            set(this.handles.contextmenu.(this.centroidDistributionType),'checked','on');                
        end               
        
        function centroidDistributionCallback(this,hObject,eventdata,selection)
            this.centroidDistributionType = selection;
            this.plotCentroids();
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
                'menu_weekdays'
                'menu_duration'
                'axes_primary'
                'axes_secondary'
                'check_trim'
                'edit_trimToPercent'
                'check_cull'
                'edit_cullToPercent'
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
                };
            
            for f=1:numel(handlesOfInterest)
                fname = handlesOfInterest{f};
                this.handles.(fname) = tmpHandles.(fname);
            end
            this.handles.panels_sansCentroids = [
                tmpHandles.panel_plotType;
                tmpHandles.panel_plotSignal;
                tmpHandles.panel_plotData];
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
            daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
            daysofweekOrder = 1:7;
            features = this.featureStruct.features;
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
                    titleStr = 'Average Daily Tallies (total daily tally divided by number of subjects that day)';
                    weekdayticks = linspace(1,7,7);
                    
                case 'dailytally'
                    imageMap = nan(7,1);
                    for dayofweek=0:6
                        imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));
                        
                        dayofweekIndex = daysofweekOrder(dayofweek+1);
                        numSubjects = sum(dayofweek==daysofweek);
                        daysofweekStr{dayofweekIndex} = sprintf('%s\n(n=%u)',daysofweekStr{dayofweekIndex},numSubjects);
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
        %> @brief Callback for cull percent change edit widget
        %> @param this Instance of PAStatTool
        %> @param editHandle handle to edit box.
        %> @param eventdata (req'd by matlab, but unset)
        % ======================================================================
        function editCullToPercentChange(this,editHandle,~)
            percent = str2double(get(editHandle,'string'));
            if(isempty(percent) || isnan(percent) || percent<=0 || percent>100)
                percent = 0;
                warndlg('Percent value should be in the range: (0, 100]');
            end
            set(editHandle,'string',num2str(percent));
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
            set(this.handles.edit_cullToPercent,'enable',enableState);            
            this.refreshPlot();
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the next centroid.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function showNextCentroid(this,varargin)
            if(~isempty(this.centroidObj))
                this.centroidObj.increaseCOISortOrder();
                this.plotCentroids();
            end
        end
        
        % ======================================================================
        %> @brief Push button callback for displaying the previous centroid.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function showPreviousCentroid(this,varargin)
            if(~isempty(this.centroidObj))
                this.centroidObj.decreaseCOISortOrder();
                this.plotCentroids();
            end
        end
        
        % ======================================================================
        %> @brief Callback to enable the push_refreshCentroids button.  The button's 
        %> background color is switched to green to highlight the change and need
        %> for recalculation.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function enableCentroidRecalculation(this,varargin)
            set(this.handles.push_refreshCentroids,'enable','on','backgroundcolor','green');
        end
        
        % ======================================================================
        %> @brief Check button callback to refresh centroid display.
        %> @param this Instance of PAStatTool
        %> @param Variable number of arguments required by MATLAB gui callbacks
        % ======================================================================
        function checkShowCentroidMembershipCallback(this,varargin)
            this.plotCentroids();
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
            this.clearPlots();
            this.showBusy();
            pSettings= this.getPlotSettings();
            this.centroidObj = [];            
            if(this.loadFeatureStruct())            
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
                switch(pSettings.weekdayTag)
                    
                    case 'weekdays'
                        daysOfInterest = 1:5;
                    case 'weekends'
                        daysOfInterest = [0,6];
                    case 'all'
                        daysOfInterest = [];
                    otherwise               
                        daysOfInterest = [];
                        %this is the default case with 'all'
                end
                
                if(~isempty(daysOfInterest))
                    rowsOfInterest = ismember(this.featureStruct.startDaysOfWeek,daysOfInterest); 
                    % fieldsOfInterest = {'startDatenums','startDaysOfWeek','shapes','features'};
                    fieldsOfInterest = {'startDaysOfWeek','features'};
                    for f=1:numel(fieldsOfInterest)
                        fname = fieldsOfInterest{f};
                        this.featureStruct.(fname) = this.featureStruct.(fname)(rowsOfInterest,:);                        
                    end                    
                end                
                resultsTextH = this.handles.text_resultsCentroid;
                set(this.handles.axes_primary,'color',[1 1 1],'xlimmode','auto','ylimmode','auto','xtickmode','auto','ytickmode','auto','xticklabelmode','auto','yticklabelmode','auto','xminortick','off','yminortick','off');
                set(resultsTextH,'visible','on','foregroundcolor',[0.1 0.1 0.1]);
% %                 set(this.handles.text_primaryAxes,'backgroundcolor',[0 0 0],'foregroundcolor',[1 1 0],'visible','on');
                this.showCentroidControls();
                
                drawnow();
                this.centroidObj = PACentroid(this.featureStruct.features,pSettings,this.handles.axes_primary,resultsTextH);
                if(this.centroidObj.failedToConverge())
                    warndlg('Failed to converge');
                    this.centroidObj = [];
                else
                    %                     fprintf(1,'pause(3)');
                    %                     pause(3);
                    %                     set(this.handles.text_results,'visible','off','string','');
                    %                     fprintf(1,'\n');
                end
            else
                inputFilename = sprintf(this.featureInputFilePattern,this.featuresDirectory,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);                
                warndlg(sprintf('Could not find the input file required (%s)!',inputFilename));
            end
            
            if(~isempty(this.centroidObj))
                defaultBackgroundColor = get(0,'FactoryuicontrolBackgroundColor');
                set(this.handles.push_refreshCentroids,'enable','off','backgroundcolor',defaultBackgroundColor);
                this.plotCentroids(pSettings); 
                this.enableCentroidControls();
            else
                this.disableCentroidControls();
                set(this.handles.axes_primary,'color',[0.75 0.75 0.75]);
            end
            dissolve(resultsTextH,2.5);
            this.showReady();
        end        
        
        function hideCentroidControls(this)
            set(this.handles.panel_controlCentroid,'visible','off'); 
            % add a context menu now to primary axes
            set(this.handles.axes_primary,'uicontextmenu',[]);
        end
        
        function showCentroidControls(this)
            set(this.handles.panel_controlCentroid,'visible','on');
        end
        
        function enableCentroidControls(this)
            set(findall(this.handles.panel_controlCentroid,'enable','off'),'enable','on');  
            % add a context menu now to primary axes
            contextmenu_primaryAxes = uicontextmenu();
            nextPlotmenu = uimenu(contextmenu_primaryAxes,'Label','Next plot','callback',@this.primaryAxesNextPlotContextmenuCallback);
%             this.handles.contextmenu.nextPlot.replace = uimenu(nextPlotmenu,'Label','Replace','callback',{@this.primaryAxesNextPlotCallback,'replace'});
            this.handles.contextmenu.nextPlot.add = uimenu(nextPlotmenu,'Label','Add','callback',{@this.primaryAxesNextPlotCallback,'add'});
            %                         this.handles.contextmenu.nextPlot.new = uimenu(nextPlotmenu,'Label','New','callback',{@this.primaryAxesNextPlotCallback,'new'});
            this.handles.contextmenu.nextPlot.replacechildren = uimenu(nextPlotmenu,'Label','Replace children','callback',{@this.primaryAxesNextPlotCallback,'replacechildren'});
            set(this.handles.axes_primary,'uicontextmenu',contextmenu_primaryAxes);            
        end
        
        function disableCentroidControls(this)
            set(findall(this.handles.panel_controlCentroid,'enable','on'),'enable','off');              
            set(this.handles.text_resultsCentroid,'enable','on');
            % add a context menu now to primary axes           
            set(this.handles.axes_primary,'uicontextmenu',[]);
        end
        
        % ======================================================================
        %> @brief Displays most recent centroid data according to gui
        %> setttings.
        %> @param this Instance of PAStatTool
        %> @param plotSettings Structure of GUI parameters for configuration and 
        %> display of centroid data.
        % ======================================================================
        function plotCentroids(this,centroidAndPlotSettings)
            this.clearPlots();
            this.showMouseBusy();

            
            if(isempty(this.centroidObj)|| this.centroidObj.failedToConverge())
               % clear everything and give a warning that the centroid is empty
               fprintf('Clustering results are empty\n');
            else
                if(nargin<2)
                    centroidAndPlotSettings = this.getPlotSettings();
                end
                distributionAxes = this.handles.axes_secondary;
                centroidAxes = this.handles.axes_primary;
                
                
                numCentroids = this.centroidObj.numCentroids();
                numLoadShapes = this.centroidObj.numLoadShapes();
                
                %% Show centroids on primary axes
                coi = this.centroidObj.getCentroidOfInterest();
                
                %                 dailyDivisionTicks = 1:8:featureStruct.totalCount;
                %                 xticks = dailyDivisionTicks;
                %                 weekdayticks = xticks;
                %                 xtickLabels = featureStruct.startTimes(1:8:end);
                %                 daysofweekStr = xtickLabels;
                
                nextPlot = get(centroidAxes,'nextplot');                
                if(centroidAndPlotSettings.showCentroidMembers)
                    hold(centroidAxes,'on');                    
                    plot(centroidAxes,coi.memberShapes','-','linewidth',1,'color',[0.85 0.85 0.85]);
                    set(centroidAxes,'ygrid','on');
                else
                    set(centroidAxes,'ygrid','off');                    
                end                
                set(centroidAxes,'ytickmode','auto','ylimmode','auto','yticklabelmode','auto');
                plot(centroidAxes,coi.shape,'linewidth',2,'color',[0 0 0]);
                
                set(centroidAxes,'nextplot',nextPlot);
                
                xTicks = 1:8:this.featureStruct.totalCount;
                if(xTicks(end)~=this.featureStruct.totalCount)
                    xTicks(end+1)=this.featureStruct.totalCount;
                end
                xTickLabels = this.featureStruct.startTimes(xTicks);
                
                centroidTitle = sprintf('Centroid #%u (%s). Popularity %u of %u (membership count = %u of %u)',coi.index, this.featureStruct.method, numCentroids-coi.sortOrder+1,numCentroids, coi.numMembers, numLoadShapes);
                title(centroidAxes,centroidTitle,'fontsize',14);
                set(centroidAxes,'xlim',[1,this.featureStruct.totalCount],'xtick',xTicks,'xticklabel',xTickLabels);
                
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
                        daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
                        daysofweekOrder = 1:7;
                        
                        % +1 to adjust startDaysOfWeek range from [0,6] to [1,7]
                        coiDaysOfWeek = this.featureStruct.startDaysOfWeek(coi.memberIndices)+1;
                        coiDaysOfWeekCount = histc(coiDaysOfWeek,daysofweekOrder);
                        coiDaysOfWeekPct = coiDaysOfWeekCount/sum(coiDaysOfWeekCount(:));
                        bar(distributionAxes,coiDaysOfWeekPct);
                        
                        for d=1:7
                            daysofweekStr{d} = sprintf('%s (n=%u)',daysofweekStr{d},coiDaysOfWeekCount(d));
                        end
                        
                        title(distributionAxes,sprintf('Weekday distribution for Centroid #%u (membership count = %u)',coi.index,coi.numMembers),'fontsize',14);
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
                        oldVersion = false;
                        if(oldVersion)
                            barH = bar(distributionAxes,y,barWidth);
                            defaultColor = [0 0 9/16];
                            faceVertexCData = repmat(defaultColor,numCentroids,1);
                            faceVertexCData(coi.sortOrder,:) = highlightColor;
                            patchH = get(barH,'children');
                            if(numCentroids>100)
                                %  set(patchH,'edgecolor',[0.4 0.4 0.4]);
                                set(patchH,'edgecolor','none');
                            end
                            set(patchH,'facevertexcdata',faceVertexCData);
                        else
                            bar(distributionAxes,y,barWidth);
                            patch(repmat(x(coi.sortOrder),1,4)+0.5*barWidth*[-1 -1 1 1],1*[y(coi.sortOrder) 0 0 y(coi.sortOrder)],highlightColor,'parent',distributionAxes,'facecolor',highlightColor,'edgecolor',highlightColor);
                        end
                        
                        title(distributionAxes,sprintf('Load shape count per centroid (Total centroid count: %u\tTotal load shape count: %u)',this.centroidObj.numCentroids(), this.centroidObj.numLoadShapes()),'fontsize',14);
                        %ylabel(distributionAxes,sprintf('Load shape count'));
                        xlabel(distributionAxes,'Centroid');
                        xlim(distributionAxes,[0.25 numCentroids+.75]);
                        set(distributionAxes,'ygrid','on','ytickmode','auto','xtick',[]);
                    otherwise
                        warndlg(sprintf('Distribution type (%s) is unknonwn and or not supported',distributionType));                        
                end
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
            userSettings.trimToPercent = str2double(get(this.handles.edit_trimToPercent,'string'));
            userSettings.cullResults = get(this.handles.check_cull,'value'); % returns 0 for unchecked, 1 for checked            
            userSettings.cullToPercent = str2double(get(this.handles.edit_cullToPercent,'string'));
            
            userSettings.minClusters = str2double(get(this.handles.edit_centroidMinimum,'string'));
            userSettings.clusterThreshold = str2double(get(this.handles.edit_centroidThreshold,'string'));            
            userSettings.weekdaySelection = get(this.handles.menu_weekdays,'value');
            userSettings.weekdayTag = this.base.weekdayTags{userSettings.weekdaySelection};
            userSettings.centroidDurationSelection = get(this.handles.menu_duration,'value');
            userSettings.centroidDurationHours = this.base.centroidHourlyDurations(userSettings.centroidDurationSelection);
        end
                
                
    end
    
    methods (Static)
        
        % ======================================================================
        %> @brief Loads and aligns features from a padaco batch process
        %> results output file.
        %> @param filename Full filename (i.e. contains absolute pathname)
        %> of features file produced by padaco's batch processing mode.
        %> @retval featureStruct A structure of aligned features obtained
        %> from filename.  Fields include:
        %> - @c shapes
        %> - @c startTimes
        %> - @c startDaysOfWeek
        %> - @c startDatenums
        %> - @c totalCount
        %> - @c signal
        %> - @c method
        %> - @c methodDescription
        %     filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
        % ======================================================================
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
            featureStruct.shapes = cell2mat(C(:,3:end));
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
        %> - @c normalizeValues
        %> - @c processedTypeSelection
        %> - @c baseFeatureSelection
        %> - @c signalSelection
        %> - @c plotTypeSelection
        %> - @c trimToPercent
        %> - @c cullToPercent
        %> - @c showCentroidMembers
        %> - @c minClusters
        %> - @c clusterThreshold
        %> - @c weekdaySelection
        %> - @c centroidDurationSelection
        % ======================================================================
        function paramStruct = getDefaultParameters()
            paramStruct.trimResults = 0;
            paramStruct.cullResults = 0;
            paramStruct.normalizeValues = 0;            
            paramStruct.processedTypeSelection = 1;
            paramStruct.baseFeatureSelection = 1;
            paramStruct.signalSelection = 1;
            paramStruct.plotTypeSelection = 1;
            paramStruct.trimToPercent = 100;
            paramStruct.trimToPercent = 0;
            paramStruct.showCentroidMembers = 0;
            paramStruct.minClusters = 40;
            paramStruct.clusterThreshold = 1.5;
            paramStruct.weekdaySelection = 1;
            paramStruct.centroidDurationSelection = 1;
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
            baseSettings.featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
            baseSettings.featureTypes = {'mean','mode','rms','std','sum','var'};
            baseSettings.signalTypes = {'x','y','z','vecMag'};
            baseSettings.signalDescriptions = {'X','Y','Z','Vector Magnitude'};
            
            baseSettings.plotTypes = {'dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling','centroids'};
            baseSettings.plotTypeDescriptions = {'Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)','Centroids'};
            
            baseSettings.processedTypes = {'count','raw'};            
            baseSettings.numShades = 1000;
            
            baseSettings.weekdayDescriptions = {'All days','Monday-Friday','Weekend'};            
            baseSettings.weekdayTags = {'all','weekdays','weekends'};
            
            baseSettings.centroidDurationDescriptions = {'1 day','12 hours','6 hours','4 hours','3 hours','2 hours','1 hour'};
            baseSettings.centroidHourlyDurations = [24
                12
                6
                4
                3
                2
                1];
        end
                
    end
end
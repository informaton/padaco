%> @file PAView.cpp
%> @brief PAView serves as Padaco's time series view controller
% ======================================================================
%> @brief PAView serves as Padaco's time series view controller.
classdef PAView < handle
    
    properties (SetAccess = protected)
        
        %> @brief String representing the current type of display being used.
        %> Can be
        %> @li @c Time Series
        %> @li @c Aggregate Bins
        %> @li @c Features
        displayType; 
        
        %> Boolean value: 
        %> - @c true : Apply line smoothing when presenting features on the
        %> secondary axes (Default).  
        %> - @c false : Do not apply line smoothing when presenting features on the
        %> secondary axes (show them in original form).
        useSmoothing;  
        
        %> Boolean value: 
        %> - @c true : Highlight nonwear in second secondary axes (Default).  
        %> - @c false : Do not highlight nonwear on the secondary axes.
        nonwearHighlighting;          
        
        

        %> for the patch handles when editing and dragging
        hg_group;   %may be unused?
        
        %>cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell;
        
        %> figure handle that the class instance is associated with
        figurehandle;
        
        %> @brief struct whose fields are axes handles.  Fields include:
        %> - @b primary handle to the main axes an instance of this class is associated with
        %> - @b secondary Window view of events (over view)
        axeshandle;
        
        %> @brief struct whose fields are patch handles.  Fields include:
        %> - @c feature Patches representing the current feature method.
        patchhandle;        
        
        %         %> @brief Struct whose fields are table handles.  Fields include:
        %         %> - @c centroidProfiles Table for showing descriptive nature of
        %         %> the profiles.
        % tableHandle;
        
        %> @brief struct whose fields are structs with names of the axes and whose fields are property values for those axes.  Fields include:
        %> - @b primary handle to the main axes an instance of this class is associated with
        %> - @b secondary Window view of events (over view)
        axesproperty;
        
        %> @brief struct of text handles.  Fields are: 
        %> - @c status handle to the text status location of the Padaco figure where updates can go
        %> - @c studyinfo handle to the text box for display of loaded filename
        %> - @c curWindow 
        %> - @c aggregateDuration
        %> - @c frameDurationMinutes
        %> - @c frameDurationHours
        %> - @c trimAmount        
        texthandle; 
        
        %> @brief struct of panel handles.  Fields are: 
        %> - @c controls Handle to the left most panel that contains a panel of features
        %> - @c features Handle to the panel that contains widgets for extracting features.
        %> - @c metaData Handle to the panel that describes information about the current study.
        panelhandle;
        
        %> @brief struct of menu handles.  Fields are: 
        %> - @c windowDurSec The window display duration in seconds
        %> - @c prefilter The selection of prefilter methods
        %> - @c signalSelection The signal to use (e.g. x-acceleration)
        %> - @c displayFeature Which feature to display (Default is all)
        %> - @c signalource - This is for the result type
        %> - @c featureSource - Result selection feature.
        %> - @c resultType - plot type used to show signal-feature results.
        menuhandle;
        
        %> @brief Struct of check box handles.  Fields include
        %> - @c normalizeResults - check to show normalized results.
        %> - @c trimResults - check to trim outlier results.  
        checkhandle;
        %> @brief Struct of line handles (graphic handle class) for showing
        %> activity data.
        linehandle;
        
        %> @brief struct of line handles with matching fieldnames of
        %> instance variable linehandle which are used to draw a dotted reference
        %> line corresponding to zero.
        referencelinehandle;
        %> @brief Struct of text handles (graphic handle class) that display the 
        %> the name or label of the line held at the corresponding position
        %> of linehandle.        
        labelhandle;
        
        %> @brief Graphic handle of the vertical bar which provides a
        %> visual reference of where the window is in comparison to the entire
        %> study.
        positionBarHandle;
        
        %> struct of handles for the context menu.  Fields include
        %> - @c primaryAxes - for the primary Axes.
        %> - @c signals - For the lines, reference lines, and labels
        contextmenuhandle; 
         
        %> PASensorData instance
        accelObj;
        window_resolution;%struct of different time resolutions, field names correspond to the units of time represented in the field        
    end


    methods
        
        % --------------------------------------------------------------------
        %> PAView class constructor.
        %> @param Padaco_fig_h Figure handle to assign PAView instance to.
        %> @param lineContextmenuHandle Contextmenu handle to assign to
        %> VIEW's line handles
        %> @param primaryAxesContextmenuHandle Contextmenu to assign to
        %> VIEW's primary axes.
        %> @param featureLineContextmenuHandle Contextmenu to assign to
        %> VIEW's feature line handles.
        %> @retval obj Instance of PAView
        % --------------------------------------------------------------------
        function obj = PAView(Padaco_fig_h,lineContextmenuHandle,primaryAxesContextmenuHandle,featureLineContextmenuHandle,secondaryAxesContextmenuHandle)
            if(ishandle(Padaco_fig_h))
                if(nargin<4)
                    secondaryAxesContextmenuHandle = [];
                    if(nargin<3)
                        primaryAxesContextmenuHandle = [];
                        
                        if(nargin<2)
                            lineContextmenuHandle = [];
                        else
                            if(ishandle(lineContextmenuHandle))
                                set(lineContextmenuHandle,'parent',Padaco_fig_h);
                            end
                        end
                    else
                        if(ishandle(primaryAxesContextmenuHandle))
                            set(primaryAxesContextmenuHandle,'parent',Padaco_fig_h);
                        end
                    end
                else
                    if(ishandle(secondaryAxesContextmenuHandle))
                        set(secondaryAxesContextmenuHandle,'parent',Padaco_fig_h);
                    end
                    
                end
                
                obj.figurehandle = Padaco_fig_h;
                set(obj.figurehandle,'renderer','zbuffer');
                %                 set(obj.figurehandle,'renderer','OpenGL');

                obj.contextmenuhandle.primaryAxes = primaryAxesContextmenuHandle;
                obj.contextmenuhandle.secondaryAxes = secondaryAxesContextmenuHandle;
                obj.contextmenuhandle.signals = lineContextmenuHandle;
                obj.contextmenuhandle.featureLine = featureLineContextmenuHandle;
                
                obj.useSmoothing = true;
                obj.nonwearHighlighting = true;
                
                obj.createView(); 
                obj.disableWidgets();
                
                %                 set(obj.getFigHandle(),'visible','on');

                
            else
                obj = [];
            end
        end 
        
                
        % --------------------------------------------------------------------
        %> @brief Creates line handles and maps figure tags to PAView instance variables.
        %> @param obj Instance of PAView.
        %> @note This method does not set the view mode.  Call
        %> setViewMode(.) to configure the axes and widgets accordingly.
        % --------------------------------------------------------------------
        function createView(obj)
            
            handles = guidata(obj.getFigHandle());
            
            obj.texthandle.status = handles.text_status;
            obj.texthandle.filename = handles.text_filename;
            obj.texthandle.studyinfo = handles.text_studyinfo;
            obj.texthandle.curWindow = handles.edit_curWindow;
            obj.texthandle.aggregateDuration = handles.edit_aggregate;
            obj.texthandle.frameDurationMinutes = handles.edit_frameSizeMinutes;
            obj.texthandle.frameDurationHours = handles.edit_frameSizeHours;            
            obj.texthandle.trimAmount = handles.edit_aggregate;
            
            %             obj.tablehandle.centroidProfiles = handles.table_profiles;
            obj.patchhandle.controls = handles.panel_timeseries;
            obj.patchhandle.features = handles.panel_features;
            obj.patchhandle.metaData = handles.panel_study;
            
            obj.menuhandle.windowDurSec = handles.menu_windowDurSec;
            obj.menuhandle.signalSelection = handles.menu_signalSelection;
            obj.menuhandle.prefilterMethod = handles.menu_prefilter;
            obj.menuhandle.displayFeature = handles.menu_displayFeature;
            
            obj.menuhandle.signalSource = handles.menu_signalsource;
            obj.menuhandle.featureSource = handles.menu_feature;
            obj.menuhandle.resultType = handles.menu_plottype;
            
            obj.checkhandle.normalizeResults = handles.check_normalizevalues;
            
            obj.checkhandle.trimResults = handles.check_trim;
            
            %             obj.timeseries.menuhandle = obj.menuhandle;
            %             obj.timeseries.texthandle = obj.texthandle;
            %             obj.timeseries.patchhandle = obj.patchhandle;
            
            obj.axeshandle.primary = handles.axes_primary;
            obj.axeshandle.secondary = handles.axes_secondary;
            
            % create a spot for it in the struct;
            obj.patchhandle.feature = [];
            

            % Clear the figure and such.  
            obj.clearAxesHandles();
            obj.clearTextHandles(); 
            obj.clearWidgets();            
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets padaco's view mode to either time series or results viewing.
        %> @param obj Instance of PAView
        %> @param viewModeView A string with one of two values
        %> - @c timeseries
        %> - @c results
        % --------------------------------------------------------------------        
        function setViewMode(obj,viewMode)
            set(obj.figurehandle,'WindowKeyPressFcn',[]);
            set(obj.axeshandle.secondary,'uicontextmenu',[]);

            obj.initAxesHandlesViewMode(viewMode);
            obj.clearTextHandles();
            obj.initWidgets(viewMode);
        end
        
        % returns visible linehandles in the upper axes of padaco.
        function visibleLineHandles = getVisibleLineHandles(obj)
            lineHandleStructs = obj.getLinehandle(obj.getDisplayType());
            lineHandles = struct2vec(lineHandleStructs);
            visibleLineHandles = lineHandles(strcmpi(get(lineHandles,'visible'),'on'));
        end
        
        function hiddenLineHandles = getHiddenLineHandles(obj)
            lineHandleStructs = obj.getLinehandle(obj.getDisplayType());
            lineHandles = struct2vec(lineHandleStructs);
            hiddenLineHandles = lineHandles(strcmpi(get(lineHandles,'visible'),'off'));
            
        end
        %> @brief Want to redistribute or evenly distribute the lines displayed in
        %> this axis.
        function redistributePrimaryAxesLineHandles(obj)
            visibleLineHandles = obj.getVisibleLineHandles();
            numLines = numel(visibleLineHandles);
            if(numLines>0)
                curYLim = get(obj.axeshandle.primary,'ylim');
                
                axesHeight = diff(curYLim);
                deltaHeight = axesHeight/numLines;
                offset = deltaHeight/2;
                for n=1:numLines
                    curH = visibleLineHandles(n);
                    curTag = get(curH,'tag');
                    obj.accelObj.setOffset(curTag,offset);
                    offset = offset+deltaHeight;
                end
            end
            obj.draw()
        end

        % --------------------------------------------------------------------
        %> @brief Retrieves the window duration drop down menu's current value as a number.
        %> @param obj Instance of PAView.
        %> @retval windowDurSec Duration of the current view's window as seconds.
        % --------------------------------------------------------------------
        function windowDurSec = getWindowDurSec(obj)
            userChoice = get(obj.menuhandle.windowDurSec,'value');
            userData = get(obj.menuhandle.windowDurSec,'userdata');
            windowDurSec = userData(userChoice);
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets the window duration drop down menu's current value
        %> based on the input parameter (as seconds).  If the duration in
        %> seconds is not found, then the value is appended to the drop down
        %> menu prior to being set.
        %> @param obj Instance of PAView.
        %> @param windowDurSec Duration in seconds to set the drop downmenu's selection to
        % --------------------------------------------------------------------
        function windowDurSec = setWindowDurSecMenu(obj, windowDurSec)
            windowDurSecMat = get(obj.menuhandle.windowDurSec,'userdata');
            userChoice = find(windowDurSecMat==windowDurSec,1);
            
            % We did not find a match!  and need to append
            if(isempty(userChoice))
                windowDurStrCell = get(obj.menuhandle.windowDurSec,'string');
                windowDurStrCell(end+1) = num2str(windowDurSec);
                windowDurSecMat(end+1) = windowDurSec;
                userChoice =numel(windowDurStrCell);
                
                set(obj.menuhandle.windowDurSec,'userdata',windowDurSecMat,'string',windowDurStrCell);
            end
            set(obj.menuhandle.windowDurSec,'value',userChoice);
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves the current window's edit box string value as a
        %> number
        %> @param obj Instance of PAView.
        %> @retval curWindow Numeric value of the current window displayed in the edit box.
        % --------------------------------------------------------------------
        function curWindow = getCurWindow(obj)
            curWindow = str2double(get(obj.texthandle.curWindow,'string'));
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets current window edit box string value
        %> @param obj Instance of PAView.
        %> @param windowStr A string to display in the current window edit
        %> box.
        %> @param xposStart The position on the x-axis of where the window starts.
        %> This will be a datenum for padaco.
        %> @param xposEnd The position on the x-axis of where the window in the 
        %> ends. This will be a datenum for padaco.        
        % --------------------------------------------------------------------
        function setCurWindow(obj,windowStr,xposStart,xposEnd)
            set(obj.texthandle.curWindow,'string',windowStr);
            set(obj.positionBarHandle,'xdata',[repmat(xposStart,1,2),repmat(xposEnd,1,2),xposStart]);
            set(obj.patchhandle.positionBar,'xdata',[repmat(xposStart,1,2),repmat(xposEnd,1,2)]);
            obj.draw();
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets aggregate duration edit box string value
        %> @param obj Instance of PAView.
        %> @param aggregateDurationStr A string representing the aggregate duration as minutes.
        % --------------------------------------------------------------------
        function setAggregateDurationMinutes(obj,aggregateDurationStr)
           set(obj.texthandle.aggregateDuration,'string',aggregateDurationStr);            
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves the aggregate duration edit box value as a
        %> number.
        %> @param obj Instance of PAView.
        %> @retval aggregateDurMin The aggregate duration (in minutes) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function aggregateDurMin = getAggregateDurationMinutes(obj)
            aggregateDurMin = str2double(get(obj.texthandle.aggregateDuration,'string'));
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets frame duration edit box (minutes) string value
        %> @param obj Instance of PAView.
        %> @param frameDurationMinutesStr A string representing the frame duration as minutes.
        % --------------------------------------------------------------------
        function setFrameDurationMinutes(obj,frameDurationMinutesStr)
           set(obj.texthandle.frameDurationMinutes,'string',frameDurationMinutesStr);            
        end   
        
        % --------------------------------------------------------------------
        %> @brief Sets frame duration edit box (hours) string value
        %> @param obj Instance of PAView.
        %> @param frameDurationHoursStr A string representing the frame duration as minutes.
        % --------------------------------------------------------------------
        function setFrameDurationHours(obj,frameDurationHoursStr)
           set(obj.texthandle.frameDurationHours,'string',frameDurationHoursStr);            
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets line smoothing state for feature vectors displayed on the secondary axes.
        %> @param obj Instance of PAView.
        %> @param smoothingState  Possible values include:
        %> - @c true Smoothing is on.
        %> - @c false Smoothing is off.
        % --------------------------------------------------------------------
        function setUseSmoothing(obj,smoothingState)
            if(nargin<2 || isempty(smoothingState))
                obj.useSmoothing = true;
            else
                obj.useSmoothing = smoothingState==true;
            end           
        end
        
        function smoothing = getUseSmoothing(obj)
            smoothing = obj.useSmoothing;
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets nonwear highlighting flag for secondary axis
        % display.
        %> @param obj Instance of PAView.
        %> @param smoothingState  Possible values include:
        %> - @c true Nonwear highlighting is on.
        %> - @c false Nonwear highlighting is off.
        % --------------------------------------------------------------------
        function setNonwearHighlighting(obj,showNonwearHighlighting)
            if(nargin<2 || isempty(showNonwearHighlighting))
                obj.nonwearHighlighting = true;
            else
                obj.nonwearHighlighting = showNonwearHighlighting==true;
            end           
        end
        
        function smoothing = getNonwearHighlighting(obj)
            smoothing = obj.nonwearHighlighting;
        end
                 

        
        % --------------------------------------------------------------------
        %> @brief Sets display type instance variable.    
        %> @param obj Instance of PAView.
        %> @param displayTypeStr A string representing the display type.  Can be 
        %> @li @c timeSeries
        %> @li @c bins
        %> @li @c features
        %> @param visibleProps Struct with the visibility property for each
        %> lineTag that can be displayed under the current displayType
        %> specified.        
        % --------------------------------------------------------------------
        function setDisplayType(obj,displayTypeStr,visibleProps)
            if(any(strcmpi(fieldnames(PASensorData.getStructTypes()),displayTypeStr)))
                allProps.visible = 'off';
                allStructTypes = PASensorData.getStructTypes();
                fnames = fieldnames(allStructTypes);
                for f=1:numel(fnames)
                    curStructName = fnames{f};
                    obj.recurseHandleInit(obj.labelhandle.(curStructName), allProps);
                    obj.recurseHandleInit(obj.referencelinehandle.(curStructName), allProps);
                    obj.recurseHandleInit(obj.linehandle.(curStructName), allProps);
                end
                
                obj.displayType = displayTypeStr;
                
                displayStruct = obj.displayType;
                
                obj.recurseHandleSetter(obj.referencelinehandle.(displayStruct), visibleProps);
                obj.recurseHandleSetter(obj.linehandle.(displayStruct), visibleProps);
                obj.recurseHandleSetter(obj.labelhandle.(displayStruct), visibleProps);
            else
                fprintf('Warning, this string (%s) is not an acceptable option.\n',displayTypeStr);
            end
        end        
        
        % --------------------------------------------------------------------
        %> @brief Returns the display type instance variable.    
        %> @param obj Instance of PAView.
        %> @retval displayTypeStr A string representing the display type.
        %> Will be one of:
        %> @li @c Time Series
        %> @li @c Aggregate Bins
        %> @li @c Features
        % --------------------------------------------------------------------
        function displayTypeStr = getDisplayType(obj)
            displayTypeStr = obj.displayType;
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves the frame duration edit box value (minutes) as a
        %> number.
        %> @param obj Instance of PAView.
        %> @retval frameDurMinutes The frame duration (in minutes) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function frameDurMinutes = getFrameDurationMinutes(obj)
            frameDurMinutes = str2double(get(obj.texthandle.frameDurationMinutes,'string'));
        end        
        % --------------------------------------------------------------------
        %> @brief Retrieves the frame duration hours edit box value ) as a
        %> number.
        %> @param obj Instance of PAView.
        %> @retval frameDurHours The frame duration (hours) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function frameDurHours = getFrameDurationHours(obj)
            frameDurHours = str2double(get(obj.texthandle.frameDurationHours,'string'));
        end        
        
        % --------------------------------------------------------------------
        % --------------------------------------------------------------------
        %
        %   Initializations
        %
        % --------------------------------------------------------------------
        % --------------------------------------------------------------------
        
       
        % --------------------------------------------------------------------
        %> @brief Clears the main figure's handles (deletes all children
        %> handles).
        %> @param obj Instance of PAView.
        % --------------------------------------------------------------------
        function clearFigure(obj)
            
            %clear the figure handle
            set(0,'showhiddenhandles','on');
            
            cf = get(0,'children');
            for k=1:numel(cf)
                if(cf(k)==obj.getFigHandle())
                    set(0,'currentfigure',cf(k));
                else
                    delete(cf(k)); %removes other children aside from this one
                end
            end;
            
            set(0,'showhiddenhandles','off');
        end
        
        % --------------------------------------------------------------------
        %> @brief Initialize text handles that will be used in the view.
        %> resets the currentWindow to 1.
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function clearTextHandles(obj)
            textProps.visible = 'on';
            textProps.string = '';
            obj.recurseHandleInit(obj.texthandle,textProps);
        end

 
        % --------------------------------------------------------------------
        %> @brief Clears axes handles of any children and sets default properties.
        %> Called when first creating a view.  See also initAxesHandles.
        %> @param obj Instance of PAView
        %> @param viewMode A string with one of two values
        %> - @c timeseries
        %> - @c results        
        % --------------------------------------------------------------------
        function initAxesHandlesViewMode(obj,viewMode)
            
            obj.clearAxesHandles();
            
            axesProps.primary.xtickmode='manual';
            axesProps.primary.xticklabelmode='manual';
            axesProps.primary.xlimmode='manual';
            axesProps.primary.xtick=[];
            axesProps.primary.xgrid='on';
            axesProps.primary.visible = 'on';
            
%             axesProps.primary.nextplot='replacechildren';
            axesProps.primary.box= 'on';
            axesProps.primary.plotboxaspectratiomode='auto';
            axesProps.primary.fontSize = 14;            
            % axesProps.primary.units = 'normalized'; %normalized allows it to resize automatically
            if verLessThan('matlab','7.14')
                axesProps.primary.drawmode = 'normal'; %fast does not allow alpha blending...
            else
                axesProps.primary.sortmethod = 'childorder'; %fast does not allow alpha blending...
            end
            
            axesProps.primary.ygrid='off';
            axesProps.primary.ytick = [];
            axesProps.primary.yticklabel = [];
            axesProps.primary.uicontextmenu = [];

            if(strcmpi(viewMode,'timeseries'))                
                % Want these for both the primary (upper) and secondary (lower) axes
                axesProps.primary.xAxisLocation = 'top';
                axesProps.primary.ylimmode = 'manual';
                axesProps.primary.ytickmode='manual';
                axesProps.primary.yticklabelmode = 'manual';
                
                axesProps.secondary = axesProps.primary;
                
                % Distinguish primary and secondary properties here:
                axesProps.primary.xminortick='on';
                axesProps.primary.uicontextmenu = obj.contextmenuhandle.primaryAxes;
                
                axesProps.secondary.xminortick = 'off';
                axesProps.secondary.uicontextmenu = obj.contextmenuhandle.secondaryAxes;                
                
            elseif(strcmpi(viewMode,'results'))
                axesProps.primary.ylimmode = 'auto';
                %                 axesProps.primary.ytickmode='auto';
                %                 axesProps.primary.yticklabelmode = 'auto';
                axesProps.primary.xAxisLocation = 'bottom';
                axesProps.primary.xminortick='off';
                
                axesProps.secondary = axesProps.primary; 
                axesProps.secondary.visible = 'off';
            end
            
            axesProps.secondary.xgrid = 'off';
            axesProps.secondary.xminortick = 'off';
            axesProps.secondary.xAxisLocation = 'bottom';

            %initialize axes
            obj.initAxesHandles(axesProps);           
        end
        
        % --------------------------------------------------------------------
        %> @brief Clears axes handles of any children and sets default properties.
        %> Called when first creating a view.  See also initAxesHandles.
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function clearAxesHandles(obj)    
            axesH = struct2array(obj.axeshandle);  %place in utility folder
            for a=1:numel(axesH)
                h=axesH(a);
                cla(h);
                title(h,'');
                ylabel(h,'');
                xlabel(h,'');
                set(h,'xtick',[],'ytick',[]);
            end
        end

        % --------------------------------------------------------------------
        %> @brief Clear text ('string') of view's user interface widgets
        %> @param obj Instance of PAView
         % --------------------------------------------------------------------
        function clearWidgets(obj)            
            handles = guidata(obj.getFigHandle());            
            
            set(handles.edit_aggregate,'string','');
            set(handles.edit_frameSizeHours,'string','');
            set(handles.edit_frameSizeMinutes,'string','');
            set(handles.edit_curWindow,'string','');
            
            %what about all of the menus that I have ?
            set(handles.panel_study,'visible','off');
            set(handles.panel_clusterInfo,'visible','off');            
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Disable user interface widgets 
        %> @param obj Instance of PAView
         % --------------------------------------------------------------------
        function disableWidgets(obj)            
            handles = guidata(obj.getFigHandle());            

            resultPanels = [
                            handles.panel_results;
                            handles.panel_clusterPlotControls;
                            handles.panel_epochControls;
                           ];

            timeseriesPanels = [handles.panel_timeseries;
                handles.panel_displayButtonGroup;
                handles.panel_epochControls];                        
            menubarHandles = [handles.menu_file_screenshot_primaryAxes;
                handles.menu_file_screenshot_secondaryAxes];
            set(menubarHandles,'enable','off');
            
            % disable panel widgets
            set(findall([resultPanels;timeseriesPanels],'enable','on'),'enable','off');

        end
               
        % --------------------------------------------------------------------
        %> @brief Initialize data specific properties of the axes handles.
        %> Set the x and y limits of the axes based on limits found in
        %> dataStruct struct.
        %> @param obj Instance of PAView
        %> @param axesProps Structure of axes property structures.  First fields
        %> are:
        %> - @c primary (for the primary axes);
        %> - @c secondary (for the secondary axes, lower, timeline axes)
        % --------------------------------------------------------------------
        function initAxesHandles(obj,axesProps)
            axesNames = fieldnames(axesProps);
            for a=1:numel(axesNames)
                axesName = axesNames{a};
                set(obj.axeshandle.(axesName),axesProps.(axesName));
            end
        end

        % --------------------------------------------------------------------
        %> @brief Initialize user interface widgets on start up.
        %> @param obj Instance of PAView 
        %> @param viewMode A string with one of two values
        %> - @c timeseries [default]
        %> - @c results
        %> @param disableFlag boolean flag
        %> - @c false [default] do not disable widgets for the view mode
        %> - @c true - disable widgets for the view mode (sets 
        %> 'enable' properties to 'off'
        %> @note Programmers: 
        %> do not enable all radio button group children on init.  Only
        %> if features and aggregate bins are available would we do
        %> this.  However, we do not know if that is the case here.
        %> - buttonGroupChildren = get(handles.panel_displayButtonGroup,'children');
        % --------------------------------------------------------------------
        function initWidgets(obj, viewMode, disableFlag)
            if(nargin<3)
                disableFlag = true;
                if(nargin<2)
                    viewMode = 'timeseries';
                end
            end
            
            handles = guidata(obj.getFigHandle());
            
            resultPanels = [
                handles.panel_results;
                handles.panel_clusterPlotControls;
                handles.toolbar_results;
                ];
            
                       
            timeseriesPanels = [
                handles.panel_timeseries;
                handles.panel_displayButtonGroup;
                handles.panel_epochControls];
            
            if(strcmpi(viewMode,'timeseries'))
                
                set(timeseriesPanels,'visible','on');
                set(resultPanels,'visible','off');
                set(findall(resultPanels,'enable','on'),'enable','off');
                
                set(handles.menu_viewmode_timeseries,'checked','on');
                set(handles.menu_viewmode_results,'checked','off');
                
                if(disableFlag)                    
                    set(findall(timeseriesPanels,'enable','on'),'enable','off');
                end
                
            elseif(strcmpi(viewMode,'results'))
                set(resultPanels(1),'visible','on');
                set(timeseriesPanels,'visible','off');
                % Handle the enabling or disabling in the PAStatTool ->
                % which has more control
                % Disable everything.
                if(disableFlag)                    
                    set(findall(resultPanels,'enable','on'),'enable','off');
                end

                % Handle the specific visibility in the PAStatTool ->
                % which has more control
                %                 set(resultPanels(1),'visible','on');
                %                 set(resultPanels(2:3),'visible','off');
                set(handles.menu_viewmode_timeseries,'checked','off');
                set(handles.menu_viewmode_results,'checked','on');
            else
                fprintf('Unknown view mode (%s)\n',viewMode);
            end

            menubarHandles = [handles.menu_file_screenshot_primaryAxes;
                handles.menu_file_screenshot_secondaryAxes];
            set(menubarHandles,'visible','on','enable','on');
            
            set(handles.panel_study,'visible','off');
            set(handles.panel_clusterInfo,'visible','off');
            
        end        

        % --------------------------------------------------------------------
        %> @brief Initializes the graphic handles (label and line handles) and maps figure tag names
        %> to PAView instance variables.  Initializes the menubar and various widgets.  Also set the acceleration data instance variable and assigns
        %> line handle y values to those found with corresponding field
        %> names in PASensorDataObject.        
        %> @note Resets the currentWindow to 1.
        %> @param obj Instance of PAView
        %> @param PASensorDataObject (Optional) PASensorData display struct that matches the linehandle struct of
        %> obj and whose values will be assigned to the 'ydata','xdata', and 'color' fields of the
        %> line handles.  A label property struct will be created
        %> using the string values of labelStruct and the initial x, y value of the line
        %> props to initialize the 'string' and 'position' properties of 
        %> obj's corresponding label handles.          
        % --------------------------------------------------------------------
        function obj = initWithAccelData(obj, PASensorDataObject)
            
            obj.accelObj = PASensorDataObject;

            axesProps.primary.xlim = PASensorDataObject.getCurWindowRange();
            axesProps.primary.ylim = PASensorDataObject.getDisplayMinMax();
            
            if(strcmpi(obj.accelObj.getAccelType(),'raw'))
                ytickLabel = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|','Activity','Daylight'};
            else
                ytickLabel = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|','Activity','Lumens','Daylight'};
            end

            axesProps.secondary.ytick = obj.getTicksForLabels(ytickLabel);
            axesProps.secondary.yticklabel = ytickLabel;
            
            
            axesProps.secondary.TickDir = 'in';
            axesProps.secondary.TickDirMode = 'manual';
            
            axesProps.secondary.TickLength = [0.001 0];
            
            obj.initAxesHandles(axesProps);
            
%             axesChildren = allchild(obj.axeshandle.secondary);
%             for h=1:numel(axesChildren)
%                 if(strcmpi(get(axesChildren(h),'type'),'text') && isfield(get(axesChildren(h)),'Rotation'))
%                     set(axesChildren(h),'rotation',90,'string','blahs');
%                 end
%             end
            
            
            %creates and initializes line handles (obj.linehandle fields)
            % lineContextMenuHandle Contextmenu handle to assign to
            %VIEW's line handles

            % However, all lines are invisible.
            obj.createLineAndLabelHandles(PASensorDataObject);
            
            %resize the secondary axes according to the new window
            %resolution
            obj.updateSecondaryAxes(PASensorDataObject.getStartStopDatenum());
                        
            %initialize the various line handles and label content and
            %color.  Struct types consist of
            %> 1. timeSeries
            %> 2. features
            structType = PASensorDataObject.getStructTypes();
            fnames = fieldnames(structType);
            for f=1:numel(fnames)
                curStructType = fnames{f};
                
                labelProps = PASensorDataObject.getLabel(curStructType);
                labelPosStruct = obj.getLabelhandlePosition(curStructType);                
                labelProps = mergeStruct(labelProps,labelPosStruct);
                
                colorStruct = PASensorDataObject.getColor(curStructType);
                
                visibleStruct = PASensorDataObject.getVisible(curStructType);
                
                % Keep everything invisible at this point - so ovewrite the
                % visibility property before we merge it together.
                visibleStruct = structEval('overwrite',visibleStruct,visibleStruct,'off');
                
                
                allStruct = mergeStruct(colorStruct,visibleStruct);
                
                labelProps = mergeStruct(labelProps,allStruct);
                
                
                lineProps = PASensorDataObject.getStruct('dummydisplay',curStructType);
                lineProps = mergeStruct(lineProps,allStruct);
                
                obj.recurseHandleSetter(obj.linehandle.(curStructType),lineProps);
                obj.recurseHandleSetter(obj.referencelinehandle.(curStructType),lineProps);
                
                obj.recurseHandleSetter(obj.labelhandle.(curStructType),labelProps);                
            end
            
            obj.setFilename(obj.accelObj.getFilename());  
            
            obj.setStudyPanelContents(PASensorDataObject.getHeaderAsString());
            
            % initialize and enable widgets (drop down menus, edit boxes, etc.)
            obj.initWidgets('timeseries');

            
            obj.setAggregateDurationMinutes(num2str(PASensorDataObject.aggregateDurMin));
            [frameDurationMinutes, frameDurationHours] = PASensorDataObject.getFrameDuration();
            obj.setFrameDurationMinutes(num2str(frameDurationMinutes));
            obj.setFrameDurationHours(num2str(frameDurationHours));
            
            windowDurationSec = PASensorDataObject.getWindowDurSec();
            obj.setWindowDurSecMenu(windowDurationSec);
            
            set(obj.positionBarHandle,'visible','on','xdata',nan(1,5),'ydata',[0 1 1 0 0],'linestyle',':'); 
            set(obj.patchhandle.positionBar,'visible','on','xdata',nan(1,4),'ydata',[0 1 1 0]); 
            
            % Enable and some panels 
            handles = guidata(obj.getFigHandle());
            timeseriesPanels = [handles.panel_timeseries;                
                handles.panel_epochControls];
            set(findall(timeseriesPanels,'enable','off'),'enable','on');
            
            % This has not been implemented yet, so disable it.
            set(findall(handles.panel_features_prefilter,'enable','on'),'enable','off');
            
            % Disable button group - option to switch radio buttons will be
            % allowed after go callback (i.e. user presses a gui button).
            
            set(findall(handles.panel_displayButtonGroup,'enable','on'),'enable','off');
            
            % This is in the panel display button group, but is not
            % actually part of it and should be moved to another place
            % soon.
            set(handles.menu_displayFeature,'enable','on');

            
            % Turn on the meta data handles - panel that shows information
            % about the current file/study.
            metaDataHandles = [obj.patchhandle.metaData;get(obj.patchhandle.metaData,'children')];
            set(metaDataHandles,'visible','on');
            
        end       
         
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes x and y axes limits.
        %> @param obj Instance of PAView
        %> @param axesRange A 1x2 vector of the starting and stoping
        %> date numbers for the primary axes' x-axis.
        % --------------------------------------------------------------------
        function updatePrimaryAxes(obj,axesRange)
            axesProps.primary.xlim = axesRange;
            curWindow = obj.getCurWindow();
            windowDurSec = obj.getWindowDurSec();
            curDateNum = obj.accelObj.window2datenum(curWindow);
            nextDateNum = obj.accelObj.window2datenum(curWindow+1); 
            numTicks = 10;
            xTick = linspace(axesRange(1),axesRange(2),numTicks);
            dateTicks = linspace(curDateNum,nextDateNum,numTicks);
            % if number of seconds or window length is less than 10 minute then include seconds;
            if(windowDurSec < 60*10)
                axesProps.primary.XTickLabel = datestr(dateTicks,'ddd HH:MM:SS');                
            %  else if it is less than 120 minutes then include minutes.
            elseif(windowDurSec < 60*120)
                axesProps.primary.XTickLabel = datestr(dateTicks,'ddd HH:MM');
            %  otherwise just include day and hours.
            else 
                axesProps.primary.XTickLabel = datestr(dateTicks,'ddd HH:MM PM');
            end    
            
            axesProps.primary.XTick = xTick;
            
           
            obj.initAxesHandles(axesProps);
%             datetick(obj.axeshandle.secondary,'x','ddd HH:MM')
        end
        
        
        
        
        % --------------------------------------------------------------------
        % Wear states
        % Awake
        % 35        ACTIVE
        % 25        INACTIVE
        % Sleep
        % 20        NAP
        %                    15        NREM
        % 10        REMS
        % Non-wear states
        % 5        Study-not-over
        % 0        Study-over
        % -1         Unknown
        % --------------------------------------------------------------------
        function featureHandles = addWeartimeToSecondaryAxes(obj, featureVector, startStopDatenum, overlayHeightRatio, overlayOffset)
            featureHandles = obj.addFeaturesVecToAxes(featureVector, startStopDatenum, overlayHeightRatio, overlayOffset,obj.axeshandle.secondary, obj.getUseSmoothing());
            
            nonwearHeightRatio = overlayHeightRatio*(7.5/(35--1));
            wearHeightRatio = overlayHeightRatio-nonwearHeightRatio;
            axesH = obj.axeshandle.secondary;
            yLim = get(axesH,'ylim');
            
            % nonwear is lower down
            yLimPatches = yLim*nonwearHeightRatio+overlayOffset;
            ydata = [yLimPatches, fliplr(yLimPatches)]';
            xStart = startStopDatenum(1);
            xEnd = startStopDatenum(end);
            xdata = [xStart xStart xEnd xEnd]';
             
            set(obj.patchhandle.nonwear,'xdata',xdata,'ydata',ydata,'visible','on');
            
            % place wear above it.  xData is same, but yDdata is shifted up
            % some.
            overlayOffset = yLimPatches(end);
            yLimPatches = yLim*wearHeightRatio+overlayOffset;
            ydata = [yLimPatches, fliplr(yLimPatches)]';            
            set(obj.patchhandle.wear,'xdata',xdata,'ydata',ydata,'visible','on');
            obj.draw();
            
            
            
            
%             feature_patchH = patch(x,y,vertexColor,'parent',axesH,'edgecolor','interp','facecolor','interp','hittest','off');
                        
            
            
            %             if(ishandle(obj.patchhandle.feature))
            %                 delete(obj.patchhandle.feature);
            %             end
            %             if(ishandle(obj.linehandle.feature))
            %                 delete(obj.linehandle.feature);
            %             end
            %             if(ishandle(obj.linehandle.featureCumsum))
            %                 delete(obj.linehandle.featureCumsum);
            %             end
            %             [feature_patchH, feature_lineH, feature_cumsumLineH] = obj.addFeaturesVecAndOverlayToAxes( featureVector, startStopDatenum, overlayHeight, overlayOffset, obj.axeshandle.secondary, obj.getUseSmoothing(), obj.contextmenuhandle.featureLine);
            %             [obj.patchhandle.feature, obj.linehandle.feature, obj.linehandle.featureCumsum] = deal(feature_patchH, feature_lineH, feature_cumsumLineH);
        end
        
        % --------------------------------------------------------------------
        %> @brief Adds a feature vector as a heatmap and as a line plot to the secondary axes.
        %> @param obj Instance of PAView.
        %> @param featureVector A vector of features to be displayed on the
        %> secondary axes.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the secondary axes.        
        % --------------------------------------------------------------------
        function [feature_patchH, feature_lineH, feature_cumsumLineH] = addFeaturesVecAndOverlayToSecondaryAxes(obj, featureVector, startStopDatenum, overlayHeight, overlayOffset)
            if(ishandle(obj.patchhandle.feature))
                delete(obj.patchhandle.feature);
            end
            if(ishandle(obj.linehandle.feature))
                delete(obj.linehandle.feature);
            end
            if(ishandle(obj.linehandle.featureCumsum))
                delete(obj.linehandle.featureCumsum);
            end
            [feature_patchH, feature_lineH, feature_cumsumLineH] = obj.addFeaturesVecAndOverlayToAxes( featureVector, startStopDatenum, overlayHeight, overlayOffset, obj.axeshandle.secondary, obj.getUseSmoothing(), obj.contextmenuhandle.featureLine);
            [obj.patchhandle.feature, obj.linehandle.feature, obj.linehandle.featureCumsum] = deal(feature_patchH, feature_lineH, feature_cumsumLineH);
        end
        
        % --------------------------------------------------------------------
        %> @brief Plots a feature vector on the secondary axes.
        %> @param obj Instance of PAView.
        %> @param featureVector A vector of features to be displayed on the
        %> secondary axes.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the secondary axes.
        %> @retval featureHandles Line handles created from the method.
        % --------------------------------------------------------------------
        function featureHandles = addFeaturesVecToSecondaryAxes(obj, featureVector, startStopDatenum, overlayHeight, overlayOffset)
            featureHandles = obj.addFeaturesVecToAxes(featureVector, startStopDatenum, overlayHeight, overlayOffset,obj.axeshandle.secondary, obj.getUseSmoothing());
        end
        
        % --------------------------------------------------------------------
        %> @brief Adds a magnitude vector as a heatmap to the secondary axes.
        %> @param obj Instance of PAView.
        %> @param overlayVector A magnitude vector to be displayed in the
        %> secondary axes as a heat map.
        %> @param startStopDatenum An Nx2 matrix start and stop datenums which
        %> correspond to the start and stop times of the same row in overlayVector.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset that is applied to
        %> the overlayVector when displayed on the secondary axes.
        %> @param maxValue The maximum value to normalize the overlayVector
        %> with so that the normalized overlayVector's maximum value is 1.
        % --------------------------------------------------------------------
        function [overlayLineH, overlayPatchH] = addOverlayToSecondaryAxes(obj, overlayVector, startStopDatenum, overlayHeight, overlayOffset,maxValue)
            [overlayLineH,overlayPatchH] = obj.addOverlayToAxes(overlayVector, startStopDatenum, overlayHeight, overlayOffset,maxValue,obj.axeshandle.secondary,obj.contextmenuhandle.featureLine);
            %             obj.linehandle.overlay = overlayLineH;
        end

        
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes x and y axes limits.
        %> @param obj Instance of PAView
        %> @param startStopDatenum A 1x2 vector of the starting and stoping
        %> date numbers.
        % --------------------------------------------------------------------
        function updateSecondaryAxes(obj,startStopDatenum)
            
            axesProps.secondary.xlim = startStopDatenum;
            [~,~,d,h,mi,s] = datevec(diff(startStopDatenum));
            durationDays = d+h/24+mi/60/24+s/3600/24;
            if(durationDays<0.25)
                dateScale = 1/48; %show every 30 minutes
            elseif(durationDays<0.5)
                dateScale = 1/24; %show every hour
            elseif(durationDays<0.75)
                dateScale = 1/12; %show every couple hours
            elseif(durationDays<=1)
                dateScale = 1/6; %show every four hours
            elseif(durationDays<=2)
                dateScale = 1/3; %show every 8 hours
            elseif(durationDays<=10)
                dateScale = 1/2; %show every 12 hours
            else
                dateScale = 1; %show every 24 hours.
                
            end    
            if(dateScale >= 1/3)
                timeDeltaSec = datenum(0,0,1)/24/3600;
                studyDatenums = startStopDatenum(1):timeDeltaSec:startStopDatenum(2);
                [~,~,~,hours,minutes,sec] = datevec(studyDatenums);
                newDayIndices = mod([hours(:),minutes(:),sec(:)]*[1;1/60;1/3600],24)==0;
%                 quarterDayIndices =  mod([hours(:),min(:),sec(:)]*[1;1/60;1/3600],24/4)==0;

                xTick = studyDatenums(newDayIndices);
                axesProps.secondary.XGrid = 'on';
                axesProps.secondary.XMinorGrid = 'off';
                axesProps.secondary.XMinorTick = 'on';
                
                
            else
                timeDelta = datenum(0,0,1)*dateScale;
                xTick = [startStopDatenum(1):timeDelta:startStopDatenum(2), startStopDatenum(2)];
                axesProps.secondary.XMinorTick = 'off';
                axesProps.secondary.XGrid = 'off';

            end
            
            axesProps.secondary.gridlinestyle = '--';
            
            axesProps.secondary.YGrid = 'off';
            axesProps.secondary.YMinorGrid = 'off';
            
            axesProps.secondary.ylim = [0 1];
            axesProps.secondary.xlim = startStopDatenum;
            
            axesProps.secondary.XTick = xTick;
            axesProps.secondary.XTickLabel = datestr(xTick,'ddd HH:MM');
            
           
            fontReduction = min([4, floor(durationDays/4)]);
            axesProps.secondary.fontSize = 14-fontReduction;
            obj.initAxesHandles(axesProps);
%             datetick(obj.axeshandle.secondary,'x','ddd HH:MM')
        end
        
        % --------------------------------------------------------------------
        %> @brief Create the line handles and text handles that describe the lines,
        %> that will be displayed by the view.
        %> This is based on the structure template generated by member
        %> function getStruct('dummydisplay').
        %> @param PASensorDataObject Instance of PASensorData.
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function createLineAndLabelHandles(obj,PASensorDataObject)
            % Kill off anything else still in the primary and secondary
            % axes...
            zombieLines = findobj([obj.axeshandle.primary;obj.axeshandle.secondary],'type','line');
            zombiePatches = findobj([obj.axeshandle.primary;obj.axeshandle.secondary],'type','patch');
            zombieText = findobj([obj.axeshandle.primary;obj.axeshandle.secondary],'type','text');
            
            zombieHandles = [zombieLines(:);zombiePatches(:);zombieText(:)];
            delete(zombieHandles);
            
            obj.linehandle = [];
            obj.labelhandle = [];
            obj.referencelinehandle = [];
            
            handleProps.UIContextMenu = obj.contextmenuhandle.signals;
            handleProps.Parent = obj.axeshandle.primary;

            handleProps.visible = 'off';
            
            structType = PASensorDataObject.getStructTypes();            
            fnames = fieldnames(structType);
            for f=1:numel(fnames)
                curName = fnames{f};
                dataStruct = PASensorDataObject.getStruct('dummy',curName);
            
                handleType = 'line';
                handleProps.tag = curName;

                obj.linehandle.(curName) = obj.recurseHandleGenerator(dataStruct,handleType,handleProps);
            
                obj.referencelinehandle.(curName) = obj.recurseHandleGenerator(dataStruct,handleType,handleProps);
            
                handleType = 'text';
                obj.labelhandle.(curName) = obj.recurseHandleGenerator(dataStruct,handleType,handleProps);
            end
            
            %secondary axes
            obj.positionBarHandle = line('parent',obj.axeshandle.secondary,'visible','off');%annotation(obj.figurehandle.sev,'line',[1, 1], [pos(2) pos(2)+pos(4)],'hittest','off');
%             obj.patchhandle.positionBar =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'zdata',repmat(-1,1,4),'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[0.5 0.85 0.5],'edgecolor','none','facealpha',0.5);
            obj.patchhandle.positionBar =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[0.5 0.85 0.5],'edgecolor','none','facealpha',0.5);
            
            obj.patchhandle.wear =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[0 1 1],'edgecolor','none','facealpha',0.5);
            obj.patchhandle.nonwear =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[1 0.45 0],'edgecolor','none','facealpha',0.5);
            
            
            uistack(obj.positionBarHandle,'top');
            uistack(obj.patchhandle.positionBar,'top');
            obj.linehandle.feature = [];
            obj.linehandle.featureCumsum = [];
            
        end

        
        % --------------------------------------------------------------------
        %> @brief Enables the aggregate radio button.  
        %> @note Requires aggregate data exists in the associated
        %> PASensorData object instance variable 
        %> @param obj Instance of PAView
        %> @param enableState Optional tag for specifying the 'enable' state. 
        %> - @c 'on' [default]
        %> - @c 'off'
        % --------------------------------------------------------------------
        function enableAggregateRadioButton(obj,enableState)
            if(nargin<2)
                enableState = 'on';
            end
            handles = guidata(obj.getFigHandle());
            set(handles.radio_bins,'enable',enableState);
        end
        
        % --------------------------------------------------------------------
        %> @brief Enables the Feature radio button
        %> @param obj Instance of PAView
        %> @param enableState Optional tag for specifying the 'enable' state. 
        %> - @c 'on' [default]
        %> - @c 'off'
        % --------------------------------------------------------------------
        function enableFeatureRadioButton(obj,enableState)
            if(nargin<2)
                enableState = 'on';
            end
            handles = guidata(obj.getFigHandle());
            set([handles.radio_features],'enable',enableState);
        end
        
        % --------------------------------------------------------------------
        %> @brief Enables the time series radio button.  
        %> @note Requires feature data exist in the associated
        %> PASensorData object instance variable 
        %> @param obj Instance of PAView
        %> @param enableState Optional tag for specifying the 'enable' state. 
        %> - @c 'on' [default]
        %> - @c 'off'
        % --------------------------------------------------------------------
        function enableTimeSeriesRadioButton(obj,enableState)
            if(nargin<2)
                enableState = 'on';
            end
            handles = guidata(obj.getFigHandle());
            set(handles.radio_time,'enable',enableState);
        end
        
        
        
        % --------------------------------------------------------------------
        %> @brief Appends the new feature to the drop down feature menu.
        %> @param obj Instance of PAView
        %> @param newFeature String label to append to the drop down feature menu.
        %> @param newUserData Mixed entry to append to the drop down
        %> feature menu's user data field.
        % --------------------------------------------------------------------
        function appendFeatureMenu(obj,newFeature,newUserData)
            
            featureOptions = get(obj.menuhandle.displayFeature,'string');
            userData = get(obj.menuhandle.displayFeature,'userdata');
            if(~iscell(featureOptions))
                featureOptions = {featureOptions};
                userData = {userData};
            end
            if(isempty(intersect(featureOptions,newFeature)))
                featureOptions{end+1} = newFeature;
                userData{end+1} = newUserData;
                set(obj.menuhandle.displayFeature,'string',featureOptions,'userdata',userData);
            end;
        end        
        
        % --------------------------------------------------------------------
        %> @brief Displays the string argument in the view.
        %> @param obj PASensorDataObject Instance of PASensorData
        %> @param sourceFilename String that will be displayed in the view as the source filename when provided.
        % --------------------------------------------------------------------
        function setFilename(obj,sourceFilename)
            set(obj.texthandle.filename,'string',sourceFilename,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Displays the contents of cellString in the study panel
        %> @param obj PASensorDataObject Instance of PASensorData
        %> @param cellString Cell of string that will be displayed in the study panel.  Each 
        %> cell element is given its own display line.
        % --------------------------------------------------------------------
        function setStudyPanelContents(obj,cellString)
            set(obj.texthandle.studyinfo,'string',cellString,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Draws the view
        %> @param obj PASensorDataObject Instance of PASensorData
        % --------------------------------------------------------------------
        function draw(obj)
            % Axes range must occur at the top as it is used to determine
            % the position of text labels.
            axesRange   = obj.accelObj.getCurUncorrectedWindowRange(obj.displayType);
            
            %make it increasing
            if(diff(axesRange)==0)
                axesRange(2) = axesRange(2)+1;
            end
            
            set(obj.axeshandle.primary,'xlim',axesRange);
            
            obj.updatePrimaryAxes(axesRange);
            
            structFieldName =obj.displayType;
            lineProps   = obj.accelObj.getStruct('currentdisplay',structFieldName);
            obj.recurseHandleSetter(obj.linehandle.(structFieldName),lineProps);
                        
            offsetProps = obj.accelObj.getStruct('displayoffset',structFieldName);
            offsetStyle.LineStyle = '--';
            offsetStyle.color = [0.6 0.6 0.6];
            offsetProps = appendStruct(offsetProps,offsetStyle);
           
            obj.recurseHandleSetter(obj.referencelinehandle.(structFieldName),offsetProps);
                        
            % update label text positions based on the axes position.
            % So the axes range must be set above this!
            % link the x position with the axis x-position ...
            labelProps = obj.accelObj.getLabel(structFieldName);
            labelPosStruct = obj.getLabelhandlePosition();            
            labelProps = mergeStruct(labelProps,labelPosStruct);             
            obj.recurseHandleSetter(obj.labelhandle.(structFieldName),labelProps);
            
        end

        % --------------------------------------------------------------------
        %> @brief Sets the color of the line handles.
        %> @param obj Instance of PAView
        %> @param lineHandleStruct Struct of line handles to set the color of.        
        %> @param colorStruct Struct with field organization corresponding to that of
        %> input line handles.  The values are the colors to set
        %> the matching line handle to.
        % --------------------------------------------------------------------
        function setLinehandleColor(obj,lineHandleStruct,colorStruct)
            obj.setStructWithStruct(lineHandleStruct,colorStruct);
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates the 'position' property of the labelhandle
        %> instance variable.
        %> @param obj Instance of PAView.      
        %> @param displayTypeStr String representing the current display
        %> type.  This can be
        %> @li @c time series
        %> @li @c aggregate bins
        %> @li @c Features        
        %> @retval labelPosStruct A struct of 'position' properties that can be assigned
        %> to labelhandle instance variable.
        % --------------------------------------------------------------------
        function labelPosStruct = getLabelhandlePosition(obj,displayTypeStr)
            if(nargin<2 || isempty(displayTypeStr))
                displayTypeStr = obj.displayType;
            end
            yOffset = -30; %Trial and error
            dummyStruct = obj.accelObj.getStruct('dummy',displayTypeStr);
            offsetStruct = obj.accelObj.getStruct('displayoffset',displayTypeStr);
            labelPosStruct = structEval('calculateposition',dummyStruct,offsetStruct);
            xOffset = 1/250*diff(get(obj.axeshandle.primary,'xlim'));            
            offset = [xOffset, yOffset, 0];
            labelPosStruct = structScalarEval('plus',labelPosStruct,offset);            
        end

        % --------------------------------------------------------------------
        %> @brief Get the view's figure handle.
        %> @param obj Instance of PAView
        %> @retval figHandle View's figure handle.
        % --------------------------------------------------------------------
        function figHandle = getFigHandle(obj)
            figHandle = obj.figurehandle;
        end
        
        % --------------------------------------------------------------------
        %> @brief Get the view's line handles as a struct.
        %> @param obj Instance of PAView
        %> @param structType String of a subfieldname to access the line
        %> handle of.  (e.g. 'timeSeries')
        %> @retval linehandle View's line handles as a struct.        
        % --------------------------------------------------------------------
        function lineHandle = getLinehandle(obj,structType)
            if(nargin<1 || isempty(structType))
                lineHandle = obj.linehandle;
            else
                lineHandle = obj.linehandle.(structType);
            end
        end        
        
        
        % --------------------------------------------------------------------
        %> @brief Shows busy status (mouse becomes a watch).
        %> @param obj Instance of PAView  
        %> @param status_label Optional string which, if included, is displayed
        %> in the figure's status text field (currently at the top right of
        %> the view).
        %> @param axesTag Optional tag, that if set will set the axes tag's
        %> state to 'busy'.  See setAxesState method.
        % --------------------------------------------------------------------
        function showBusy(obj,status_label,axesTag)
            set(obj.getFigHandle(),'pointer','watch');
            if(nargin>1)
                set(obj.texthandle.status,'string',status_label);
                if(nargin>2)
                    obj.setAxesState(axesTag,'busy');
                end
            end
            drawnow();
        end  
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param axesTag Optional tag, that if set will set the axes tag's
        %> state to 'ready'.  See setAxesState method.
        %> @param obj Instance of PAView        
        % --------------------------------------------------------------------
        function showReady(obj,axesTag)
            set(obj.getFigHandle(),'pointer','arrow');
            set(obj.texthandle.status,'string','');
            if(nargin>1 && ~isempty(axesTag))
                obj.setAxesState(axesTag,'ready');
            end
            drawnow();
        end
        
        %> @brief Adjusts the color of the specified axes according to the
        %> specified state.
        %> @param obj Instance of PAView
        %> @param axesTag tag of the axes to set as ready or busy. Can be:
        %> - @c primary
        %> - @c secondary
        %> - @c all
        %> @param stateTag State to set the axes as. Can be:
        %> - @c busy - color is darker
        %> - @c ready - color is white
        function setAxesState(obj,axesTag,stateTag)
            if(ismember(axesTag,{'primary','secondary','all'}) && ismember(stateTag,{'busy','ready'}))
                colorMap.ready = [1 1 1];
                colorMap.busy = [0.75 0.75 0.75];
                if(strcmp(axesTag,'all'))
                    set([obj.axeshandle.primary
                        obj.axeshandle.secondary],'color',colorMap.(stateTag));
                else
                    set(obj.axeshandle.(axesTag),'color',colorMap.(stateTag));
                end
            end
        end
               
        % --------------------------------------------------------------------
        %> @brief An alias for showReady()
        %> @param obj Instance of PAView        
        % --------------------------------------------------------------------
        function obj = clear_handles(obj)
            obj.showReady();
        end
        
    end
    
    
    methods(Static)
        % --------------------------------------------------------------------
        %> @brief Adds a feature vector as a heatmap and as a line plot to the
        %> specified axes
        %> @param featureVector The vector of features to be displayed.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the axes. 
        %> @param axesH Handle of the axes to assign features to.
        %> @param useSmoothing Boolean flag to set if feature vector should
        %> be applied (true) or not (false) before display.
        %> @param contextmenuH Optional contextmenu handle.  Is assigned to the overlayLineH lines
        %> contextmenu callback when included.  
        %> @retval feature_patchH Patch handle of feature
        %> @retval feature_lineH Line handle of feature
        %> @retval feature_cumsumLineH Line handle of cumulative sum of feature        
        % --------------------------------------------------------------------
        function [feature_patchH, feature_lineH, feature_cumsumLineH] = addFeaturesVecAndOverlayToAxes(featureVector, startStopDatenum, overlayHeight, overlayOffset, axesH, useSmoothing,contextmenuH)
            if(nargin<7)
                contextmenuH = [];
                if(nargin<6 || isempty(useSmoothing))
                    useSmoothing = true;
                end
            end
            
            yLim = get(axesH,'ylim');
            yLimPatches = (yLim+1)*overlayHeight/2+overlayOffset;
            
            %             minColor = [.0 0.25 0.25];
            minColor = [0.1 0.1 0.1];
            
            %             maxValue = max(featureVector);
            maxValue = quantile(featureVector,0.90);
            nFaces = numel(featureVector);
            
            x = nan(4,nFaces);
            y = repmat(yLimPatches([1 2 2 1])',1,nFaces);
            vertexColor = nan(4,nFaces,3);
            
            % each column represent a face color triplet            
            featureColorMap = (featureVector/maxValue)*[1,1,1]+ repmat(minColor,nFaces,1);
       
            % patches are drawn clock wise in matlab
            
            for f=1:nFaces
                if(f==nFaces)
                    vertexColor(:,f,:) = featureColorMap([f,f,f,f],:);
                else
                    vertexColor(:,f,:) = featureColorMap([f,f,f+1,f+1],:);
                end
                x(:,f) = startStopDatenum(f,[1 1 2 2])';
            end            
            
            feature_patchH = patch(x,y,vertexColor,'parent',axesH,'edgecolor','interp','facecolor','interp','hittest','off');
                        
            % draw the lines
            
            normalizedFeatureVector = featureVector/quantile(featureVector,0.99)*(overlayHeight/2);
            
            if(useSmoothing)
                n = 10;
                b = repmat(1/n,1,n);
                % Sometimes 'single' data is loaded, particularly with raw
                % accelerations.  We need to convert to double in such
                % cases for filtfilt to work.
                if(~isa(normalizedFeatureVector,'double'))
                    normalizedFeatureVector = double(normalizedFeatureVector);
                end

                smoothY = filtfilt(b,1,normalizedFeatureVector);
            else
                smoothY = normalizedFeatureVector;
            end
            
            feature_lineH = line('parent',axesH,'ydata',smoothY+overlayOffset,'xdata',startStopDatenum(:,1),'color','b','hittest','on');
            
            if(~isempty(contextmenuH))
                set(feature_lineH,'uicontextmenu',contextmenuH);
                set(contextmenuH,'userdata',featureVector);
            end
            
            % No longer want to keep the cumulative sum in this one.
            %vectorSum = cumsum(featureVector)/sum(featureVector)*overlayHeight/2;
            % feature_cumsumLineH =line('parent',axesH,'ydata',vectorSum+overlayOffset,'xdata',startStopDatenum(:,1),'color','g','hittest','off');
            feature_cumsumLineH = [];
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Plots a feature vector on the specified axes.
        %> @param featureVector A vector of features to be displayed.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the secondary axes.
        %> @param axesH The graphic handle to the axes.
        %> @param useSmoothing Boolean flag to set if feature vector should
        %> be applied (true) or not (false) before display.
        %> @retval featureHandles Line handles created from the method.
        % --------------------------------------------------------------------
        function featureHandles = addFeaturesVecToAxes(featureVector, startStopDatenum, overlayHeight, overlayOffset, axesH, useSmoothing)
            if(overlayOffset>0)
                featureHandles = nan(3,1);
            else
                featureHandles = nan(2,1);
            end            

                
            n = 10;
            b = repmat(1/n,1,n);
            
            
            if(useSmoothing)
                % Sometimes 'single' data is loaded, particularly with raw
                % accelerations.  We need to convert to double in such
                % cases for filtfilt to work.
                if(~isa(featureVector,'double'))
                    featureVector = double(featureVector);
                end
                smoothY = filtfilt(b,1,featureVector);
            else
                smoothY = featureVector;
            end
            smoothY = smoothY-min(smoothY);
            normalizedY = smoothY/max(smoothY)*overlayHeight+overlayOffset;%drop it right down in place, center vertically
            
            featureHandles(1) = line('parent',axesH,'ydata',normalizedY,'xdata',startStopDatenum(:,1),'color','b','hittest','off','userdata',featureVector);
            %draw some boundaries around our features - put in rails
            railsBottom = [overlayOffset,overlayOffset]+0.001;
            railsTop = railsBottom+overlayHeight - 0.001;
            x = [startStopDatenum(1), startStopDatenum(end)];
            featureHandles(2) = line('parent',axesH,'ydata',railsBottom,'xdata',x,'color',[0.2 0.2 0.2],'linewidth',0.2,'hittest','off');
            if(overlayOffset>0)
                featureHandles(3) = line('parent',axesH,'ydata',railsTop,'xdata',x,'color',[0.2 0.2 0.2],'linewidth',0.2,'hittest','off');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Adds a magnitude vector as a heatmap to the specified axes.
        %> @param overlayVector A magnitude vector to be displayed in the
        %> axes as a heat map.
        %> @param startStopDatenum An Nx2 matrix start and stop datenums which
        %> correspond to the start and stop times of the same row in overlayVector.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset that is applied to
        %> the overlayVector when displayed on the secondary axes.
        %> @param maxValue The maximum value to normalize the overlayVector
        %> with so that the normalized overlayVector's maximum value is 1.
        %> @param axesH The graphic handle to the axes.
        %> @param contextmenuH Optional contextmenu handle.  Is assigned to the overlayLineH lines
        %> contextmenu callback when included.    
        % --------------------------------------------------------------------
        function [overlayLineH, overlayPatchH] = addOverlayToAxes(overlayVector, startStopDatenum, overlayHeight, overlayOffset,maxValue,axesH,contextmenuH)
            if(nargin<7)
                contextmenuH = [];
            end
            
            yLim = get(axesH,'ylim');
            yLim = yLim*overlayHeight+overlayOffset;
            minColor = [0.0 0.0 0.0];
            
            nFaces = numel(overlayVector);
            x = nan(4,nFaces);
            y = repmat(yLim([1 2 2 1])',1,nFaces);
            vertexColor = nan(4,nFaces,3);
            
            % each column represent a face color triplet            
            overlayColorMap = (overlayVector/maxValue)*[1,1,0.65]+ repmat(minColor,nFaces,1);
       
            % patches are drawn clock wise in matlab
            
            for f=1:nFaces
                if(f==nFaces)
                    vertexColor(:,f,:) = overlayColorMap([f,f,f,f],:);
                    
                else
                    vertexColor(:,f,:) = overlayColorMap([f,f,f+1,f+1],:);
                    
                end
                x(:,f) = startStopDatenum(f,[1 1 2 2])';
                
            end
            overlayPatchH = patch(x,y,vertexColor,'parent',axesH,'edgecolor','interp','facecolor','interp');
            
            normalizedOverlayVector = overlayVector/maxValue*(overlayHeight)+overlayOffset;
            overlayLineH = line('parent',axesH,'linestyle',':','xdata',linspace(startStopDatenum(1),startStopDatenum(end),numel(overlayVector)),'ydata',normalizedOverlayVector,'color',[1 1 0]);
            if(~isempty(contextmenuH))
                set(overlayLineH,'uicontextmenu',contextmenuH);
                % set(contextmenuH,'userdata',overlayVector);
            end

        end        
        
        %==================================================================
        %> @brief Recursively fills in the template structure dummyStruct
        %> with matlab lines and returns as a new struct.  If dummyStruct
        %> has numeric values in its deepest nodes, then these values are
        %> assigned as the y-values of the corresponding line handle, and the
        %> x-value is a vector from 1 to the number of elements in y.
        %> @param dummyStruct Structure with arbitrarily deep number fields.
        %> @param handleType String name of the type of handle to be created:
        %> - @c line
        %> - @c text
        %> @param handleProperties Struct of line handle properties to initialize line handles with.  
        %> @param destStruct Optional struct; see note.
        %> @retval destStruct The filled in struct, with the same field
        %> layout as dummyStruct but with line handles filled in at the
        %> deepest nodes.
        %> @note If destStruct is included, then lineproperties must also be included, even if only as an empty place holder.
        %> For example as <br>
        %> destStruct = PAView.recurseHandleGenerator(dummyStruct,handleType,[],destStruct)
        %> @param destStruct The initial struct to grow to (optional and can be different than the output node).
        %> For example<br> desStruct = PAView.recurseLineGenerator(dummyStruct,'line',proplines,diffStruct)
        %> <br>Or<br> recurseHandleGenerator(dummyStruct,'line',[],diffStruct)
        %==================================================================
        function destStruct = recurseHandleGenerator(dummyStruct,handleType,handleProperties,destStruct)
            if(nargin < 4 || isempty(destStruct))
                destStruct = struct();
                if(nargin<3)
                    handleProperties = [];
                end
            
            end
            
            fnames = fieldnames(dummyStruct);
            for f=1:numel(fnames)
                fname = fnames{f};
                
                curHandleProperties = handleProperties;
                if(isfield(handleProperties,'tag'))
                    curHandleProperties.tag = [handleProperties.tag,'.',fname];
                end
                        

                if(isstruct(dummyStruct.(fname)))
                    destStruct.(fname) = [];
                    
                    %recurse down
                    destStruct.(fname) = PAView.recurseHandleGenerator(dummyStruct.(fname),handleType,curHandleProperties,destStruct.(fname));
                else
                    
                    if(strcmpi(handleType,'line') || strcmpi(handleType,'text'))
                        if(nargin>1 && ~isempty(curHandleProperties)) %aka  if(hasProperties)
                            destStruct.(fname) = feval(handleType,curHandleProperties);
                        else                            
                            destStruct.(fname) = feval(handleType);
                        end
                    else
                        destStruct.(fname) = [];
                        fprintf('Warning!  Handle type %s unknown!',handleType);
                    end
                    
                end
            end
        end

        %==================================================================
        %> @brief Recursively sets struct of graphic handles with a matching struct
        %> of handle properties.
        %> @param handleStruct The struct of matlab graphic handles.  This
        %> is searched recursively until a handle is found (i.e. ishandle())
        %> @param propertyStruct Structure of property/value pairings to set the graphic
        %> handles found in handleStruct to.
        %==================================================================
        function recurseHandleSetter(handleStruct, propertyStruct)
            fnames = fieldnames(handleStruct);
            % Add some checking to make sure we match properties correctly.
            % Experience showed that 'raw' accelTypes do not contain all
            % fields that exist for display which leads to exception throws.
            matchingFields = isfield(propertyStruct,fnames);
            fnames = fnames(matchingFields);
            for f=1:numel(fnames)
                fname = fnames{f};
                curField = handleStruct.(fname);
                curPropertyStruct = propertyStruct.(fname);
                try
                    if(isstruct(curField))
                        PAView.recurseHandleSetter(curField,curPropertyStruct);
                    else
                        if(ishandle(curField))
                            set(curField,curPropertyStruct);
                        end
                    end
                catch me
                    showME(me);
                end
            end
        end
        
        %==================================================================
        %> @brief Recursively initializes the graphic handles found in the
        %> provided structure with the properties found at corresponding locations
        %> in the propStruct argument.
        %> @param handleStruct The struct of line handles to set the
        %> properties of.  
        %> @param propertyStruct Structure of property structs (i.e. property/value pairings) to set the graphic
        %> handles found in handleStruct to.
        %==================================================================
        function setStructWithStruct(handleStruct,propertyStruct)
            fnames = fieldnames(handleStruct);
            for f=1:numel(fnames)
                fname = fnames{f};
                curHandleField = handleStruct.(fname);
                curPropertyField = propertyStruct.(fname);
                if(isstruct(curHandleField))
                    PAView.setStructWithStruct(curHandleField,curPropertyField);
                else
                    if(ishandle(curHandleField))
                        try
                            set(curHandleField,curPropertyField);
                        catch me
                            showME(me);
                        end
                    end
                end
            end
        end
        
        
        %==================================================================
        %> @brief Recursively initializes the graphic handles found in the
        %> provided structure with the handle properties provided.
        %> @param handleStruct The struct of line handles to set the
        %> properties of.  
        %> @param properties Structure of property/value pairings to set the graphic
        %> handles found in handleStruct to.
        %==================================================================
        function recurseHandleInit(handleStruct,properties)
            fnames = fieldnames(handleStruct);
            for f=1:numel(fnames)
                fname = fnames{f};
                curField = handleStruct.(fname);
                if(isstruct(curField))
                    PAView.recurseHandleInit(curField,properties);
                else
                    if(ishandle(curField))
                        set(curField,properties);
                    end
                end
            end
        end
        
        %> @brief Returns evenly spaced tick marks for an input cell of
        %> labels.  This is a utility method for placing nicely spaced labels
        %> along an x or y axes.
        %> @param cellOfLabels For example {'X','Y','Z','VecMag'}
        %> @retval ticks Vector of evenly spaced values between 1/(number
        %> of labels)/2 and 1
        function ticks = getTicksForLabels(cellOfLabels)
            if(~iscell(cellOfLabels))
                numTicks = 1;
            else
                numTicks = numel(cellOfLabels);
            end
             ticks = 1/numTicks/2:1/numTicks:1;
            
        end
        
    end
end



% Archive

% This was no longer being called - so placed in archive 5/11/2017 @hyatt

% --------------------------------------------------------------------
%> @brief Adds an overlay of the lumens signal to the secondary axes.
%> @param obj Instance of PAView.
%> @param lumenVector An Nx1 vector of lumen values to be displayed in the
%> secondary axes.
%> @param startStopDatenum An Nx2 matrix start and stop datenums which
%> correspond to the start and stop times of the same row in overlayVector.
% --------------------------------------------------------------------
% function addLumensOverlayToSecondaryAxes(obj, lumenVector, startStopDatenum)
%     yLim = get(obj.axeshandle.secondary,'ylim');
%     yLim = yLim*1/3+2/3;
%     minColor = [.2 0.1 0];
%
%     maxLumens = 250;
%
%
%     nFaces = numel(lumenVector);
%     x = nan(4,nFaces);
%     y = repmat(yLim([1 2 2 1])',1,nFaces);
%     vertexColor = nan(4,nFaces,3);
%
%     % each column represent a face color triplet
%     luxColorMap = (lumenVector/maxLumens)*[0.8,0.9,1]+ repmat(minColor,nFaces,1);
%
%     % patches are drawn clock wise in matlab
%
%     for f=1:nFaces
%         if(f==nFaces)
%             vertexColor(:,f,:) = luxColorMap([f,f,f,f],:);
%
%         else
%             vertexColor(:,f,:) = luxColorMap([f,f,f+1,f+1],:);
%
%         end
%         x(:,f) = startStopDatenum(f,[1 1 2 2])';
%
%     end
%     patch(x,y,vertexColor,'parent',obj.axeshandle.secondary,'edgecolor','interp','facecolor','interp');
% end

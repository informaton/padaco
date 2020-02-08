classdef(Abstract) PAViewController < PAFigureController
    properties(SetAccess=protected)
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
        
        %> @brief Struct of text handles (graphic handle class) that display the 
        %> the name or label of the line held at the corresponding position
        %> of linehandle.        
        labelhandle;
        
        %> struct of handles for the context menu.  Fields include
        %> - @c primaryAxes - for the primary Axes.
        %> - @c signals - For the lines, reference lines, and labels
        contextmenuhandle; 
         
        
        %> Linehandle in Padaco that is currently selected by the user.
        current_linehandle;
        
    end
    properties(Abstract, Constant)
        viewTag
    end
    
    methods
        
        % Sometimes a figure handle is given and sometimes it is not.
        % Same goes for initSettings.  When a figureH is given it will be a
        % figure handle and when initSettings are given it will be a
        % struct.
        function this = PAViewController(varargin)
            this@PAFigureController(varargin{:});            
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Initialize text handles that will be used in the view.
        %> resets the currentWindow to 1.
        %> @param obj Instance of PASingleStudyController
        % --------------------------------------------------------------------
        function clearTextHandles(obj)
            textProps.visible = 'on';
            textProps.string = '';
            recurseHandleInit(obj.texthandle,textProps);
        end


        % --------------------------------------------------------------------
        %> @brief Clears axes handles of any children and sets default properties.
        %> Called when first creating a view.  See also initAxesHandles.
        %> @param obj Instance of PASingleStudyController
        % --------------------------------------------------------------------
        function clearAxesHandles(obj)   
            % Also works
            %clearAxesHandles(obj.axeshandle);
            
            axesH = struct2array(obj.axeshandle);  %place in utility folder
            clearAxesHandles(axesH);            
        end
        
        % --------------------------------------------------------------------
        %> @brief Clear text ('string') of view's user interface widgets
        %> @param obj Instance of PASingleStudyController
         % --------------------------------------------------------------------
        function clearWidgets(obj)            
            
            set(obj.handles.edit_aggregate,'string','');
            set(obj.handles.edit_frameSizeHours,'string','');
            set(obj.handles.edit_frameSizeMinutes,'string','');
            set(obj.handles.edit_curWindow,'string','');
            
            %what about all of the menus that I have ?
            set(obj.handles.panel_study,'visible','off');
            set(obj.handles.panel_clusterInfo,'visible','off');            
        end        

        % --------------------------------------------------------------------
        %> @brief Disable user interface widgets
        %> @param obj Instance of PASingleStudyController
        % --------------------------------------------------------------------
        function disableWidgets(obj)
            
            resultPanels = [
                obj.handles.panel_results
                obj.handles.btngrp_clusters
                obj.handles.panel_epochControls
                ];
            
            timeseriesPanels = [obj.handles.panel_timeseries;
                obj.handles.panel_displayButtonGroup;
                obj.handles.panel_epochControls];
            menubarHandles = [obj.handles.menu_file_screenshot_primaryAxes;
                obj.handles.menu_file_screenshot_secondaryAxes];
            set(menubarHandles,'enable','off');
            
            % disable panel widgets
            set(findall([resultPanels;timeseriesPanels],'enable','on'),'enable','off');
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Initialize user interface widgets on start up.
        %> @param obj Instance of PASingleStudyController 
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
        function updateWidgets(obj, viewMode, disableFlag)
            if(nargin<3)
                disableFlag = true;
                if(nargin<2)
                    viewMode = obj.viewTag;
                end
            end
            
            resultPanels = [
                obj.handles.panel_results
                %  obj.handles.toolbar_results
                obj.handles.btngrp_clusters
                ];
                       
            timeseriesPanels = [
                obj.handles.panel_timeseries;
                obj.handles.panel_displayButtonGroup;
                obj.handles.panel_epochControls];
            
            if(strcmpi(viewMode,'timeseries'))
                
                set(timeseriesPanels,'visible','on');
                set(resultPanels,'visible','off');
                %set(findall(resultPanels,'enable','on'),'enable','off');
                set(findall(obj.handles.toolbar_results,'enable','on'),'enable','off');
                set(obj.handles.menu_viewmode_timeseries,'checked','on');
                set(obj.handles.menu_viewmode_results,'checked','off');
                
                if(disableFlag)                    
                    set(findall(timeseriesPanels,'enable','on'),'enable','off');
                end
                
            elseif(strcmpi(viewMode,'results'))
                set(timeseriesPanels,'visible','off');
                
                set(resultPanels(1:2),'visible','on');
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
                set(obj.handles.menu_viewmode_timeseries,'checked','off');
                set(obj.handles.menu_viewmode_results,'checked','on');
            else
                fprintf('Unknown view mode (%s)\n',viewMode);
            end

            menubarHandles = [obj.handles.menu_file_screenshot_primaryAxes;
                obj.handles.menu_file_screenshot_secondaryAxes];
            set(menubarHandles,'visible','on','enable','on');
            
            set(obj.handles.panel_study,'visible','off');
            set(obj.handles.panel_clusterInfo,'visible','off');            
        end          
        
        function refreshView(obj)            
            obj.clearCallbacks();
            obj.initAxesHandles();
            obj.clearTextHandles();
            obj.updateWidgets();
        end
        
        function didClear = clearCallbacks(obj)
            didClear = true;
            figH = obj.figureH;            
            % mouse and keyboard callbacks
            set(figH,'WindowKeyPressFcn',[]);
            set(figH,'KeyPressFcn',[]);
            set(figH,'KeyReleaseFcn',[]);
            set(figH,'WindowButtonDownFcn',[]);
            set(figH,'WindowButtonUpFcn',[]);
            
            set(obj.axeshandle.secondary,'uicontextmenu',[]);
        end
        
        function axesProps = getPadacoAxesProps(obj,optionalView)
            
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
            
            if(nargin)
                viewMode = optionalView;
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
                    % axesProps.secondary.visible = 'off';
                end
            end
            
            axesProps.secondary.xgrid = 'off';
            axesProps.secondary.xminortick = 'off';
            axesProps.secondary.xAxisLocation = 'bottom';
        end        
    end
    methods(Abstract,Access=protected)
        didInit = initWidgets(obj)
        didInit = initCallbacks(obj);
    end
        
    methods(Access=protected)
        
        function didInit = initFigure(obj)
            if(ishandle(obj.figureH))
                obj.designateHandles();
                didInit = obj.initWidgets();
                obj.initCallbacks(); %initialize callbacks now that we have some data we can interact with.       
            else
                didInit = false;
            end
        end
        
        %> @brief Creates line handles and maps figure tags to PASingleStudyController instance variables.
        %> @param obj Instance of PASingleStudyController.
        %> @note This method does not set the view mode.  Call
        %> refreshView or initView(.) to configure the axes and widgets accordingly.
        % --------------------------------------------------------------------
        function designateHandles(obj)
            % handles = guidata(obj.figureH);
            
            obj.texthandle.status = obj.handles.text_status;
            obj.texthandle.filename = obj.handles.text_filename;
            obj.texthandle.studyinfo = obj.handles.text_studyinfo;
            
            obj.axeshandle.primary = obj.handles.axes_primary;
            obj.axeshandle.secondary = obj.handles.axes_secondary; 
            
            obj.setStatusHandle(obj.handles.text_status);
        end        
        
        % --------------------------------------------------------------------
        %> @brief Initialize data specific properties of the axes handles.
        %> Set the x and y limits of the axes based on limits found in
        %> dataStruct struct.
        %> @param obj Instance of PASingleStudyController
        %> @param axesProps Structure of axes property structures.  First fields
        %> are:
        %> - @c primary (for the primary axes);
        %> - @c secondary (for the secondary axes, lower, timeline axes)
        % --------------------------------------------------------------------
        function initAxesHandles(obj,axesProps)
            if(nargin<2)                
                obj.clearAxesHandles();
                axesProps = obj.getPadacoAxesProps(obj.viewTag);                
                %initialize axes
                obj.initAxesHandles(axesProps);                
            else
                axesNames = fieldnames(axesProps);
                for a=1:numel(axesNames)
                    axesName = axesNames{a};
                    set(obj.axeshandle.(axesName),axesProps.(axesName));
                end
            end
        end
        

        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param axesTag Optional tag, that if set will set the axes tag's
        %> state to 'ready'.  See setAxesState method.
        %> @param obj Instance of PAViewController        
        % --------------------------------------------------------------------
        function showReady(obj,axesTag)
            if(nargin>1 && ~isempty(axesTag))
                obj.setAxesState(axesTag,'ready');
            end
            showReady@PAFigureController(obj); % set(obj.texthandle.status,'string','');
        end
        
        % --------------------------------------------------------------------
        %> @brief Shows busy status (mouse becomes a watch).
        %> @param obj Instance of PAViewController
        %> @param status_label Optional string which, if included, is displayed
        %> in the figure's status text field (currently at the top right of
        %> the view).
        %> @param axesTag Optional tag, that if set will set the axes tag's
        %> state to 'busy'.  See setAxesState method.
        % --------------------------------------------------------------------
        function showBusy(obj,status_label,axesTag)
            if(nargin>1)
                set(obj.texthandle.status,'string',status_label);
                if(nargin>2)
                    obj.setAxesState(axesTag,'busy');
                end
            end
            showBusy@PAFigureController(obj);          
        end
                
        %> @brief Adjusts the color of the specified axes according to the
        %> specified state.
        %> @param obj Instance of PASingleStudyController
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
        

        
        %> @brief
        %> @param obj Instance of PAController
        %> @param axisToUpdate Axis to update 'x' or 'y' on the secondary
        %> axes.
        %> @param labels Cell of labels to place on the secondary axes.
        function updateSecondaryAxesLabels(obj, axisToUpdate, labels)
            axesProps.secondary = struct();
            if(strcmpi(axisToUpdate,'x'))
                tickField = 'xtick';
                labelField = 'xticklabel';
            else
                tickField = 'ytick';
                labelField = 'yticklabel';
            end
            axesProps.secondary.(tickField) = getTicksForLabels(labels);
            axesProps.secondary.(labelField) = labels;
            obj.initAxesHandles(axesProps);
        end
       
        
        % =================================================================
        %> @brief Copy the selected (feature) linehandle's ydata to the system
        %> clipboard.
        %> @param obj Instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenuLine2ClipboardCb(hObject,~)
            data = get(get(hObject,'parent'),'userdata');
            clipboard('copy',data);
            disp([num2str(numel(data)),' items copied to the clipboard.  Press Control-V to access data items, or type "str=clipboard(''paste'')"']);
        end
        
    end
    
    methods(Static)

    end
end
   
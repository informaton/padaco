%> @file PAController.cpp
%> @brief PAController serves as Padaco's controller component (i.e. in the model, view, controller paradigm).
% ======================================================================
%> @brief PAController serves as the UI component of event marking in
%> the Padaco.  
%
%> In the model, view, controller paradigm, this is the
%> controller. 

classdef PAController < handle
    
    properties
        %> acceleration activity object - instance of PAData
        accelObj;
        %> Instance of PASettings - this is brought in to eliminate the need for several globals
        SETTINGS; 
        %> Instance of PAView - Padaco's view component.
        VIEW;
        %> Instance of PAModel - Padaco's model component.  To be implemented. 
        MODEL;        

        %> Linehandle in Padaco that is currently selected by the user.
        current_linehandle;
        
        %> cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell; 
        %> string of the current selected choice
        %> handle to the figure an instance of this class is associated with
        %> struct of handles for the context menus
        contextmenuhandle; 
        
        %> @brief struct with field
        %> - .x_minorgrid which is used for the x grid on the main axes
        linehandle;         
        
        %> struct of different time resolutions, field names correspond to the units of time represented in the field        
        window_resolution;
        num_windows;
        display_samples; %vector of the samples to be displayed
        shift_display_samples_delta; %number of samples to adjust display by for moving forward or back
        startDateTime;
        study_duration_in_seconds;
        study_duration_in_samples;

        STATE; %struct to keep track of various Padaco states
        Padaco_loading_file_flag; %boolean set to true when initially loading a src file
        Padaco_mainaxes_ylim;
        Padaco_mainaxes_xlim;        
    end


    methods
        
        function obj = PAController(Padaco_fig_h,...
                rootpathname,...
                parameters_filename)
            if(nargin<1)
                Padaco_fig_h = [];
            end
            if(nargin<2)
                rootpathname = fileparts(mfilename('fullpath'));
            end
            
            %check to see if a settings file exists
            if(nargin<3)
                parameters_filename = '_padaco.parameters.txt';
            end;
            
            %create/intilize the settings object            
            obj.SETTINGS = PASettings(rootpathname,parameters_filename);

            if(ishandle(Padaco_fig_h))
                %let's create a VIEW class
                uicontextmenu_handle = obj.getContextmenuHandle();
        
                
                obj.VIEW = PAView(Padaco_fig_h,uicontextmenu_handle);
                
                handles = guidata(Padaco_fig_h);
                
                obj.configureCallbacks();
                
                % Synthesize edit callback to trigger first display
                obj.edit_curWindowCallback(handles.edit_curWindow,[]);
                
            end                
        end
        
        %% Shutdown functions        
        %> Destructor
        function close(obj)
            if(~isempty(obj.accelObj))
                obj.SETTINGS.DATA = obj.accelObj.getSaveParameters();
               
            end
            obj.saveParameters(); %requires SETTINGS variable
            obj.SETTINGS = [];
        end        
        
        function saveParameters(obj)
            obj.SETTINGS.saveParametersToFile();
        end
        
        function paramStruct = getSaveParametersStruct(obj)
            paramStruct = obj.SETTINGS.VIEW;
        end            
        

        %% Startup configuration functions and callbacks
        % --------------------------------------------------------------------
        %> @brief Configure callbacks for the figure, menubar, and widets.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------        
        function configureCallbacks(obj)   
            figH = obj.VIEW.getFigHandle();
            
            % figure callbacks
            set(figH,'CloseRequestFcn',{@obj.figureCloseCallback,guidata(figH)});            
            set(figH,'KeyPressFcn',@obj.keyPressCallback);
            set(figH,'KeyReleaseFcn',@obj.keyReleaseCallback);
            set(figH,'WindowButtonDownFcn',@obj.windowButtonDownCallback);
            set(figH,'WindowButtonUpFcn',@obj.windowButtonUpCallback);

% 
%         
%         function setLinehandle(obj, line_h)
%             obj.clear_handles();
%             obj.current_linehandle = line_h;
%             set(obj.current_linehandle,'selected','on');
%         end
            
            
            
            %configure the menu bar
            obj.configureMenubar();
            
            %configure the user interface widgets
            obj.configureWidgetCallbacks();
        end
        
        % --------------------------------------------------------------------
        %> @brief Executes when user attempts to close figure_padaco.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_file_quit (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function figureCloseCallback(obj,hObject, eventdata, handles)
            try
                obj.close();
                delete(hObject);
            catch ME
                showME(ME);
                killall;
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes on key press with focus on figure and no controls selected.
        %> @param obj Instance of PAController
        %> @param hObject    handle to figure (gcf)
        %> @param eventdata Structure of key press information.
        % --------------------------------------------------------------------
        function keyPressCallback(obj,hObject, eventdata)
            % key=double(get(hObject,'CurrentCharacter')); % compare the values to the list
            key=eventdata.Key;
            handles = guidata(hObject);
            window = obj.curWindow;
            
            if(strcmp(key,'add'))
                
            elseif(strcmp(key,'subtract'))
                       
            elseif(strcmp(key,'leftarrow')||strcmp(key,'pagedown'))
                %go backward 1 window
                obj.setCurWindow(window-1);                
            elseif(strcmp(key,'rightarrow')||strcmp(key,'pageup'))
                %go forward 1 window
                obj.setCurWindow(window+1);                    
            elseif(strcmp(key,'uparrow'))
                %go forward 10 windows
                obj.setCurWindow(window+10);
            elseif(strcmp(key,'downarrow'))
                %go back 10 windows
                obj.setCurWindow(window-10);                
            end
            
            if(strcmp(eventdata.Key,'shift'))
                set(obj.VIEW.getFigHandle(),'pointer','ibeam');
            end
            if(strcmp(eventdata.Modifier,'control'))
                %kill the program            
                if(strcmp(eventdata.Key,'x'))
                    delete(hObject);
                    %take screen capture of figure
                elseif(strcmp(eventdata.Key,'p'))
                    screencap(hObject);
                    %take screen capture of main axes
                elseif(strcmp(eventdata.Key,'a'))
                    screencap(handles.axes1);
                elseif(strcmp(eventdata.Key,'h'))
                    screencap(handles.axes2);
                elseif(strcmp(eventdata.Key,'u'))
                    screencap(handles.axes3);
                end
            end;
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes on key press with focus on figure and no controls selected.
        %> @param obj Instance of PAController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventdata Structure of key press information.
        % --------------------------------------------------------------------
        function keyReleaseCallback(obj,hObject, eventdata)
            
            key=eventdata.Key;
            if(strcmp(key,'shift'))
                set(obj.VIEW.getFigHandle(),'pointer','arrow');
            end;
        end

        % --------------------------------------------------------------------
        %> @brief  Executes when user releases mouse click
        %> If the currentObject selected is the secondary axes, then 
        %> the current window is set to the closest window corresponding to
        %> the mouse's x-position.
        %> @param obj Instance of PAController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventData Structure of mouse press information; unused
        % --------------------------------------------------------------------
        function windowButtonUpCallback(obj,hObject,eventData)
            
            selected_obj = get(hObject,'CurrentObject');            
            if(~isempty(selected_obj))
                if(selected_obj==obj.VIEW.axeshandle.secondary)
                    pos = get(selected_obj,'currentpoint');
                    clicked_datenum = pos(1); 
                    cur_window = obj.accelObj.datenum2window(clicked_datenum,obj.VIEW.getDisplayType());
                    obj.setCurWindow(cur_window);
                end;
            end;
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes when user first clicks the mouse.
        %> @param obj Instance of PAController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventData Structure of mouse press information; unused
        % --------------------------------------------------------------------
        function windowButtonDownCallback(obj,hObject,eventData)
            if(ishandle(obj.current_linehandle))                
                set(obj.current_linehandle,'selected','off');
                obj.current_linehandle = [];
                obj.VIEW.showReady();
            end
        end

        
        %-- Menubar configuration --
        % --------------------------------------------------------------------
        %> @brief Assign figure's menubar callbacks.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------        
        function configureMenubar(obj)
            figH = obj.VIEW.getFigHandle();
            handles = guidata(figH);
            
            %% file
             %  open
            set(handles.menu_file_open,'callback',@obj.menuFileOpenCallback);
             %  quit - handled in main window.
            set(handles.menu_file_quit,'callback',{@obj.menuFileQuitCallback,guidata(figH)});
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Assign callbacks to various user interface widgets.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------
        function configureWidgetCallbacks(obj)
            handles = guidata(obj.VIEW.getFigHandle());
            set(handles.edit_curWindow,'callback',@obj.edit_curWindowCallback);
            set(handles.edit_aggregate,'callback',@obj.edit_aggregateCallback);
            set(handles.edit_frameSizeMinutes,'callback',@obj.edit_frameSizeMinutesCallback);
            set(handles.edit_frameSizeHours,'callback',@obj.edit_frameSizeHoursCallback);
            
            set(handles.menu_windowDurSec,'callback',@obj.menu_windowDurSecCallback);
            set(handles.panel_displayButtonGroup,'selectionChangeFcn',@obj.displayChangeCallback);
            
            set(handles.button_go,'callback',@obj.button_goCallback);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for radio button change of the panel_displayButtonGroup handle.
        %> The user can select either, 'time series', 'aggregate bins', or
        %> 'features'.  If 'Features' is selected, then the Feature dropdown
        %> menu is enabled, and is disabled otherwise.  The view is
        %> redrawn.
        %> @param obj Instance of PAController
        %> @param hObject Handle to button group panel.  
        %> @param eventData Structure of event data to include:
        %> @li @c EventName 'SelectionChanged'
        %> @li @c OldValue Handle to the previous callback
        %> @li @c NewValue Handle to the current callback
        % --------------------------------------------------------------------
        function displayChangeCallback(obj,hObject,eventData)
            displayType = get(eventData.NewValue,'string');
            obj.VIEW.setDisplayType(displayType);  
            obj.VIEW.draw();
        end
        
        % --------------------------------------------------------------------
        %> @brief Executes a radio button group callback (i.e.
        %> displayChangeCallback).
        %> @param obj Instance of PAController
        %> @param displayType String value of the radio button to set.  Can be
        %> @li @c time series
        %> @li @c aggregate bins
        %> @li @c features        
        function setRadioButton(obj,displayType)
            handles = guidata(obj.VIEW.getFigHandle());
            eventStruct.EventName = 'SelectionChanged';
            eventStruct.OldValue = get(handles.panel_displayButtonGroup,'selectedObject');
            
            switch lower(displayType)
                case 'time series'
                    eventStruct.NewValue = handles.radio_time;
                case 'aggregate bins'
                    eventStruct.NewValue = handles.radio_bins;
                case 'features'
                    eventStruct.NewValue = handles.radio_features;
                otherwise
                    fprintf('Sorry, (%s) is not a recognized type.\n',displayType);
            end
            
            if(eventStruct.OldValue~=eventStruct.NewValue)
                set(eventStruct.NewValue,'value',1);
                obj.displayChangeCallback(handles.panel_displayButtonGroup,eventStruct);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for pressing the Go push button.  Method
        %> determines parameters from current view settings (i.e. menu
        %> selections for prefilter and aggregate methods).
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function button_goCallback(obj,hObject,eventdata)
            %obtain the prefilter and feature extraction methods
            prefilterMethod = obj.getPrefilterMethod();
            extractorMethod = obj.getExtractorMethod();
            
            % get the prefilter duration in minutes. 
            % aggregateDurMin = obj.VIEW.getAggregateDuration();
            
            %Tell the model to prefilter and extract
            if(~strcmpi(prefilterMethod,'none'))                             
                obj.accelObj.prefilter(prefilterMethod);
                obj.VIEW.enableAggregateRadioButton();
                
                displayType = 'aggregate bins';
                obj.setRadioButton(displayType);  
            end
            if(~strcmpi(extractorMethod,'none'))            
                obj.accelObj.extractFeature(extractorMethod);
                obj.VIEW.enableFeatureRadioButton();
                obj.VIEW.appendFeatureMenu(extractorMethod);                
                displayType = 'features';
                obj.setRadioButton(displayType); 
            end
            obj.VIEW.draw();
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves current prefilter method from the GUI
        %> @param obj Instance of PAController
        %> @retval prefilterMethod value of the current prefilter method.
        % --------------------------------------------------------------------
        function prefilterMethod = getPrefilterMethod(obj)
            prefilterMethods = get(obj.VIEW.menuhandle.prefilterMethod,'string');
            prefilterIndex =  get(obj.VIEW.menuhandle.prefilterMethod,'value');
            if(~iscell(prefilterMethods))
                prefilterMethod = prefilterMethods;
            else
                prefilterMethod = prefilterMethods{prefilterIndex};
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves current extractor method from the GUI
        %> @param obj Instance of PAController
        %> @retval extractorMethod String value of the current feature extraction method.
        % --------------------------------------------------------------------
        function extractorMethod = getExtractorMethod(obj)
            extractorMethods = get(obj.VIEW.menuhandle.extractorMethod,'string');
            extractorIndex =  get(obj.VIEW.menuhandle.extractorMethod,'value');
            if(~iscell(extractorMethods))
                extractorMethod = extractorMethods;
            else
                extractorMethod = extractorMethods{extractorIndex};
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for menu with window duration selections (values
        %> are in seconds)
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function menu_windowDurSecCallback(obj,hObject,eventdata)
            %get the array of window sizes in seconds
            windowDurSec = get(hObject,'userdata');
            % grab the currently selected window size (in seconds)
            windowDurSec = windowDurSec(get(hObject,'value'));
            
            %change it - this internally recalculates the cur window
            obj.accelObj.setWindowDurSec(windowDurSec);
            
            obj.setCurWindow(obj.curWindow());
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for current window's edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function edit_curWindowCallback(obj,hObject,eventdata)
            window = str2double(get(hObject,'string'));
            obj.setCurWindow(window);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for aggregate size edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        %> @note Entered values are interepreted as minutes.
        % --------------------------------------------------------------------
        function edit_aggregateCallback(obj,hObject,eventdata)
            aggregateDuration = str2double(get(hObject,'string'));
            obj.setAggregateDurationMinutes(aggregateDuration);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for frame size in minutes edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        %> @note Entered values are interepreted as minutes.
        % --------------------------------------------------------------------
        function edit_frameSizeMinutesCallback(obj,hObject,eventdata)
            frameDurationMinutes = str2double(get(hObject,'string'));
            obj.setFrameDurationMinutes(frameDurationMinutes);
        end 
        
        % --------------------------------------------------------------------
        %> @brief Callback for frame size in hours edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        %> @note Entered values are interepreted as hours.
        % --------------------------------------------------------------------
        function edit_frameSizeHoursCallback(obj,hObject,eventdata)
            frameDurationHours = str2double(get(hObject,'string'));
            obj.setFrameDurationHours(frameDurationHours);
        end
        
        % --------------------------------------------------------------------
        %> @brief Set the aggregate duration in minutes.
        %> @param obj Instance of PAController
        %> @param new_aggregateDuration Aggregate duration in minutes.
        %> @retval success True if the aggregate duration is changed, and false otherwise.
        % --------------------------------------------------------------------
        function success = setAggregateDurationMinutes(obj,new_aggregateDuration)
            success = false;
            if(~isempty(obj.accelObj))                
                cur_aggregateDuration = obj.accelObj.setAggregateDurationMinutes(new_aggregateDuration);
                obj.VIEW.setAggregateDurationMinutes(num2str(cur_aggregateDuration));
                if(new_aggregateDuration==cur_aggregateDuration)
                    success=true;
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Set the frame size minute's units.
        %> @param obj Instance of PAController
        %> @param new_frameDurationMinutes Frame duration minutes measure.
        %> @retval success True if the frame duration is changed, and false otherwise.
        % --------------------------------------------------------------------
        function success = setFrameDurationMinutes(obj,new_frameDurationMinutes)
            success = false;
            if(~isempty(obj.accelObj))                
                cur_frameDurationMinutes = obj.accelObj.setFrameDurationMinutes(new_frameDurationMinutes);
                obj.VIEW.setFrameDurationMinutes(num2str(cur_frameDurationMinutes));
                if(new_frameDurationMinutes==cur_frameDurationMinutes)
                    success=true;
                end
            end
        end
         % --------------------------------------------------------------------
        %> @brief Set the frame size hour's units
        %> @param obj Instance of PAController
        %> @param new_frameDurationHours Hours for frame duration.
        %> @retval success True if the frame duration is changed, and false otherwise.
        % --------------------------------------------------------------------
        function success = setFrameDurationHours(obj,new_frameDurationHours)
            success = false;
            if(~isempty(obj.accelObj))                
                cur_frameDurationHours = obj.accelObj.setFrameDurationHours(new_frameDurationHours);
                obj.VIEW.setFrameDurationHours(num2str(cur_frameDurationHours));
                if(new_frameDurationHours==cur_frameDurationHours)
                    success=true;
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Set the current window for the instance variable accelObj
        %> (PAData)
        %> @param obj Instance of PAController
        %> @param new_window Value of the new window to set.
        %> @retval success True if the window is set successfully, and false otherwise.
        %> @note Reason for failure include window values that are outside
        %> the range allowed by accelObj (e.g. negative values or those
        %> longer than the duration given.  
        % --------------------------------------------------------------------
        function success = setCurWindow(obj,new_window)
            success= false;
            if(~isempty(obj.accelObj))                 
                curWindow = obj.accelObj.setCurWindow(new_window);
                windowStartDateNum = obj.accelObj.window2datenum(new_window);
                obj.VIEW.setCurWindow(num2str(curWindow),windowStartDateNum);
                if(new_window==curWindow)
                    success=true;
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the current window of the instance variable accelObj
        %> (PAData)
        %> @param obj Instance of PAController
        %> @retval window The  current window, or null if it has not been initialized.
        function window = curWindow(obj)
            if(isempty(obj.accelObj))
                window = [];
            else
                window = obj.accelObj.getCurWindow;
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a file.
        %> @param obj Instance of PAController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenCallback(obj,hObject,eventdata)
            f=uigetfullfile({'*.csv;*.raw','All (Count or raw)';'*.csv','Comma Separated Values';'*.raw','Raw Format (comma separated values)'},'Select a file','off',fullfile(obj.SETTINGS.DATA.pathname,obj.SETTINGS.DATA.filename));
            try
                if(~isempty(f))
                    
                    obj.VIEW.showBusy('Loading');
                    obj.accelObj = PAData(f,obj.SETTINGS.DATA);
                    
                    %initialize the PAData object's visual properties
                    obj.initView(); %calls show obj.VIEW.showReady() Ready...
                end
            catch me
                showME(me);
                obj.VIEW.showReady();
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for quitting the program.
        %> Executes when user attempts to close padaco fig.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_file_quit (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menuFileQuitCallback(obj,hObject,eventdata,handles)
            obj.figureCloseCallback(gcbf,eventdata,handles);
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates the median lux value for a given number of sections.
        %> @param obj Instance of PAController
        %> @param numPatches (optional) Number of patches to break the
        %> accelObj lux time series data into and calculate the median
        %> lumens over.
        %> @retval medianLumens Vector of median lumen values calculated
        %> from the lux field of the accelObj PAData object instance
        %> variable.  Vector values are in consecutive order of the section they are calculated from.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the medianLumens
        %> value (at the same row position) was derived from.
        %> @note  Sections will not be calculated on equally lenghted        
        %> sections when numSections does not evenly divide the total number
        %> of samples.  In this case, the last section may be shorter or
        %> longer than the others.
        function [medianLumens,startStopDatenums] = getMedianLumenPatches(obj,numSections)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            luxData = obj.accelObj.lux;
            indices = ceil(linspace(1,numel(luxData),numSections+1));
            medianLumens = zeros(numSections,1);
            startStopDatenums = zeros(numSections,2);
            for i=1:numSections
                medianLumens(i) = median(luxData(indices(i):indices(i+1)));
                startStopDatenums(i,:) = [obj.accelObj.dateTimeNum(indices(i)),obj.accelObj.dateTimeNum(indices(i+1))];
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates the mean lux value for a given number of sections.
        %> @param obj Instance of PAController
        %> @param numPatches (optional) Number of patches to break the
        %> accelObj lux time series data into and calculate the mean
        %> lumens over.
        %> @retval meanLumens Vector of mean lumen values calculated
        %> from the lux field of the accelObj PAData object instance
        %> variable.  Vector values are in consecutive order of the section they are calculated from.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the meanLumens
        %> value (at the same row position) was derived from.
        %> @note  Sections will not be calculated on equally lenghted        
        %> sections when numSections does not evenly divide the total number
        %> of samples.  In this case, the last section may be shorter or
        %> longer than the others.
        function [meanLumens,startStopDatenums] = getMeanLumenPatches(obj,numSections)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            luxData = obj.accelObj.lux;
            indices = ceil(linspace(1,numel(luxData),numSections+1));
            meanLumens = zeros(numSections,1);
            startStopDatenums = zeros(numSections,2);
            for i=1:numSections
                meanLumens(i) = mean(luxData(indices(i):indices(i+1)));
                startStopDatenums(i,:) = [obj.accelObj.dateTimeNum(indices(i)),obj.accelObj.dateTimeNum(indices(i+1))];
            end
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Calculates a desired feature for a particular acceleration object's field value.
        %> @note This is the general form of getMeanLuxPatches
        %> @param obj Instance of PAController
        %> @param featureFcn Function name or handle to use to obtain
        %> features.
        %> @param fieldName String name of the accelObj field to obtain data from.  
        %> @note Data is obtained using dynamic indexing of
        %> accelObj instance variable (ie.. data = obj.accelObj.(fildName))
        %> @param numPatches (optional) Number of patches to break the
        %> accelObj lux time series data into and calculate the mean
        %> lumens over.
        %> @retval featureVec Vector of specified feature values calculated
        %> from the specified (fieldName) field of the accelObj PAData object instance
        %> variable.  Vector values are in consecutive order of the section they are calculated from.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the feature vector
        %> value (at the same row position) was derived from.
        %> @note  Sections will not be calculated on equally lenghted        
        %> sections when numSections does not evenly divide the total number
        %> of samples.  In this case, the last section may be shorter or
        %> longer than the others.
        function [featureVec,startStopDatenums] = getFeatureVecPatches(obj,featureFcn,fieldName,numSections)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            fieldData = obj.accelObj.(fieldName);
            indices = ceil(linspace(1,numel(fieldData),numSections+1));
            featureVec = zeros(numSections,1);
            startStopDatenums = zeros(numSections,2);
            for i=1:numSections
                featureVec(i) = feval(featureFcn,fieldData(indices(i):indices(i+1)));
                startStopDatenums(i,:) = [obj.accelObj.dateTimeNum(indices(i)),obj.accelObj.dateTimeNum(indices(i+1))];
            end
        end
        
        
        %% context menu's for the lines
        % --------------------------------------------------------------------
        % Main Channel Line callback section
        % --------------------------------------------------------------------
        % =================================================================
        %> @brief Configure contextmenu for channel instances.
        %> @param obj instance of PAController.
        %> @param parent_fig The figure handle that the context menu handle
        %> is assigned to (i.e. the 'parent' handle).  (Optional, [] is
        %> default)
        %> @retval uicontextmenu_handle A contextmenu handle.  This should
        %> be assigned to the line handles drawn by the PAController and
        %> PAView classes.
        % =================================================================
        function uicontextmenu_handle = getContextmenuHandle(obj)
            
            uicontextmenu_handle = uicontextmenu('callback',@obj.contextmenu_line_callback);%,get(parentAxes,'parent'));
            uimenu(uicontextmenu_handle,'Label','Resize','separator','off','callback',@obj.contextmenu_line_resize_callback);
            uimenu(uicontextmenu_handle,'Label','Use Default Scale','separator','off','callback',@obj.contextmenu_line_default_callback);
            uimenu(uicontextmenu_handle,'Label','Move','separator','off','callback',@obj.contextmenu_line_move_callback);
            uimenu(uicontextmenu_handle,'Label','Add Reference Line','separator','on','callback',@obj.contextmenu_line_referenceline_callback);
            uimenu(uicontextmenu_handle,'Label','Change Color','separator','off','callback',@obj.contextmenu_line_color_callback);
            uimenu(uicontextmenu_handle,'Label','Align Channel','separator','off','callback',@obj.align_channels_on_axes);
            uimenu(uicontextmenu_handle,'Label','Hide','separator','on','callback',@obj.contextmenu_line_hide_callback);
            uimenu(uicontextmenu_handle,'Label','Copy window to clipboard','separator','off','callback',@obj.window2clipboard,'tag','copy_window2clipboard');
        end
        
        
        % =================================================================
        %> @brief Contextmenu callback for primary axes line handles
        %> @param obj instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenu_line_callback(obj,hObject,eventdata)
            %parent context menu that pops up before any of the children contexts are
            %drawn...
            %             handles = guidata(hObject);
            %             parent_fig = get(hObject,'parent');
            %             obj_handle = get(parent_fig,'currentobject');
            obj.current_linehandle = gco;
            set(gco,'selected','on');
            tag = get(gco,'tag');
            set(obj.VIEW.texthandle.status,'string',tag);
            
%             child_menu_handles = get(hObject,'children');  %this is all of the handles of the children menu options
%             default_scale_handle = child_menu_handles(find(~cellfun('isempty',strfind(get(child_menu_handles,'Label'),'Use Default Scale')),1));
            
%             if(channelObj.scale==1)
%                 set(default_scale_handle,'checked','on');
%             else
%                 set(default_scale_handle,'checked','off');
%             end;
%             
%             %show/hide the show filter handle
%             if(isempty(channelObj.filter_data))
%                 set(show_filtered_handle,'visible','off');
%             else
%                 set(show_filtered_handle,'visible','on');
%                 if(channelObj.show_filtered)
%                     set(show_filtered_handle,'Label','Show Raw Data');
%                     %         set(show_filtered_handle,'checked','on');
%                 else
%                     set(show_filtered_handle,'Label','Show Filtered Data');
%                     %         set(show_filtered_handle,'checked','off');
%                 end
%             end
%             guidata(hObject,handles);
        end
        
        % =================================================================
        %> @brief Resize callback for channel object contextmenu.
        %> @param obj instance of CLASS_channels_container.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        %> @retval obj instance of CLASS_channels_container.
        % =================================================================
        function contextmenu_line_resize_callback(obj,hObject,eventdata)
            set(obj.VIEW.figurehandle,'pointer','crosshair','WindowScrollWheelFcn',...
                {@obj.resize_WindowScrollWheelFcn,...
                get(gco,'tag'),obj.VIEW.texthandle.status});
        end;
                
        % =================================================================
        %> @brief Channel contextmenu callback to move the selected
        %> channel's position in the SEV.
        %> @param obj instance of CLASS_channels_container.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        %> @param channel_object The CLASS_channel object being moved.
        %> @param ylim Y-axes limits; cannot move the channel above or below
        %> these bounds.
        %> @retval obj instance of CLASS_channels_container.
        % =================================================================
        function move_line(obj,hObject,eventdata,channel_object,y_lim)
            %windowbuttonmotionfcn set by contextmenu_line_move_callback
            %axes_h is the axes that the current object (channel_object) is in
            pos = get(obj.main_axes,'currentpoint');
            channel_object.setLineOffset(max(min(pos(1,2),y_lim(2)),y_lim(1)));
        end
        
        
        % =================================================================
        %> @brief Mouse wheel callback to resize the selected channel.
        %> @param obj instance of PAController.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Mouse scroll event data.
        %> @param lineTag The tag for the current selected linehandle.
        %> @note lineTag = 'timeSeries.accelCount.x'
        %> 
        %> This is used for dynamic indexing into the accelObj's datastructs.
        %> @param text_h Text handle for outputing the channel's size/scale.         
        % =================================================================
        function resize_WindowScrollWheelFcn(obj,hObject,eventdata,lineTag,text_h)
            %the windowwheelscrollfcn set by contextmenu_line_resize_callback
            %it is used to adjust the size of the selected channel object (channelObj)
            scroll_step = 0.05;
            lowerbound = 0.01;
            
            %kind of hacky
            allScale = obj.accelObj.getScale();
            curScale = eval(['allScale.',lineTag]);
            
            
            newScale = max(lowerbound,curScale-eventdata.VerticalScrollCount*scroll_step);
            obj.accelObj.setScale(lineTag,newScale);
            obj.VIEW.draw();
            
            %update this text scale...
            click_str = sprintf('Scale: %0.2f',newScale);
            set(text_h,'string',click_str);
        end
        
        
        % =================================================================
        %> @brief configures a contextmenu selection to be hidden or to have
        %> attached uimenus with labels of hidden channels displayed.
        %> @param obj instance of CLASS_channels_container.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        %> @retval obj instance of CLASS_channels_container.
        % =================================================================
        function configure_contextmenu_unhidechannels(obj,contextmenu_h,eventdata)
            delete(get(contextmenu_h,'children'));
            set(contextmenu_h,'enable','off');
            for k=1:obj.num_channels
                tmp = obj.cell_of_channels{k};
                if(tmp.hidden)
                    set(contextmenu_h,'enable','on');
                    uimenu(contextmenu_h,'Label',tmp.title,'separator','off','callback',@tmp.show);
                end;
            end;
            set(gco,'selected','off');
            
        end
        
        
        
        
    end
    
    methods(Access=private)
        % --------------------------------------------------------------------
        %> @brief Initializes the display using instantiated instance
        %> variables VIEW (PAView) and accelObj (PAData)
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------
        function initView(obj)
            
            obj.VIEW.initWithAccelData(obj.accelObj);
            
            %             [medianLumens,startStopDatenums] = obj.getMedianLumenPatches(1000);
            [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(1000);
            
            obj.VIEW.addLumensOverlayToSecondaryAxes(meanLumens,startStopDatenums);
            
            [featureVec, startStopDatenums] = getFeatureVecPatches(obj,'mean','vecMag',1000);
            obj.VIEW.addFeaturesOverlayToSecondaryAxes(featureVec,startStopDatenums);
            
            % set the display to show time series data initially.
            displayType = 'Time Series';
            
            obj.setRadioButton(displayType);
            obj.VIEW.setDisplayType(displayType);
            
            %             curWindow = obj.SETTINGS.DATA.curWindow;
            %             frameDurMin = obj.SETTINGS.DATA.frameDurationMinutes;
            %             frameDurHour = obj.SETTINGS.DATA.frameDurationHour;
            %             aggregateDur = obj.SETTINGS.DATA.aggregateDuration;
            obj.setCurWindow(obj.accelObj.getCurWindow());
            
            %             obj.setFrameDurationMinutes(frameDurMin);
            %             obj.setFrameDurationHours(frameDurHour);
            %             obj.setAggregateDurationMinutes(aggregateDur);
            obj.VIEW.showReady();
            
        end
        
    end

    methods (Static)
        
        % =================================================================
        %> @brief Channel contextmenu callback to hide the selected
        %> channel.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenu_line_hide_callback(hObject,eventdata)
            
            set(gco,'selected','off');
        end
        
        % =================================================================
        %> @brief Copy the selected linehandle's ydata to the system
        %> clipboard.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function window2clipboard(hObject,eventdata)
            data =get(hObject,'ydata');
            clipboard('copy',data);
            disp([num2str(numel(range)),' items copied to the clipboard.  Press Control-V to access data items, or type "str=clipboard(''paste'')"']);
            set(gco,'selected','off');
        end
        
    end
    
    
end


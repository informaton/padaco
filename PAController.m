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
                
        %> Struct of batch settings with the following fields
        %> - @c sourceDirectory Directory of Actigraph files that will be batch processed
        %> - @c outputDirectory Output directory for batch processing
        %> - @c classifyUsageState
        %> - @c describeActivity
        %> - @c describeInactivity
        %> - @c describeSleep
        batch;
        
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
            obj.batch = obj.SETTINGS.CONTROLLER.batch;
            
            
            if(ishandle(Padaco_fig_h))
                % Create a VIEW class
                % 1. make context menu handles for the lines
                % 2. make context menu handles for the primary axes
                uiLinecontextmenu_handle = obj.getLineContextmenuHandle();
                uiPrimaryAxescontextmenu_handle = obj.getPrimaryAxesContextmenuHandle();
                featureLineContextMenuHandle = obj.getFeatureLineContextmenuHandle();
                obj.VIEW = PAView(Padaco_fig_h,uiLinecontextmenu_handle,uiPrimaryAxescontextmenu_handle,featureLineContextMenuHandle);

                handles = guidata(Padaco_fig_h);
                obj.initWidgets();
                obj.initCallbacks();
                
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
            obj.SETTINGS.CONTROLLER = obj.getSaveParameters();
            obj.saveParameters(); %requires SETTINGS variable
            obj.SETTINGS = [];
        end        
        
        function saveParameters(obj)
            obj.SETTINGS.saveParametersToFile();
        end
        
%         function paramStruct = getSaveParametersStruct(obj)
%             paramStruct = obj.SETTINGS.VIEW;
%         end            
        

        %% Startup configuration functions and callbacks
        % --------------------------------------------------------------------
        %> @brief Configure callbacks for the figure, menubar, and widets.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------        
        function initCallbacks(obj)   
            figH = obj.VIEW.getFigHandle();
            
            % figure callbacks
            set(figH,'CloseRequestFcn',{@obj.figureCloseCallback,guidata(figH)});            
            set(figH,'KeyPressFcn',@obj.keyPressCallback);
            set(figH,'KeyReleaseFcn',@obj.keyReleaseCallback);
            set(figH,'WindowButtonDownFcn',@obj.windowButtonDownCallback);
            set(figH,'WindowButtonUpFcn',@obj.windowButtonUpCallback);
        
%         function setLinehandle(obj, line_h)
%             obj.clear_handles();
%             obj.current_linehandle = line_h;
%             set(obj.current_linehandle,'selected','on');
%         end
            
            
            %configure the user interface widgets
            obj.initWidgetCallbacks();
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
                set(obj.VIEW.figurehandle,'windowbuttonmotionfcn',[]);
                
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
        function initMenubarCallbacks(obj)
            figH = obj.VIEW.getFigHandle();
            handles = guidata(figH);
            
            %% file
             %  open
            set(handles.menu_file_open,'callback',@obj.menuFileOpenCallback);
             %  quit - handled in main window.
            set(handles.menu_file_quit,'callback',{@obj.menuFileQuitCallback,guidata(figH)});
            
            %% Tools
            % batch
            set(handles.menu_tools_batch,'callback',@obj.menuToolsBatchCallback);
            
            
        end
        
        function initWidgets(obj)
            
            prefilterSelection = PAData.getPrefilterMethods();
            set(obj.VIEW.menuhandle.prefilterMethod,'string',prefilterSelection,'value',1);
            
            % feature extractor
            extractorMethodDescriptions = PAData.getExtractorDescriptions(); 
            extractorStruct = PAData.getFeatureDescriptionStruct(); 
            extractorMethodFcns = fieldnames(extractorStruct);
            set(obj.VIEW.menuhandle.displayFeature,'string',extractorMethodDescriptions,'userdata',extractorMethodFcns,'value',1);
            
            % set(obj.menuhandle.signalSelection,'string',extractorMethods,'value',1);
            
            % Window display resolution
            windowMinSelection = {
                1,'1 s';
                2,'2 s';
                4,'4 s';
                5,'5 s';
                10,'10 s';
                %30,'30 s';
                % 60,'1 min';
                %120,'2 min';
                300,'5 min';
                600,'10 min';
                900,'15 min';
                1800,'30 min';
                3600,'1 hour';
                7200,'2 hours';
                14400,'4 hours';
                28800,'8 hours';
                43200,'12 hours';
                57600,'16 hours';
                86400,'1 day';
                86400*2,'2 days';
                86400*3,'3 days';
                86400*5,'5 days';
                86400*7,'1 week';                
            };
            
            set(obj.VIEW.menuhandle.windowDurSec,'userdata',cell2mat(windowMinSelection(:,1)), 'string',windowMinSelection(:,2),'value',5);

        end
        
        % --------------------------------------------------------------------
        %> @brief Assign callbacks to various user interface widgets.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------
        function initWidgetCallbacks(obj)
            handles = guidata(obj.VIEW.getFigHandle());
            set(handles.edit_curWindow,'callback',@obj.edit_curWindowCallback);
            set(handles.edit_aggregate,'callback',@obj.edit_aggregateCallback);
            set(handles.edit_frameSizeMinutes,'callback',@obj.edit_frameSizeMinutesCallback);
            set(handles.edit_frameSizeHours,'callback',@obj.edit_frameSizeHoursCallback);
            
            
            %initialize dropdown menu callbacks
            set(obj.VIEW.menuhandle.displayFeature,'callback',@obj.updateSecondaryFeaturesDisplay);
            set(handles.menu_windowDurSec,'callback',@obj.menu_windowDurSecCallback);
            
            set(obj.VIEW.menuhandle.signalSelection,'callback',@obj.updateSecondaryFeaturesDisplay);
            
            set(handles.panel_displayButtonGroup,'selectionChangeFcn',@obj.displayChangeCallback);
            
            set(handles.button_go,'callback',@obj.button_goCallback);
            
            %configure the menu bar callbacks.
            obj.initMenubarCallbacks();

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
            obj.setDisplayType(PAData.getStructNameFromDescription(displayType));  
            obj.VIEW.draw();
        end        
        
        % --------------------------------------------------------------------
        %> @brief Sets display type instance variable for the view.
        %> @param obj Instance of PAView.
        %> @param displayType A string representing the display type structure.  Can be 
        %> @li @c timeSeries
        %> @li @c bins
        %> @li @c features
        % --------------------------------------------------------------------
        function setDisplayType(obj,displayType)
            visibleProps = obj.accelObj.getVisible(displayType);
            obj.VIEW.setDisplayType(displayType,visibleProps);
        end  
        
        % --------------------------------------------------------------------
        %> @brief Executes a radio button group callback (i.e.
        %> displayChangeCallback).
        %> @param obj Instance of PAController
        %> @param displayType String value of the radio button to set.  Can be
        %> @li @c timeSeries
        %> @li @c bins
        %> @li @c features        
        function setRadioButton(obj,displayType)
            handles = guidata(obj.VIEW.getFigHandle());
            eventStruct.EventName = 'SelectionChanged';
            eventStruct.OldValue = get(handles.panel_displayButtonGroup,'selectedObject');
            
            switch displayType
                case 'timeSeries'
                    eventStruct.NewValue = handles.radio_time;
                case 'bins'
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
            
            
            % get the prefilter duration in minutes. 
            % aggregateDurMin = obj.VIEW.getAggregateDuration();
            
            %Tell the model to prefilter and extract
            if(~strcmpi(prefilterMethod,'none'))                             
                obj.accelObj.prefilter(prefilterMethod);
                obj.VIEW.enableAggregateRadioButton();
                
                displayType = 'bins';
                obj.setRadioButton(displayType);  
            end
            
            %extractorMethod = obj.getExtractorMethod();
            extractorMethod = 'all';            
            selectedSignalTagLine = obj.getSignalSelection();

            obj.accelObj.extractFeature(selectedSignalTagLine,extractorMethod);
            obj.VIEW.enableFeatureRadioButton();
            
            obj.updateSecondaryFeaturesDisplay();
            % obj.VIEW.appendFeatureMenu(extractorMethod);
            displayType = 'features';
            obj.setRadioButton(displayType);            
            
            obj.VIEW.draw();
        end
        
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes with the current features selected in the GUI
        %> @param obj Instance of PAController
        %> @param numSamples Optional number of features to extract (i.e. the number of chunks that the
        %> the study data will be broken into and the current feature
        %> category applied to.  Default is the current frame count.
        % --------------------------------------------------------------------
        function updateSecondaryFeaturesDisplay(obj,numSamples)
            if(nargin<2 || isempty(numSamples))
                numFrames = obj.getFrameCount(); 
            end
            featureFcn = obj.getExtractorMethod();
            signalTagLine = obj.getSignalSelection();
            obj.drawFeatureVecPatches(featureFcn,signalTagLine,numFrames);
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
        %> @brief Retrieves current extractor method (i.e. function name) associated with the GUI displayed description.
        %> @param obj Instance of PAController
        %> @retval extractorMethod String value of the function call represented by
        %> the current feature extraction method displayed in the VIEW's displayFeature drop down menu.
        %> @note Results of applying the extractor method to the current
        %> signal (selected from its dropdown menu) are displayed in the
        %> secondary axes of PAView.
        % --------------------------------------------------------------------
        function extractorMethod = getExtractorMethod(obj)
            extractorFcns = get(obj.VIEW.menuhandle.displayFeature,'userdata');
            extractorIndex =  get(obj.VIEW.menuhandle.displayFeature,'value');
            if(~iscell(extractorFcns))
                extractorMethod = extractorFcns;
            else
                extractorMethod = extractorFcns{extractorIndex};
            end
            if(strcmpi(extractorMethod,'rms'))
                extractorMethod = @(data)sqrt(mean(data.^2))';
            end

        end
        
        
        % --------------------------------------------------------------------
        %> @brief Sets the extractor method (i.e. function name) associated with the GUI displayed description.
        %> @param obj Instance of PAController
        %> @param featureFcn String value of the function call represented by
        %> the current feature extraction method displayed in the VIEW's displayFeature drop down menu.
        %> @note No change is made if featureFcn is not found listed in
        %> menu handle's userdata.
        % --------------------------------------------------------------------
        function setExtractorMethod(obj,featureFcn)
            extractorFcns = get(obj.VIEW.menuhandle.displayFeature,'userdata');
            extractorInd = find(strcmpi(extractorFcns,featureFcn));
            if(~isempty(extractorInd))
                set(obj.VIEW.menuhandle.displayFeature,'value',extractorInd);
            end
        end
        
        

        % --------------------------------------------------------------------
        %> @brief Retrieves current signal selection from the GUI's
        %> signalSelection dropdown menu.
        %> @param obj Instance of PAController
        %> @retval signalSelection The tag line of the selected signal.
        % --------------------------------------------------------------------
        function signalSelection = getSignalSelection(obj)
            signalSelections = get(obj.VIEW.menuhandle.signalSelection,'userdata');
            selectionIndex =  get(obj.VIEW.menuhandle.signalSelection,'value');
            if(~iscell(signalSelections))
                signalSelection= signalSelections;
            else
                signalSelection = signalSelections{selectionIndex};
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets the Signal Selection's drop down menu's value based on
        %> the input parameter.        
        %> @param obj Instance of PAController.
        %> @param signalTagLine String representing the tag line associated with each
        %> signal choice selection and listed as dropdown menus userdata.
        %> @note No change is made if signalTagLine is not found listed in
        %> menu handle's userdata.
        % --------------------------------------------------------------------
        function signalTagLine = setSignalSelection(obj, signalTagLine)
            signalTagLines = get(obj.VIEW.menuhandle.signalSelection,'userdata');
            selectionIndex = find(strcmpi(signalTagLines,signalTagLine)) ;
            if(~isempty(selectionIndex))
                set(obj.VIEW.menuhandle.signalSelection,'value',selectionIndex);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Initializes the signal selection drop down menu using PAData's 
        %> default taglines and associated labels.
        %> signalSelection dropdown menu.
        %> @param obj Instance of PAController
        %> @note Tag lines are stored as user data at indices corresponding
        %> to the menu label descriptions.  For example, label{1} = 'X' and
        %> userdata{1} = 'accelRaw.x'
        % --------------------------------------------------------------------        
        function initSignalSelectionMenu(obj)
            [tagLines,labels] = PAData.getDefaultTagLineLabels();
            offAccelType = obj.accelObj.getOffAccelType();
            if(~isempty(offAccelType))
                cellIndices = strfind(tagLines,offAccelType);
                pruneIndices = false(size(cellIndices));
                for k=1:numel(cellIndices)
                   pruneIndices(k) = ~isempty(cellIndices{k}); 
                end
                labels(pruneIndices) = [];
                tagLines(pruneIndices) = [];
            end
            set(obj.VIEW.menuhandle.signalSelection,'string',labels,'userdata',tagLines,'value',1);
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
                windowEndDateNum = obj.accelObj.window2datenum(new_window+1);
                if(new_window==curWindow)
                    obj.VIEW.setCurWindow(num2str(curWindow),windowStartDateNum,windowEndDateNum);                
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
            %DATA.pathname	/Volumes/SeaG 1TB/sampleData/csv
            %DATA.filename	700023t00c1.csv.csv
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
        %> @brief Menubar callback for running the batch tool.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_tools_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menuFileQuitCallback(obj,hObject,eventdata,handles)
            obj.figureCloseCallback(gcbf,eventdata,handles);
        end
        
        
        %% Batch mode callbacks        
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for quitting the program.
        %> Executes when user attempts to close padaco fig.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_file_quit (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------        
        function menuToolsBatchCallback(obj,hObject,eventdata)           
            batchFig = batchTool();
            batchHandles = guidata(batchFig);
            
            set(batchHandles.button_getSourcePath,'callback',{@obj.getSourceDirectoryCallback,batchHandles.text_sourcePath,batchHandles.text_filesFound});  
            set(batchHandles.button_getOutputPath,'callback',{@obj.getOutputDirectoryCallback,batchHandles.text_outputPath});
            
            set(batchHandles.text_outputPath,'string',obj.batch.outputDirectory);
            set(batchHandles.check_usageState,'value',obj.batch.classifyUsageState);
            set(batchHandles.check_activityPatterns,'value',obj.batch.describeActivity);
            set(batchHandles.check_inactivityPatterns,'value',obj.batch.describeInactivity);
            set(batchHandles.check_sleepPatterns,'value',obj.batch.describeSleep);
          
            set(batchHandles.button_go,'callback',@obj.startBatchProcessCallback);
            
            obj.calculateFilesFound(batchHandles.text_sourcePath,batchHandles.text_filesFound);
        end        
        
        function getSourceDirectoryCallback(obj,hObject,eventdata,text_sourcePathH,text_filesFoundH)
            displayMessage = 'Select the directory containing .raw or count actigraphy files';
            initPath = get(text_sourcePathH,'string');
            tmpSrcDirectory = uigetfulldir(initPath,displayMessage);
            if(~isempty(tmpSrcDirectory))
                %assign the settings directory variable
                obj.batch.sourceDirectory = tmpSrcDirectory;
                obj.calculateFilesFound(text_sourcePathH,text_filesFoundH);
            end
        end
        
        function getOutputDirectoryCallback(obj,hObject,eventdata,textH)
            displayMessage = 'Select the output directory to place processed results.';
            initPath = get(textH,'string');
            tmpOutputDirectory = uigetfulldir(initPath,displayMessage);
            if(~isempty(tmpOutputDirectory))
                %assign the settings directory variable
                obj.batch.outputDirectory = tmpOutputDirectory;
                set(textH,'string',tmpOutputDirectory);
            end
        end
        
        function startBatchProcessCallback(obj,hObject,eventdata)
            [filenames, fullFilenames] = getFilenamesi(obj.batch.sourceDirectory,'.csv');
            failedFiles = {};
            pctDone = 0;
            pctDelta = 1/numel(fullFilenames);
            waitH = waitbar(pctDone);
            for f=1:numel(fullFilenames)
                waitbar(pctDone,waitH,filenames{f});
                pctDone = pctDone+pctDelta;
                try
                    fprintf('Processing %s\n',filenames{f});
                    curData = PAData(fullFilenames{f});%,obj.SETTINGS.DATA
                    [~,filename,~] = fileparts(curData.getFilename());
                    if(obj.batch.classifyUsageState)
                        curData.classifyUsageState();
                        saveFilename = fullfile(obj.batch.outputDirectory,strcat(filename,'.usage.txt'));
                        curData.saveToFile('usageState',saveFilename);
                    end
                    if(obj.batch.describeActivity)
                        curData.describeActivity('activity');
                        saveFilename = fullfile(obj.batch.outputDirectory,strcat(filename,'.activity.txt'));
                        curData.saveToFile('activity',saveFilename);
                    end
                    if(obj.batch.describeInactivity)
                        curData.describeActivity('inactivity');
                        saveFilename = fullfile(obj.batch.outputDirectory,strcat(filename,'.inactivity.txt'));
                        curData.saveToFile('inactivity',saveFilename);
                    end
                    if(obj.batch.describeSleep)
                        curData.describeActivity('sleep');
                        saveFilename = fullfile(obj.batch.outputDirectory,strcat(filename,'.sleep.txt'));
                        curData.saveToFile('sleep',saveFilename);
                    end
                    
                catch me
                    showME(me);
                    failedFiles{end+1} = filenames{f};
                    fprintf('\t%s\tFAILED.\n',fullFilenames{f});
                end                
            end
            waitbar(pctDone,waitH,'Finished!');
            
            if(~isempty(failedFiles))
                fprintf('\n\n%u Files Failed:\n',numel(failedFiles));
                for f=1:numel(failedFiles)
                    fprintf('\t%s\tFAILED.\n',failedFiles{f});
                end
            end
        end
        
        function calculateFilesFound(obj,text_sourcePath_h,text_filesFound_h)
           %update the source path edit field with the source directory
           handles = guidata(text_sourcePath_h);
           set(text_sourcePath_h,'string',obj.batch.sourceDirectory);
           %get the file count and update the file count text field. 
           rawFileCount = numel(getFilenamesi(obj.batch.sourceDirectory,'.raw'));
           csvFileCount = numel(getFilenamesi(obj.batch.sourceDirectory,'.csv'));
           msg = '';
           if(rawFileCount==0 && csvFileCount==0)
               msg = '0 files found.';
               set(handles.button_go,'enable','off');
            
           else
              if(rawFileCount>0)
                  msg = sprintf('%u .raw file(s) found.\n',rawFileCount);
              end
              if(csvFileCount>0)
                  msg = sprintf('%s%u .csv file(s) found.',msg,csvFileCount);
              end
              set(handles.button_go,'enable','on');
           end
           set(text_filesFound_h,'string',msg);
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the total frame duration (i.e. hours and minutes) in aggregated minutes.
        %> @param obj Instance of PAData
        %> @retval curFrameDurationMin The current frame duration as total
        %> minutes.        
        % --------------------------------------------------------------------
        function curFrameDurationTotalMin = getFrameDurationAsMinutes(obj)
            [curFrameDurationMin, curFrameDurationHour] = obj.accelObj.getFrameDuration();
            curFrameDurationTotalMin = [curFrameDurationMin, curFrameDurationHour]*[1;60];
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the current study's duration as seconds.
        %> @param obj Instance of PAData
        %> @retval curStudyDurationSec The duration of the current study in seconds.        
        % --------------------------------------------------------------------
        function curStudyDurationSec = getStudyDurationSec(obj)
            curStudyDurationSec = obj.accelObj.durationSec;
        end

        % --------------------------------------------------------------------
        %> @brief Returns the number of frames the study can be broken into based
        %> on the frame duration set in the GUI.
        %> @param obj Instance of PAController.
        %> @note The accelObj property must be set (i.e. a file must be
        %> loaded for this function to work).        
        % --------------------------------------------------------------------
        function frameCount = getFrameCount(obj)
            frameCount = obj.accelObj.getFrameCount();
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
        %> @brief Estimates daylight intensity across the study.
        %> @param obj Instance of PAController
        %> @param numPatches (optional) Number of chunks to estimate
        %> daylight at across the study.  Default is 100.
        %> @retval daylightVector Vector of estimated daylight from the time of day at startStopDatenums.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the meanLumens
        %> value (at the same row position) was derived from.
        function [daylightVector,startStopDatenums] = getDaylight(obj,numSections)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            indices = ceil(linspace(1,numel(obj.accelObj.dateTimeNum),numSections+1));
            startStopDatenums = [obj.accelObj.dateTimeNum(indices(1:end-1)),obj.accelObj.dateTimeNum(indices(2:end))];
            [y,mo,d,H,MI,S] = datevec(mean(startStopDatenums,2));
            dayTime = [H,MI,S]*[1; 1/60; 1/3600];
%             dayTime = [[H(:,1),MI(:,1),S(:,1)]*[1;1/60;1/3600], [H(:,2),MI(:,2),S(:,2)]*[1;1/60;1/3600]];
     
            % obtain the middle spot of the daytime chunk. --> this does
            % not work because the hours flip over at 24:00.
%             dayTime = [H,MI,S]*[1;1;1/60;1/60;1/3600;1/3600]/2;
            
            
            % linear model for daylight
            %             daylightVector = (-abs(dayTime-12)+12)/12;
            
            % sinusoidal models for daylight
            T = 24;
            %             daylightVector = cos(2*pi/T*(dayTime-12));
            %             daylightVector = sin(pi/T*dayTime);  %just take half of a cycle here ...
            
            daylightVector= (cos(2*pi*(dayTime-12)/T)+1)/2;  %this is spread between 0 and 1; with 1 being brightest at noon.
            
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
            timeSeriesStruct = obj.accelObj.getStruct('all','timeSeries');
            fieldData = eval(['timeSeriesStruct.',fieldName]);
            indices = ceil(linspace(1,numel(fieldData),numSections+1));
            featureVec = zeros(numSections,1);
            startStopDatenums = zeros(numSections,2);
            for i=1:numSections
                featureVec(i) = feval(featureFcn,fieldData(indices(i):indices(i+1)));
                startStopDatenums(i,:) = [obj.accelObj.dateTimeNum(indices(i)),obj.accelObj.dateTimeNum(indices(i+1))];
            end
        end
        
        
        %% context menu's for the view
        %
        
                
        % =================================================================
        %> @brief Configure contextmenu for view's primary axes.
        %> @param obj instance of PAController.
        %> @retval contextmenu_mainaxes_h A contextmenu handle.  This should
        %> be assigned to the primary axes handle of PAView.
        % =================================================================
        function contextmenu_mainaxes_h = getPrimaryAxesContextmenuHandle(obj)
            %%% reference line contextmenu            
            contextmenu_mainaxes_h = uicontextmenu('callback',@obj.contextmenu_primaryAxes_callback);
            uimenu(contextmenu_mainaxes_h,'Label','Unhide','tag','unhide');            
        end
        
        % --------------------------------------------------------------------
        function contextmenu_primaryAxes_callback(obj,hObject, eventdata)
            %configure sub contextmenus
            unhide_h = get(hObject,'children');
            obj.configure_contextmenu_unhideSignals(unhide_h);
        end
        
       % =================================================================
       %> @brief configures a contextmenu selection to be hidden or to have
       %> attached uimenus with labels of hidden signalss displayed.  
       %> @param obj instance of PAController.
       %> @param contextmenu_h Handle of parent contextmenu to unhide
       %> channels.
       %> @param eventdata Unused.
       % =================================================================
       function configure_contextmenu_unhideSignals(obj,contextmenu_h,eventdata)           
           
           % start with a clean slate
           delete(get(contextmenu_h,'children'));
           set(contextmenu_h,'enable','off');
           lineHandles = obj.getDisplayableLineHandles();
           for h=1:numel(lineHandles)
               lineH = lineHandles(h);               
               if(strcmpi(get(lineH,'visible'),'off'))
                   tagLine = get(lineH,'tag');
                   set(contextmenu_h,'enable','on');
                   uimenu(contextmenu_h,'Label',tagLine,'separator','off','callback',{@obj.showLineHandle_callback,lineH});
               end;
           end;
           set(gco,'selected','off');
           
       end
       
       %> @brief Set's the visible property for the specified line handle
       %> and its associated reference and label handles to 'on'.
       %> @param obj Instance of PAController
       %> @param hObject Handle of the callback object.
       %> @param eventdata Unused.
       %> @param lineHandle Line handle to be shown.       
       function showLineHandle_callback(obj,hObject,eventdata,lineHandle)
           lineTag = get(lineHandle,'tag');
           tagHandles = findobj(get(lineHandle,'parent'),'tag',lineTag);
           set(tagHandles,'visible','on','hittest','on')
           obj.accelObj.setVisible(lineTag,'on');
           set(gco,'selected','off');           
       end
       
       % =================================================================
       %> @brief Configure contextmenu for signals that will be drawn in the view.
       %> @param obj instance of PAController.
       %> @param parent_fig The figure handle that the context menu handle
       %> is assigned to (i.e. the 'parent' handle).  (Optional, [] is
       %> default)
       %> @retval uicontextmenu_handle A contextmenu handle.  This should
       %> be assigned to the line handles drawn by the PAController and
       %> PAView classes.
       % =================================================================
       function uicontextmenu_handle = getLineContextmenuHandle(obj)           
           uicontextmenu_handle = uicontextmenu('callback',@obj.contextmenu_line_callback);%,get(parentAxes,'parent'));
           uimenu(uicontextmenu_handle,'Label','Resize','separator','off','callback',@obj.contextmenu_line_resize_callback);
           uimenu(uicontextmenu_handle,'Label','Use Default Scale','separator','off','callback',@obj.contextmenu_line_defaultScale_callback,'tag','defaultScale');
           uimenu(uicontextmenu_handle,'Label','Move','separator','off','callback',@obj.contextmenu_line_move_callback);
           uimenu(uicontextmenu_handle,'Label','Add Reference Line','separator','on','callback',@obj.contextmenu_line_referenceline_callback);
           uimenu(uicontextmenu_handle,'Label','Change Color','separator','off','callback',@obj.contextmenu_line_color_callback);
           uimenu(uicontextmenu_handle,'Label','Align Channel','separator','off','callback',@obj.align_channels_on_axes);
           uimenu(uicontextmenu_handle,'Label','Hide','separator','on','callback',@obj.contextmenu_line_hide_callback);
           uimenu(uicontextmenu_handle,'Label','Copy window to clipboard','separator','off','callback',@obj.contextmenu_window2clipboard_callback,'tag','copy_window2clipboard');
       end
       
       % =================================================================
       %> @brief Configure contextmenu for feature line which is drawn in the secondary axes.
       %> @param obj instance of PAController.
       %> @retval uicontextmenu_handle A contextmenu handle.  This should
       %> be assigned to the line handles drawn by the PAController and
       %> PAView classes.
       % =================================================================
       function uicontextmenu_handle = getFeatureLineContextmenuHandle(obj)           
           uicontextmenu_handle = uicontextmenu();%,get(parentAxes,'parent'));
           uimenu(uicontextmenu_handle,'Label','Copy to clipboard','separator','off','callback',@obj.contextmenu_line2clipboard_callback,'tag','copy_window2clipboard');
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
           
           lineTag = get(gco,'tag');
           set(obj.VIEW.texthandle.status,'string',lineTag);
           
           child_menu_handles = get(hObject,'children');  %this is all of the handles of the children menu options
           default_scale_handle = child_menu_handles(find(~cellfun('isempty',strfind(get(child_menu_handles,'tag'),'defaultScale')),1));
           
           allScale = obj.accelObj.getScale();
           curScale = eval(['allScale.',lineTag]);
           
           pStruct = PAData.getDefaultParameters;
           defaultScale = eval(strcat('pStruct.scale.',lineTag));
           
           
           if(curScale==defaultScale)
               set(default_scale_handle,'Label',sprintf('Default Scale (%0.2f)',defaultScale))
               set(default_scale_handle,'checked','on');
           else
               set(default_scale_handle,'Label',sprintf('Use Default Scale (%0.2f)',defaultScale))
               set(default_scale_handle,'checked','off');
           end;
           
           
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
       %> @brief A line handle's contextmenu 'move' callback.
       %> @param obj instance of PAController.
       %> @param hObject gui handle object
       %> @param eventdata unused
       % =================================================================
       function contextmenu_line_move_callback(obj,hObject,eventdata)
           y_lim = get(obj.VIEW.axeshandle.primary,'ylim');
           
           tagLine = get(gco,'tag');
           set(obj.VIEW.figurehandle,'pointer','hand',...
               'windowbuttonmotionfcn',...
               {@obj.move_line_mouseFcnCallback,tagLine,y_lim}...
               );
       end;
       
       
       % =================================================================
       %> @brief Channel contextmenu callback to move the selected
       %> channel's position in the SEV.
       %> @param obj instance of CLASS_channels_container.
       %> @param hObject Handle of callback object (unused).
       %> @param eventdata Unused.
       %> @param lineTag The tag for the current selected linehandle.
       %> @note lineTag = 'timeSeries.accelCount.x'
       %> This is used for dynamic indexing into the accelObj's datastructs.
       %> @param ylim Y-axes limits; cannot move the channel above or below
       %> these bounds.
       %> @retval obj instance of CLASS_channels_container.
       % =================================================================
       function move_line_mouseFcnCallback(obj,hObject,eventdata,lineTag,y_lim)
           %windowbuttonmotionfcn set by contextmenu_line_move_callback
           %axes_h is the axes that the current object (channel_object) is in
           pos = get(obj.VIEW.axeshandle.primary,'currentpoint');
           curOffset = max(min(pos(1,2),y_lim(2)),y_lim(1));
           obj.accelObj.setOffset(lineTag,curOffset);
           obj.VIEW.draw();
       end
       
       % =================================================================
       %> @brief Resize callback for channel object contextmenu.
       %> @param obj instance of CLASS_channels_container.
       %> @param hObject Handle of callback object (unused).
       %> @param eventdata Unused.
       %> @retval obj instance of CLASS_channels_container.
       % =================================================================
       function contextmenu_line_resize_callback(obj,hObject,eventdata)
           
           lineTag = get(gco,'tag');
           set(obj.VIEW.figurehandle,'pointer','crosshair','WindowScrollWheelFcn',...
               {@obj.resize_WindowScrollWheelFcn,...
               lineTag,obj.VIEW.texthandle.status});
           
           allScale = obj.accelObj.getScale();
           curScale = eval(['allScale.',lineTag]);
           
           %show the current scale
           click_str = sprintf('Scale: %0.2f',curScale);
           set(obj.VIEW.texthandle.status,'string',click_str);
           
           %flush the draw queue
           drawnow();
       end;
       
       % =================================================================
       %> @brief Contextmenu callback to set a line's default scale.
       %> @param obj instance of PAController
       %> @param hObject gui handle object
       %> @param eventdata unused
       % =================================================================
       function contextmenu_line_defaultScale_callback(obj,hObject,eventdata)
           
           if(strcmp(get(hObject,'checked'),'off'))
               set(hObject,'checked','on');
               lineTag = get(gco,'tag');
               
               pStruct = PAData.getDefaultParameters;
               defaultScale = eval(strcat('pStruct.scale.',lineTag));
               
               obj.accelObj.setScale(lineTag,defaultScale);
               obj.VIEW.draw();
           end;
           set(gco,'selected','off');
       end
       
       
       % =================================================================
       %> @brief Contextmenu callback to set a line's color.  MATLAB's
       %> interactive dialog is used to obtain and set the color
       %> (uisetcolor).
       %> @param obj instance of PAController
       %> @param hObject gui handle object
       %> @param eventdata unused
       % =================================================================
       function contextmenu_line_color_callback(obj, hObject, eventdata)
           lineTag = get(gco,'tag');
           c = get(gco,'color');
           c = uisetcolor(c);
           if(numel(c)~=1)
               obj.accelObj.setColor(lineTag,c);
               tagHandles = findobj(get(gco,'parent'),'tag',lineTag);
               set(tagHandles,'color',c);
           end;
           set(gco,'selected','off');
       end
       
       % =================================================================
       %> @brief Mouse wheel callback to resize the selected channel.
       %> @param obj instance of PAController.
       %> @param hObject Handle of callback object (unused).
       %> @param eventdata Mouse scroll event data.
       %> @param lineTag The tag for the current selected linehandle.
       %> @note lineTag = 'timeSeries.accelCount.x'
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
        %> @brief Copy the selected linehandle's ydata to the system
        %> clipboard.
        %> @param obj Instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenu_window2clipboard_callback(obj,hObject,eventdata)
            data =get(obj.current_linehandle,'ydata');
            clipboard('copy',data);
            disp([num2str(numel(data)),' items copied to the clipboard.  Press Control-V to access data items, or type "str=clipboard(''paste'')"']);
            set(gco,'selected','off');
            obj.current_linehandle = [];
        end
        
        % =================================================================
        %> @brief Copy the selected (feature) linehandle's ydata to the system
        %> clipboard.
        %> @param obj Instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenu_line2clipboard_callback(obj,hObject,eventdata)
            data = get(get(hObject,'parent'),'userdata');            
            clipboard('copy',data);
            disp([num2str(numel(data)),' items copied to the clipboard.  Press Control-V to access data items, or type "str=clipboard(''paste'')"']);
        end
        

       
        
    end
    
    methods(Access=private)
        % --------------------------------------------------------------------
        %> @brief Initializes the display using instantiated instance
        %> variables VIEW (PAView) and accelObj (PAData)
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------
        function initView(obj)
            
            % accelObj has already been initialized with default/saved
            % settings (i.e. obj.SETTINGS.DATA) and these are in turn
            % passed along to the VIEW class here and used to initialize 
            % many of the selected widgets.
            
            
            obj.initSignalSelectionMenu();

            obj.VIEW.initWithAccelData(obj.accelObj);
            
            
            
            %set signal choice 
            obj.setSignalSelection(obj.SETTINGS.CONTROLLER.signalTagLine);
            obj.setExtractorMethod(obj.SETTINGS.CONTROLLER.featureFcn);
         
            
            % set the display to show time series data initially.
            displayType = 'Time Series';
            displayStructName = PAData.getStructNameFromDescription(displayType);
            obj.setRadioButton(displayStructName);

            obj.setDisplayType(displayStructName);
            
            %but not everything is shown...
            
            obj.setCurWindow(obj.accelObj.getCurWindow());
            
            
            
            maxDaylight = 1;
            numFrames = obj.getFrameCount(); 
            
            
            
            maxLumens = 250;
            [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(numFrames);
            obj.VIEW.addOverlayToSecondaryAxes(meanLumens,startStopDatenums,1/4,2/4,maxLumens);
            %             [medianLumens,startStopDatenums] = obj.getMedianLumenPatches(1000);
            %             obj.VIEW.addLumensOverlayToSecondaryAxes(meanLumens,startStopDatenums);
            
            obj.updateSecondaryFeaturesDisplay();   
            
            [daylight,startStopDatenums] = obj.getDaylight(numFrames);
             obj.VIEW.addOverlayToSecondaryAxes(daylight,startStopDatenums,1/4-0.005,3/4,maxDaylight);
            
            
            obj.VIEW.showReady();
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates feature vectors and places visualizations on secondary axes.
        %> @param obj Instance of PAController
        %> @param featureType
        %> @param signalName
        %> @param numSamples        
        % --------------------------------------------------------------------
        function drawFeatureVecPatches(obj,featureType,signalName,numSamples)
            [featureVec, startStopDatenums] = obj.getFeatureVecPatches(featureType,signalName,numSamples);
            obj.VIEW.addFeaturesOverlayToSecondaryAxes(featureVec,startStopDatenums,1/2,0);
        end   
        
        % --------------------------------------------------------------------
        %> @brief Returns the display type instance variable.    
        %> @param obj Instance of PAView.
        %> @retval structName Name of the field that matches the description of the current display type used.
        %> - @c timeSeries
        %> - @c bins
        %> - @c features        
        %> @note See PAData.getStructTypes()
        % --------------------------------------------------------------------
        function structName = getDisplayType(obj)
            structName = obj.VIEW.getDisplayType();
        end       
        
        % ======================================================================
        %> @brief Returns a structure of PAControllers saveable parameters as a struct.
        %> @param obj Instance of PAView.
        %> @retval pStruct A structure of save parameters which include the following
        %> fields
        %> - @c featureFcn
        %> - @c signalTagLine
        function pStruct = getSaveParameters(obj)
            pStruct.featureFcn = obj.getExtractorMethod();
            pStruct.signalTagLine = obj.getSignalSelection();
            pStruct.batch = obj.batch;
        end
        
        % ======================================================================
        %> @brief Returns a structure of PAView's primary axes currently displayable line handles.
        %> @param obj Instance of PAView.
        %> @retval lineHandles A structure of line handles of the current display type are
        %> showable in the primary axes (i.e. they are only not seen if the
        %user has set the line handle's 'visible' property to 'off'
        function lineHandles = getDisplayableLineHandles(obj)
           lineHandleStruct = obj.VIEW.getLinehandle(obj.getDisplayType());             
           lineHandles = PAData.struct2vec(lineHandleStruct);
           
        end
        
        % =================================================================
        %> @brief Channel contextmenu callback to hide the selected
        %> channel.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenu_line_hide_callback(obj,hObject,eventdata)
            tagLine = get(gco,'tag');
            parentH = get(gco,'parent');
            obj.accelObj.setVisible(tagLine,'off');   
            
            % get the siblings handles with same tagLine (e.g. label and
            % rereference line handles.
            h = findobj(parentH,'tag',tagLine);
            set(h,'visible','off','hittest','off'); % turn the hittest off so I can access contextmenus when clicking over the unseen line.
            set(gco,'selected','off');
        end
        
    end

    methods (Static)
        
        % ======================================================================
        %> @brief Returns a structure of PAControllers default, saveable parameters as a struct.
        %> @param obj Instance of PAController.
        %> @retval pStruct A structure of parameters which include the following
        %> fields
        %> - @c featureFcn
        %> - @c signalTagLine
        function pStruct = getDefaultParameters()
            [tagLines,~] = PAData.getDefaultTagLineLabels();
            featureStruct = PAData.getFeatureDescriptionStruct();
            featureFcns = fieldnames(featureStruct);
            pStruct.featureFcn = featureFcns{1};
            pStruct.signalTagLine = tagLines{1};
            mPath = fileparts(mfilename('fullpath'));
            pStruct.batch.sourceDirectory = mPath;
            pStruct.batch.outputDirectory = mPath;
            checkFields = {'classifyUsageState';
                'describeActivity';
                'describeInactivity';
                'describeSleep';};
            for f=1:numel(checkFields)
                pStruct.batch.(checkFields{f}) = 1;
            end
            
        end
        
    end
    
    
end


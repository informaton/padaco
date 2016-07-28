%> @file PAController.cpp
%> @brief PAController serves as Padaco's controller component (i.e. in the model, view, controller paradigm).
% ======================================================================
%> @brief PAController serves as the UI component of event marking in
%> the Padaco.
%
%> In the model, view, controller paradigm, this is the
%> controller.
classdef PAController < handle
    properties(Constant)
        versionNum = 1.6;
    end
    properties(Access=private)
        %> @brief Vector for keeping track of the feature handles that are
        %> displayed on the secondary axes field.
        featureHandles;
        %> @brief The number of items to be displayed in the secondary
        %> axes.
        numViewsInSecondaryDisplay;
        %> @brief Identifies the acceleration type ('raw' or 'count' [default])
        %> displayed in the primary and secondary axes.  This is controlled
        %> by the users signal selection via GUI dropdown menu.  See
        %> updateSecondaryFeaturesDisplayCallback
        accelTypeShown;
        
        %> String identifying Padaco's current view mode.  Values include
        %> - @c timeseries
        %> - @c results
        viewMode;        
        
    end
    properties
        %> acceleration activity object - instance of PAData
        accelObj;
        %> Instance of PASettings - this is brought in to eliminate the need for several globals
        SETTINGS;
        %> Instance of PAView - Padaco's view component.
        VIEW;
        %> Instance of PAModel - Padaco's model component.  See accelObj.
        MODEL;
        
        %> Instance of PAStatTool - results controller when in results view
        %> mode.
        StatTool;
        
        %> Figure handle to the main figure window
        figureH;
        
        %> Linehandle in Padaco that is currently selected by the user.
        current_linehandle;
        
        %> cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell;
        %> string of the current selected choice
        %> handle to the figure an instance of this class is associated with
        %> struct of handles for the context menus
        contextmenuhandle;
        
        %> struct of different time resolutions, field names correspond to the units of time represented in the field
        window_resolution;
        num_windows;
        display_samples; %vector of the samples to be displayed
        shift_display_samples_delta; %number of samples to adjust display by for moving forward or back
        startDateTime;
        
        %> Struct of batch settings with fields as described by
        %PABatchTool's getDefault
        batch;
        
        %> Foldername of most recent screenshot.
        screenshotPathname;
        %> Foldername of most recent results output pathname used.
        resultsPathname;
        
        %> struct to keep track of various Padaco states
        %         STATE;  % commented out on 5/5/2016
        Padaco_loading_file_flag; %boolean set to true when initially loading a src file
        Padaco_mainaxes_ylim;
        Padaco_mainaxes_xlim;
    end
    
    
    methods
        
        function obj = PAController(Padaco_fig_h,...
                rootPathname,...
                parameters_filename)
            if(nargin<1)
                Padaco_fig_h = [];
            end
            if(nargin<2)
                rootPathname = fileparts(mfilename('fullpath'));
            end
            
            %check to see if a settings file exists
            if(nargin<3)
                parameters_filename = '_padaco.parameters.txt';
            end;
            
            obj.StatTool = [];
            
            %create/intilize the settings object
            obj.SETTINGS = PASettings(rootPathname,parameters_filename);
            obj.screenshotPathname = obj.SETTINGS.CONTROLLER.screenshotPathname;
            obj.resultsPathname = obj.SETTINGS.CONTROLLER.resultsPathname;
            
            obj.accelTypeShown = [];
            obj.figureH = Padaco_fig_h;
            if(ishandle(obj.figureH))
                obj.featureHandles = [];
                
                % Create a VIEW class
                % 1. make context menu handles for the lines
                % 2. make context menu handles for the primary axes
                uiLinecontextmenu_handle = obj.getLineContextmenuHandle();
                uiPrimaryAxescontextmenu_handle = obj.getPrimaryAxesContextmenuHandle();
                uiSecondaryAxescontextmenu_handle = obj.getSecondaryAxesContextmenuHandle();
                featureLineContextMenuHandle = obj.getFeatureLineContextmenuHandle();
                
                % initialize the view here ...?
                obj.VIEW = PAView(obj.figureH,uiLinecontextmenu_handle,uiPrimaryAxescontextmenu_handle,featureLineContextMenuHandle,uiSecondaryAxescontextmenu_handle);
                
                
                set(obj.figureH,'visible','on');
                
                obj.VIEW.showBusy([],'all');
                
                %  Apply this so that later we can retrieve useSmoothing
                %  from obj.VIEW when it comes time to save parameters.
                % obj.VIEW.setUseSmoothing(obj.SETTINGS.CONTROLLER.useSmoothing);
                obj.setSmoothingState(obj.SETTINGS.CONTROLLER.useSmoothing);
                
                obj.initTimeSeriesWidgets();
                
                set(obj.figureH,'CloseRequestFcn',{@obj.figureCloseCallback,guidata(obj.figureH)});
                
                %configure the menu bar callbacks.
                obj.initMenubarCallbacks();
                
                % attempt to load the last set of results
                lastViewMode = obj.SETTINGS.CONTROLLER.viewMode;
                try
                    obj.setViewMode(lastViewMode);
                catch me
                    showME(me);
                end
            end
        end
        
        %% Shutdown functions
        %> Destructor
        function close(obj)
            
            % Overwrite the current SETTINGS.DATA if we have an accelObj
            % instantiated.
            if(~isempty(obj.accelObj))
                obj.SETTINGS.DATA = obj.accelObj.getSaveParameters();
            end
            
            % update the stat tool settings if it was used successfully.
            if(~isempty(obj.StatTool) && obj.StatTool.getCanPlot())
                obj.SETTINGS.StatTool = obj.StatTool.getSaveParameters();
            end
            
            obj.SETTINGS.CONTROLLER = obj.getSaveParameters();
            obj.saveParameters(); %requires SETTINGS variable
            obj.SETTINGS = [];
            if(~isempty(obj.StatTool))
                obj.StatTool.delete();
            end
            
        end
        
        function saveParameters(obj)
            obj.SETTINGS.saveParametersToFile();
            fprintf(1,'Settings saved to disk.\n');
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
            
            % mouse and keyboard callbacks
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
                pause;
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
            %             handles = guidata(hObject);
            window = obj.getCurWindow();
            
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
                elseif(strcmp(eventdata.Key,'f'))
                    obj.figureScreenshot();
                    %take screen capture of main axes
                elseif(strcmp(eventdata.Key,'s'))
                    if(isa(obj.VIEW,'PAView') &&ishandle(obj.VIEW.axeshandle.secondary))
                        obj.screenshotPathname = screencap(obj.VIEW.axeshandle.secondary,[],obj.screenshotPathname);
                    end
                elseif(strcmp(eventdata.Key,'p'))
                    if(isa(obj.VIEW,'PAView') &&ishandle(obj.VIEW.axeshandle.primary))
                        obj.screenshotPathname = screencap(obj.VIEW.axeshandle.primary,[],obj.screenshotPathname);
                    end
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
            if(~isempty(selected_obj) && ~strcmpi(get(hObject,'SelectionType'),'alt'))   % Dont get confused with mouse button up due to contextmenu call
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
        %> @param Note - this turns off all other mouse movement and mouse
        %> wheel callback methods.
        % --------------------------------------------------------------------
        function windowButtonDownCallback(obj,hObject,eventData)
            if(ishandle(obj.current_linehandle))
                set(obj.VIEW.figurehandle,'windowbuttonmotionfcn',[]);
                
                obj.deactivateLineHandle();
            end
        end
        
        function deactivateLineHandle(obj)
            set(obj.current_linehandle,'selected','off');
            obj.current_linehandle = [];
            obj.VIEW.showReady();
            set(obj.VIEW.figurehandle,'windowbuttonmotionfcn',[],'WindowScrollWheelFcn',[]);
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
            % settings and about
            set(handles.menu_file_about,'callback',@obj.menuFileAboutCallback);
            set(handles.menu_file_settings,'callback',@obj.menuFileSettingsCallback);
            set(handles.menu_file_usageRules,'callback',@obj.menuFileUsageRulesCallback);
            
            %  open
            set(handles.menu_file_open,'callback',@obj.menuFileOpenCallback);
            set(handles.menu_file_openFitBit,'callback',@obj.menuFileOpenFitBitCallback);
            
            set(handles.menu_file_open_resultspath,'callback',@obj.menuFileOpenResultsPathCallback);
            
            % screeshots
            set(handles.menu_file_screenshot_figure,'callback',{@obj.menuFileScreenshotCallback,'figure'});
            set(handles.menu_file_screenshot_primaryAxes,'callback',{@obj.menuFileScreenshotCallback,'primaryAxes'});
            set(handles.menu_file_screenshot_secondaryAxes,'callback',{@obj.menuFileScreenshotCallback,'secondaryAxes'});
            
            %  quit - handled in main window.
            set(handles.menu_file_quit,'callback',{@obj.menuFileQuitCallback,guidata(figH)});
            set(handles.menu_file_restart,'callback',@restartDlg);
            
            %% Tools
            % export
            set(handles.menu_file_export,'callback',@obj.menu_file_exportMenu_callback);
            set(handles.menu_file_export_dataObj,'callback',@obj.menu_file_export_dataObj_callback);
            set(handles.menu_file_export_centroidObj,'callback',@obj.menu_file_export_centroidObj_callback);
            set(handles.menu_viewmode_batch,'callback',@obj.menuViewmodeBatchCallback);
            
            
            %% View Modes
            set(handles.menu_viewmode_timeseries,'callback',{@obj.setViewModeCallback,'timeSeries'});
            set(handles.menu_viewmode_results,'callback',{@obj.setViewModeCallback,'results'});
            
            %% Help
            set(handles.menu_help_faq,'callback',@obj.menuHelpFAQCallback);
            
            % enable everything
            set([
                handles.menu_file
                handles.menu_file_about
                handles.menu_file_settings
                handles.menu_file_open
                handles.menu_file_quit
                handles.menu_viewmode
                handles.menu_help
                handles.menu_help_faq
                ],'enable','on');
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Callback to display help FAQ from the menubar help->faq menu.
        %> @param obj Instance of PAController
        %> @param hObject
        %> @param eventdata
        % --------------------------------------------------------------------
        function menuHelpFAQCallback(this,hObject,eventdata)
            %msg = sprintf('Help FAQ');
            this.VIEW.showBusy('Initializing help');
            filename = fullfile(this.SETTINGS.rootpathname,'html','PadacoFAQ.html');
            url = sprintf('file://%s',filename);
            %             web(url,'-notoolbar','-noaddressbox');
            htmldlg('url',url);
            
            this.VIEW.showReady();
            %             web(url);
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Assign figure's file->about menubar callback.
        %> @param obj Instance of PAController
        %> @param hObject
        %> @param eventdata
        % --------------------------------------------------------------------
        function menuFileAboutCallback(obj,hObject,eventdata)
            msg = sprintf(['Padaco version %0.2f\n',...
                '\nSponsored by Stanford University\nin a collaborative effort between\nStanford Pediatric''s Solution Science Lab and\nCivil Engineering''s Sustainable Energy Lab.\n',...
                '\nSoftware license: To be decided',...
                '\nCopyright Hyatt Moore IV (2014-2016)\n'
                ],obj.versionNum);
            msgbox(msg);
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Assign figure's menubar callbacks.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        %> @param hObject
        %> @param eventdata
        %> @param optionalSettingsName String specifying the settings to
        %> update (optional)
        % --------------------------------------------------------------------
        function menuFileSettingsCallback(obj,hObject,eventdata,optionalSettingsName)
            if(nargin<4)
                optionalSettingsName = [];
            end
            wasModified = obj.SETTINGS.defaultsEditor(optionalSettingsName);
            if(wasModified)
                if(isa(obj.StatTool,'PAStatTool'))
                    obj.StatTool.setWidgetSettings(obj.SETTINGS.StatTool);
                end
                fprintf('Settings have been updated.\n');
                
                % save parameters to disk
                obj.saveParameters();
                
                % Activate a refresh()
                obj.setViewMode(obj.getViewMode());
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Assign values for usage state classifier rules.
        %> Called internally during class construction.
        %> @param obj Instance of PAController
        %> @param hObject
        %> @param eventdata
        %> @param optionalSettingsName String specifying the settings to
        %> update (optional)
        % --------------------------------------------------------------------
        function menuFileUsageRulesCallback(obj,hObject,eventdata)
            
            if(~isempty(obj.accelObj))
                usageRules= obj.accelObj.usageStateRules;
            else
                usageRules = obj.SETTINGS.DATA.usageStateRules;
            end
            defaultRules = PAData.getDefaultParameters();
            defaultRules = defaultRules.usageStateRules;
            updatedRules = simpleEdit(usageRules,defaultRules);
            
            if(~isempty(updatedRules))
                if(~isempty(obj.accelObj))
                    obj.accelObj.setUsageClassificationRules(updatedRules);
                else
                    obj.SETTINGS.DATA.usageStateRules = updatedRules;
                end
                
                %                 if(isa(obj.StatTool,'PAStatTool'))
                %                     obj.StatTool.setWidgetSettings(obj.SETTINGS.StatTool);
                %                 end
                fprintf('Settings have been updated.\n');
                
                % save parameters to disk
                obj.saveParameters();
                
                % Activate a refresh()
                obj.setViewMode(obj.getViewMode());
                
            end
        end 
        
        function initTimeSeriesWidgets(obj)
            
            prefilterSelection = PAData.getPrefilterMethods();
            set(obj.VIEW.menuhandle.prefilterMethod,'string',prefilterSelection,'value',1);
            
            % feature extractor
            extractorStruct = rmfield(PAData.getFeatureDescriptionStruct(),'usagestate');
            
            % Don't include the following because these are more
            % complicated ... and require fieldnames to correspond to
            % function names.
            
            %             psd_bandNames = PAData.getPSDBandNames();
            %             fieldsToRemove = ['usagestate';psd_bandNames];
            %             for f=1:numel(fieldsToRemove)
            %                 fieldToRemove = fieldsToRemove{f};
            %                 if(isfield(extractorStruct,fieldToRemove))
            %                     extractorStruct = rmfield(extractorStruct,fieldToRemove);
            %                 end
            %             end
            
            
            extractorMethodFcns = fieldnames(extractorStruct);
            extractorMethodDescriptions = struct2cell(extractorStruct);
            
            set(obj.VIEW.menuhandle.displayFeature,'string',extractorMethodDescriptions,'userdata',extractorMethodFcns,'value',1);
            
            %             obj.VIEW.appendFeatureMenu('PSD','getPSD');
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
            set(obj.VIEW.menuhandle.displayFeature,'callback',@obj.updateSecondaryFeaturesDisplayCallback);
            set(handles.menu_windowDurSec,'callback',@obj.menu_windowDurSecCallback);
            
            %             set(obj.VIEW.menuhandle.prefilterMethod,'callback',[]);
            %             set(obj.VIEW.menuhandle.signalSelection,'callback',[]);
            %             set(obj.VIEW.menuhandle.signalSelection,'callback',@obj.updateSecondaryFeaturesDisplayCallback);
            
            set(handles.panel_displayButtonGroup,'selectionChangeFcn',@obj.displayChangeCallback);
            
            set(handles.button_go,'callback',@obj.button_goCallback);
            
            % Configure stats panel callbacks ...
            % - this is now handed in the PAStatTool.m class
            %             set([handles.check_sortvalues;
            %                 handles.check_normalizevalues;
            %                 handles.menu_feature;
            %                 handles.menu_signalsource;
            %                 handles.menu_plottype],'callback',@refreshResultsPlot);
            
            
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
            try
                %obtain the prefilter and feature extraction methods
                prefilterMethod = obj.getPrefilterMethod();
                
                %                 set(hObject,'enable','off');
                obj.VIEW.showBusy('Calculating Features','all');
                % get the prefilter duration in minutes.
                % aggregateDurMin = obj.VIEW.getAggregateDuration();
                
                %Tell the model to prefilter and extract
                if(~strcmpi(prefilterMethod,'none'))
                    obj.accelObj.prefilter(prefilterMethod);
                    obj.VIEW.enableAggregateRadioButton();
                    
                    % No point of changing to the bin state right now as we
                    % will be selecting features anyway...
                    %                 displayType = 'bins';
                    %                 obj.setRadioButton(displayType);
                else
                    obj.VIEW.enableAggregateRadioButton('off');
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
                
                
                
                
                % This is disabled until the first time features are
                % calculated.
                obj.VIEW.enableTimeSeriesRadioButton();
                
                
                obj.VIEW.draw();
                obj.VIEW.showReady('all');
                set(hObject,'enable','on');
                
            catch me
                showME(me);
                obj.VIEW.showReady('all');
                set(hObject,'enable','on');
                
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
            axesProps.secondary.(tickField) = PAView.getTicksForLabels(labels);
            axesProps.secondary.(labelField) = labels;
            obj.VIEW.initAxesHandles(axesProps);
        end
        
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes with the current features selected in the GUI
        %> @param obj Instance of PAController
        %> @param numFeatures Optional number of features to extract (i.e. the number of chunks that the
        %> the study data will be broken into and the current feature
        %> category applied to.  Default is the current frame count.
        %> @retval heightOffset y-axis value of the top of the features
        %> displayed.  This is helpful in determining where to stack
        %> additional items on top of in the secondary axes.
        % --------------------------------------------------------------------
        function heightOffset = updateSecondaryFeaturesDisplay(obj,numFeatures)
            
            
            if(nargin<2 || isempty(numFeatures))
                numFeatures = obj.getFrameCount();
            end
            
            featureFcn = obj.getExtractorMethod();
            
            % update secondary axes y labels according to our feature
            % function.
            if(strcmpi(featureFcn,'psd'))
                ytickLabels = {sprintf('PSD (B4)\r(0.01 - 1)'),'Band 3','Band 2','Band 1','Band 1','Activity','Lumens','Daylight'};
            else
                ytickLabels = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|','Activity','Lumens','Daylight'};
            end
            obj.updateSecondaryAxesLabels('y',ytickLabels);
            
            %  signalTagLine = obj.getSignalSelection();
            %  obj.drawFeatureVecPatches(featureFcn,signalTagLine,numFrames);
            
            signalTagLines = strcat('accel.',obj.accelTypeShown,'.',{'x','y','z','vecMag'})';
            numViews = obj.numViewsInSecondaryDisplay; %(numel(signalTagLines)+1);
            height = 1/numViews;
            heightOffset = 0;
            if(any(ishandle(obj.featureHandles)))
                delete(obj.featureHandles);
            end
            obj.featureHandles = [];
            startStopDatenums = obj.getFeatureStartStopDatenums(featureFcn,signalTagLines{1},numFeatures);
            
            % Normal behavior is to show each axes for the accelerometer
            % x, y, z, vecMag (i.e. accel.count.x, accel.count.y, ...)
            % However, for the PSD, we assign PSD bands to these axes as
            % 'vecMag' - psd_band_1
            % 'x' - psd_band_2
            % 'y' - psd_band_3
            % 'z' - psd_band_4
            for s=1:numel(signalTagLines)
                signalName = signalTagLines{s};
                featureVec = obj.getFeatureVec(featureFcn,signalName,numFeatures);  %  redundant time stamp calculations benig done for start stpop dateneums in here.
                
                % x, y, z
                if(s<numel(signalTagLines))
                    vecHandles = obj.VIEW.addFeaturesVecToSecondaryAxes(featureVec,startStopDatenums,height,heightOffset);
                    obj.featureHandles = [obj.featureHandles(:);vecHandles(:)];
                    heightOffset = heightOffset+height;
                    
                    % vecMag
                else
                    % This requires twice the height because it will have a
                    % feature line and heat map
                    obj.VIEW.addFeaturesVecAndOverlayToSecondaryAxes(featureVec,startStopDatenums,height*2,heightOffset);
                    heightOffset = heightOffset+height*2;
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback from signal selection widget that triggers
        %> the update to the secondary axes with the GUI selected feature
        %> and signal.
        %> @param obj Instance of PAController
        %> @param hObject handle to the callback object.
        %> @param eventdata Not used.  Required by MATLAB.
        % --------------------------------------------------------------------
        function updateSecondaryFeaturesDisplayCallback(obj,hObject,eventdata)
            set(hObject,'enable','off');
            handles = guidata(hObject);
            initColor = get(handles.axes_secondary,'color');
            obj.VIEW.showBusy('(Updating secondary display)','secondary');
            numFrames = obj.getFrameCount();
            obj.updateSecondaryFeaturesDisplay(numFrames);
            set(handles.axes_secondary,'color',initColor);
            
            obj.VIEW.showReady('secondary');
            set(hObject,'enable','on');
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
            if(isempty(selectionIndex))
                selectionIndex = 1;
                signalTagLine = signalTagLines{selectionIndex};
                
            end
            
            set(obj.VIEW.menuhandle.signalSelection,'value',selectionIndex);
            if(isempty(obj.accelTypeShown))
                obj.accelTypeShown = 'count';
            end
            
            if(~isempty(signalTagLines))
                v=regexp(signalTagLines{selectionIndex},'.+\.([^\.]+)\..*','tokens');
                if(~isempty(v))
                    obj.accelTypeShown = v{1}{1};
                end
            end
            
            %             obj.SETTINGS.CONTROLLER.signalTagLine = signalTagLine;
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
            obj.setCurWindow(obj.getCurWindow());
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
                    % update the aggregate duration if new frame duration is
                    % smaller.
                    frameDurationTotalMinutes = obj.getFrameDurationAsMinutes();
                    if(frameDurationTotalMinutes<obj.getAggregateDurationAsMinutes())
                        obj.setAggregateDurationMinutes(frameDurationTotalMinutes);
                    end
                    
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
                    
                    % update the aggregate duration if new frame duration is
                    % smaller.
                    frameDurationTotalMinutes = obj.getFrameDurationAsMinutes();
                    if(frameDurationTotalMinutes<obj.getAggregateDurationAsMinutes())
                        obj.setAggregateDurationMinutes(frameDurationTotalMinutes);
                    end
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
        function window = getCurWindow(obj)
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
            f=uigetfullfile({'*.csv;*.raw;*.bin','All (counts, raw accelerations)';'*.csv','Comma Separated Values';'*.bin','Raw Acceleration (binary format: firmwares 2.2.1, 2.5.0, and 3.1.0)';'*.raw','Raw Acceleration (comma separated values)';'*.gt3x','Raw GT3X binary'},'Select a file','off',fullfile(obj.SETTINGS.DATA.pathname,obj.SETTINGS.DATA.filename));
            try
                if(~isempty(f))
                    %                     if(~strcmpi(obj.getViewMode(),'timeseries'))
                    %                         obj.VIEW.setViewMode('timeseries'); % bypass the this.setViewMode() for now to avoid follow-up query that a file has not been loaded yet.
                    %                     end
                    
                    
                    obj.VIEW.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.SETTINGS.DATA.pathname = pathname;
                    obj.SETTINGS.DATA.filename = strcat(basename,baseext);
                    
                    obj.accelObj = PAData(f,obj.SETTINGS.DATA);
                    
                    
                    if(~strcmpi(obj.getViewMode(),'timeseries'))
                        obj.setViewMode('timeseries');
                    end
                    
                    %initialize the PAData object's visual properties
                    obj.initAccelDataView(); %calls show obj.VIEW.showReady() Ready...
                    
                    % For testing/debugging
                    %                     featureFcn = 'mean';
                    %                     elapsedStartHour = 0;
                    %                     intervalDurationHours = 24;
                    %                     signalTagLine = obj.getSignalSelection(); %'accel.count.x';
                    %                     obj.accelObj.getAlignedFeatureVecs(featureFcn,signalTagLine,elapsedStartHour, intervalDurationHours);
                    
                    
                end
            catch me
                showME(me);
                obj.VIEW.showReady('all');
            end
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a fitbit file.
        %> @param obj Instance of PAController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenFitBitCallback(obj,hObject,eventdata)
            
            f=uigetfullfile({'*.txt;*.fbit','Fitbit';'*.csv','Comma Separated Values'},'Select a file','off',fullfile(obj.SETTINGS.DATA.pathname,obj.SETTINGS.DATA.filename));
            try
                if(~isempty(f))

                    
                    
                    obj.VIEW.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.SETTINGS.DATA.pathname = pathname;
                    obj.SETTINGS.DATA.filename = strcat(basename,baseext);
                    
                    obj.accelObj = PAData(f,obj.SETTINGS.DATA);
                    
                    
                    if(~strcmpi(obj.getViewMode(),'timeseries'))
                        obj.setViewMode('timeseries');
                    end
                    
                    %initialize the PAData object's visual properties
                    obj.initAccelDataView(); %calls show obj.VIEW.showReady() Ready...
                    
                    % For testing/debugging
                    %                     featureFcn = 'mean';
                    %                     elapsedStartHour = 0;
                    %                     intervalDurationHours = 24;
                    %                     signalTagLine = obj.getSignalSelection(); %'accel.count.x';
                    %                     obj.accelObj.getAlignedFeatureVecs(featureFcn,signalTagLine,elapsedStartHour, intervalDurationHours);
                    
                    
                end
            catch me
                showME(me);
                obj.VIEW.showReady('all');
            end
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a results path for use with
        %> the results view mode.
        %> @param obj Instance of PAController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenResultsPathCallback(obj,hObject,eventdata)
            initialPath = obj.resultsPathname;
            resultsPath = uigetfulldir(initialPath, 'Select path containing padaco results output directories');
            if(~isempty(resultsPath))
                % Say good bye to your old stat tool if you selected a
                % directory.  This ensures that if a breakdown occurs in
                % the following steps, we do not have a previous StatTool
                % hanging around showing results and the user unaware that
                % a problem occurred (i.e. no change took place).
                obj.StatTool = [];
                obj.resultsPathname = resultsPath;
                if(~strcmpi(obj.getViewMode(),'results'))
                    obj.VIEW.showBusy('Switching to results view');
                    obj.setViewMode('results');
                end
                
                obj.VIEW.showBusy('Initializing results view','all');
                if(obj.initResultsView())
                    obj.VIEW.showReady('all');
                else
                    f=warndlg('I could not find any feature files in the directory you selected.  Check the editor window for further information','Load error','modal');
                    waitfor(f);
                    obj.VIEW.showReady();
                end
            else
                % switch back to other mode?
                % No - maybe we already were in a results view
                % Yes - maybe we were not in a results view
                
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar file->screenshot callback.
        %> @param obj Instance of PAController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        %> @param screenshotDescription String label for which part of the
        %> GUI is to be captured.  Valid labels include:
        %> - @c figure
        %> - @c primaryAxes
        %> - @c secondaryAxes
        % --------------------------------------------------------------------
        function menuFileScreenshotCallback(obj,hObject,eventdata,screenshotDescription)
            
            switch(lower(screenshotDescription))
                case 'figure'
                    handle = obj.VIEW.figurehandle;
                case 'primaryaxes'
                    handle = obj.VIEW.axeshandle.primary;
                case 'secondaryaxes'
                    handle = obj.VIEW.axeshandle.secondary;
                otherwise
                    handle = [];
                    fprintf('%s is not a recognized description.  No screenshot will be taken',screenshotDescription);
            end
            if(ishandle(handle))
                if(strcmpi(screenshotDescription,'figure'))
                    obj.figureScreenshot();
                else
                    obj.screenshotPathname = screencap(handle,[],obj.screenshotPathname);
                end
            end
            
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for quitting the program.
        %> Executes when user attempts to close padaco fig.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_file_quit (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @note See startBatchProcessCallback for actual batch processing
        %> steps.
        % --------------------------------------------------------------------
        function menuFileQuitCallback(obj,hObject,eventdata,handles)
            obj.figureCloseCallback(gcbf,eventdata,handles);
        end
        
        %         % --------------------------------------------------------------------
        %         %> @brief Menubar callback for restarting the program.
        %         %> Executes when user clicks restart from the menubar's file->restart item.
        %         %> @param obj Instance of PAController
        %         %> @param hObject    handle to menu_file_quit (see GCBO)
        %         %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %         %> @note See startBatchProcessCallback for actual batch processing
        %         %> steps.
        %         % --------------------------------------------------------------------
        %         function menuFileRestartCallback(obj,hObject,eventdata)
        %             restartDlg();  % or just go straight to a restart() call
        %         end
        
        
        %> @brief Call back for export menu option under menubar 'file'
        %> option.
        function menu_file_exportMenu_callback(this,hObject, eventdata)
            handles = guidata(hObject); %this.VIEW.getFigHandle());
            if(isempty(this.accelObj))
                set(handles.menu_file_export_dataObj,'enable','off');
            else
                set(handles.menu_file_export_dataObj,'enable','on');
            end
            if(isempty(this.StatTool) || ~this.StatTool.hasCentroid())
                set(handles.menu_file_export_centroidObj,'enable','off');
            else
                set(handles.menu_file_export_centroidObj,'enable','on');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for exporting PAController's data object to the
        %> workspace.  This is useful for debugging and developing methods
        %> ad hoc.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_viewmode_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menu_file_export_dataObj_callback(obj,hObject,~)
            dataObj = obj.accelObj;
            varName = 'dataObject';
            try
                assignin('base',varName,dataObj);
                uiwait(msgbox(sprintf('Data object was assigned to workspace variable %s',varName)));
                
            catch me
                showME(me);
                uiwait(msgbox('An error occurred while trying to export data object to a workspace variable.  See console for details.'));
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for exporting PAController's data object to the
        %> workspace.  This is useful for debugging and developing methods
        %> ad hoc.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_viewmode_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menu_file_export_centroidObj_callback(obj,hObject,~)
            centroidObj = obj.StatTool.getCentroidObj();
            varName = 'centroidObj';
            try
                assignin('base',varName,centroidObj);
                uiwait(msgbox(sprintf('Centroid object was assigned to workspace variable %s',varName)));
                
            catch me
                showME(me);
                uiwait(msgbox('An error occurred while trying to export the centroid object to a workspace variable.  See console for details.'));
            end
        end
        
        
        function viewMode = getViewMode(obj)
            viewMode = obj.viewMode;
        end
        
        function setViewModeCallback(this, hObject, eventData, viewMode)
            this.setViewMode(viewMode);
        end
        
        % --------------------------------------------------------------------
        %% Settings menubar callbacks
        %> @brief Sets padaco's view mode to either time series or results viewing.
        %> @param obj Instance of PAController
        %> @param viewMode A string with one of two values
        %> - @c timeseries
        %> - @c results
        % --------------------------------------------------------------------
        function setViewMode(obj,viewMode)
            
            if(~strcmpi(viewMode,'timeseries') && ~strcmpi(viewMode,'results'))
                warndlg(sprintf('Unrecognized view mode (%s) - switching to ''timeseries''',viewMode));
                viewMode = 'timeseries';
            end
            
            obj.viewMode = viewMode;
            obj.VIEW.showBusy(['Switching to ',viewMode,' view'],'all');
            obj.VIEW.setViewMode(viewMode);
            figure(obj.figureH);  %redraw and place it on top
            refresh(obj.figureH); % redraw it
            %             shg();  %make sure it is on top.
            
            switch lower(viewMode)
                case 'timeseries'
                    if(isempty(obj.accelObj))
                        responseButton = questdlg('A time series file is not currently loaded.  Would you like to open one now?','Find a time series file to load?');
                        if(strcmpi(responseButton,'yes'))
                            obj.menuFileOpenCallback();
                        end
                    else
                        obj.initAccelDataView();
                    end
                case 'results'
                    obj.initResultsView();
            end
            
            % Show ready when everything has been initialized to avoid
            % flickering (i.e. don't place this above the switch
            % statement).
            obj.VIEW.showReady();
            
        end
        
        
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for running the batch tool.
        %> @param obj Instance of PAController
        %> @param hObject    handle to menu_viewmode_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menuViewmodeBatchCallback(obj,hObject,eventdata)
            batchTool = PABatchTool(obj.SETTINGS.BATCH);
            batchTool.addlistener('BatchToolStarting',@obj.updateBatchToolSettingsCallback);
            batchTool.addlistener('SwitchToResults',@obj.setResultsViewModeCallback);
        end
        
        % Pass through callback for setViewModeCallback method with
        % 'results' argument.
        function setResultsViewModeCallback(obj, hObject, eventData)
            obj.setViewModeCallback(hObject,eventData,'results');
        end
        
        function updateBatchToolSettingsCallback(obj,batchToolObj,eventData)
            obj.SETTINGS.BATCH = eventData.settings;
            if(isdir(obj.SETTINGS.BATCH.outputDirectory))
                obj.resultsPathname = obj.SETTINGS.BATCH.outputDirectory;
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Creates a temporary figure and axes, draws an overlay
        %> image on it using curData, saves the image to disk, and then
        %> removes the figure from view.
        %> @param obj Instance of PAController
        %> @param curData Instance of PAData
        %> @param featureFcn Extractor method for obtaining features from
        %> curData.
        %> @param img_filename Filename to save image to.
        %> @note The image format is determined from the extension of
        %> img_filename (e.g. if img_filename = 'picture.jpg', then a jpeg
        %> is used.
        % --------------------------------------------------------------------
        function save2image(obj, curData,featureFcn, img_filename)
            obj.overlayScreenshot(curData,featureFcn,img_filename);
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
        %> @brief Returns the total frame duration (i.e. hours and minutes) in aggregated minutes.
        %> @param obj Instance of PAData
        %> @retval curFrameDurationMin The current frame duration as total
        %> minutes.
        % --------------------------------------------------------------------
        function aggregateDurationTotalMin = getAggregateDurationAsMinutes(obj)
            aggregateDurationTotalMin = obj.accelObj.getAggregateDurationInMinutes();
            
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
        %> @brief Calculates the mean lux value for a given number of sections.
        %> @param obj Instance of PAController
        %> @param numSections (optional) Number of patches to break the
        %> accelObj lux time series data into and calculate the mean
        %> lumens over.
        %> @param paDataObj Optional instance of PAData.  Mean lumens will
        %> be calculated from this when included, otherwise the instance
        %> variable accelObj is used.
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
        % --------------------------------------------------------------------
        function [meanLumens,startStopDatenums] = getMeanLumenPatches(obj,numSections,paDataObj)
            if(nargin<2 || isempty(numSections))
                numSections = 100;
            end
            if(nargin<3) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            luxData = paDataObj.lux;
            indices = ceil(linspace(1,numel(luxData),numSections+1));
            meanLumens = zeros(numSections,1);
            startStopDatenums = zeros(numSections,2);
            for i=1:numSections
                meanLumens(i) = mean(luxData(indices(i):indices(i+1)));
                startStopDatenums(i,:) = [paDataObj.dateTimeNum(indices(i)),paDataObj.dateTimeNum(indices(i+1))];
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Estimates daylight intensity across the study.
        %> @param obj Instance of PAController
        %> @param numSections (optional) Number of chunks to estimate
        %> daylight at across the study.  Default is 100.
        %> @param paDataObj Optional instance of PAData.  Date time will
        %> be calculated from this when included, otherwise date time from the
        %> instance variable accelObj is used.
        %> @retval daylightVector Vector of estimated daylight from the time of day at startStopDatenums.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the meanLumens
        %> value (at the same row position) was derived from.
        % --------------------------------------------------------------------
        function [daylightVector,startStopDatenums] = getDaylight(obj,numSections,paDataObj)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            if(nargin<3) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            
            indices = ceil(linspace(1,numel(paDataObj.dateTimeNum),numSections+1));
            startStopDatenums = [paDataObj.dateTimeNum(indices(1:end-1)),paDataObj.dateTimeNum(indices(2:end))];
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
        %> @param numSections (optional) Number of patches to break the
        %> accelObj time series data into and calculate the features from.
        %> @param paDataObj Optional instance of PAData.  Date time will
        %> be calculated from this when included, otherwise date time from the
        %> instance variable accelObj is used.
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
        % --------------------------------------------------------------------
        function [featureVec,varargout] = getFeatureVec(obj,featureFcn,fieldName,numSections,paDataObj)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            
            if(nargin<5) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            
            
            featureVec = zeros(numSections,1);
            
            % Here we deal with features, which *should* already have the
            % correct number of sections needed.
            if(strcmpi(featureFcn,'psd'))
                featureStruct = paDataObj.getStruct('all','features');
                switch fieldName(end)
                    case 'g'  % accel.count.vecMag
                        featureVec = featureStruct.psd_band_1;
                    case 'x'
                        featureVec = featureStruct.psd_band_2;
                    case 'y'
                        featureVec = featureStruct.psd_band_3;
                    case 'z'
                        featureVec = featureStruct.psd_band_4;
                    otherwise
                        featureVec = featureStruct.psd_band_1;
                end
                
            else
                timeSeriesStruct = paDataObj.getStruct('all','timeSeries');
                fieldData = eval(['timeSeriesStruct.',fieldName]);
                
                indices = ceil(linspace(1,numel(fieldData),numSections+1));
                for i=1:numSections
                    featureVec(i) = feval(featureFcn,fieldData(indices(i):indices(i+1)));
                end
            end
            
            if(nargout>1)
                varargout{1} = obj.getFeatureStartStopDatenums(featureFcn,fieldName,numSections,paDataObj);
            end
        end
        
        
        % Retrieves the start stop datenum pairs for the provided feature function and fieldName.
        % Originally this function was implemented inside getFeatureFcn
        % with the thinking that it would degrade performance to call a
        % second for loop to calculate the startStopDatenums.  This was not
        % the case in practice, however, because the features would be
        % retrieved for different signals which all had the same number of
        % samples and startStopDatenums (so it was redundant to keep
        % calculating the same values.
        function startStopDatenums = getFeatureStartStopDatenums(obj,featureFcn,fieldName,numSections,paDataObj)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            
            if(nargin<5) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            
            startStopDatenums = zeros(numSections,2);
            
            if(strcmpi(featureFcn,'psd'))
                indices = ceil(linspace(1,numel(paDataObj.dateTimeNum),numSections+1));
                for i=1:numSections
                    startStopDatenums(i,:) = [paDataObj.dateTimeNum(indices(i)),paDataObj.dateTimeNum(indices(i+1))];
                end
            else
                timeSeriesStruct = paDataObj.getStruct('all','timeSeries');
                fieldData = eval(['timeSeriesStruct.',fieldName]);
                
                indices = ceil(linspace(1,numel(fieldData),numSections+1));
                for i=1:numSections
                    startStopDatenums(i,:) = [paDataObj.dateTimeNum(indices(i)),paDataObj.dateTimeNum(indices(i+1))];
                end
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
        %> @param numSections (optional) Number of patches to break the
        %> accelObj time series data into and calculate the features from.
        %> @param paDataObj Optional instance of PAData.  Date time will
        %> be calculated from this when included, otherwise date time from the
        %> instance variable accelObj is used.
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
        % --------------------------------------------------------------------
        function [usageVec, usageStates,startStopDatenums] = getUsageState(obj)
            paDataObj = obj.accelObj;
            [usageVec, usageStates, startStopDatenums] = paDataObj.classifyUsageState();
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
            
            % If we did not load a file then our signal selection will be
            % empty (don't know if were going to use count or raw data,
            % etc.  So, just stick with whatever we began with at time of construction.
            if(isempty(pStruct.signalTagLine))
                pStruct.signalTagLine = obj.SETTINGS.CONTROLLER.signalTagLine;
            end
            
            pStruct.useSmoothing = obj.VIEW.getUseSmoothing();
            pStruct.screenshotPathname = obj.screenshotPathname;
            pStruct.viewMode = obj.viewMode;
            pStruct.resultsPathname = obj.resultsPathname;
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
        
        
        
        
    end
    
    methods(Access=private)
        
        % --------------------------------------------------------------------
        %> @brief Initializes the display for accelerometer data viewing
        %> using instantiated instance
        %> variables VIEW (PAView) and accelObj (PAData)
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------
        function initAccelDataView(obj)
            
            % accelObj has already been initialized with default/saved
            % settings (i.e. obj.SETTINGS.DATA) and these are in turn
            % passed along to the VIEW class here and used to initialize
            % many of the selected widgets.
            
            obj.VIEW.showBusy('Initializing View','all');
            
            obj.initSignalSelectionMenu();
            
            if(strcmpi(obj.accelObj.accelType,'all'))
                obj.accelTypeShown = 'raw';
            else
                obj.accelTypeShown = 'count';
            end
            
            
            % Shows line labels after initWithAccelData
            obj.VIEW.initWithAccelData(obj.accelObj);
            
            
            %set signal choice
            signalSelection = obj.setSignalSelection(obj.SETTINGS.CONTROLLER.signalTagLine); %internally sets to 1st in list if not found..
            obj.setExtractorMethod(obj.SETTINGS.CONTROLLER.featureFcn);
            
            % Go ahead and extract features using current settings.  This
            % is good because then we can use
            obj.VIEW.showBusy('Calculating features','all');
            
            obj.accelObj.extractFeature(signalSelection,'all');
            
            
            % This was disabled until the first time features are
            % calculated.
            obj.VIEW.enableTimeSeriesRadioButton();
            obj.VIEW.enableFeatureRadioButton();
            
            % set the display to show time series data initially.
            displayType = 'Time Series';
            displayStructName = PAData.getStructNameFromDescription(displayType);
            obj.setRadioButton(displayStructName);
            
            % Now I am showing labels
            obj.setDisplayType(displayStructName);
            
            %but not everything is shown...
            
            obj.setCurWindow(obj.accelObj.getCurWindow());
            
            % Update the secondary axes
            % Items to display = 8;
            obj.numViewsInSecondaryDisplay = 8;
            
            % Items 1-5
            % Starting from the bottom of the axes - display the features
            % for x, y, z, vec magnitude, and 1-d values
            heightOffset = obj.updateSecondaryFeaturesDisplay();
            
            itemsToDisplay = 3; % usage state, mean lumens, daylight approx
            remainingHeight = 1-heightOffset;
            height = remainingHeight/itemsToDisplay;
            if(obj.accelObj.getSampleRate()<=1)
                [usageVec,usageState, startStopDatenums] = obj.getUsageState();
                
                vecHandles = obj.VIEW.addFeaturesVecToSecondaryAxes(usageVec,obj.accelObj.dateTimeNum,height,heightOffset);
                %obj.VIEW.addOverlayToSecondaryAxes(usageState,startStopDatenums,1/numRegions,curRegion/numRegions);
            else
                vecHandles = [];
            end
            % Next, add lumens intensity to secondary axes
            heightOffset = heightOffset+height;
            maxLumens = 250;
            numFrames = obj.getFrameCount();
            [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(numFrames);
            obj.VIEW.addOverlayToSecondaryAxes(meanLumens,startStopDatenums,height,heightOffset,maxLumens);
            %             [medianLumens,startStopDatenums] = obj.getMedianLumenPatches(1000);
            %             obj.VIEW.addLumensOverlayToSecondaryAxes(meanLumens,startStopDatenums);
            
            % Finally Add daylight to the top.
            heightOffset = heightOffset+height;
            maxDaylight = 1;
            [daylight,startStopDatenums] = obj.getDaylight(numFrames);
            obj.VIEW.addOverlayToSecondaryAxes(daylight,startStopDatenums,height-0.005,heightOffset,maxDaylight);
            
            obj.initCallbacks(); %initialize callbacks now that we have some data we can interact with.
            
            obj.VIEW.showReady('all');
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Initializes widgets for results view mode.  Widgets are
        %> disabled if the resultsPathname does not exist or cannot be
        %> found.
        %> @param this Instance of PAController
        %> @retval success A boolean value (true on successful initialization of the resultsPathname into padaco's view
        % --------------------------------------------------------------------
        function success = initResultsView(this)
            success = false;
            % this.VIEW.initWidgets('results',false);
            if(isdir(this.resultsPathname))
                if(~isempty(this.StatTool))
                    this.StatTool.init();  %calls a plot refresh
                else
                    this.StatTool = PAStatTool(this.VIEW.figurehandle,this.resultsPathname,this.SETTINGS.StatTool);
                end
                success = this.StatTool.getCanPlot();
            end
            
            if(~success)
                this.StatTool.disable();
                
                this.StatTool = [];
                responseButton = questdlg('Results output pathname is either not set or was not found.  Would you like to choose one now?','Find results output path?');
                if(strcmpi(responseButton,'yes'))
                    this.menuFileOpenResultsPathCallback();
                end
            else
                this.VIEW.showReady();
            end
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Creates a temporary overlay from paDataObject's values
        %> and takes a screenshot of it which is saved as img_filename.
        %> @param obj Instance of PAController
        %> @param paDataObject Instance of PAData
        %> @param featureFcn Extractor method for obtaining features from
        %> curData.
        %> @param img_filename Filename (full) to save the screenshot too.
        %> @note The image format is determined from img_filename's
        %> extension.
        % --------------------------------------------------------------------
        function overlayScreenshot(obj, paDataObject, featureFcn, img_filename)
            [~,~, ext] = fileparts(img_filename);
            ext = strrep(ext,'.','');  %remove leading '.' when it exists (i.e. not an empty string).
            if(strcmpi(ext,'jpg'))
                imgFmt = '-djpeg';
            else
                imgFmt = strcat('-d',lower(ext));
            end
            
            fig_h = obj.VIEW.figurehandle;
            axes_copy = copyobj(obj.VIEW.axeshandle.secondary,fig_h);
            
            f = figure('visible','off','paperpositionmode','auto','inverthardcopy','on',...
                'units',get(fig_h,'units'),'position',get(fig_h,'position'),...
                'toolbar','none','menubar','none');
            set(f,'units','normalized','renderer','zbuffer');
            set(axes_copy,'parent',f);
            
            obj.drawOverlay(paDataObject,featureFcn,axes_copy);
            obj.cropFigure2Axes(f,axes_copy);
            
            set(f,'visible','on');
            set(f,'clipping','off');
            print(f,imgFmt,'-r0',img_filename);
            delete(f);
        end
        
        %> Draw all parts of the overlay to axesH using paDataObject
        %> This is used for batch processing.
        function [featureHandles] = drawOverlay(obj,paDataObject,featureFcn,axesH)
            
            numFrames = paDataObject.getFrameCount();
            maxLumens = 250;
            
            % Modified - by adding paDataObject as secondary value.
            [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(numFrames,paDataObject);
            
            % Modified - by adding axesH as second argument
            obj.VIEW.addOverlayToAxes(meanLumens,startStopDatenums,1/7,5/7,maxLumens,axesH);
            
            maxDaylight = 1;
            % Modified get daylight somehow - perhaps to include accelObj as second argument.
            [daylight,startStopDatenums] = obj.getDaylight(numFrames,paDataObject);
            
            % Modified - by adding axesH as last argument
            obj.VIEW.addOverlayToAxes(daylight,startStopDatenums,1/7-0.005,6/7,maxDaylight,axesH);
            
            % updateSecondaryFeaturesDisplay
            signalTagLines = strcat('accel.',paDataObject.accelType,'.',{'x','y','z','vecMag'})';
            numViews = (numel(signalTagLines)+1)+2;
            height = 1/numViews;
            heightOffset = 0;
            featureHandles = [];
            for s=1:numel(signalTagLines)
                signalName = signalTagLines{s};
                % Modified to pass in the paDataObj as last parameter
                [featureVec, startStopDatenums] = obj.getFeatureVec(featureFcn,signalName,numFrames,paDataObject);
                if(s<numel(signalTagLines))
                    vecHandles = obj.VIEW.addFeaturesVecToAxes(featureVec,startStopDatenums,height,heightOffset,axesH);
                    featureHandles = [featureHandles(:);vecHandles(:)];
                else
                    % This requires twice the height because it will have a
                    % feature line and heat map
                    obj.VIEW.addFeaturesVecAndOverlayToAxes(featureVec,startStopDatenums,height*2,heightOffset,axesH);
                    
                end
                heightOffset = heightOffset+height;
            end
            
            ytickLabel = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|','Activity','Lumens','Daylight'};
            numViews = numel(ytickLabel);
            startStopDatenum = [startStopDatenums(1),startStopDatenums(end)];
            axesProps.yticklabel = ytickLabel;
            axesProps.ytick = 1/numViews/2:1/numViews:1;
            axesProps.TickDir = 'in';
            axesProps.TickDirMode = 'manual';
            axesProps.TickLength = [0.001 0];
            
            
            axesProps.xlim = startStopDatenum;
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
                axesProps.XGrid = 'on';
                axesProps.XMinorGrid = 'off';
                axesProps.XMinorTick = 'on';
                
            else
                timeDelta = datenum(0,0,1)*dateScale;
                xTick = [startStopDatenum(1):timeDelta:startStopDatenum(2), startStopDatenum(2)];
                axesProps.XMinorTick = 'off';
                axesProps.XGrid = 'off';
            end
            
            axesProps.gridlinestyle = '--';
            axesProps.YGrid = 'off';
            axesProps.YMinorGrid = 'off';
            axesProps.ylim = [0 1];
            axesProps.xlim = startStopDatenum;
            
            axesProps.XTick = xTick;
            axesProps.XTickLabel = datestr(xTick,'ddd HH:MM');
            
            
            fontReduction = min([4, floor(durationDays/4)]);
            axesProps.fontSize = 14-fontReduction;
            
            set(axesH,axesProps);
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Takes a screenshot of the padaco figure.
        %> @param obj Instance of PAController
        % --------------------------------------------------------------------
        function figureScreenshot(obj)
            
            filterspec = {'png','PNG';'jpeg','JPEG'};
            save_format = {'-dpng','-djpeg'};
            if(isa(obj.accelObj,'PAData'))
                img_filename = [obj.accelObj.filename,'_window ',num2str(obj.getCurWindow),'.png'];
            else
                img_filename = ['padaco_window ',num2str(obj.getCurWindow),'.png'];
            end
            [img_filename, img_pathname, filterindex] = uiputfile(filterspec,'Screenshot name',fullfile(obj.screenshotPathname,img_filename));
            if isequal(img_filename,0) || isequal(img_pathname,0)
                disp('User pressed cancel');
            else
                try
                    if(filterindex>2)
                        filterindex = 1; %default to .png
                    end
                    fig_h = obj.VIEW.figurehandle;
                    axes_copy = copyobj(obj.VIEW.axeshandle.secondary,fig_h);
                    
                    f = figure('visible','off','paperpositionmode','auto','inverthardcopy','on',...
                        'units',get(fig_h,'units'),'position',get(fig_h,'position'),...
                        'toolbar','none','menubar','none');
                    set(f,'units','normalized');
                    set(axes_copy,'parent',f);
                    
                    cropFigure2Axes(f,axes_copy);
                    
                    set(f,'visible','on');
                    set(f,'clipping','off');
                    
                    print(f,save_format{filterindex},'-r0',fullfile(img_pathname,img_filename));
                    
                    %save the screenshot
                    %         print(f,['-d',filterspec{filterindex,1}],'-r75',fullfile(img_pathname,img_filename));
                    %         print(f,fullfile(img_pathname,img_filename),['-d',filterspec{filterindex,1}]);
                    %         print(f,['-d',filterspec{filterindex,1}],fullfile(img_pathname,img_filename));
                    %         set(handles.axes1,'position',apos,'dataaspectratiomode','manual' ,'dataaspectratio',dataaspectratio,'parent',handles.sev_main_fig)
                    delete(f);
                    obj.screenshotPathname = img_pathname;
                catch ME
                    showME(ME);
                    %         set(handles.axes1,'parent',handles.sev_main_fig);
                end
            end
        end
        
        
        %% context menu callbacks for channels
        
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
        
        %% context menus for the view
        
        % =================================================================
        %> @brief Configure contextmenu for view's primary axes.
        %> @param obj instance of PAController.
        %> @retval contextmenu_mainaxes_h A contextmenu handle.  This should
        %> be assigned to the primary axes handle of PAView.
        % =================================================================
        function contextmenu_mainaxes_h = getPrimaryAxesContextmenuHandle(obj)
            %%% reference line contextmenu
            contextmenu_mainaxes_h = uicontextmenu('parent',obj.figureH);
            hideH =uimenu(contextmenu_mainaxes_h,'Label','Hide','tag','hide');
            unhideH = uimenu(contextmenu_mainaxes_h,'Label','Unhide','tag','unhide');
            set(contextmenu_mainaxes_h,'callback',{@obj.contextmenu_primaryAxes_callback,hideH,unhideH});
            
        end
        
        % --------------------------------------------------------------------
        function contextmenu_primaryAxes_callback(obj,hObject, eventdata, hide_uimenu_h, unhide_uimenu_h)
            %configure sub contextmenus
            obj.configure_contextmenu_unhideSignals(unhide_uimenu_h);
            obj.configure_contextmenu_hideSignals(hide_uimenu_h);
        end
        
        % =================================================================
        %> @brief Configure contextmenu for view's secondary axes.
        %> @param obj instance of PAController.
        %> @retval contextmenu_mainaxes_h A contextmenu handle.  This should
        %> be assigned to the primary axes handle of PAView.
        % =================================================================
        function contextmenu_secondaryAxes_h = getSecondaryAxesContextmenuHandle(obj)
            %%% reference line contextmenu
            contextmenu_secondaryAxes_h = uicontextmenu('parent',obj.figureH);
            menu_h = uimenu(contextmenu_secondaryAxes_h,'Label','Line Smoothing','tag','smoothing');
            on_menu_h =uimenu(menu_h,'Label','On','tag','smoothing_on','callback',{@obj.contextmenu_featureSmoothing_callback,true});
            off_menu_h = uimenu(menu_h,'Label','Off','tag','smoothing_off','callback',{@obj.contextmenu_featureSmoothing_callback,false});
            set(menu_h,'callback',{@obj.configure_contextmenu_smoothing_callback,on_menu_h,off_menu_h});
        end
        
        % =================================================================
        %> @brief Configure Line Smoothing sub contextmenus for view's secondary axes.
        %> @param obj instance of PAController.
        %> @param hObject Handle to the Line Smoothing context menu
        %> @param eventdata Not used
        %> @param on_uimenu_h Handle to Smoothing on menu option
        %> @param off_uimenu_h Handle to smoothing off menu option
        %> @retval contextmenu_mainaxes_h A contextmenu handle.  This should
        %> be assigned to the primary axes handle of PAView.
        
        % =================================================================
        % --------------------------------------------------------------------
        function configure_contextmenu_smoothing_callback(obj,hObject, eventdata, on_uimenu_h, off_uimenu_h)
            %configure sub contextmenus
            if(obj.VIEW.getUseSmoothing())
                set(on_uimenu_h,'checked','on');
                set(off_uimenu_h,'checked','off');
            else
                set(on_uimenu_h,'checked','off');
                set(off_uimenu_h,'checked','on');                
            end 
        end
        
        % =================================================================
        %> @brief Contextmenu selection callback for turning line smoothing 'on' or 'off'
        %> in the secondary axes when looking at time series data.
        %> @param obj instance of PAController.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        %> @param useSmoothingState Boolean flag for smoothing state
        %> - @c true  : Turn smoothing on (default)
        %> - @c false : Turn smoothing off
        % =================================================================
        function contextmenu_featureSmoothing_callback(obj,contextmenu_h,eventdata,useSmoothing)
            % --------------------------------------------------------------------
            if(nargin<4)
                useSmoothing = true;
            end
            obj.setSmoothingState(useSmoothing == true);
        end
        
        function setSmoothingState(obj,smoothingState)
            if(nargin>1 && ~isempty(smoothingState))  
                obj.VIEW.setUseSmoothing(smoothingState); 
                if(obj.isViewable('timeseries'))
                    obj.VIEW.showBusy('Setting smoothing state','secondary');
                    obj.updateSecondaryFeaturesDisplay();
                    obj.VIEW.showReady('secondary');
                end
            end
        end
        
        
        %> @brief Check if I the viewing mode passed in is current, and if it is
        %> displayable (i.e. has an accel or stat tool object)
        %> @param obj Instance of PAController
        %> @param viewingMode View mode to check.  Valid strings include:
        %> - @c timeseries
        %> - @c results
        %> @retval viewable True/False
        function viewable = isViewable(obj, viewingMode)
            if(strcmpi(obj.getViewMode(),viewingMode))
                if(strcmpi(viewingMode,'timeseries') && ~isempty(obj.accelObj))
                    viewable = true;
                elseif(strcmpi(viewingMode,'results') && ~isempty(obj.statTool))
                    viewable = true;
                else
                    viewable = false;
                end
            else
                viewable = false;
            end
        end
        
        % =================================================================
        %> @brief configures a contextmenu selection to be hidden or to have
        %> attached uimenus with labels of unhidden signals displayed for selection. (if seleceted, the signal is then hidden)
        %> @param obj instance of PAController.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        % =================================================================
        function configure_contextmenu_hideSignals(obj,contextmenu_h,eventdata)
            % --------------------------------------------------------------------
            % start with a clean slate
            delete(get(contextmenu_h,'children'));
            set(contextmenu_h,'enable','off');
            lineHandles = obj.getDisplayableLineHandles();
            hasVisibleSignals = false;
            for h=1:numel(lineHandles)
                lineH = lineHandles(h);
                if(~strcmpi(get(lineH,'visible'),'off'))
                    tagLine = get(lineH,'tag');
                    set(contextmenu_h,'enable','on');
                    uimenu(contextmenu_h,'Label',tagLine,'separator','off','callback',{@obj.hideLineHandle_callback,lineH});
                    hasVisibleSignals = true;
                end;
            end;
            set(gco,'selected','off');
            if(~hasVisibleSignals)
                set(contextmenu_h,'visible','off');
            else
                set(contextmenu_h,'visible','on');
            end
            
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
            % --------------------------------------------------------------------
            % start with a clean slate
            delete(get(contextmenu_h,'children'));
            set(contextmenu_h,'enable','off');
            lineHandles = obj.getDisplayableLineHandles();
            hasHiddenSignals = false;
            for h=1:numel(lineHandles)
                lineH = lineHandles(h);
                if(strcmpi(get(lineH,'visible'),'off'))
                    tagLine = get(lineH,'tag');
                    set(contextmenu_h,'enable','on');
                    uimenu(contextmenu_h,'Label',tagLine,'separator','off','callback',{@obj.showLineHandle_callback,lineH});
                    hasHiddenSignals = true;
                end;
            end;
            set(gco,'selected','off');
            if(~hasHiddenSignals)
                set(contextmenu_h,'visible','off');
            else
                set(contextmenu_h,'visible','on');
            end
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Set's the visible property for the specified line handle
        %> and its associated reference and label handles to 'on'.
        %> @param obj Instance of PAController
        %> @param hObject Handle of the callback object.
        %> @param eventdata Unused.
        %> @param lineHandle Line handle to be shown.
        % --------------------------------------------------------------------
        function showLineHandle_callback(obj,hObject,eventdata,lineHandle)
            % --------------------------------------------------------------------
            lineTag = get(lineHandle,'tag');
            tagHandles = findobj(get(lineHandle,'parent'),'tag',lineTag);
            set(tagHandles,'visible','on','hittest','on')
            obj.accelObj.setVisible(lineTag,'on');
            set(gco,'selected','off');
        end
        
        % --------------------------------------------------------------------
        %> @brief Set's the visible property for the specified line handle
        %> and its associated reference and label handles to 'off'.
        %> @param obj Instance of PAController
        %> @param hObject Handle of the callback object.
        %> @param eventdata Unused.
        %> @param lineHandle Line handle to be shown.
        % --------------------------------------------------------------------
        function hideLineHandle_callback(obj,hObject,eventdata,lineHandle)
            % --------------------------------------------------------------------
            lineTag = get(lineHandle,'tag');
            tagHandles = findobj(get(lineHandle,'parent'),'tag',lineTag);
            set(tagHandles,'visible','off','hittest','off')
            obj.accelObj.setVisible(lineTag,'off');
            set(gco,'selected','off');
        end
        
        % =================================================================
        %> @brief Configure contextmenu for signals that will be drawn in the view.
        %> @param obj instance of PAController.
        %> @retval uicontextmenu_handle A contextmenu handle.  This should
        %> be assigned to the line handles drawn by the PAController and
        %> PAView classes.
        % =================================================================
        function uicontextmenu_handle = getLineContextmenuHandle(obj)
            % --------------------------------------------------------------------
            uicontextmenu_handle = uicontextmenu('callback',@obj.contextmenu_line_callback,'parent',obj.figureH);%,get(parentAxes,'parent'));
            uimenu(uicontextmenu_handle,'Label','Resize','separator','off','callback',@obj.contextmenu_line_resize_callback);
            uimenu(uicontextmenu_handle,'Label','Use Default Scale','separator','off','callback',@obj.contextmenu_line_defaultScale_callback,'tag','defaultScale');
            uimenu(uicontextmenu_handle,'Label','Move','separator','off','callback',@obj.contextmenu_line_move_callback);
            uimenu(uicontextmenu_handle,'Label','Change Color','separator','off','callback',@obj.contextmenu_line_color_callback);
            %            uimenu(uicontextmenu_handle,'Label','Add Reference Line','separator','on','callback',@obj.contextmenu_line_referenceline_callback);
            %            uimenu(uicontextmenu_handle,'Label','Align Channel','separator','off','callback',@obj.align_channels_on_axes);
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
            uicontextmenu_handle = uicontextmenu('parent',obj.figureH);%,get(parentAxes,'parent'));
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
        %> @param y_lim Y-axes limits; cannot move the channel above or below
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
        

        
    end
    
    methods (Static)
                % =================================================================
        %> @brief Copy the selected (feature) linehandle's ydata to the system
        %> clipboard.
        %> @param obj Instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenu_line2clipboard_callback(hObject,eventdata)
            data = get(get(hObject,'parent'),'userdata');
            clipboard('copy',data);
            disp([num2str(numel(data)),' items copied to the clipboard.  Press Control-V to access data items, or type "str=clipboard(''paste'')"']);
        end
        
        
        
        function cropFigure2Axes(fig_h,axes_h)
            %places axes_h in middle of figure with handle fig_h
            %useful for prepping screen captures
            
            % Hyatt Moore IV
            % 1/16/2013
            
            fig_units_in = get(fig_h,'units');
            axes_units_in = get(axes_h,'units');
            
            set(fig_h,'units','pixels');
            set(axes_h,'units','pixels');
            
            
            a_pos = get(axes_h,'position'); %x, y, width, height
            f_pos = get(fig_h,'position');
            
            a_width = a_pos(3);
            a_height = a_pos(4);
            
            set(axes_h,'position',[a_width*0.06,a_height*0.1,a_width,a_height]);
            set(fig_h,'position',[f_pos(1),f_pos(2),a_width*1.1,a_height*1.2]);
            
            %reset units to original
            set(fig_h,'units',fig_units_in);
            set(axes_h,'units',axes_units_in);
            
        end
        
        % ======================================================================
        %> @brief Returns a structure of PAControllers default, saveable parameters as a struct.
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
            pStruct.screenshotPathname = mPath;
            pStruct.viewMode = 'timeseries';
            pStruct.useSmoothing = true;
            batchSettings = PABatchTool.getDefaultParameters();
            pStruct.resultsPathname = batchSettings.outputDirectory;
        end
    end
    
    
end


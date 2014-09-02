%> @file PAView.cpp
%> @brief PAView serves as Padaco's view component (i.e. in the model, view, controller paradigm).
% ======================================================================
%> @brief PAView serves as Padaco's view component.
%> In the model, view, controller paradigm, this is the view.
classdef PAView < handle
    
    properties (Access = private)
        
        %> @brief String representing the current type of display being used.
        %> Can be
        %> @li @c Time Series
        %> @li @c Aggregate Bins
        %> @li @c Features
        displayType; 
        
        
    end
    properties
        %> for the patch handles when editing and dragging
        hg_group; 

        %>linehandle in Padaco currently selected;
        current_linehandle;
        
        %>cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell; 
        %>string of the current selected choice
        marking_state; 
        %> figure handle that the class instance is associated with
        figurehandle;
        
        %> @brief struct whose fields are axes handles.  Fields include:
        %> - @b primary handle to the main axes an instance of this class is associated with
        %> - @b secondary Window view of events (over view)
        axeshandle;

        %> @brief struct whose fields are structs with names of the axes and whose fields are property values for those axes.  Fields include:
        %> - @b primary handle to the main axes an instance of this class is associated with
        %> - @b secondary Window view of events (over view)
        axesproperty;
        
        %> @brief struct of text handles.  Fields are: 
        %> - @c status handle to the text status location of the Padaco figure where updates can go
        %> - @c src_filename handle to the text box for display of loaded filename
        %> - @c edit_window  handle to the editable window handle        
        texthandle; 
        
        %> @brief struct of menu handles.  Fields are: 
        %> - @c menu_windowDurSec The window display duration in seconds
        %> - @c menu_prefilter The selection of prefilter methods
        %> - @c menu_extractor The selection of feature extraction methods
        menuhandle;
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
        %> visual reference of where the window is comparison to the entire
        %> study.
        positionBarHandle;
        
        %> struct of handles for the context menus
        contextmenuhandle; 
         
        %> PAData instance
        dataObj;
        window_resolution;%struct of different time resolutions, field names correspond to the units of time represented in the field        
        %> The window currently in view.
        current_window;
        
    end
    

    methods
        
        % --------------------------------------------------------------------
        %> PAView class constructor.
        %> @param Padaco_fig_h Figure handle to assign PAView instance to.
        %> @retval obj Instance of PAView
        % --------------------------------------------------------------------
        function obj = PAView(Padaco_fig_h)
            if(ishandle(Padaco_fig_h))
                obj.figurehandle = Padaco_fig_h;
                obj.createView();                
            else
                obj = [];
            end
        end 
        
                
        % --------------------------------------------------------------------
        %> @brief Creates line handles and maps figure tags to PAView instance variables.
        %> @param obj Instance of PAView.
        % --------------------------------------------------------------------
        function createView(obj)
            handles = guidata(obj.getFigHandle());
            
            set(handles.panel_left,'backgroundcolor',[0.75,0.75,0.75]);
            set(handles.panel_study,'backgroundcolor',[0.95,0.95,0.95]);
            
            whiteHandles = [handles.text_aggregate
                handles.text_frameSizeMinutes
                handles.text_frameSizeHours
                handles.panel_features_prefilter
                handles.panel_features_aggregate
                handles.panel_features_frame
                handles.panel_features_extractor];
            set(whiteHandles,'backgroundcolor',[0.95,0.95,0.95]);
            
            obj.texthandle.status = handles.text_status;
            obj.texthandle.filename = handles.text_filename;
            obj.texthandle.studyinfo = handles.text_studyinfo;
            obj.texthandle.curWindow = handles.edit_curWindow;
            obj.texthandle.aggregateDuration = handles.edit_aggregate;
            obj.texthandle.frameDurationMinutes = handles.edit_frameSizeMinutes;
            obj.texthandle.frameDurationHours = handles.edit_frameSizeHours;
            
            obj.menuhandle.extractorMethod = handles.menu_extractor;
            obj.menuhandle.prefilterMethod = handles.menu_prefilter;
            obj.menuhandle.displayFeature = handles.menu_displayFeature;
            
            obj.axeshandle.primary = handles.axes_primary;
            obj.axeshandle.secondary = handles.axes_secondary;

            
            % Clear the figure and such.  
            obj.clearAxesHandles();
            obj.clearTextHandles(); 
            obj.clearWidgets();

            %creates and initializes line handles (obj.linehandle fields)
            % However, all lines are invisible.
            obj.createLineAndLabelHandles();
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets current window edit box string value
        %> @param obj Instance of PAView.
        %> @param windowStr A string to display in the current window edit
        %> box.
        %> @param xpos The position on the x-axis of where the window is.
        %> This will be a datenum for padaco.
        % --------------------------------------------------------------------
        function setCurWindow(obj,windowStr,xpos)
           set(obj.texthandle.curWindow,'string',windowStr); 
           set(obj.positionBarHandle,'xdata',repmat(xpos,1,2));
           obj.draw();
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets aggregate duration edit box string value
        %> @param obj Instance of PAView.
        %> @param aggregateDurationStr A string representing the aggregate duration as minutes.
        % --------------------------------------------------------------------
        function setAggregateDuration(obj,aggregateDurationStr)
           set(obj.texthandle.aggregateDuration,'string',aggregateDurationStr);            
        end
        % --------------------------------------------------------------------
        %> @brief Retrieves the aggregate duration edit box value as a
        %> number.
        %> @param obj Instance of PAView.
        %> @retval aggregateDurMin The aggregate duration (in minutes) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function aggregateDurMin = getAggregateDuration(obj)
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
        %> @brief Sets display type instance variable.    
        %> @param obj Instance of PAView.
        %> @param displayTypeStr A string representing the display type.  Can be 
        %> @li @c Time Series
        %> @li @c Aggregate Bins
        %> @li @c Features
        % --------------------------------------------------------------------
        function setDisplayType(obj,displayTypeStr)
            if(any(strcmpi({'Time Series','Aggregate Bins','Features'},displayTypeStr)))
                structName = PAData.getStructNameFromDescription(obj.displayType);
                allProps.visible = 'off';
                if(~isempty(structName))
                    obj.recurseHandleInit(obj.labelhandle.(structName), allProps);
                    obj.recurseHandleInit(obj.referencelinehandle.(structName), allProps);
                    obj.recurseHandleInit(obj.linehandle.(structName), allProps);
                end
                
                obj.displayType = displayTypeStr;
                
                if(strcmpi(displayTypeStr,'Features'))
                    set(obj.menuhandle.displayFeature,'enable','on');
                else
                    set(obj.menuhandle.displayFeature,'enable','off');
                end
                
                structName = PAData.getStructNameFromDescription(obj.displayType);
                allProps.visible = 'on';
                obj.recurseHandleInit(obj.labelhandle.(structName), allProps)
                obj.recurseHandleInit(obj.referencelinehandle.(structName), allProps)
                obj.recurseHandleInit(obj.linehandle.(structName), allProps)
                
            else
                fprintf('Warning, this string (%s) is not an acceptable option.\n',displayTypeStr);
            end
        end        
        
        % --------------------------------------------------------------------
        %> @brief Returns the display type instance variable.    
        %> @param obj Instance of PAView.
        %> @retva; displayTypeStr A string representing the display type.
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
        % --------------------------------------------------------------------
        function clearAxesHandles(obj)
            
            cla(obj.axeshandle.primary);
            cla(obj.axeshandle.secondary);
            
            axesProps.units = 'normalized'; %normalized allows it to resize automatically
            axesProps.drawmode = 'normal'; %fast does not allow alpha blending...
            axesProps.xgrid='on';
            axesProps.ygrid='off';
            axesProps.xminortick='on';
            axesProps.xlimmode='manual';
            axesProps.xtickmode='manual';
            axesProps.xticklabelmode='manual';
            axesProps.xtick=[];
            axesProps.ytickmode='manual';
            axesProps.ytick=[];
            axesProps.nextplot='replacechildren';
            axesProps.box= 'on';
            axesProps.plotboxaspectratiomode='auto';
            
            %initialize axes
            set(obj.axeshandle.primary,axesProps);
            
            axesProps.xgrid = 'off';
            axesProps.xminortick = 'off';
            
            set(obj.axeshandle.secondary,axesProps);             
        end
        
        % --------------------------------------------------------------------
        %> @brief Disable user interface widgets and clear contents.
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function clearWidgets(obj)            
            handles = guidata(obj.getFigHandle());            
            
            obj.initWidgets();
            buttonGroupChildren = get(handles.panel_displayButtonGroup,'children');
            
            widgetList = [handles.edit_curWindow
                handles.menu_windowDurSec
                handles.menu_prefilter
                handles.edit_aggregate
                handles.edit_frameSizeMinutes
                handles.edit_frameSizeHours
                handles.text_aggregate
                handles.text_frameSizeMinutes
                handles.text_frameSizeHours
                handles.menu_extractor
                handles.button_go
                buttonGroupChildren];  
            set(widgetList,'enable','off'); 
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Initializes the graphic handles (label and line handles) and maps figure tag names
        %> to PAView instance variables.  Initializes the menubar and various widgets.  Also set the acceleration data instance variable and assigns
        %> line handle y values to those found with corresponding field
        %> names in PADataObject.        
        %> @note Resets the currentWindow to 1.
        %> @param obj Instance of PAView
        %> @param PADataObject (Optional) PAData display struct that matches the linehandle struct of
        %> obj and whose values will be assigned to the 'ydata','xdata', and 'color' fields of the
        %> line handles.  A label property struct will be created
        %> using the string values of labelStruct and the initial x, y value of the line
        %> props to initialize the 'string' and 'position' properties of 
        %> obj's corresponding label handles.          
        % --------------------------------------------------------------------
        function obj = initWithAccelData(obj, PADataObject)
            
            obj.dataObj = PADataObject;

            axesProps.primary.xlim = PADataObject.getCurWindowRange();
            axesProps.primary.ylim = PADataObject.getDisplayMinMax();
            
            obj.initAxesHandles(axesProps);
            
            
            %resize the secondary axes according to the new window
            %resolution
            obj.updateSecondaryAxes(PADataObject.getStartStopDatenum());
            
                        
            %initialize the various line handles and label content and
            %color.
            structType = PAData.getStructTypes();
            fnames = fieldnames(structType);
            for f=1:numel(fnames)
                curName = fnames{f};
                curDescription = structType.(curName);
                
                labelProps = obj.dataObj.getLabel(curDescription);
                labelPosStruct = obj.getLabelhandlePosition(curDescription);
                labelProps = PAData.mergeStruct(labelProps,labelPosStruct);
                
                %                 visibleProp.visible = 'off';
                %                 labelProps = PAData.appendStruct(labelProps,visibleProp);
                
                lineProps = PADataObject.getStruct('dummydisplay',curDescription);
                obj.recurseHandleSetter(obj.linehandle.(curName),lineProps);
                obj.recurseHandleSetter(obj.referencelinehandle.(curName),lineProps);
                
                obj.setStructWithStruct(obj.linehandle.(curName),PADataObject.getColor(curDescription));
                obj.setStructWithStruct(obj.referencelinehandle.(curName),PADataObject.getColor(curDescription));
                
                %                 obj.setLinehandleColor(obj.linehandle.(curName),PADataObject.getColor());
                %                 obj.setLinehandleColor(obj.referencelinehandle.(curName),PADataObject.getColor());
                %
                obj.recurseHandleSetter(obj.labelhandle.(curName),labelProps);                
            end
            
            obj.setFilename(obj.dataObj.getFilename());  
            
            obj.setStudyPanelContents(PADataObject.getHeaderAsString);
            
            obj.setAggregateDuration(num2str(PADataObject.aggregateDurMin));
            [frameDurationMinutes, frameDurationHours] = PADataObject.getFrameDuration();
            obj.setFrameDurationMinutes(num2str(frameDurationMinutes));
            obj.setFrameDurationHours(num2str(frameDurationHours));
            
            obj.initMenubar();
            obj.initWidgets();
            
            set(obj.positionBarHandle,'visible','on','ydata',[0 1]); 
            
            obj.restore_state();
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
        %> @brief Configures the figure's menubar
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function initMenubar(obj)

            %turn on the appropriate menu items still for initial use
            %before any files are loaded
            handles = guidata(obj.getFigHandle());
            
            set(handles.menu_file,'enable','on');
            set(handles.menu_file_open,'enable','on');
            set(handles.menu_file_quit,'enable','on');
            
            set(handles.menu_settings,'enable','on');
            
            obj.restore_state();
        end

        % --------------------------------------------------------------------
        %> @brief Initialize user interface widgets on start up.
        %> @param obj Instance of PAView        
        % --------------------------------------------------------------------
        function initWidgets(obj)
            handles = guidata(obj.getFigHandle());
            %buttonGroupChildren = get(handles.panel_displayButtonGroup,'children');
            % do not enable all radio button group children on init.  Only
            % if features and aggregate bins are available would we do
            % this.  However, we do not know if that is the case here.
            
            widgetList = [handles.menu_windowDurSec
                handles.edit_curWindow
                handles.menu_windowDurSec
                handles.menu_prefilter
                handles.edit_aggregate
                handles.edit_frameSizeMinutes
                handles.edit_frameSizeHours
                handles.text_aggregate
                handles.text_frameSizeMinutes
                handles.text_frameSizeHours
                handles.menu_extractor
                handles.button_go
                handles.radio_time;
                ];                
            
            set(handles.edit_aggregate,'string','');
            set(handles.edit_frameSizeHours,'string','');
            set(handles.edit_frameSizeMinutes,'string','');
            set(handles.edit_curWindow,'string','');
            
            prefilterSelection = PAData.getPrefilterMethods();
            set(handles.menu_prefilter,'string',prefilterSelection,'value',1);
            
            % feature extractor
            extractorMethods = PAData.getExtractorMethods();
            set(handles.menu_extractor,'string',extractorMethods,'value',1);
            
            % Window display resolution
            windowMinSelection = {30,'30 s';
                60,'1 min';
                120,'2 min';
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
                86400,'24 hours'};
            
            set(handles.menu_windowDurSec,'userdata',cell2mat(windowMinSelection(:,1)), 'string',windowMinSelection(:,2),'value',1);

            %             obj.displayType = 'Time Series';
            %             set(obj.menuhandle.displayFeature,'enable','off');
            
            set(widgetList,'enable','on','visible','on');
        end        
        
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes x and y axes limits.
        %> @param obj Instance of PAView
        %> @param startStopDatenum A 1x2 vector of the starting and stoping
        %> date numbers.
        %> @param windowCount The total number of windows that can be displayed in the
        %> primary axes.  This will be xlim(2) for the secondary axes (i.e.
        %> timeline/overview axes) in the event that startStopDatenum is
        %> not used.
        % --------------------------------------------------------------------
        function updateSecondaryAxes(obj,startStopDatenum)
            
            axesProps.secondary.xlim = startStopDatenum;
            [y,m,d,h,mi,s] = datevec(diff(startStopDatenum));
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
                dateScale = 1/2; %show every 12 hurs
            else
                dateScale = 1; %show every 24 hours.
                
            end    
            
            timeDelta = datenum(0,0,1)*dateScale; 
            xTick = [startStopDatenum(1):timeDelta:startStopDatenum(2), startStopDatenum(2)];
            
            axesProps.secondary.ylim = [0 1];
            axesProps.secondary.xlim = startStopDatenum;
            axesProps.secondary.XTick = xTick;
            axesProps.secondary.XTickLabel = datestr(xTick,'ddd HH:MM');
           
            obj.initAxesHandles(axesProps);
%             datetick(obj.axeshandle.secondary,'x','ddd HH:MM')
        end
        
        % --------------------------------------------------------------------
        %> @brief Create the line handles and text handles that describe the lines,
        %> that will be displayed by the view.
        %> This is based on the structure template generated by member
        %> function getStruct('dummydisplay').
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function createLineAndLabelHandles(obj)
            handleProps.Parent = obj.axeshandle.primary;

            handleProps.visible = 'off';
            
            structType = PAData.getStructTypes();
            fnames = fieldnames(structType);
            for f=1:numel(fnames)
                curName = fnames{f};
                curDescription = structType.(curName);
                dataStruct = PAData.getDummyStruct(curDescription);
            
                handleType = 'line';
                obj.linehandle.(curName) = obj.recurseHandleGenerator(dataStruct,handleType,handleProps);
            
                obj.referencelinehandle.(curName) = obj.recurseHandleGenerator(dataStruct,handleType,handleProps);
            
                handleType = 'text';
                obj.labelhandle.(curName) = obj.recurseHandleGenerator(dataStruct,handleType,handleProps);
            end
            
            %secondary axes
            obj.positionBarHandle = line('parent',obj.axeshandle.secondary,'visible','off');%annotation(obj.figurehandle.sev,'line',[1, 1], [pos(2) pos(2)+pos(4)],'hittest','off');
        end

        
        % --------------------------------------------------------------------
        %> @brief Enables the aggregate radio button.  
        %> @note Requires aggregate data exists in the associated
        %> PAData object instance variable 
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function enableAggregateRadioButton(obj)
            handles = guidata(obj.getFigHandle());
            set(handles.radio_bins,'enable','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Enables the Feature radio button.  
        %> @note Requires feature data exist in the associated
        %> PAData object instance variable 
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function enableFeatureRadioButton(obj)
            handles = guidata(obj.getFigHandle());
            set(handles.radio_features,'enable','on');
            set(handles.radio_features,'enable','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Appends the new feature to the drop down feature menu.
        %> @param obj Instance of PAView
        %> @param newFeature String label to append to the drop down feature menu.
        % --------------------------------------------------------------------
        function appendFeatureMenu(obj,newFeature)
            
            handles = guidata(obj.getFigHandle());
            featureOptions = get(handles.menu_displayFeature,'string');
            if(~iscell(featureOptions))
                featureOptions = {featureOptions};
            end
            if(isempty(intersect(featureOptions,newFeature)))
                featureOptions{end+1} = newFeature;
                set(handles.menu_displayFeature,'string',featureOptions);
            end;
        end        
        
        % --------------------------------------------------------------------
        %> @brief Displays the string argument in the view.
        %> @param obj PADataObject Instance of PAData
        %> @param sourceFilename String that will be displayed in the view as the source filename when provided.
        % --------------------------------------------------------------------
        function setFilename(obj,sourceFilename)
            set(obj.texthandle.filename,'string',sourceFilename,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Displays the contents of cellString in the study panel
        %> @param obj PADataObject Instance of PAData
        %> @param cellString Cell of string that will be displayed in the study panel.  Each 
        %> cell element is given its own display line.
        % --------------------------------------------------------------------
        function setStudyPanelContents(obj,cellString)
            set(obj.texthandle.studyinfo,'string',cellString,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Draws the view
        %> @param obj PADataObject Instance of PAData
        % --------------------------------------------------------------------
        function draw(obj)
            % Axes range must occur at the top as it is used to determine
            % the position of text labels.
            axesRange   = obj.dataObj.getCurUncorrectedWindowRange(obj.displayType);
            
            %make it increasing
            if(diff(axesRange)==0)
                axesRange(2) = axesRange(2)+1;
            end
            set(obj.axeshandle.primary,'xlim',axesRange);
            
            structFieldName = PAData.getStructNameFromDescription(obj.displayType);
            lineProps   = obj.dataObj.getStruct('currentdisplay',obj.displayType);
            obj.recurseHandleSetter(obj.linehandle.(structFieldName),lineProps);
                        
            offsetProps = obj.dataObj.getStruct('displayoffset',obj.displayType);
            offsetStyle.LineStyle = '--';
            offsetStyle.color = [0.6 0.6 0.6];
            offsetProps = PAData.appendStruct(offsetProps,offsetStyle);
           
            obj.recurseHandleSetter(obj.referencelinehandle.(structFieldName),offsetProps);
                        
            % update label text positions based on the axes position.
            % So the axes range must be set above this!
            % link the x position with the axis x-position ...
            labelProps = obj.dataObj.getLabel(obj.displayType);
            labelPosStruct = obj.getLabelhandlePosition();            
            labelProps = PAData.mergeStruct(labelProps,labelPosStruct);             
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
            dummyStruct = obj.dataObj.getStruct('dummy',displayTypeStr);
            offsetStruct = obj.dataObj.getStruct('displayoffset',displayTypeStr);
            labelPosStruct = PAData.structEval('calculateposition',dummyStruct,offsetStruct);
            xOffset = 1/120*diff(get(obj.axeshandle.primary,'xlim'));            
            offset = [xOffset, 15, 0];
            labelPosStruct = PAData.structScalarEval('plus',labelPosStruct,offset);            
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
        %> @retval linehandle View's line handles as a struct.
        % --------------------------------------------------------------------
        function lineHandle = getLinehandle(obj)
            lineHandle = obj.linehandle;
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Shows busy status (mouse becomes a watch).
        %> @param obj Instance of PAView  
        %> @param status_label Optional string which, if included, is displayed
        %> in the figure's status text field (currently at the top right of
        %> the view).
        % --------------------------------------------------------------------
        function showBusy(obj,status_label)
            set(obj.getFigHandle(),'pointer','watch');
            if(nargin>1)
                set(obj.texthandle.status,'string',status_label);
            end
            drawnow();
        end  
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param obj Instance of PAView        
        % --------------------------------------------------------------------
        function showReady(obj)
            set(obj.getFigHandle(),'pointer','arrow');
            set(obj.texthandle.status,'string','');
            drawnow();
        end
        
     
        % --------------------------------------------------------------------
        %> @brief Restores the view to ready state (mouse becomes the default pointer).
        %> @param obj Instance of PAView        
        % --------------------------------------------------------------------
        function obj = restore_state(obj)
            obj.clear_handles();
            
            set(obj.getFigHandle(),'pointer','arrow');
            obj.marking_state = 'off';
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

                if(isstruct(dummyStruct.(fname)))
                    destStruct.(fname) = [];
                    
                    %recurse down
                    destStruct.(fname) = PAView.recurseHandleGenerator(dummyStruct.(fname),handleType,handleProperties,destStruct.(fname));
                else
                    if(strcmpi(handleType,'line'))
                        destStruct.(fname) = line();
                    elseif(strcmpi(handleType,'text'))
                        destStruct.(fname) = text();
                    else
                        destStruct.(fname) = [];
                        fprintf('Warning!  Handle type %s unknown!',handleType);
                    end
                    if(nargin>1 && ~isempty(handleProperties))
                        set(destStruct.(fname),handleProperties);
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
            for f=1:numel(fnames)
                fname = fnames{f};
                curField = handleStruct.(fname);
                try
                if(isstruct(curField))
                    PAView.recurseHandleSetter(curField,propertyStruct.(fname));
                else
                    if(ishandle(curField))                        
                       set(curField,propertyStruct.(fname));
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
                        set(curHandleField,curPropertyField);
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
    end
end


% % --------------------------------------------------------------------
% %> @brief Initialize the line handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of line properties corresponding to the
% %> fields of the linehandle instance variable.
% %> If empty ([]) then default PAData.getDummyDisplayStruct is used.
% % --------------------------------------------------------------------
% function initLineHandles(obj,lineProps)
% 
% if(nargin<2 || isempty(lineProps))
%     lineProps = PAData.getDummyDisplayStruct();
% end
% 
% obj.recurseHandleSetter(obj.linehandle, lineProps);
% obj.recurseHandleSetter(obj.referencelinehandle, lineProps);
% 
% 
% end
% 
% % --------------------------------------------------------------------
% %> @brief Initialize the label handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of label properties corresponding to the
% %> fields of the labelhandle instance variable.
% % --------------------------------------------------------------------
% function initLabelHandles(obj,labelProps)
% obj.recurseHandleSetter(obj.labelhandle, labelProps);
% end



% % --------------------------------------------------------------------
% %> @brief Restores the view to ready state (mouse becomes the default pointer).
% %> @param obj Instance of PAView
% % --------------------------------------------------------------------
% function popout_axes(~, ~, axes_h)
% % hObject    handle to context_menu_pop_out (see GCBO)
% % eventdata  reserved - to be defined in a future version of MATLAB
% % handles    structure with handles and user data (see GUIDATA)
% fig = figure;
% copyobj(axes_h,fig); %or get parent of hObject's parent
% end

%> @file PAView.m
%> @brief PAView serves as Padaco's controller component (i.e. in the model, view, controller paradigm).
% ======================================================================
%> @brief PAView serves as the UI component of event marking in
%> the Padaco.  
%
%> In the model, view, controller paradigm, this is the
%> controller. 

classdef PAView < handle
    
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
        %> - @b.primary handle to the main axes an instance of this class is associated with
        %> - @b.secondary Epoch view of events (over view)
        axeshandle;

        %> @brief struct whose fields are structs with names of the axes and whose fields are property values for those axes.  Fields include:
        %> - @b.primary handle to the main axes an instance of this class is associated with
        %> - @b.secondary Epoch view of events (over view)
        axesproperty;
        
        %> @brief struct of text handles.  Fields are: 
        %> - .status; %handle to the text status location of the Padaco figure where updates can go
        %> - .src_filename; %handle to the text box for display of loaded filename
        %> - .edit_epoch;  %handle to the editable epoch handle        
        texthandle; 
        
        %> @brief Struct of line handles (graphic handle class) for showing
        %> activity data.
        linehandle;
        
        %> struct of handles for the context menus
        contextmenuhandle; 
         
        %> PAData instance
        dataObj;
        epoch_resolution;%struct of different time resolutions, field names correspond to the units of time represented in the field        
        %> The epoch currently in view.
        current_epoch;
        display_samples; %vector of the samples to be displayed
        shift_display_samples_delta; %number of samples to adjust display by for moving forward or back
        startDateTime;
    end
    

    methods
        
        % --------------------------------------------------------------------
        %> PAView class constructor.
        %> @param Figure handle to assign PAView instance to.
        %> @retval Instance of PAView
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
        %> @param Instance of PAView.
        % --------------------------------------------------------------------
        function createView(obj)
            handles = guidata(obj.getFigHandle());

            obj.texthandle.status = handles.text_status;
            obj.texthandle.filename = handles.text_filename;
            obj.texthandle.curEpoch = handles.edit_curEpoch;
            
            obj.axeshandle.primary = handles.axes_primary;
            obj.axeshandle.secondary = handles.axes_secondary;

            % Clear the figure and such.
            obj.clearAxesHandles();
            obj.clearTextHandles(); 
            obj.clearWidgets();
            
            %creates and initializes line handles (obj.linehandle fields)
            % However, all lines are invisible.
            obj.createLineHandles();
        end     
        
        % --------------------------------------------------------------------
        %> @brief Sets current epoch edit box string value
        %> @param Instance of PAView.
        %> @param A string.
        % --------------------------------------------------------------------
        function setCurEpoch(obj,epochStr)
           set(obj.texthandle.curEpoch,'string',epochStr); 
           obj.draw();
        end
        
        % --------------------------------------------------------------------
        % --------------------------------------------------------------------
        %
        %   Initializations
        %
        % --------------------------------------------------------------------
        % --------------------------------------------------------------------
        
       
        % --------------------------------------------------------------------
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
        %> resets the currentEpoch to 1.
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
            set(handles.edit_curEpoch,'enable','off','string','','visible','off'); 
        end        
        
        % --------------------------------------------------------------------
        %> @brief Set the acceleration data instance variable and assigns
        %> line handle y values to those found with corresponding field
        %> names in PADataObject.
        %> resets the currentEpoch to 1.
        %> @param obj Instance of PAView
        %> @param PADataObject Instance of PAData
        % --------------------------------------------------------------------
        function obj = initWithAccelData(obj, PADataObject)
            obj.dataObj = PADataObject;          
            axesProps.xlim = obj.dataObj.getCurEpochRangeAsSamples();
            axesProps.ylim = obj.dataObj.getDisplayMinMax();
            obj.initView(axesProps,obj.dataObj.getCurrentDisplayStruct());
            
            obj.setLinehandleColor(PADataObject.getColor());
            obj.setFilename(obj.dataObj.getFilename());
        end        
        
        % --------------------------------------------------------------------
        %> @brief Initializes the graphic handles and maps figure tag names
        %> to PAView instance variables.
        %> @param obj Instance of PAView
        %> @param obj (Optional) PAData struct that matches the linehandle struct of
        %> obj and whose values will be assigned to the 'ydata' fields of the
        %> corresponding line handles.  
        % --------------------------------------------------------------------
        function initView(obj,axesProps,dataStruct)
            lineProps = [];
            if(nargin>1 && ~isempty(axesProps))
                obj.initAxesHandles(axesProps);
            end
            
            if(nargin<3)
                dataStruct = [];
            end
            
            %Default line properties are used in initLineHandles if lineProps is empty
            % (i.e. if axesProps is not provided or is empty)            
            lineProps.visible = 'on';
            lineProps.xdata = axesProps.xlim;
            lineProps.ydata = [1 1];
            
            obj.initLineHandles(lineProps, dataStruct);
            
            obj.initMenubar();
            obj.initWidgets();
            
            obj.restore_state();
        end       
        
        % --------------------------------------------------------------------
        %> @brief Initialize data specific properties of the axes handles.
        %> Set the x and y limits of the axes based on limits found in
        %> dataStruct struct.
        %> @param obj Instance of PAView
        %> @param Structure of axes properties.
        %> @note Currently only sets the primary axes handle
        % --------------------------------------------------------------------
        function initAxesHandles(obj,axesProps)
            % See @note Currently only sets the primary axes handle
            set(obj.axeshandle.primary,axesProps);            
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
            set(handles.edit_curEpoch,'enable','on','visible','on','string','0');             
        end
        
        % --------------------------------------------------------------------
        %> @brief Create the line handles that will be used in the view.
        %> This is based on the structure template generated by member
        %> function getDummyStruct().
        %> @param obj Instance of PAView
        % --------------------------------------------------------------------
        function createLineHandles(obj)
            lineProps.Parent = obj.axeshandle.primary;

            lineProps.visible = 'off';
            dataStruct = PAData.getDummyStruct();
            
            obj.linehandle = obj.recurseLineGenerator(dataStruct,lineProps);
            
            %add grid lines
%             if(~isfield(obj.linehandle,'x_minorgrid')||isempty(obj.linehandle.x_minorgrid)||~ishandle(obj.linehandle.x_minorgrid))
%                 obj.linehandle.x_minorgrid = line('xdata',[],'ydata',[],'parent',obj.axeshandle.primary,'color',[0.8 0.8 0.8],'linewidth',0.5,'linestyle',':','hittest','off','visible','on');
%             end            
        end
        
        % --------------------------------------------------------------------
        %> @brief Initialize the line handles that will be used in the view.
        %> resets the currentEpoch to 1.
        %> @param obj Instance of PAView
        %> @param Structure of line properties to be applied to all line
        %> handles.  If empty ([]) then defaultvalues are used.
        %> @param obj (Optional) PAData struct that matches the linehandle struct of
        %> obj and whose values will be assigned to the 'ydata' fields of the
        %> corresponding line handles.  Otherwise the values found in ydata and xdata fields of lineProps are used.
        % --------------------------------------------------------------------
        function initLineHandles(obj,lineProps,lineData)
            if(isempty(lineProps))
                lineProps.visible = 'on';
                lineProps.xdata = [0 1];
                lineProps.ydata = [0 0];
            end
            
            obj.recurseHandleInit(obj.linehandle,lineProps);
            
            if(nargin>2 && ~isempty(lineData))                
                obj.recurseLineSetter(obj.linehandle, lineData);
            end
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Displays the string argument in the view.
        %> @param PADataObject Instance of PAData
        %> @param String that will be displayed in the view as the source filename when provided.
        % --------------------------------------------------------------------
        function setFilename(obj,sourceFilename)
            set(obj.texthandle.filename,'string',sourceFilename,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Draws the view
        %> @param PADataObject Instance of PAData
        % --------------------------------------------------------------------
        function draw(obj)
            epochRange = obj.dataObj.getCurEpochRangeAsSamples();
            curData = obj.dataObj.getCurrentDisplayStruct();
            set(obj.axeshandle.primary,'xlim',epochRange);       
            lineProps.xdata = epochRange(1):epochRange(end);
            obj.recurseLineSetter(obj.linehandle,curData,lineProps);
        end

        % --------------------------------------------------------------------
        %> @brief Sets the color of the line handles.
        %> @param PADataObject Instance of PAData
        %> @param Struct with field organization corresponding to that of
        %> instance variable linehandle.  The values are the colors to set
        %> the matching line handle to.
        % --------------------------------------------------------------------
        function setLinehandleColor(obj,colorStruct)
            obj.setStructWithStruct(obj.linehandle,colorStruct);
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
        %> @retval View's line handles as a struct.
        % --------------------------------------------------------------------
        function lineHandle = getLinehandle(obj)
            lineHandle = obj.linehandle;
        end
        
        
        function showBusy(obj,status_label)
            set(obj.getFigHandle(),'pointer','watch');
            if(nargin>1)
                set(obj.texthandle.status,'string',status_label);
            end
            drawnow();
        end  
        
        function showReady(obj)
            set(obj.getFigHandle(),'pointer','arrow');
            set(obj.texthandle.status,'string','');
            drawnow();
        end
        
     
        %VIEW parts of the class....
        
        function obj = restore_state(obj)
            obj.clear_handles();
            
            set(obj.getFigHandle(),'pointer','arrow');
            obj.marking_state = 'off';
        end
        
        function obj = clear_handles(obj)
            obj.showReady();
        end

        function Padaco_main_fig_WindowButtonUpFcn(obj,hObject,eventdata)            
            obj.Padaco_button_up();
        end
        
        function Padaco_main_fig_WindowButtonDownFcn(obj,hObject,eventdata)
            obj.Padaco_button_down();            
        end
        
        function Padaco_button_up(obj)                        
            selected_obj = get(obj.getFigHandle(),'CurrentObject');
            
            if ~isempty(selected_obj)
                if(selected_obj==obj.axeshandle.timeline)                    
                    if(obj.getSecondsPerEpoch()>0)
                        pos = round(get(obj.axeshandle.timeline,'currentpoint'));
                        clicked_epoch = pos(1);
                        obj.setEpoch(clicked_epoch);
                    end;
                end;
            end;
        end
        
        function obj = Padaco_button_down(obj)
            if(strcmpi(obj.marking_state,'off')) %don't want to reset the state if we are marking events
                if(~isempty(obj.current_linehandle))
                    obj.restore_state();
                end;
            else
                if(ishghandle(obj.hg_group))
                    if(~any(gco==allchild(obj.hg_group))) %did not click on a member of the object being drawn...
                        obj.clear_handles();
                    end;
                end;
            end;
            if(~isempty(obj.current_linehandle)&&ishandle(obj.current_linehandle) && strcmpi(get(obj.current_linehandle,'selected'),'on'))
                set(obj.current_linehandle,'selected','off');
            end
        end

                
        function setLinehandle(obj, line_h)
            obj.clear_handles();
            obj.current_linehandle = line_h;
            set(obj.current_linehandle,'selected','on');
        end
        

        function status = isActive(obj)
            status = ~strcmpi(obj.marking_state,'off');
        end

        
    end
    methods(Static)
        
        %==================================================================
        %> @brief Recursively fills in the template structure dummyStruct
        %> with matlab lines and returns as a new struct.  If dummyStruct
        %> has numeric values in its deepest nodes, then these values are
        %> assigned as the y-values of the corresponding line handle, and the
        %> x-value is a vector from 1 to the number of elements in y.
        %> @param obj Instance of PAView
        %> @param dummyStruct Structure with arbitrarily deep number fields.
        %> @param Struct of line handle properties to initialize line handles with.  
        %> @retval destStruct The filled in struct, with the same field
        %> layout as dummyStruct but with line handles filled in at the
        %> deepest nodes.
        %> @note If destStruct is included, then lineproperties must also be included, even if only as an empty place holder.
        %> For example as <br>
        %> destStruct = PAView.recurseLineGenerator(dummyStruct,[],destStruct)
        %> @param destStruct The initial struct to grow to (optional and can be different than the output node).
        %> For example<br> desStruct = PAView.recurseLineGenerator(dummyStruct,proplines,diffStruct)
        %> <br>Or<br> recurseLineGenerator(dummyStruct,[],diffStruct)
        %==================================================================
        function destStruct = recurseLineGenerator(dummyStruct,lineproperties,destStruct)
            if(nargin < 3 || isempty(destStruct))
                destStruct = struct();
                if(nargin<2)
                    lineproperties = [];
                end
            
            end
            
            fnames = fieldnames(dummyStruct);
            for f=1:numel(fnames)
                fname = fnames{f};

                if(isstruct(dummyStruct.(fname)))
                    destStruct.(fname) = [];
                    
                    %recurse down
                    destStruct.(fname) = PAView.recurseLineGenerator(dummyStruct.(fname),lineproperties,destStruct.(fname));
                else
                    destStruct.(fname) = line();
                    if(nargin>1 && ~isempty(lineproperties))
                        set(destStruct.(fname),lineproperties);
                    end                    
                end
            end
        end

        %==================================================================
        %> @brief Recursively maps values from dataObj to the x/y fields of 
        %> linehandle struct child handles.
        %> @param handleStruct The struct of line handles to set the x/y
        %> values and graphic properties of.
        %> @param dataStruct Structure whose fields contain structures or
        %> numeric vectors that will be placed as the y-values of line
        %> handles at the same location in the handleStruct struct.
        %> @param Optional structure of property/value pairings to set the graphic
        %> handles found in handleStruct to.
        %==================================================================
        function recurseLineSetter(handleStruct, dataStruct,lineproperties)
            if(nargin<3)
                lineproperties = [];
            end
            fnames = fieldnames(dataStruct);
            for f=1:numel(fnames)
                fname = fnames{f};
                curField = handleStruct.(fname);
                try
                if(isstruct(curField))
                    PAView.recurseLineSetter(curField,dataStruct.(fname),lineproperties);
                else
                    if(ishandle(curField))
                        y = dataStruct.(fname)(:);
                        
                        % give the option to include xdata and adjust where
                        % things are shown.
                        if(~isfield(lineproperties,'xdata'))
                            lineproperties.xdata = [1:numel(y)]';
                        end
                        lineproperties.ydata = y;
                        set(curField,lineproperties);
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
        %> @param Structure of property structs (i.e. property/value pairings) to set the graphic
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
        %> @param Structure of property/value pairings to set the graphic
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
        
        
        % --------------------------------------------------------------------
        function popout_axes(~, ~, axes_h)
            % hObject    handle to context_menu_pop_out (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            fig = figure;
            copyobj(axes_h,fig); %or get parent of hObject's parent
        end
        

    end
end


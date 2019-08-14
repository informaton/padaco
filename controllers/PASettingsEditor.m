%> Copyright Hyatt Moore IV
%> Created 8/8/2019
classdef PASettingsEditor < PAFigureFcnController
    
    properties(Access=protected)
       figureFcn = @settingsDlg; 
    end
    methods
        %> @brief Class constructor.
        function this = PASettingsEditor(varargin)
            if(nargin<1)
                varargin = {PAAppSettings()};
            end
            this@PAFigureFcnController(varargin{:});
            waitfor(this.figureH);
        end
        
        function setSettings(this, varargin)
            if(isa(varargin{1},'PASettings'))
                varargin{1} = varargin{1}.duplicate();
            end
            
            setSettings@PAFigureController(this, varargin{:});
        end
    end
    
    methods(Access=protected)
        
        function didInit = initFigure(this)
            didInit = false;
            if(ishandle(this.figureH))
                try
                    set([this.handles.push_apply
                        this.handles.push_cancel
                        this.handles.push_defaults],'callback',@this.buttonCb);
                    set(this.figureH,'visible','on');
                    
                    if(isa(this.settings,'PASettings'))
                        tabs = this.settings.fieldNames;
                        labelProps.style = 'text';
                        labelProps.fontsize = 14;
                        
                        [color, ~, map] = imread('file_open.png','backgroundcolor','none');
                        fileOpenCDATA = double(color)/(2^16-1);
                        map=repmat(map==0,1,1,3);
                        fileOpenCDATA(map) = nan;
                        
                        labelProps.units = 'normalized';
                        labelProps.horizontalAlignment = 'left';
                        labelProps.fontweight = 'normal';
                        
                        valueProps = labelProps;
                        valueProps.horizontalAlignment = 'center';
                        
                        pathBtnProps = labelProps;
                        pathBtnProps.cdata = fileOpenCDATA;
                        pathBtnProps.style = 'pushbutton';
                        pathBtnProps.callback = @this.pathBtnCb;
                        
                        for t = 1:numel(tabs)
                            settingName = tabs{t};
                            
                            setting = this.settings.(settingName);
                            if(isstruct(setting))
                                
                                keys = fieldnames(setting);
                                numKeys = numel(keys);
                                
                                if(numKeys==0 || strcmpi(settingName,'SensorData'))
                                    break;
                                end
                                
                                parent = uitab(this.handles.tabgroup,...
                                    'title',settingName,'tag',sprintf('tag_%d',t));
                                
                                % if we have too many keys to fit, then
                                % need to place everything in a scrollable
                                % panel.  
                                yDelta = 0.08;
                                % lowestY = 0.875 - yDelta*(numKeys-1)-yDelta;
                                
                                numIndexParams = sum(structfun(@(s)isa(s,'PAIndexParam'),setting));
                                numVisibleKeys = numKeys - numIndexParams;
                                
                                lowestY = 0.875 - yDelta*(numVisibleKeys-0.5);
                                heightScale = [1 1 1 1];
                                scrollScale = [1 1 1 1];
                                newH = 1;
                                if( lowestY< 0) 
                                    %parent.Scrollable = 'on';
                                    newH = 1+abs(lowestY);
                                    heightScale = [1 1 1 1/newH];
                                    scrollScale = [1 1/newH 1 1];
                                    %parent.Scrollable = 'off';
                                    hPanel = uipanel(parent,'bordertype','none','units','normalized',...
                                        'position',[0 lowestY 0.98 newH]);
                                    % hPanel.BorderType = 'etchedin';
                                  
                                    maxPos = -lowestY;
                                    minPos = 0; 
                                    uicontrol('style','slider',...
                                        'callback',{@this.scrollPanelCb,hPanel},...
                                        'units','normalized','position',[0.98 0 0.02 1],...
                                        'parent',parent,...
                                        'max',maxPos,'min',minPos,'value',maxPos);
                                    parent = hPanel;
                                end
                                
                                labelProps.parent = parent;
                                valueProps.parent = parent;
                                valueProps.Callback = @this.valueWidgetCb;
                                pathBtnProps.parent = parent;
                                labelProps.String = '';
                                yStart = 1-0.125/newH;
                                labelProps.position = [0.05 yStart 0.475 0.075].*heightScale;
                                
                                yStart = 1-0.1/newH;
                                valueProps.position = [0.5 yStart 0.45 0.05].*heightScale;
                                enumProps.position  = [0.6 yStart 0.35 0.05].*heightScale;
                                pathProps.position  = [0.4 yStart 0.4975 0.05].*heightScale;
                                boolProps.position  = [0.7 yStart 0.25 0.05].*heightScale;
                                numericProps.position=[0.7 yStart 0.25 0.05].*heightScale;
                                pathBtnProps.position=[0.895 yStart 0.05 0.05].*heightScale;

                                % indexProps.position = [0.8 0.9 0.15 0.05];
                                for k =1:numKeys
                                    try
                                        param = setting.(keys{k});
                                        labelProps.String = param.description;
                                        valueProps.String = num2str(param.value);
                                        valueProps.userdata = param;
                                        valueProps.tooltip = param.getHelp();
                                        nextValuePropsPosition = valueProps.position+[0 -yDelta 0 0].*scrollScale;
                                        nextLabelPosition = labelProps.position+[0 -yDelta 0 0].*scrollScale;
                                        
                                        switch(class(param))
                                            case 'PAPathParam' %PAFilenameParam, PANumericParam, PAStringParam
                                                uicontrol(labelProps);
                                                labelProps.position  = nextLabelPosition;
                                                
                                                pathProps.position(2) = valueProps.position(2);
                                                valueProps.position = pathProps.position;
                                                valueProps.String = param.value;
                                                valueProps.style = 'edit';
                                                valueProps.enable = 'inactive';
                                                % valueProps.horizontalAlignment = 'right';
                                                v =uicontrol(valueProps);
                                                %valueProps.horizontalAlignment = 'center';
                                                valueProps.enable = 'on';

                                                pathBtnProps.position(2) = valueProps.position(2);
                                                pathBtnProps.userdata = v;
                                                uicontrol(pathBtnProps);
                                                
                                                % This needs to come at the
                                                % end, just before the
                                                % continue.
                                                valueProps.position = nextValuePropsPosition;

                                                continue;
                                            case 'PABoolParam'
                                                boolProps.position(2) = valueProps.position(2);
                                                valueProps.position = boolProps.position;
                                                valueProps.style = 'popupmenu';
                                                valueProps.String = {'No','Yes'};
                                                valueProps.value = param.value+1;
                                            case 'PAEnumParam'
                                                enumProps.position(2) = valueProps.position(2);
                                                valueProps.position = enumProps.position;
                                                valueProps.style = 'popupmenu';
                                                valueProps.String = param.categories;
                                                valueProps.value = find(strcmpi(param.categories,param.value));
                                            case 'PAIndexParam'
                                                continue;
                                                %   indexProps.position(2) = valueProps.position(2);
                                                %   valueProps.position = indexProps.position;
                                                %
                                                %   valueProps.style = 'popupmenu';
                                                %   valueProps.String = num2str((1:10)');
                                                %   valueProps.value = param.value;
                                                %
                                            case 'PANumericParam'
                                                numericProps.position(2) = valueProps.position(2);
                                                valueProps.position = numericProps.position;
                                                
                                                valueProps.style = 'edit';
                                                valueProps.String = num2str(param.value);
                                                
                                            otherwise % PAPathParam, PAFilenameParam, PANumericParam, PAStringParam
                                                valueProps.String = num2str(param.value);
                                                valueProps.style = 'edit';
                                        end
                                        uicontrol(labelProps);
                                        uicontrol(valueProps);
                                        labelProps.position = nextLabelPosition;
                                        valueProps.position = nextValuePropsPosition;
                                    catch me
                                       showME(me); 
                                    end
                                end
                            end
                        end
                    end
                    didInit = true;
                catch me
                    showME(me);
                end
            end
        end
        
        function valueWidgetCb(this, hObject, evtData)
            
            param = get(hObject,'userdata');
            value = get(hObject,'value');
            str  = get(hObject,'string');
            switch(class(param))
                case 'PABoolParam'
                    param.setValue(strcmpi(getMenuString(hObject),'yes'));                     
                case 'PAEnumParam'
                    param.setValue(param.categories{value});  
                case 'PAIndexParam'
                    param.setValue(value);
                case 'PANumericParam' 
                    num = str2double(str);
                    if(~param.setValue(num))
                        % getMenuString(hObject);  --> should also work,
                        % but below is more robust if we start using
                        % different descriptions in the menu for the
                        % corresponding category values.
                        set(hObject,'string', num2str(param.value));
                    end
                otherwise % PAPathParam, PAFilenameParam, PAStringParam
                    param.setValue(str);
            end
        end
        function scrollPanelCb(this, hObject, eventData, panelH)
            %arrayfun(@(a)set(a,'Position',get(a,'Position')),allchild(panelH));
            %arrayfun(@(a)set(a,'Position',get(a,'Position')+[0 -hObject.Value 0 0]),allchild(panelH));
            panelH.Position(2) = -hObject.Value;
        end
        
        function pathBtnCb(this, hButton, evtData)
            pathEditH = get(hButton,'userdata');
            param = get(pathEditH,'userdata');
            initialDirectoryname = param.value;
            displayMessage = param.description;
            newPath = uigetfulldir(initialDirectoryname,displayMessage);
            if(~isempty(newPath))
                param.setValue(newPath);
                set(pathEditH,'string',newPath);
            end
        end
        
        function buttonCb(this, hButton, evtData)
            buttTag = get(hButton,'tag');
            switch(strrep(buttTag,'push_',''))
                case 'defaults'
                    fprintf('Defaults not implemented yet :(\n');
                case 'apply'
                    %fprintf('Apply and close\n');
                    delete(this.figureH);
                case 'cancel'
                    fprintf('Settings configuration canceled\n');
                    this.settings = [];
                    delete(this.figureH);
                otherwise
                    this.logWarning('Unknown button (%s)',buttTag);
            end
        end
    end
    
    methods(Static)

        function p=getDefaults()
            p=[];
        end
    end
end

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
                        for t = 1:numel(tabs)
                            settingName = tabs{t};
                            if(strcmpi(settingName,'SensorData'))
                                break;
                            end
                            u = uitab(this.handles.tabgroup,...
                                'title',settingName,'tag',sprintf('tag_%d',t));
                            labelProps.parent = u;
                            labelProps.units = 'normalized';
                            labelProps.position = [0.05 0.875 0.475 0.075];
                            labelProps.horizontalAlignment = 'left';
                            labelProps.fontweight = 'normal';
                            valueProps = labelProps;
                            valueProps.position = [0.5 0.9 0.45 0.05];
                            enumProps.position  = [0.6 0.9 0.35 0.05];
                            boolProps.position  = [0.7 0.9 0.25 0.05];
                            indexProps.position = [0.8 0.9 0.15 0.05];
                            
                            valueProps.horizontalAlignment = 'center';
                            setting = this.settings.(settingName);
                            if(isstruct(setting))
                                keys = fieldnames(setting);
                                for k =1:numel(keys)
                                    try
                                        param = setting.(keys{k});
                                        labelProps.String = param.description;
                                        valueProps.String = num2str(param.value);
                                        valueProps.userdata = param;
                                        nextValuePropsPosition = valueProps.position+[0 -0.08 0 0];
                                        switch(class(param))
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
                                                indexProps.position(2) = valueProps.position(2);
                                                valueProps.position = indexProps.position;
                                                
                                                valueProps.style = 'popupmenu';
                                                valueProps.String = num2str((1:10)');
                                                valueProps.value = param.value;
                                            
                                            case 'PANumericParam'
                                                valueProps.String = num2str(param.value);
                                                valueProps.style = 'edit';
                                            otherwise % PAPathParam, PAFilenameParam, PANumericParam, PAStringParam
                                                valueProps.String = num2str(param.value);
                                                valueProps.style = 'edit';
                                        end
                                        t = uicontrol(labelProps);
                                        v =uicontrol(valueProps);
                                        labelProps.position(2)  = labelProps.position(2)-0.08;
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
        
        function buttonCb(this, hButton, evtData)
            buttTag = get(hButton,'tag');
            switch(strrep(buttTag,'push_',''))
                case 'defaults'
                    fprintf('Default\n');
                case 'apply'
                    fprintf('Apply and close\n');
                case 'cancel'
                    fprintf('Cancel\n');
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

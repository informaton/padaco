classdef(Abstract) PAFigureController < PABase
    properties(SetAccess=protected)
        %> Figure handle to the main figure window
        figureH;
        settings;  % struct of settings that can be saved on exit and loaded on startup
    end
    methods(Abstract, Access=protected)
        didInit=initFigure(this)
    end
    
    methods
        
        function this = PAFigureController(figureH, initSettings)
            this@PABase();
            if(nargin<2 || isempty(initSettings))
                this.settings = this.getDefaults();
            else
                % This call ensures that we have at a minimum, the default parameter field-values in widgetSettings.
                % And eliminates later calls to determine if a field exists
                % or not in the input widgetSettings parameter
                this.settings = mergeStruct(this.getDefaults(),initSettings);
            end
            
            nargin && this.setFigureHandle(figureH) && this.initFigure(); %#ok<VUNUS>
        end
        
        function settings = getSettings(this)            
            settings = this.settings;
        end
        
        function didSet = setSetting(this, varargin)
            narginchk(3,inf);
            value2set = varargin{end};
            keys = varargin{1:end-1};
            param = this.getSettingsParam(keys);
            if(~isempty(param) && isa(param, 'PAParam'))
                didSet = param.setValue(value2set);
            else
                didSet = false;
            end
        end
        
        function value = getSetting(this, varargin)
            narginchk(2,inf);
            param = this.getSettingsParam(varargin{:});
            if(~isempty(param))
                value = param.value;
            else
                value = [];
            end
        end
        
        % Overload as necessary.
        function saveParams = getSaveParameters(this)
            saveParams = this.getSettings();
        end
        
    end
    
    methods(Access=protected)
        function didSet = setFigureHandle(obj, figHandle)
            didSet = false;
            if(nargin<2 || isempty(figHandle) || ~ishandle(figHandle))
                obj.logWarning('Could not set figure handle');
            else
                obj.figureH = figHandle;
                obj.handles = guidata(figHandle);
                didSet = true;
            end
        end
        
        function param = getSettingsParam(this, key, varargin)
            param = [];
            exactKey = getCaseSensitiveMatch(key, this.settings);
            if(~isempty(exactKey))
                param = this.settings.(exactKey);
                
                % go down the tree structure if we have additional keys
                % e.g. settings.alignment.x = 1;
                %      retrieved by :  this.getSettings('alignment','x');
                for v=numel(varargin)
                    if isstruct(param)
                        exactKey = getCaseSensitiveMatch(varargin{v}, param);
                        param = param.(exactKey);
                    else
                        break;
                    end
                end
            end
        end

    end
    methods(Abstract, Static)
        getDefaults
    end
end
    
    
    
   
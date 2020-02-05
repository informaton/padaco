classdef PABaseWithSettings < PABase   
    events
        DefaultParameterChange;
    end
    
    properties(SetAccess=protected)
        settings;  % struct of settings that can be saved on exit and loaded on startup
    end
    
    methods(Static, Abstract)
       defaults = getDefaults() 
    end
    
    methods
        
        function this = PABaseWithSettings(varargin)
            inputSettings = [];
            for v=1:numel(varargin)
                if(isstruct(varargin{v}) || isa(varargin{v},'PASettings'))
                    inputSettings = varargin{v};
                    break; % just take the first one given...
                end
            end
            defaultSettings = this.getDefaults();
            % if defaultSettins are empty, then we don't have any default settings
            % to work with 
            if(isempty(defaultSettings) && ~isempty(inputSettings))
                this.setSettings(inputSettings);
            elseif(~isempty(defaultSettings))
                if(isempty(inputSettings))
                    inputSettings = defaultSettings;
                else
                    try
                        inputSettings = mergeStruct(defaultSettings,inputSettings);
                    catch me
                        obj.logError(me,'There was an error trying to use previously saved settings.  Using default settings instead.');
                    end
                end
                this.setSettings(inputSettings);
            end
        end
        
        function didSet = setSettings(this, inputSettings)
            this.settings = inputSettings;
            didSet = true;
        end

        function settings = getSettings(this)            
            settings = this.settings;
        end
        
        function didSet = setSetting(this, varargin)
            narginchk(3,inf);
            value2set = varargin{end};
            keys = varargin(1:end-1);
            param = this.getSettingsParam(keys{:});
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
                if(isa(param,'PAParam'))
                    value = param.value;
                else
                    value = param;
                end
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
        
        function param = getSettingsParam(this, key, varargin)
            param = [];
            exactKey = getCaseSensitiveMatch(key, this.settings);
            if(~isempty(exactKey))
                param = this.settings.(exactKey);
                
                % go down the tree structure if we have additional keys
                % e.g. settings.alignment.x = 1;
                %      retrieved by :  this.getSettings('alignment','x');
                for v=1:numel(varargin)
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
end
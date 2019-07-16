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
    end
    
    methods(Access=protected)
        function didSet = setFigureHandle(obj, figHandle)
            didSet = false;
            if(nargin<2 || isempty(figHandle) || ~ishandle(figHandle))
                obj.logWarning('Could not set figure handle');
            else
                obj.figureH = figHandle;
                didSet = true;
            end
        end
    end
    methods(Abstract, Static)
        getDefaults
    end
end
    
    
    
   
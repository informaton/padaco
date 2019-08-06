classdef(Abstract) PAFigureController < PABaseWithSettings
    properties(SetAccess=protected)
        %> Figure handle to the main figure window
        figureH;        
    end
    methods(Abstract, Access=protected)
        didInit=initFigure(this)
    end
    
    methods
        
        % Sometimes a figure handle is given and sometimes it is not.
        % Same goes for initSettings.  When a figureH is given it will be a
        % figure handle and when initSettings are given it will be a
        % struct.
        function this = PAFigureController(varargin)
            this@PABaseWithSettings(varargin{:});
            figureH = [];
            for v=1:numel(varargin)
               if(ishandle(varargin{v}))
                   figureH = varargin{v};
               end
            end
            
            if(this.setFigureHandle(figureH))
                this.initFigure();                
            end
        end
    end
    
    methods(Access=protected)
        function didSet = setFigureHandle(obj, figHandle)
            didSet = false;
            if(nargin>1 && ~isempty(figHandle) && ishandle(figHandle))                
                obj.figureH = figHandle;
                obj.handles = guidata(figHandle);
                didSet = true;
            else
                disp('oops');
            end
        end
    end
end
    
    
    
   
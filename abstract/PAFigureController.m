classdef(Abstract) PAFigureController < PABaseWithSettings
    properties(SetAccess=protected)
        %> Figure handle to the main figure window
        figureH;
    end
    methods(Abstract, Access=protected)
        didInit=initFigure(obj)
    end
    
    methods
        
        % Sometimes a figure handle is given and sometimes it is not.
        % Same goes for initSettings.  When a figureH is given it will be a
        % figure handle and when initSettings are given it will be a
        % struct.
        function obj = PAFigureController(varargin)
            obj@PABaseWithSettings(varargin{:});
            figureH = [];
            for v=1:numel(varargin)
               if(ishandle(varargin{v}))
                   figureH = varargin{v};
               end
            end
            
            if(obj.setFigureHandle(figureH))
                obj.initFigure();                
            end
        end
        % --------------------------------------------------------------------
        %> @brief Get the view's figure handle.
        %> @param obj Instance of PAFigureController
        %> @retval figHandle The figure handle.
        % --------------------------------------------------------------------
        function figHandle = getFigHandle(obj)
            figHandle = obj.figureH;
        end
        
    end
    
    methods(Access=protected)
        function didSet = setFigureHandle(obj, figHandle)
            didSet = false;
            if(nargin>1 && ~isempty(figHandle) && ishandle(figHandle))                
                obj.figureH = figHandle;
                obj.handles = guidata(obj.figureH);
                if(isempty(obj.handles))
                    obj.handles = guihandles(obj.figureH);
                end
                didSet = true;
            else
                disp('oops');
            end
        end

        function disable(this)
            disableHandles(this.figureH);
        end
        function enable(this)
            enableHandles(this.figureH);
        end
        
        function hide(this)
            set(this.figureH,'visible','off');
        end
        function show(this)
            this.unhide();
        end
        function unhide(this)
            set(this.figureH,'visible','on');
        end
  
        
        % --------------------------------------------------------------------
        %> @brief Shows busy status (mouse becomes a watch).
        %> @param obj Instance of PASingleStudyController
        % --------------------------------------------------------------------
        function showBusy(obj)
            obj.showMouseBusy();
            drawnow();
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param obj Instance of PASingleStudyController        
        % --------------------------------------------------------------------
        function showReady(obj)
            obj.showMouseReady();
            set(obj.statusHandle,'string','');            
            drawnow();
        end
        
        % ======================================================================
        %> @brief Shows busy state (mouse pointer becomes a watch)
        %> @param obj Instance of PAStatTool
        % ======================================================================
        function showMouseBusy(obj)
            set(obj.figureH,'pointer','watch');
            drawnow();
        end
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param obj Instance of PAStatTool
        % --------------------------------------------------------------------
        function showMouseReady(obj)
            set(obj.figureH,'pointer','arrow');
            drawnow();
        end
    end
end
    
    
    
   
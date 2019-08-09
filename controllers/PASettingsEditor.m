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
        
    end
    
    methods(Access=protected)
        
        function didInit = initFigure(this)
            didInit = false;
            if(ishandle(this.figureH))
                try
                    set(this.figureH,'visible','on');
                    didInit = true;
                catch me
                    showME(me);
                end
            end
        end
        

    end
    
    methods(Static)

        function p=getDefaults()
            p=[];
        end
    end
end

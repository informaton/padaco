classdef(Abstract) PAFigureFcnController <PAFigureController
    properties(Abstract, Access=protected)
        figureFcn
    end
    
    methods        
        function obj = PAFigureFcnController(varargin)
            obj@PAFigureController(varargin{:});
        end        
    end
    
    methods(Access=protected)
        function didSet = setFigureHandle(obj, figHandle)
            if(nargin<2 || isempty(figHandle))
                figHandle = obj.figureFcn('visible','off','name','','sizechangedfcn',[]);
            end
            didSet = setFigureHandle@PAFigureController(obj,figHandle);
        end
    end
end
classdef PANumericParam < PAParam
    
    properties(SetAccess=protected)
        minAllowed=-inf;
        maxAllowed=inf;
    end
    
    methods
        function this = PANumericParam(varargin)
            this@PAParam('double',varargin{:})
            args.min = -inf;
            args.max = inf;
            args = mergepvpairs(args,varargin{:});
            
            this.minAllowed = args.min;
            this.maxAllowed = args.max;
        end
        
        function canIt = canSetValue(this, value2set)
            canIt = canSetValue@PAParam(this,value2set) && value2set>=this.minAllowed && value2set<=this.maxAllowed;
        end
    end
end
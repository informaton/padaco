classdef PACategoricalParam < PAParam
    
    properties(SetAccess=protected)
        categories;
        maxAllowed=inf;
    end
    
    methods
        function this = PACategoricalParam(varargin)
            this@PAParam('double',varargin{:})
            args.categories = {};
            args = mergepvpairs(args,varargin{:});
            
            this.minAllowed = args.min;
            this.maxAllowed = args.max;
        end
        
        function canIt = canSetValue(this, value2set)
            canIt = canSetValue@PAParam(this,value2set) && value2set>=this.minAllowed && value2set<=this.maxAllowed;
        end
    end
end
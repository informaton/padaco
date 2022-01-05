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
        
        function str = char(this)
            str = num2str(this.value);
        end
        
        function canIt = canSetValue(this, value2set)
            try
                canIt = canSetValue@PAParam(this,value2set) && ((value2set>=this.minAllowed && value2set<=this.maxAllowed) || (isnan(value2set) && isnan(this.default)));
            catch me
                showME(me);
                canIt = false;
            end
        end
    end
end
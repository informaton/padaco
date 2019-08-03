classdef PAIndexParam < PANumericParam     
    methods
        function this = PAIndexParam(varargin)
            this@PANumericParam(varargin{:});
            if(isinf(this.minAllowed))
                this.minAllowed = -1;
            end
        end        
    end
end
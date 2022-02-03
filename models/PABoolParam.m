classdef PABoolParam < PAParam
    methods
        function this = PABoolParam(varargin)
            this@PAParam('logical',varargin{:})    
        end
        
        function value = logical(this)
            value = this.value;
        end
    end
end
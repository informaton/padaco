classdef PABoolParam < PAParam
    methods
        function this = PABoolParam(varargin)
            this@PAParam('logical',varargin{:})    
        end
    end
end
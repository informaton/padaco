classdef PAStringParam < PAParam
    methods
        function this = PAStringParam(varargin)
            this@PAParam('char',varargin{:})            
        end
    end
end
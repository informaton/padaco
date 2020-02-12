classdef PAPathParam < PAStringParam
    methods
        function this = PAPathParam(varargin)
            this@PAStringParam(varargin{:});
        end
        
        function doesIt = exist(this, varargin)
            doesIt = exist(this.value, varargin{:});
        end
        function parts = fileparts(this, varargin)
            parts = fileparts(this.value, varargin{:});
        end
        function isIt = isdir(this)
            isIt = isdir(this.value);
        end        
        
    end
end
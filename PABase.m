classdef PABase < handle
    
    properties(SetAccess=protected)
        handles;
        statusHandle;
    end
    methods
        function setStatus(obj, fmtStr, varargin)
           str = sprintf(fmtStr, varargin{:});
           if(~isempty(this.statusHandle) && ishandle(this.statusHandle))
               set(obj.statusHandle,'string',str);
           else
               fprintf(1,['%s',newline],str);
           end
        end
    end
end
    
    
    
   
classdef PABase < handle
    events
        DefaultParameterChange;
    end
    properties(SetAccess=protected)
        handles;
        statusHandle;
    end
    methods
        
        function clearStatus(obj)
            obj.setStatus('');
        end
        
        function setStatus(obj, fmtStr, varargin)
           str = sprintf(fmtStr, varargin{:});
           if(~isempty(obj.statusHandle) && ishandle(obj.statusHandle))
               set(obj.statusHandle,'string',str);
           else
               if(~isempty(fmtStr))
                   fprintf(1,['%s',newline],str);
               end
           end
        end
        
        function logWarning(obj,fmtStr, varargin)
            obj.logError(fmtStr, [], varargin{:});
        end
        
        function logError(obj, fmtStr, me, varargin)
            if(nargin>2 && ~isempty(me))
                showME(me);
                msgType = 'Error';
            else
                msgType = 'Warning';
            end
            errMsg = sprintf(fmtStr,varargin{:});
            obj.logStatus('[%s] %s',msgType,errMsg);
        end
        
        function logStatus(obj, fmtStr, varargin)
            str = sprintf(fmtStr, varargin{:});
            fprintf(1,'%s\n',str);
        end
        
        function didSet = setStatusHandle(obj, statusH)
            didSet = false;
            if(ishandle(statusH))
                obj.statusHandle = statusH;
                didSet = true;
            end
        end

    end
end
    
    
    
   
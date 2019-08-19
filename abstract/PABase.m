classdef PABase < handle
    
    properties(Access=protected)
        handles;
        statusHandle;
        statusTimerH;
    end
    
    methods
        
        function clearStatus(obj)
            obj.setStatus('');
        end
        
        function clearStatusCb(this, varargin)
            this.clearStatus();
        end
        
        function setTimedStatus(obj, delayToFade, varargin)            
            if(isempty(obj.statusTimerH))
               obj.statusTimerH = timer('timerfcn',@obj.clearStatusCb,'executionmode','singleshot','startdelay',5);
            end
            if(strcmpi(obj.statusTimerH.Running,'on'))
                stop(obj.statusTimerH);
            end
            if(delayToFade>1)
                set(obj.statusTimerH,'startdelay',delayToFade);              
            end
            obj.setStatus(varargin{:});
            start(obj.statusTimerH);            
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
        
        function logError(obj, me, fmtStr, varargin)
            if(nargin>1 && ~isempty(me))
                showME(me);
                msgType = 'Error';
            else
                msgType = 'Warning';
            end
            if(nargin>2)
                errMsg = sprintf(fmtStr,varargin{:});
                obj.logStatus('[%s] %s',msgType,errMsg);
            end
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
    
    
    
   
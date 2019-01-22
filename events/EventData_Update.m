classdef (ConstructOnLoad) EventData_Update < event.EventData
   properties
       update
   end

   methods
      function data = EventData_Update(fmtMsg, varargin)
          data.update = sprintf(fmtMsg, varargin{:});
      end
   end
end
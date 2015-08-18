classdef (ConstructOnLoad) EventData_BatchTool < event.EventData
   properties
      settings;
   end

   methods
      function data = EventData_BatchTool(settings)
         data.settings = settings;
      end
   end
end
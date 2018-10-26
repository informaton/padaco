classdef (ConstructOnLoad) LinePropertyChanged_EventData < event.EventData
   properties
       lineTag
       name;
       value;
       previousValue;
   end

   methods
      function data = LinePropertyChanged_EventData(lineTag,propName, newValue, oldValue)
          data.lineTag = lineTag;
          data.name = propName;
          data.value = newValue;
          if(nargin>3)
              data.previousValue = oldValue;
          end
      end
   end
end
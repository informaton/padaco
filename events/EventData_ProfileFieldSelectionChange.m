classdef (ConstructOnLoad) EventData_ProfileFieldSelectionChange < event.EventData
   properties
      fieldName;
      fieldIndex
   end

   methods
      function data = EventData_ProfileFieldSelectionChange(fName,fIndex)
         data.fieldName = fName;
         data.fieldIndex = fIndex;
      end
   end
end
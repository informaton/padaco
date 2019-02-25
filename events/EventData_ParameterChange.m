classdef (ConstructOnLoad) EventData_ParameterChange < event.EventData
   properties(SetAccess=protected)
       fieldName;
       changedTo;
       changedFrom;
   end

   methods
      function data = EventData_ParameterChange(fieldName, changedTo, changedFrom)
          if(nargin<3)
              changedFrom = [];
              if(nargin<2)
                  changedFrom = [];
                  if(nargin<1)
                      fieldName = [];
                  end
              end
          end
          data.fieldName = fieldName;
          data.changedTo = changedTo;
          data.changedFrom = changedFrom;
      end
   end
end
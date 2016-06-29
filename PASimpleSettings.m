classdef PASimpleSettings < handle
   properties
       fieldNames;
       inputStruct;
       defaultStruct;
       outputStruct;
       Settings;
   end
   
   methods
       function this = PASimpleSettings(inputStruct, defaultStruct)
           if(nargin<2)
               defaultStruct = inputStruct;
           end
           
           this.defaultStruct = defaultStruct;
           this.inputStruct = inputStruct;
           
           this.Settings = this.inputStruct;
           
           this.fieldNames = {'Settings'};
           this.outputStruct = [];
           
           this.runEditor();
           
       end
    
       function runEditor(this)
           tmp = pair_value_dlg(this);
           if(~isempty(tmp))
               this.outputStruct = tmp.Settings;
               this.Settings = tmp.Settings;
           end
       end
       
       function didSet = setDefaults(this,fieldToChange)
           try
               fnames = fieldnames(this.(fieldToChange));
               if(~iscell(fnames))
                   fnames = {fnames};
               end
               for f=1:numel(fnames)
                   fname = fnames{f};
                   this.Settings.(fname) = this.defaultStruct.(fname);
               end
               
               didSet = true;
           catch me
               showME(me);
               didSet = false;
           end 
       end
   end
   
   methods(Static)
       function structOut = editor(varargin)
           this = PASimpleSettings(varargin{:});
           structOut = this.outputStruct;           
       end       
   end
    
end
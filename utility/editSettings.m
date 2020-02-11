  parameters_filename = PAAppSettings().parameters_filename; % '.pasettings'
  paramsPath = getSavePath();
  paramsFile = fullfile(paramsPath, parameters_filename);
  
  edit(paramsFile);

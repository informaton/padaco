% Returns clustering related settings from a pasettings file
function settings = getSettingsFromFile(settingsFilename)
    settings = PASettings.loadParametersFromFile(settingsFilename);
    if isstruct(settings) && isfield(settings,'StatTool')
        settings = settings.StatTool;
    end
end
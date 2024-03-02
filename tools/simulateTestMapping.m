% Increase the noise - and then run a 100, 1000 for each noise step and
% tabulate the results.
addpath("~/git/padaco/utility/");
methods = testMapping('methods');
num_clusters = 5;
cluster_length = 30;
num_iters = 1000;
noises = 0:50:40;

% Number of methods and noises
num_methods = numel(methods);
num_noises = numel(noises);

% results = mkstruct(methods, nan(1,num_iters));
simulationResults = repmat({struct('noise',nan,'mappings', mkstruct(methods, nan(1,num_iters)))}, 1, num_noises);

for p=1:num_noises
    noise = noises(p);
    tic
    fprintf(1,'Simulating for noise = %03d\n',noise);
    rng(num_iters);
    simulationResults{p}.noise = noise;
    for k=1:num_iters
        results = testMapping(num_clusters, cluster_length, noise);
        for n=1:numel(methods)
            method = methods{n};
            simulationResults{p}.mappings.(method)(k) = results.(method);            
        end
    end
    toc
end


% Preallocate table
summaryTable = array2table(nan(num_noises * num_methods, 6),...
    'VariableNames', {'NoiseLevel', 'Method', 'Mean', 'Variance', 'LowerCI', 'UpperCI'});

% Convert 'Method' column to a cell to store strings
summaryTable.Method = cell(size(summaryTable, 1), 1);

% Index for table rows
idx = 1;

for p=1:num_noises
    for n=1:num_methods
        % Get results for a specific noise and method combination
        data = simulationResults{p}.mappings.(methods{n});
        
        % Calculate statistics
        mu = mean(data);
        varValue = var(data);
        
        % 95% Confidence Interval
        stderr = std(data) / sqrt(num_iters); % standard error
        ci95 = 1.96 * stderr; % assuming a normal distribution
        
        % Store results in the table
        summaryTable.NoiseLevel(idx) = simulationResults{p}.noise;
        summaryTable.Method{idx} = methods{n};
        summaryTable.Mean(idx) = mu;
        summaryTable.Variance(idx) = varValue;
        summaryTable.LowerCI(idx) = mu - ci95;
        summaryTable.UpperCI(idx) = mu + ci95;
        
        idx = idx + 1;
    end
end

% Display the summary table
disp(summaryTable);

% Create a cell array to store the tables for each method
tablesForMethods = cell(1, num_methods);

for n=1:num_methods
    % Preallocate table for current method
    methodTable = array2table(nan(4, num_noises), 'VariableNames', cellstr(num2str(noises')), ...
                              'RowNames', {'Mean', 'Variance', 'LowerCI', 'UpperCI'});
    
    for p=1:num_noises
        % Get results for a specific noise and method combination
        data = simulationResults{p}.mappings.(methods{n});
        
        % Calculate statistics
        mu = mean(data);
        varValue = var(data);
        
        % 95% Confidence Interval
        stderr = std(data) / sqrt(num_iters); % standard error
        ci95 = 1.96 * stderr; % assuming a normal distribution
        
        % Store results in the table
        methodTable{ 'Mean', p } = mu;
        methodTable{ 'Variance', p } = varValue;
        methodTable{ 'LowerCI', p } = mu - ci95;
        methodTable{ 'UpperCI', p } = mu + ci95;
    end
    
    % Store the table for the current method in the cell array
    tablesForMethods{n} = methodTable;
    
    % Display the table for current method
    fprintf('Results for method: %s\n', methods{n});
    disp(methodTable);
    fprintf('\n');
end

fprintf('The mean value of successful mapping per method for %d clusters, each with a length of %d elements.\n',num_clusters, cluster_length);
% Prepare variable (column) names with the desired format
formattedNoiseNames = arrayfun(@(x) sprintf('Noise=%3d', x), noises, 'UniformOutput', false);

% Preallocate table
meanResultsTable = array2table(nan(num_methods, num_noises), ...
                               'VariableNames', formattedNoiseNames, ...
                               'RowNames', methods);

for n=1:num_methods
    filteredTable = summaryTable(strcmp(summaryTable.Method, methods{n}), :);
    meanResultsTable{methods{n}, :} = filteredTable.Mean';
end

% Display the table
disp(meanResultsTable);


% Prepare variable (column) names with the desired format
formattedNoiseNames = arrayfun(@(x) sprintf('Noise=%3d', x), noises, 'UniformOutput', false);

% Preallocate a numeric table for the mean results
meanResultsTable = array2table(zeros(num_methods, num_noises), ...
                               'VariableNames', formattedNoiseNames, ...
                               'RowNames', methods);

for n=1:num_methods
    filteredTable = summaryTable(strcmp(summaryTable.Method, methods{n}), :);
    meanResultsTable{methods{n}, :} = filteredTable.Mean';
end

% Display the table
disp(meanResultsTable);

% To view formatted values, we can use fprintf:
for n=1:num_methods
    fprintf('%s: ', methods{n});
    for p=1:num_noises
        fprintf('%.4f ', meanResultsTable{methods{n}, p});
    end
    fprintf('\n');
end


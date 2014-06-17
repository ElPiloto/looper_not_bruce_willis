function [] = coil(args, varargin )
% This function is for calling loopify in parallel.  It accepts the same inputs as loopify.m (see 'help loopify'), but instead of running all loops sequentially,
% will call the function in 'execute_fn' using the system function and the cluster-to-matlab-interfacing command specified in this function via SUBMIT_COMMAND_TEMPLATE
% for one parameter combination at a time via loopify's 'range' argument and 'load,args_filename.mat' invocation.  Additionally, all results are saved with a name specific to 
% the particular function being called and the job number.  Unlike loopify, if 'execute_fn' parameter is required.

% Example Actually call a function
%
% args.first = [1];
% args.second = [1 2];
%
% coil(args,'execute_fn','minus');
%
% Assuming your SUBMIT_COMMAND_TEMPLATE is 'submit %s', then the above call to coil will make the following 2 calls (1 for each possible parameter combination)
% after saving the arguments to a job-specific file
%
%      submit loopify.m "'load,minus_job1_140617_0358.mat'" 
%
%           minus_job1_140617_0359.mat has the variables to pass into loopify, as well was:
%                range: 1 % this is the job number, tells us which parameters combination to operate on
%                save_file: 'minus_job1.mat' % job specific save name
%
%      submit loopify.m "'load,minus_job2_140617_0359.mat'" 
%
%           minus_job2_140617_0359.mat has the variables to pass into loopify, as well was:
%                range: 2 % this is the job number, tells us which parameters combination to operate on
%                save_file: 'minus_job2.mat' % job specific save name
%
% NOTE: requires parsepropval.m function from matlab file exchange
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DEBUG = true;

% this is the unix command used to launch each individual job, it should
% have a single placeholder: a string for specifying the matlab function to run
SUBMIT_COMMAND_TEMPLATE = 'submit %s';

% some setup to tell us how many iteration we'll need, without actually executing anything
parameters = fieldnames(args);
% calculate total number of parameters
num_params = numel(parameters);
% grab the number of possible values for each parameter
sizes = structfun(@numel,args)';
total_num_combinations = prod(sizes);

try
	defaults.execute_fn = '';
	defaults.constant_args = {};
	defaults.pass_param_names = false;
	defaults.save_name = '';
	defaults.save_directory = './';
	options = parsepropval(defaults,varargin{:});
catch err
	error('looper_not_bruce_willis:coil:invalidArgument', 'Argument "range" specified to coil.m, but running loopify in parallel via coil.m does not support specification of ranges.  Please remove this argument and call this function again');
end

% verify execute_fn is specified
if isempty(get_idx_into_varargin_for_param(varargin,'execute_fn'))
	error('looper_not_bruce_willis:coil:noExecuteFnSpecified', 'Named parameter "execute_fn" is required, otherwise what the crap are we going to call in parallel?');
end


% specify the .range argument
range_idx = get_idx_into_varargin_for_param(varargin,'range');
if isempty(range_idx)
	varargin{end+1} = 'range';
	varargin{end+1} = [];
	range_idx = length(varargin);
end

% now we go through and save a .mat file with the arguments in it for each loop
for loop_idx = 1 : total_num_combinations
	% specify that this job should only operate on a single idx using the range argument
	varargin{range_idx} = loop_idx;

	% additionally, add a save location specific to this job
	job_specific_file_name = [strrep(options.execute_fn,' ','_') '_job' num2str(loop_idx) '_' datetime() '.mat'];
	save_name_idx = get_idx_into_varargin_for_param(varargin,'save_name');
	if isempty(save_name_idx)
		job_specific_file_name_short = [strrep(options.execute_fn,' ','_') '_job' num2str(loop_idx) '.mat'];
		varargin{end+1} = 'save_name';
		varargin{end+1} = ['results_' job_specific_file_name_short];
	else
		varargin{save_name_idx} = [strrep(varargin{save_name_idx},'.mat','') job_specific_file_name '.mat'];
	end

	% specify that we should exit loopify when it's done doing its job - we don't want to leave a bunch of hanging matlab jobs
	should_exit_idx = get_idx_into_varargin_for_param(varargin,'should_exit_when_done');
	if isempty(should_exit_idx)
		varargin{end+1} = 'should_exit_when_done';
		varargin{end+1} = true;
	else
		varargin{should_exit_idx} = true;
	end

	% save args to job specific file
	save(job_specific_file_name, 'args','varargin');
	
	launch_loopify_command = ['loopify.m "''load,' job_specific_file_name '''"' ];
	
	% either submit job or display what we would be submitting if the DEBUG flag is true
	if DEBUG 
		sprintf(SUBMIT_COMMAND_TEMPLATE, launch_loopify_command)
	else
		[status, result] = system(sprintf(SUBMIT_COMMAND_TEMPLATE, launch_loopify_command));
	end
end


end

function [match_idx] = get_idx_into_varargin_for_param(args, param_name)
	matches = cellfun(@(str) strfind(str,param_name), args, 'UniformOutput',false);
	matches = cellfun(@(x) ~isempty(x), matches);
	match_idx = find(matches) + 1; % we add one because if the param is at location 1, then the actual value is at location 2
end

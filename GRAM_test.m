% --------------------------------------------------------
% MDP Tracking
% Copyright (c) 2015 CVGL Stanford
% Licensed under The MIT License [see LICENSE for details]
% Written by Yu Xiang
% --------------------------------------------------------
%
% cross_validation on the KITTI benchmark
function GRAM_test(is_train, seq_idx_train, seq_idx_test,...
    continue_from_seq, use_hungarian, start_offset,...
    read_images_in_batch, enable_eval, show_cropped_figs, save_video)

def.is_train = 1;
% def.seq_idx_train = {[1:9, 16:24], [31:50]};
% def.seq_idx_test = {[10:15, 25:30], [51:60]};
% def.seq_idx_train = {[1, 2], [3]};
% def.seq_idx_test = {[1, 2], [3]};
def.seq_idx_train = {[79]};
def.seq_idx_test = {[67]};
def.continue_from_seq = 0;
def.use_hungarian = 0;
def.start_offset = 0;
def.read_images_in_batch = [1, 0];
def.enable_eval = 1;
def.show_cropped_figs = 0;
def.save_video = 0;

% set is_train to 0 if testing trained trackers only
arg_id = 1;
if nargin < arg_id
    is_train = def.is_train;
end
arg_id = arg_id + 1;
if nargin < arg_id
    seq_idx_train = def.seq_idx_train;
end
arg_id = arg_id + 1;
if nargin < arg_id
    seq_idx_test = def.seq_idx_test;
end
arg_id = arg_id + 1;
if nargin<arg_id
    continue_from_seq = def.continue_from_seq;
end
arg_id = arg_id + 1;
if nargin<arg_id
    use_hungarian = def.use_hungarian;
end
arg_id = arg_id + 1;
if nargin<arg_id
    start_offset = def.start_offset;
end
arg_id = arg_id + 1;
if nargin<arg_id
    read_images_in_batch = def.read_images_in_batch;
end
arg_id = arg_id + 1;
if nargin<arg_id
    enable_eval = def.enable_eval;
end
arg_id = arg_id + 1;
if nargin<arg_id
    show_cropped_figs = def.show_cropped_figs;
end
arg_id = arg_id + 1;
if nargin<arg_id
    save_video = def.save_video;
end

db_type = 2;
opt = globals();
seq_set_test = 'testing';
N = max([numel(seq_idx_train),numel(seq_idx_test)]);

if ~exist('datetime')
    log_fname = sprintf('%s/log.txt', opt.results_gram);
else
    log_fname = sprintf('%s/log_%s.txt', opt.results_gram,...
        char(datetime('now', 'Format','yyMMdd_HHmm')));
end

diary(log_fname);

if use_hungarian
    fprintf('Using Hungarian variant\n');
end

% for each training-testing pair
for i = 1:N
    % training
    if numel(seq_idx_train)<i
        idx_train = seq_idx_train{end};
        fprintf('Insufficient training indices %d provioded for testing idx %d\n',...
            numel(seq_idx_train), i);
        fprintf('Using the last index instead:\n');
        disp(idx_train);
    else
        idx_train = seq_idx_train{i};
    end
    
    tracker = [];
    if ~is_train || continue_from_seq
        % load tracker from file
        if continue_from_seq
            seq_idx = continue_from_seq;
        else
            seq_idx = idx_train(end);
        end
        seq_name = opt.gram_seqs{seq_idx};
        seq_n_frames = opt.gram_nums(seq_idx);
        seq_train_ratio = opt.gram_train_ratio(seq_idx);
        [train_start_idx, train_end_idx] = getSubSeqIdx(seq_train_ratio,...
            seq_n_frames);
        filename = sprintf('%s/gram_%s_%d_%d_tracker.mat',...
            opt.results_gram, seq_name, train_start_idx, train_end_idx);
        fprintf('loading tracker from file %s\n', filename);
        object = load(filename);
        tracker = object.tracker;
    end
    
    if is_train
        % number of training sequences
        num = numel(idx_train);
        % online training
        for j = 1:num
            fprintf('Online training on sequence: %s\n', opt.gram_seqs{idx_train(j)});
            tracker = MDP_train(idx_train(j), tracker, db_type,...
                read_images_in_batch(1));
        end
        fprintf('%d training examples after online training\n', size(tracker.f_occluded, 1));
    end
    
    % testing
    if numel(seq_idx_test)<i
        idx_test = seq_idx_test{end};
        fprintf('Insufficient testing indices %d provioded for training idx %d\n',...
            numel(seq_idx_test), i);
        fprintf('Using the last index instead:\n');
        disp(idx_test);
    else
        idx_test = seq_idx_test{i};
    end
    % number of testing sequences
    num = numel(idx_test);
    for j = 1:num
        fprintf('Testing on sequence: %s\n', opt.gram_seqs{idx_test(j)});
        if use_hungarian
            dres_track = MDP_test_hungarian(idx_test(j), seq_set_test,...
                tracker, db_type, start_offset, 1);
        else
            dres_track = MDP_test(idx_test(j), seq_set_test, tracker, db_type,...
                start_offset, read_images_in_batch(2), 1, show_cropped_figs, save_video);
        end
    end
    % filename = sprintf('%s/%s_%d_%d.txt', opt.results_gram, seq_name,...
    %     test_start_idx, test_end_idx);
    % fprintf('writing results to: %s\n', filename);
    % write_tracking_results(filename, dres_track, opt.tracked);
    if enable_eval
        GRAM_evaluation_only(idx_test, 0);
    end
end

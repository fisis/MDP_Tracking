% --------------------------------------------------------
% MDP Tracking
% Copyright (c) 2015 CVGL Stanford
% Licensed under The MIT License [see LICENSE for details]
% Written by Yu Xiang
% --------------------------------------------------------
%
% generate training data from GRAM
function [dres_train, dres_det, labels] = generate_training_data_gram(db_path,...
    seq_name, dres_image, opt, train_start_idx, train_end_idx)

% dres.covered: Normalized overlap between the bounding box for each target
% in each frame with the maximally overlapping GT box in the same frame
is_show = 0;

% read detections
filename = fullfile(db_path, 'Detections', [seq_name '.txt']);
fprintf('reading detections from: %s\n', filename);
try    
    zip_files = ls(fullfile(db_path, 'Detections', '*.zip'));    
    fprintf('Zip files in this folder:\n');
    disp(zip_files)
catch ME
    fprintf('No zip files in this folder\n');
end
    
dres_det = read_gram2dres(filename, train_start_idx, train_end_idx);

% read ground truth
filename = fullfile(db_path, 'Annotations', [seq_name '.txt']);
fprintf('reading gt from: %s\n', filename);
dres_gt = read_gram2dres(filename, train_start_idx, train_end_idx);
 % max y of all objects in the gt
y_gt = dres_gt.y + dres_gt.h;

% collect true positives and false alarms from detections
num = numel(dres_det.fr); %  no. of detections
labels = zeros(num, 1);
overlaps = zeros(num, 1);
for i = 1:num
    fr = dres_det.fr(i);
    index = find(dres_gt.fr == fr);
    if isempty(index) == 0
        % overlaps between detection i and all gt boxes in the same frame
        % as this detection
        overlap = calc_overlap(dres_det, i, dres_gt, index);
        o = max(overlap);
        % label this detection based on the maximum overlap between it and
        % all gt boxes in its frame
        if o < opt.overlap_neg % 0.2
            labels(i) = -1; % false positive
        elseif o > opt.overlap_pos % 0.5
            labels(i) = 1; % true positive
        else
            labels(i) = 0; % unknown
        end
        overlaps(i) = o;
    else
        overlaps(i) = 0;
        labels(i) = -1;
    end
end

% build the training sequences
ids = unique(dres_gt.id);
dres_train = [];
count = 0;
% one object/target in the GT at a time
for i = 1:numel(ids)    
    % check if the target is occluded or not
    
     % set of frames with this object
    index = find(dres_gt.id == ids(i)); 
    dres = sub(dres_gt, index); 
    % no. of frames with this object
    num = numel(dres.fr);
    dres.occluded = zeros(num, 1);
    dres.covered = zeros(num, 1); % with GT boxes    
    dres.overlap = zeros(num, 1); % with detections
    dres.r = zeros(num, 1);
    dres.area_inside = zeros(num, 1);
    y = dres.y + dres.h; % max y of the object box
    % one frame containing this object at a time
    for j = 1:num
        fr = dres.fr(j);
        % all objects except the current one in the current frame 
        index = find(dres_gt.fr == fr & dres_gt.id ~= ids(i));
        
        if isempty(index) == 0
            % normalized intersection area of this box with all other boxes
            % in the current frame
            [~, ov] = calc_overlap(dres, j, dres_gt, index); 
            % for some unknown reason, if the max y of this box exceeds the
            % max y of another box, the norm overlap between them is set to 0
            ov(y(j) > y_gt(index)) = 0;
            % fractional coverage of this object is the max norm overlap
            dres.covered(j) = max(ov);
        end
        % if fractional coverage of this obj exceeds a threshold, it is
        % considered as occluded
        if dres.covered(j) > opt.overlap_occ % 0.7
            dres.occluded(j) = 1;
        end
        
        % overlap with detections
        index = find(dres_det.fr == fr);
        if isempty(index) == 0
            overlap = calc_overlap(dres, j, dres_det, index);
            [o, ind] = max(overlap);
            % overlap is the IoU rather than the IoA that was
            % used for GT coverage; the pruning of boxes whose maximum y exceeds
            % this box's is not done either
            dres.overlap(j) = o;        
            % detection score of the detection with the maximum overlap
            dres.r(j) = dres_det.r(index(ind));
            
            % area inside image of the max overlap detection
            [~, overlap] = calc_overlap(dres_det, index(ind), dres_image, 1);
            dres.area_inside(j) = overlap;
        end
    end
    
    % start with bounding overlap > opt.overlap_pos and non-occluded box
    
    % start with the frame where the overlap with the detection that has the maximum overlap
    % with this box is greater than a threshold - 0.5 - and it is not  
    % covered by another GT box and the fraction of the maximum overlap 
    % detection box that lies  inside the image also exceeds a threshold - 0.95
    index = find(dres.overlap > opt.overlap_pos & dres.covered == 0 & dres.area_inside > opt.exit_threshold);

    if isempty(index) == 0
        index_start = index(1);
        count = count + 1;
        dres_train{count} = sub(dres, index_start:num);
        
        % show gt
        % if is_show
        % disp(count);
        % for j = 1:numel(dres_train{count}.fr)
        %     fr = dres_train{count}.fr(j);
        %     I = dres_image.I{fr};
        %     figure(1);
        %     show_dres(fr, I, 'GT', dres_train{count});
        %     pause;
        % end
        % end
    end
end

fprintf('%s: %d positive sequences\n', seq_name, numel(dres_train));
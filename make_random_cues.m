function make_random_cues(cuesDir, tokens)
    % Generate 6 files (set1..3 × run1..2) with 14 blocks × 4 trials.
    % Each trial is 3 tokens sampled uniformly from tokens (size 3), with replacement.
    
        if nargin < 1 || isempty(cuesDir), cuesDir = fullfile(fileparts(mfilename('fullpath')),'cues'); end
        if ~exist(cuesDir,'dir'), mkdir(cuesDir); end
    
        if nargin < 2 || isempty(tokens)
            % auto-detect from stimuli
            videoDir = fullfile(fileparts(mfilename('fullpath')),'stimuli');
            mp4s = dir(fullfile(videoDir,'*.mp4'));
            if numel(mp4s) ~= 3
                error('Expected exactly 3 .mp4 files in %s to auto-detect tokens.', audioDir);
            end
            tokens = cell(1,3);
            for i = 1:3
                [~, base, ~] = fileparts(mp4s(i).name);
                tokens{i} = regexprep(lower(base), '^[0-9]+_?', '');
            end
        else
            assert(numel(tokens)==3, 'Provide exactly 3 tokens.');
            tokens = lower(tokens(:))';
        end
    
        N_BLOCKS = 14;
        TRIALS_PER_BLOCK = 3;
    
        for setN = 1:3
            for runN = 1:2
                fn = fullfile(cuesDir, sprintf('set%d_run%d.txt', setN, runN));
                fid = fopen(fn,'w');
                if fid < 0, error('Could not open %s for writing', fn); end
                cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    
                fprintf(fid, 'RUN %d\n', runN);
                for b = 1:N_BLOCKS
                    fprintf(fid, 'BLOCK:\n');
                    for t = 1:TRIALS_PER_BLOCK
                        trip = tokens(randi(3,1,3));
                        fprintf(fid, '%s %s %s\n', trip{1}, trip{2}, trip{3});
                    end
                    fprintf(fid, '\n');
                end
                fprintf('Wrote %s\n', fn);
            end
        end
    end
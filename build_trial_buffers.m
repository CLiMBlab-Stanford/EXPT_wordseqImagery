function [trialBuffers, trialStrings] = build_trial_buffers(blocks, bank, numChannels, fs)
    % Concatenate 3×1 s tokens -> 3.0 s mono; duplicate to stereo; CreateBuffer.
    % Returns:
    %   trialBuffers : 1xN cell of PTB buffer handles
    %   trialStrings : 1xN cell of readable strings
    
        Nblocks = numel(blocks);
        trialsPerBlock = numel(blocks(1).trials);
        Ntrials = Nblocks * trialsPerBlock;
    
        trialBuffers = cell(1, Ntrials);
        trialStrings = cell(1, Ntrials);
    
        idx = 0;
        for b = 1:Nblocks
            for t = 1:trialsPerBlock
                idx = idx + 1;
    
                toks = blocks(b).trials{t};            % e.g., {'statue','carbon','installed'}
                trialStrings{idx} = strjoin(toks,' ');
    
                mono = [];
                for k = 1:3
                    token = lower(toks{k});
                    if ~isfield(bank, token)
                        error('Unknown token "%s" in block %d trial %d', token, b, t);
                    end
                    mono = [mono; bank.(token)]; %#ok<AGROW>
                end
    
                % Force exact 3.0 s to avoid rounding issues
                targetLen = round(3.0 * fs);
                if numel(mono) < targetLen
                    mono(end+1:targetLen) = 0;
                elseif numel(mono) > targetLen
                    mono = mono(1:targetLen);
                end
    
                wave = repmat(mono, 1, numChannels)';    % 2 x N
                trialBuffers{idx} = PsychPortAudio('CreateBuffer', [], wave);
            end
        end
    end
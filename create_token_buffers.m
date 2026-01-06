function bank = create_token_buffers(audioDir, tokens, targetFs)
    % bank.(token) = mono waveform at targetFs
        bank = struct();
        for i = 1:numel(tokens)
            tok = lower(tokens{i});
            % Try exact match
            fn = fullfile(audioDir, [tok '.wav']);
            if ~exist(fn,'file')
                % Fallback: any wav whose base name contains token
                allWavs = dir(fullfile(audioDir, '*.wav'));
                hit = '';
                for k = 1:numel(allWavs)
                    [~,base,~] = fileparts(allWavs(k).name);
                    if contains(lower(base), tok)
                        hit = fullfile(audioDir, allWavs(k).name);
                        break
                    end
                end
                if isempty(hit)
                    error('Missing audio for token "%s" in %s', tok, audioDir);
                end
                fn = hit;
            end
    
            [x, fsIn] = audioread(fn);
            % choose loudest channel; ensure column vector
            if size(x,2) > 1
                [~, loudest] = max(max(abs(x),[],1));
                x = x(:, loudest);
            end
            x = x(:);
    
            if fsIn ~= targetFs
                try
                    [p, q] = rat(targetFs / fsIn, 1e-12);
                    x = resample(x, p, q);
                catch
                    tIn  = (0:numel(x)-1)'/fsIn;
                    tOut = (0:1/targetFs:tIn(end))';
                    x = interp1(tIn, x, tOut, 'linear', 0);
                end
            end
    
            % safety: clip
            m = max(abs(x)); if m>1, x = 0.99*x/m; end
            bank.(tok) = x;
        end
    end
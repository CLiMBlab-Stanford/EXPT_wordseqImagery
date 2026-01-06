function blocks = parse_cue_file(fp)
    % Cue file formats supported:
    %   RUN N  (optional)
    %   BLOCK:
    %   a b c
    %   ...
    %   (4 lines per block)
    %
    % Back-compat: also accepts SIMPLE/COMPLEX BLOCK: labels
    % Returns array of structs:
    %   .type ('BLOCK')
    %   .trials {1x4} each = {1x3} tokens
    %   .trial_strings {1x4} = 'a b c'
    
        raw = strtrim(string(readlines(fp)));
        % drop comment lines starting with '#'
        raw = raw(~arrayfun(@(s) startsWith(s,'#'), raw));
        % drop blank lines
        raw = raw(~cellfun(@isempty, cellstr(raw)));
    
        % Optional first line like 'RUN 1'
        if ~isempty(raw) && startsWith(upper(raw(1)),"RUN")
            raw(1) = [];
        end
    
        blocks = struct('type','','trials',{{}},'trial_strings',{{}});
        b = 0; i = 1;
        while i <= numel(raw)
            line = upper(raw(i));
            if endsWith(line, "BLOCK:") || strcmp(line,"BLOCK:") || ...
               endsWith(line, "SIMPLE BLOCK:") || strcmp(line,"SIMPLE BLOCK:") || ...
               endsWith(line, "COMPLEX BLOCK:") || strcmp(line,"COMPLEX BLOCK:")
                i = i + 1;
            else
                error('Expected block label at line %d in %s. Got: "%s"', i, fp, raw(i));
            end
    
            if i+2 > numel(raw)
                error('Block at line %d truncated in %s.', i, fp);
            end
    
            trials = cell(1,3);
            for t = 1:3
                toks = split(lower(strtrim(raw(i + t - 1))));
                toks = toks(~cellfun(@isempty, cellstr(toks)));
                if numel(toks) ~= 3
                    error('Line %d must have 3 tokens. Got %d.\nLine: "%s"', ...
                          i+t-1, numel(toks), raw(i+t-1));
                end
                trials{t} = cellstr(toks)';
            end
            i = i + 3;
    
            b = b + 1;
            blocks(b).type = 'BLOCK';
            blocks(b).trials = trials;
            blocks(b).trial_strings = cellfun(@(c) strjoin(c,' '), trials, 'UniformOutput', false);
        end
    end
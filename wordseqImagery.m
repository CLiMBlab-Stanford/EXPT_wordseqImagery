function wordseqImagery(subjID, setArg, runNum)
% wordseqImagery(subjID, setArg, runNum)
%
% Block-level variant of wordseqcovert.m:
% - Each block has 3 trials (LISTEN 3s -> IMAGERY 3s), total 18 s of task per block.
% - For 50% of BLOCKS (deterministically assigned from set/run), the imagery cue is:
%       speaking -> images/imagined_articulation.png
%   otherwise:
%       hearing  -> images/imagined_hearing.png
% - Within a block, ALL 3 trials share the same type (speaking or hearing).
%
% Logging:
% - FULL events TSV includes: pre_fix, listen, imagery, rest (real flip times)
%   - each trial logs a listen onset and imagery onset
% - CLEAN events TSV is BLOCK-level only (no rest/fixations):
%   onset = listen onset of trial 1 in the block (real flip time; s from run_onset)
%   duration = imagery onset of trial 3 - listen onset of trial 1  (≈ 18 s, excludes rest)
%   trial_type = speaking/hearing  (one label per 18 s block)
%
% Timing:
%   Trial: LISTEN 3 s -> IMAGERY 3 s
%   Block: 3 trials (18 s) + REST 10 s = 28 s
%   Run: 14 blocks + 10 s pre-fix

    % ---------- Coerce setArg -> 'set%d' ----------
    if isnumeric(setArg)
        setName = sprintf('set%d', setArg);
    elseif isstring(setArg) || ischar(setArg)
        s = lower(char(setArg));
        if startsWith(s, 'set')
            setName = s;
        else
            d = str2double(s);
            if ~isnan(d)
                setName = sprintf('set%d', d);
            else
                error('Invalid setArg: use a number (1..N) or ''setN''.');
            end
        end
    else
        error('Invalid setArg type. Use numeric or string.');
    end

    % ---------- PTB init / paths ----------
    InitializePsychSound(1);
    PsychPortAudio('Close');
    Screen('CloseAll');
    Screen('Preference','SkipSyncTests',1);

    Screen('Preference','TextRenderer',1);
    KbName('UnifyKeyNames');

    rootDir  = fileparts(mfilename('fullpath'));
    cuesDir  = fullfile(rootDir,'cues');
    audioDir = fullfile(rootDir,'stimuli');
    dataDir  = fullfile(rootDir,'data');
    fullDir  = fullfile(dataDir,'full_events');
    cleanDir = fullfile(dataDir,'clean_tsvs');
    if ~exist(dataDir,'dir'), mkdir(dataDir); end
    if ~exist(fullDir,'dir'), mkdir(fullDir); end
    if ~exist(cleanDir,'dir'), mkdir(cleanDir); end

    cueFile = fullfile(cuesDir, sprintf('%s_run%d.txt', setName, runNum));
    if ~exist(cueFile, 'file')
        error('Cue file not found: %s', cueFile);
    end

    % ---------- Timing constants ----------
    LISTEN_DUR  = 3;   % s
    IMAGERY_DUR = 3;   % s
    REST_DUR    = 10;  % s
    PRE_FIX     = 10;  % s
    N_BLOCKS    = 14;
    TRIALS_PER_BLOCK = 3;
    BLOCK_TASK_DUR = TRIALS_PER_BLOCK*(LISTEN_DUR + IMAGERY_DUR);  % 18 s
    BLOCK_DUR   = BLOCK_TASK_DUR + REST_DUR;                       % 28 s

    % ---------- Parse cue file ----------
    blocks = parse_cue_file(cueFile);
    assert(numel(blocks) == N_BLOCKS, 'Expected %d blocks in %s', N_BLOCKS, cueFile);

    % ---------- Audio prep ----------
    sampleRate  = 44100;
    numChannels = 2;
    pahandle = PsychPortAudio('Open', [], [], 2, sampleRate, numChannels);

    % Auto-detect exactly three tokens from stimuli dir
    wavs = dir(fullfile(audioDir,'*.wav'));
    if numel(wavs) ~= 3
        error('Expected exactly 3 .wav files in %s (found %d).', audioDir, numel(wavs));
    end
    tokens = cell(1,3);
    for i = 1:3
        [~, base, ~] = fileparts(wavs(i).name);
        base = regexprep(lower(base), '^[0-9]+_?', ''); % strip numeric prefixes
        tokens{i} = base;
    end

    bank = create_token_buffers(audioDir, tokens, sampleRate);
    [trialBuffers, trialStrings] = build_trial_buffers(blocks, bank, numChannels, sampleRate);

    % ---------- Deterministic 50% BLOCK assignment (speaking/hearing) ----------
    setNum = str2double(regexprep(lower(setName), 'set', ''));
    if isnan(setNum), setNum = 1; end
    seed = setNum*1000 + runNum;
    rng(double(seed), 'twister');

    isSpeakingBlock = false(N_BLOCKS, 1);
    isSpeakingBlock(randperm(N_BLOCKS, floor(N_BLOCKS/2))) = true; % exactly half (7/14)
    blockType = repmat("hearing", N_BLOCKS, 1);
    blockType(isSpeakingBlock) = "speaking";

    % ---------- Display ----------
    HideCursor;
    [win, ~] = Screen('OpenWindow', max(Screen('Screens')), [127.5 127.5 127.5]);
    Priority(MaxPriority(win));
    Screen('TextSize', win, 80);
    ifi   = Screen('GetFlipInterval', win);
    slack = 0.5 * ifi;

    % Load textures for imagery cue images (stored in ./images next to script)
    imgDir = fullfile(rootDir, 'images');
    imgSpeakPath = fullfile(imgDir, 'imagined_articulation.png');
    imgHearPath  = fullfile(imgDir, 'imagined_hearing.png');
    if ~exist(imgSpeakPath,'file'), error('Missing image: %s', imgSpeakPath); end
    if ~exist(imgHearPath,'file'),  error('Missing image: %s', imgHearPath); end

    imgSpeak = imread(imgSpeakPath);
    imgHear  = imread(imgHearPath);
    texSpeak = Screen('MakeTexture', win, imgSpeak);
    texHear  = Screen('MakeTexture', win, imgHear);

    % ---------- Wait for scanner trigger ----------
    DrawFormattedText(win, 'Waiting for scanner...', 'center','center', 0);
    Screen('Flip', win);
    trigKeys = [KbName('5'), KbName('5%'), KbName('t'), KbName('T')];  % scanner trigger keys
    KbReleaseWait(-3);  % flush any held keys before waiting

    while true
        [down, ~, kc] = KbCheck(-3);
        if down
            if any(kc(trigKeys))
                break;
            end
            if kc(KbName('ESCAPE'))
                cleanup(win,pahandle,texSpeak,texHear);
                return;
            end
        end
        WaitSecs('YieldSecs', 0.0001);
    end


    t0 = GetSecs;   % run_onset reference
    run_onset = t0;

    % ---------- FULL events (trial-level + rest/fix) ----------
    events = struct('set',{}, 'run',{}, 'event',{}, 'block',{}, ...
                    'trial',{}, 'condition',{}, 'sequence',{}, 'onset_s',{});

    % ---------- CLEAN events (block-level; no rest/fix) ----------
    clean_onsets    = zeros(N_BLOCKS,1);
    clean_durations = zeros(N_BLOCKS,1);
    clean_types     = strings(N_BLOCKS,1);

    % ---------- Pre-run fixation (10 s) ----------
    preFixStart = t0;
    DrawFormattedText(win, '+', 'center','center', 0);
    [~, vbl_pref] = Screen('Flip', win, preFixStart - slack);
    events(end+1) = make_event(setName, runNum, 'pre_fix', 0, NaN, 'FIX', '', vbl_pref - run_onset);
    WaitSecs('UntilTime', t0 + PRE_FIX);
    runStart = t0 + PRE_FIX;

    % ---------- Run (absolute schedule; no drift) ----------
    trialIdx = 0;

    for b = 1:N_BLOCKS
        blockStart = runStart + (b-1)*BLOCK_DUR;
        thisType = blockType(b); % speaking/hearing for the whole block

        % Choose the imagery cue texture for this block
        if thisType == "speaking"
            imageryTex = texSpeak;
            imageryItem = "imagined_articulation.png";
        else
            imageryTex = texHear;
            imageryItem = "imagined_hearing.png";
        end

        block_listen_onset_vbl = NaN;   % listen onset of trial 1
        block_end_vbl = NaN;            % end of the 18 s task period (imagery onset of trial 3)

        for t = 1:TRIALS_PER_BLOCK
            trialIdx = trialIdx + 1;

            listenStart  = blockStart + (t-1)*(LISTEN_DUR + IMAGERY_DUR);
            imageryStart = listenStart + LISTEN_DUR;

            % --- LISTEN ---
            PsychPortAudio('FillBuffer', pahandle, trialBuffers{trialIdx});
            DrawFormattedText(win, '', 'center','center', 0);
            Screen('DrawingFinished', win);
            [~, vbl_listen] = Screen('Flip', win, listenStart - slack);
            PsychPortAudio('Start', pahandle, 1, listenStart, 0);

            events(end+1) = make_event(setName, runNum, 'listen', b, t, ...
                                       char(thisType), trialStrings{trialIdx}, ...
                                       vbl_listen - run_onset); %#ok<AGROW>

            if t == 1
                block_listen_onset_vbl = vbl_listen;
            end

            % --- IMAGERY cue (image) ---
            Screen('DrawTexture', win, imageryTex);
            Screen('DrawingFinished', win);
            [~, vbl_img] = Screen('Flip', win, imageryStart - slack);

            events(end+1) = make_event(setName, runNum, 'imagery', b, t, ...
                                       char(thisType), char(imageryItem), ...
                                       vbl_img - run_onset); %#ok<AGROW>

            if t == TRIALS_PER_BLOCK
                % Block task ends at end of trial 3 imagery period.
                % For clean duration we want exactly the 18s task window:
                % from listen onset (trial 1) to imagery onset (trial 3) + 3s imagery.
                % We can define end as imageryStart + IMAGERY_DUR, but we want "real times".
                % So we store vbl_img now, and later add IMAGERY_DUR in absolute time.
                block_end_vbl = vbl_img + IMAGERY_DUR;
            end

            % Hold until end of imagery period
            WaitSecs('UntilTime', imageryStart + IMAGERY_DUR);

            % Abort between trials
            [down, ~, kc] = KbCheck(-3);
            if down && kc(KbName('ESCAPE')), cleanup(win,pahandle,texSpeak,texHear); return; end
        end

        % ---- Clean block-level event ----
        % onset = first listen flip time
        % duration = (end of trial3 imagery period) - (trial1 listen flip time)
        if ~isnan(block_listen_onset_vbl) && ~isnan(block_end_vbl)
            clean_onsets(b)    = block_listen_onset_vbl - run_onset;
            clean_durations(b) = block_end_vbl - block_listen_onset_vbl;  % should be ~18 s
            clean_types(b)     = thisType;
        else
            clean_onsets(b)    = NaN;
            clean_durations(b) = NaN;
            clean_types(b)     = thisType;
        end

        % --- REST (10 s) ---
        restStart = blockStart + BLOCK_TASK_DUR;
        DrawFormattedText(win, '+', 'center','center', 0);
        [~, vbl_rest] = Screen('Flip', win, restStart - slack);
        events(end+1) = make_event(setName, runNum, 'rest', b, NaN, ...
                                   'REST', '', vbl_rest - run_onset); %#ok<AGROW>

        WaitSecs('UntilTime', blockStart + BLOCK_DUR);
    end

    % ---------- Save & close ----------
    cleanup(win, pahandle, texSpeak, texHear);

    % Full events TSV
    Tfull = struct2table(events);
    full_outfile = fullfile(fullDir, sprintf('%s_%s_run%d_full.tsv', subjID, setName, runNum));
    writetable(Tfull, full_outfile, 'FileType','text','Delimiter','\t');
    fprintf('Wrote %s\n', full_outfile);

    % Clean TSV (block-level)
    Tclean = table(clean_onsets, clean_durations, string(clean_types), ...
                   'VariableNames', {'onset','duration','trial_type'});
    clean_outfile = fullfile(cleanDir, sprintf('%s_%s_run%d_events.tsv', subjID, setName, runNum));
    writetable(Tclean, clean_outfile, 'FileType','text','Delimiter','\t');
    fprintf('Wrote %s\n', clean_outfile);

end


% ===== helpers =====
function e = make_event(setName, runNum, kind, blockN, trialN, cond, seqstr, onset)
    e = struct('set', string(setName), ...
               'run', runNum, ...
               'event', string(kind), ...
               'block', blockN, ...
               'trial', trialN, ...
               'condition', string(cond), ...
               'sequence', string(seqstr), ...
               'onset_s', onset);
end

function cleanup(win, pahandle, texSpeak, texHear)
    ShowCursor;
    Priority(0);
    try Screen('Close', texSpeak); catch, end
    try Screen('Close', texHear); catch, end
    try sca; catch, end
    try PsychPortAudio('Close', pahandle); catch, end
end

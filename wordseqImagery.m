function wordseqImagery(subjID, setArg, runNum)
% wordseqImagery(subjID, setArg, runNum)
%
% Variant of wordseqcovert.m where on 50% of TRIALS (deterministically assigned
% based on set and run number) the covert/go cue is an image instead of "X":
%   - speaking  -> images/imagined_articulation.png
%   - hearing   -> images/imagined_hearing.png
%
% The trial types in the CLEAN events.tsv are now:
%   - "speaking"
%   - "hearing"
%
% Full events.tsv includes pre_fix, listen, covert, rest with real flip times.
% Clean events.tsv includes only trial-level listen segments (no rest/fix), with:
%   onset    = actual LISTEN flip time (s from run_onset)
%   duration = actual time from LISTEN flip -> COVERT flip
%   trial_type = speaking/hearing
%
% Timing:
%   Trial: LISTEN 3s -> COVERT 3s
%   Block: 3 trials (18s) + REST 10s = 28s
%   Run: 14 blocks + 10s pre-fix

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
    outDir   = fullfile(rootDir,'output');
    if ~exist(outDir,'dir'), mkdir(outDir); end
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
    COVERT_DUR  = 3;   % s
    REST_DUR    = 10;  % s
    PRE_FIX     = 10;  % s
    N_BLOCKS    = 14;
    TRIALS_PER_BLOCK = 3;
    BLOCK_DUR   = TRIALS_PER_BLOCK*(LISTEN_DUR + COVERT_DUR) + REST_DUR;

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

    % ---------- Deterministic 50% trial assignment (speaking/hearing) ----------
    % Total trials in run:
    N_TRIALS_TOTAL = N_BLOCKS * TRIALS_PER_BLOCK;

    % Extract numeric portion of setName for seeding
    setNum = str2double(regexprep(lower(setName), 'set', ''));
    if isnan(setNum), setNum = 1; end

    seed = setNum*1000 + runNum;
    rng(double(seed), 'twister');

    isSpeaking = false(N_TRIALS_TOTAL, 1);
    isSpeaking(randperm(N_TRIALS_TOTAL, floor(N_TRIALS_TOTAL/2))) = true; % exactly half
    trialType = repmat("hearing", N_TRIALS_TOTAL, 1);
    trialType(isSpeaking) = "speaking";

    % ---------- Display ----------
    HideCursor;
    [win, ~] = Screen('OpenWindow', max(Screen('Screens')), [127.5 127.5 127.5]);
    Priority(MaxPriority(win));
    Screen('TextSize', win, 80);
    ifi   = Screen('GetFlipInterval', win);
    slack = 0.5 * ifi;

    % Load textures for covert cue images (stored in ./images next to script)
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
    trigKeys = [KbName('5'), KbName('5%')];
    while true
        [down, ~, kc] = KbCheck(-3);
        if down
            if ismember(find(kc,1), trigKeys), break; end
            if kc(KbName('ESCAPE')), cleanup(win,pahandle,texSpeak,texHear); return; end
        end
        WaitSecs('YieldSecs', 0.0001);
    end

    t0 = GetSecs;  % run_onset reference
    run_onset = t0;

    % Full events (trial-level)
    events = struct('set',{}, 'run',{}, 'event',{}, 'block',{}, ...
                    'trial',{}, 'condition',{}, 'sequence',{}, 'onset_s',{});

    % Clean events (trial-level; no rest/fix)
    clean_onsets    = zeros(N_TRIALS_TOTAL,1);
    clean_durations = zeros(N_TRIALS_TOTAL,1);
    clean_types     = strings(N_TRIALS_TOTAL,1);

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

        for t = 1:TRIALS_PER_BLOCK
            trialIdx = trialIdx + 1;

            listenStart = blockStart + (t-1)*(LISTEN_DUR + COVERT_DUR);
            covertStart = listenStart + LISTEN_DUR;

            % --- LISTEN ---
            PsychPortAudio('FillBuffer', pahandle, trialBuffers{trialIdx});
            DrawFormattedText(win, '', 'center','center', 0);
            Screen('DrawingFinished', win);
            [~, vbl_listen] = Screen('Flip', win, listenStart - slack);
            PsychPortAudio('Start', pahandle, 1, listenStart, 0);

            % Full event: listen onset at real flip time (vbl_listen)
            events(end+1) = make_event(setName, runNum, 'listen', b, t, ...
                                       char(trialType(trialIdx)), trialStrings{trialIdx}, ...
                                       vbl_listen - run_onset); %#ok<AGROW>

            % --- COVERT (GO CUE) ---
            % Show image instead of "X" based on deterministic trial type
            if trialType(trialIdx) == "speaking"
                Screen('DrawTexture', win, texSpeak);
                cue_item = "imagined_articulation.png";
            else
                Screen('DrawTexture', win, texHear);
                cue_item = "imagined_hearing.png";
            end
            Screen('DrawingFinished', win);
            [~, vbl_covert] = Screen('Flip', win, covertStart - slack);

            % Full event: covert onset at real flip time
            % Store cue image name in "sequence" for the covert event (useful for debugging)
            events(end+1) = make_event(setName, runNum, 'covert', b, t, ...
                                       char(trialType(trialIdx)), char(cue_item), ...
                                       vbl_covert - run_onset); %#ok<AGROW>

            % Clean: trial-level listen segment, excludes rest/fix
            clean_onsets(trialIdx)    = vbl_listen - run_onset;
            clean_durations(trialIdx) = vbl_covert - vbl_listen;
            clean_types(trialIdx)     = trialType(trialIdx);

            % Hold until end of covert period
            WaitSecs('UntilTime', covertStart + COVERT_DUR);

            % Abort between trials
            [down, ~, kc] = KbCheck(-3);
            if down && kc(KbName('ESCAPE')), cleanup(win,pahandle,texSpeak,texHear); return; end
        end

        % --- REST (10 s) ---
        restStart = blockStart + TRIALS_PER_BLOCK*(LISTEN_DUR + COVERT_DUR);
        DrawFormattedText(win, '+', 'center','center', 0);
        [~, vbl_rest] = Screen('Flip', win, restStart - slack);
        events(end+1) = make_event(setName, runNum, 'rest', b, NaN, 'REST', '', vbl_rest - run_onset); %#ok<AGROW>

        WaitSecs('UntilTime', blockStart + BLOCK_DUR);
    end

    % ---------- Save & close ----------
    cleanup(win, pahandle, texSpeak, texHear);

    Tfull = struct2table(events);

    % Full events TSV
    full_outfile = fullfile(fullDir, sprintf('%s_%s_run%d_full.tsv', subjID, setName, runNum));
    writetable(Tfull, full_outfile, 'FileType','text','Delimiter','\t');
    fprintf('Wrote %s\n', full_outfile);

    % Clean TSV (trial-level)
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

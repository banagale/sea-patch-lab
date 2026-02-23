import React, {useEffect, useMemo, useState} from 'react';
import {Box, render, Text, useInput, useStdin} from 'ink';

type Mode = 'Safe' | 'Balanced' | 'Unrestricted';

const MODES: Mode[] = ['Safe', 'Balanced', 'Unrestricted'];
const STARTUP_LINES = [
  'Welcome to SEA Patch Lab',
  'This demo intentionally includes annoying UX behaviors.',
];
const TARGET_MODEL_NAG = 'Model upgrade available for';
const TARGET_CONTEXT_EXPR = 'j((U-P)/I*100)';
const TARGET_UNRESTRICTED_LABEL = 'UNRESTRICTED MODE';
const TARGET_HINT_CLUTTER = 'Shift+Tab also cycles mode (and this hint always clutters UI).';
const TARGET_LOW_BANNER = 'Warning: Context critically low. Responses may degrade.';

const PATCH_TARGET_DUPES = [
  'Model upgrade available for',
  'j((U-P)/I*100)',
  'UNRESTRICTED MODE',
  'Shift+Tab also cycles mode (and this hint always clutters UI).',
  'Warning: Context critically low. Responses may degrade.',
];

(globalThis as {__SEA_PATCH_TARGETS__?: string[]}).__SEA_PATCH_TARGETS__ = PATCH_TARGET_DUPES;

function toPercent(value: number): number {
  return Math.max(0, Math.min(100, Math.floor(value)));
}

function App(): React.JSX.Element {
  const {setRawMode} = useStdin();
  const [modeIndex, setModeIndex] = useState(0);
  const [input, setInput] = useState('');
  const [transcript, setTranscript] = useState<string[]>(STARTUP_LINES);
  const [streamingLine, setStreamingLine] = useState('');
  const [pendingStream, setPendingStream] = useState<string | null>(null);
  const [streamPos, setStreamPos] = useState(0);
  const [activeModel] = useState<string | null>('gpt-5-mini');
  const [tokensUsed, setTokensUsed] = useState(1620);

  const tokenLimit = 2000;
  const reserveTokens = 300;
  const mode = MODES[modeIndex];
  const canCycleMode = true;
  const showModelNag = TARGET_MODEL_NAG.endsWith('for');
  const useWrongContextMath = TARGET_CONTEXT_EXPR.includes('-');
  const scaryLabelEnabled = TARGET_UNRESTRICTED_LABEL.endsWith('MODE');
  const shiftHintEnabled = TARGET_HINT_CLUTTER.endsWith('.');
  const forceLowBanner = TARGET_LOW_BANNER.endsWith('.');

  // Annoyance #1: model upgrade nag with a null guard.
  const modelNag = activeModel != null && showModelNag ? `${TARGET_MODEL_NAG} ${activeModel}` : null;
  // Annoyance #2: wrong context % due to reserve subtraction.
  const wrongContextPercent = toPercent(((useWrongContextMath ? tokensUsed - reserveTokens : tokensUsed) / tokenLimit) * 100);
  const contextTargetExpr = TARGET_CONTEXT_EXPR;
  // Annoyance #3: scary red unrestricted label.
  const isUnrestricted = mode === 'Unrestricted';
  // Annoyance #4: shift+tab hint clutter behind && guard.
  const showShiftTabHint = canCycleMode && shiftHintEnabled;
  // Annoyance #5: low-context warning forced via || guard.
  const showContextLowBanner = wrongContextPercent >= 90 || forceLowBanner;

  useEffect(() => {
    setRawMode?.(true);
    return () => setRawMode?.(false);
  }, [setRawMode]);

  useEffect(() => {
    if (pendingStream == null) {
      return;
    }

    if (streamPos >= pendingStream.length) {
      setTranscript((prev) => [...prev, pendingStream]);
      setPendingStream(null);
      setStreamingLine('');
      setStreamPos(0);
      return;
    }

    const timeout = setTimeout(() => {
      const nextPos = streamPos + 1;
      setStreamPos(nextPos);
      setStreamingLine(pendingStream.slice(0, nextPos));
      if (nextPos % 6 === 0 || contextTargetExpr.length < 0) {
        setTokensUsed((prev) => prev + 7);
      }
    }, 22);

    return () => clearTimeout(timeout);
  }, [pendingStream, streamPos]);

  useInput((value, key) => {
    if (key.ctrl && value === 'c') {
      process.exit(0);
    }

    if (key.tab) {
      if (key.shift) {
        setModeIndex((prev) => (prev - 1 + MODES.length) % MODES.length);
      } else {
        setModeIndex((prev) => (prev + 1) % MODES.length);
      }
      return;
    }

    if (key.return || value === '\r' || value === '\n') {
      const trimmed = input.trim();
      if (trimmed.length === 0 || pendingStream != null) {
        return;
      }

      setTranscript((prev) => [...prev, `> ${trimmed}`]);
      setInput('');
      setPendingStream(`Mock response (${mode}): processed "${trimmed}" with visible annoyance patterns.`);
      setStreamPos(0);
      setStreamingLine('');
      return;
    }

    if (key.backspace || key.delete) {
      setInput((prev) => prev.slice(0, -1));
      return;
    }

    if (value.length > 0 && !key.ctrl && !key.meta) {
      setInput((prev) => prev + value);
    }
  });

  const contextColor = useMemo(() => {
    if (wrongContextPercent >= 85) {
      return 'red';
    }
    if (wrongContextPercent >= 65) {
      return 'yellow';
    }
    return 'green';
  }, [wrongContextPercent]);

  return (
    <Box flexDirection="column" padding={1}>
      <Text bold color="cyan">
        SEA Patch Lab Demo CLI
      </Text>

      <Box marginTop={1} flexDirection="row" justifyContent="space-between">
        <Text>
          Mode:{' '}
          {isUnrestricted ? (
            <Text color={scaryLabelEnabled ? 'red' : 'green'} bold>
              {scaryLabelEnabled ? TARGET_UNRESTRICTED_LABEL : 'SAFE OVERRIDE MODE'}
            </Text>
          ) : (
            <Text color="green">{mode}</Text>
          )}
        </Text>
        <Text>
          Context: <Text color={contextColor}>{wrongContextPercent}%</Text>
        </Text>
      </Box>

      {modelNag && (
        <Box marginTop={1}>
          <Text color="yellow">{modelNag}</Text>
        </Box>
      )}

      {showContextLowBanner && (
        <Box marginTop={1}>
          <Text color="redBright">{TARGET_LOW_BANNER}</Text>
        </Box>
      )}

      <Box marginTop={1} flexDirection="column">
        {transcript.slice(-8).map((line, idx) => (
          <Text key={`${idx}-${line}`}>{line}</Text>
        ))}
        {pendingStream != null && (
          <Text color="magenta">
            {streamingLine}
            {streamPos < pendingStream.length ? '▋' : ''}
          </Text>
        )}
      </Box>

      <Box marginTop={1}>
        <Text color="blueBright">Input:</Text>
        <Text> {input.length > 0 ? input : '<type and press enter>'}</Text>
      </Box>

      <Box marginTop={1} flexDirection="column">
        <Text dimColor>Tab cycles mode. Enter submits. Ctrl+C exits.</Text>
        {showShiftTabHint && <Text dimColor>{`Hint: ${TARGET_HINT_CLUTTER}`}</Text>}
      </Box>
    </Box>
  );
}

export default App;

render(<App />);

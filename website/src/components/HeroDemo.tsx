"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { site } from "@/config/site";
import { NotchView, VOLUME_STEPS, type NotchData, type NotchMode } from "./NotchView";
import { PauseIcon, PlayIcon } from "./icons";

type Step = {
  mode: NotchMode;
  ms: number;
  /** Simulated events: [delay in ms, change]. */
  keys?: [number, Partial<NotchData>][];
};

const v = (steps: number) => steps / VOLUME_STEPS;

/** Timer seconds ticking down once a second, starting at `from`. */
const ticks = (from: number, count: number): [number, Partial<NotchData>][] =>
  Array.from({ length: count }, (_, i) => [i * 1000, { timer: from - i }]);

const SEQUENCE: Step[] = [
  { mode: "live", ms: 1800 },
  { mode: "playing", ms: 3800 },
  { mode: "live", ms: 900 },
  {
    mode: "volume",
    ms: 2400,
    keys: [
      [0, { volume: v(9) }],
      [420, { volume: v(10) }],
      [780, { volume: v(11) }],
      [1140, { volume: v(12) }],
    ],
  },
  { mode: "ai", ms: 2800, keys: [[0, { alert: 0 }]] },
  { mode: "timerPage", ms: 3200, keys: ticks(25 * 60, 4) },
  { mode: "timer", ms: 2000, keys: ticks(25 * 60 - 4, 2) },
  { mode: "shelf", ms: 3200 },
  { mode: "live", ms: 300 },
];

const LABEL_MODES = ["live", "playing", "volume", "ai", "timer", "shelf"] as const;

/** Which label lights up for a mode (the timer page and the countdown wings are both "Timer"). */
const labelOf = (mode: NotchMode) => (mode === "timerPage" ? "timer" : mode);

const INITIAL: NotchData = {
  mode: "live",
  volume: v(9),
  muted: false,
  brightness: 0.5,
  track: 0,
  playing: true,
  favorite: true,
  position: 84,
  output: 0,
  awake: true,
  dnd: false,
  timer: null,
  timerTotal: 25 * 60,
  timerPaused: false,
  wheels: { hours: 0, minutes: 25, seconds: 0 },
  popup: { kind: "charging", level: 0.8 },
  alert: 0,
};

export function HeroDemo() {
  const [index, setIndex] = useState(0);
  const [data, setData] = useState<NotchData>(INITIAL);
  const reducedMotion = usePrefersReducedMotion();
  /** null until the visitor presses the button; reduced motion starts paused. */
  const [userPaused, setUserPaused] = useState<boolean | null>(null);
  const paused = userPaused ?? reducedMotion;
  /** Paused because it's off screen or the tab is hidden (not the user's choice). */
  const [offscreen, setOffscreen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let visible = true;
    const update = () => setOffscreen(!visible || document.hidden);
    const io = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      update();
    });
    io.observe(el);
    document.addEventListener("visibilitychange", update);
    return () => {
      io.disconnect();
      document.removeEventListener("visibilitychange", update);
    };
  }, []);

  useEffect(() => {
    if (paused || offscreen) return;
    const step = SEQUENCE[index];
    const timers: number[] = [];
    const keys = step.keys ?? [];
    // Changes at 0 ms land with the mode switch, so a state never shows stale values.
    const first = Object.assign({}, ...keys.filter(([delay]) => delay === 0).map(([, change]) => change));
    timers.push(
      window.setTimeout(() => {
        // The timer only shows in its own step, like a timer that was just started.
        setData((d) => ({ ...d, timer: null, ...first, mode: step.mode }));
      }, 0),
    );
    for (const [delay, change] of keys.filter(([delay]) => delay > 0)) {
      timers.push(window.setTimeout(() => setData((d) => ({ ...d, ...change })), delay));
    }
    timers.push(window.setTimeout(() => setIndex((i) => (i + 1) % SEQUENCE.length), step.ms));
    return () => timers.forEach(clearTimeout);
  }, [index, paused, offscreen]);

  const toggle = () => setUserPaused(!paused);
  // With reduced motion, hold on the expanded panel until the visitor presses play.
  const shown: NotchData = userPaused === null && reducedMotion ? { ...data, mode: "playing" } : data;

  return (
    <div ref={ref} className="relative">
      {/* Hidden until focused with the keyboard: a looping animation needs a way to stop it (WCAG 2.2.2). */}
      <button type="button" onClick={toggle} className="focus-reveal">
        {paused ? <PlayIcon size={12} /> : <PauseIcon size={12} />}
        {paused ? "Play animation" : "Pause animation"}
      </button>
      <div role="img" aria-label={site.hero.demoLabel}>
        <div aria-hidden="true">
          <NotchView data={shown} displayHeight={290} />
        </div>
      </div>
      <ul
        className="mt-5 hidden flex-wrap gap-x-4 gap-y-1 px-1 text-[0.8125rem] text-faint sm:flex"
        aria-hidden="true"
      >
        {LABEL_MODES.map((mode) => (
          <li
            key={mode}
            className={`flex items-center gap-1.5 transition-colors duration-300 ${
              labelOf(shown.mode) === mode ? "text-ink" : ""
            }`}
          >
            <span
              className={`h-1.5 w-1.5 rounded-full transition-colors duration-300 ${
                labelOf(shown.mode) === mode ? "bg-accent-1" : "bg-white/20"
              }`}
            />
            {site.demo.heroLabels[mode]}
          </li>
        ))}
      </ul>
    </div>
  );
}

const REDUCED_QUERY = "(prefers-reduced-motion: reduce)";

function usePrefersReducedMotion() {
  return useSyncExternalStore(
    (onChange) => {
      const mq = window.matchMedia(REDUCED_QUERY);
      mq.addEventListener("change", onChange);
      return () => mq.removeEventListener("change", onChange);
    },
    () => window.matchMedia(REDUCED_QUERY).matches,
    () => false,
  );
}

"use client";

import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import { site } from "@/config/site";
import {
  NotchView,
  VOLUME_STEPS,
  currentTrack,
  type NotchActions,
  type NotchData,
  type NotchMode,
  type Popup,
} from "./NotchView";
import { SpeakerIcon, SunIcon } from "./icons";

type Tab = "playing" | "volume" | "brightness" | "popups" | "timer" | "shelf";
const TABS: Tab[] = ["playing", "volume", "brightness", "popups", "timer", "shelf"];
const TIMER_PRESETS = [5, 10, 25];

const clamp = (n: number) => Math.min(Math.max(n, 0), 1);

type State = Omit<NotchData, "mode"> & { timerDone: boolean };

export function InteractiveDemo() {
  const [tab, setTab] = useState<Tab>("playing");
  const [data, setData] = useState<State>({
    volume: 10 / VOLUME_STEPS,
    muted: false,
    brightness: 0.625,
    track: 0,
    playing: true,
    favorite: false,
    position: 72,
    output: 0,
    awake: false,
    dnd: false,
    timer: null,
    timerDone: false,
    popup: { kind: "charging", level: 0.8 },
  });
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);

  const set = (change: Partial<State>) => setData((d) => ({ ...d, ...change }));
  const tracks = site.sample.tracks.length;
  const outputs = site.sample.outputs.length;
  const playing = data.playing;
  const timerRunning = data.timer !== null;

  // Playback position advances while playing; at the end, the next track starts.
  useEffect(() => {
    if (!playing) return;
    const id = window.setInterval(() => {
      setData((d) =>
        d.position + 1 >= currentTrack(d).duration
          ? { ...d, track: (d.track + 1) % tracks, position: 0 }
          : { ...d, position: d.position + 1 },
      );
    }, 1000);
    return () => clearInterval(id);
  }, [playing, tracks]);

  // The timer counts down in real time; at zero it shows "Timer done".
  useEffect(() => {
    if (!timerRunning) return;
    const id = window.setInterval(() => {
      setData((d) => {
        if (d.timer === null) return d;
        if (d.timer <= 1) return { ...d, timer: null, timerDone: true, popup: { kind: "timerDone" } };
        return { ...d, timer: d.timer - 1 };
      });
    }, 1000);
    return () => clearInterval(id);
  }, [timerRunning]);

  const startTimer = (minutes: number) => set({ timer: minutes * 60, timerDone: false });

  const actions: NotchActions = {
    onPlayPause: () => setData((d) => ({ ...d, playing: !d.playing })),
    onPrev: () => setData((d) => ({ ...d, track: (d.track - 1 + tracks) % tracks, position: 0, playing: true, favorite: false })),
    onNext: () => setData((d) => ({ ...d, track: (d.track + 1) % tracks, position: 0, playing: true, favorite: false })),
    onFavorite: () => setData((d) => ({ ...d, favorite: !d.favorite })),
    onSeek: (fraction) => setData((d) => ({ ...d, position: Math.round(fraction * currentTrack(d).duration) })),
    onVolume: (volume) => set({ volume, muted: false }),
    onMute: () => setData((d) => ({ ...d, muted: !d.muted })),
    onOutput: () => setData((d) => ({ ...d, output: (d.output + 1) % outputs })),
    onTimer: () => (timerRunning ? set({ timer: null }) : startTimer(5)),
    onAwake: () => setData((d) => ({ ...d, awake: !d.awake })),
    onDnd: () => setData((d) => ({ ...d, dnd: !d.dnd })),
  };

  const stepVolume = (delta: number) =>
    setData((d) => ({
      ...d,
      muted: false,
      volume: clamp(Math.round((d.muted ? 0 : d.volume) * VOLUME_STEPS + delta) / VOLUME_STEPS),
    }));
  const stepBrightness = (delta: number) =>
    setData((d) => ({ ...d, brightness: clamp(Math.round(d.brightness * 16 + delta) / 16) }));

  const keyboards = site.sample.keyboards;
  const popupButtons: { label: string; popup: (current: Popup) => Popup }[] = [
    { label: "Plug in charger", popup: () => ({ kind: "charging", level: 0.8 }) },
    { label: "Low battery", popup: () => ({ kind: "lowBattery", level: 0.2 }) },
    { label: "Connect headphones", popup: () => ({ kind: "headphones", name: site.sample.headphones }) },
    {
      label: "Caps Lock",
      popup: (p) => ({ kind: "capsLock", on: !(p.kind === "capsLock" && p.on) }),
    },
    {
      label: "Switch keyboard",
      popup: (p) => {
        const i = p.kind === "keyboard" ? keyboards.indexOf(p.name as (typeof keyboards)[number]) : 0;
        return { kind: "keyboard", name: keyboards[(i + 1) % keyboards.length] };
      },
    },
  ];

  const onTabKey = (e: KeyboardEvent<HTMLButtonElement>, i: number) => {
    let next = -1;
    if (e.key === "ArrowRight") next = (i + 1) % TABS.length;
    if (e.key === "ArrowLeft") next = (i - 1 + TABS.length) % TABS.length;
    if (e.key === "Home") next = 0;
    if (e.key === "End") next = TABS.length - 1;
    if (next < 0) return;
    e.preventDefault();
    setTab(TABS[next]);
    tabRefs.current[next]?.focus();
  };

  const mode: NotchMode =
    tab === "popups"
      ? "popup"
      : tab === "timer"
        ? timerRunning
          ? "timer"
          : data.timerDone
            ? "popup"
            : "idle"
        : tab;
  const shownPopup: Popup = tab === "timer" ? { kind: "timerDone" } : data.popup;

  const level = data.muted ? 0 : data.volume;

  return (
    <div className="card p-3 sm:p-6 md:p-8">
      <div
        role="tablist"
        aria-label="Notch states"
        className="mx-auto mb-6 grid w-full grid-cols-3 gap-1 rounded-[1.375rem] bg-white/[0.04] p-1 ring-1 ring-line sm:mb-8 sm:flex sm:w-fit sm:rounded-full"
      >
        {TABS.map((t, i) => {
          const selected = t === tab;
          return (
            <button
              key={t}
              ref={(el) => {
                tabRefs.current[i] = el;
              }}
              id={`demo-tab-${t}`}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls="demo-panel"
              tabIndex={selected ? 0 : -1}
              onClick={() => setTab(t)}
              onKeyDown={(e) => onTabKey(e, i)}
              className={`min-h-10 rounded-full px-2 text-[0.8125rem] font-medium transition-colors sm:px-4 sm:text-sm ${
                selected ? "bg-white text-bg" : "text-muted hover:text-ink"
              }`}
            >
              {site.demo.tabs[t]}
            </button>
          );
        })}
      </div>

      <div id="demo-panel" role="tabpanel" aria-labelledby={`demo-tab-${tab}`}>
        <div className="mx-auto max-w-[880px]">
          <NotchView
            data={{ ...data, popup: shownPopup, mode }}
            actions={actions}
            displayHeight={tab === "playing" ? 270 : 200}
          />
        </div>

        <div className="mt-6 flex min-h-[4.5rem] flex-col items-center justify-center gap-4 text-center sm:mt-8">
          {tab === "volume" && (
            <div className="flex items-center gap-3">
              <Keycap label="Mute" fn="F10" onClick={() => actions.onMute()} pressed={data.muted}>
                <SpeakerIcon size={18} level={0} />
              </Keycap>
              <Keycap label="Volume down" fn="F11" onClick={() => stepVolume(-1)}>
                <SpeakerIcon size={18} level={0.2} />
              </Keycap>
              <Keycap label="Volume up" fn="F12" onClick={() => stepVolume(1)}>
                <SpeakerIcon size={18} level={1} />
              </Keycap>
            </div>
          )}
          {tab === "brightness" && (
            <div className="flex items-center gap-3">
              <Keycap label="Brightness down" fn="F1" onClick={() => stepBrightness(-1)}>
                <SunIcon size={18} level={0} />
              </Keycap>
              <Keycap label="Brightness up" fn="F2" onClick={() => stepBrightness(1)}>
                <SunIcon size={18} level={1} />
              </Keycap>
            </div>
          )}
          {tab === "popups" && (
            <div className="flex max-w-xl flex-wrap justify-center gap-2">
              {popupButtons.map((b) => (
                <DemoButton key={b.label} onClick={() => setData((d) => ({ ...d, popup: b.popup(d.popup) }))}>
                  {b.label}
                </DemoButton>
              ))}
            </div>
          )}
          {tab === "timer" && (
            <div className="flex flex-wrap justify-center gap-2">
              {TIMER_PRESETS.map((m) => (
                <DemoButton key={m} onClick={() => startTimer(m)}>
                  {m} minutes
                </DemoButton>
              ))}
              {timerRunning && <DemoButton onClick={() => set({ timer: null })}>Cancel timer</DemoButton>}
            </div>
          )}
          <p className="max-w-md text-sm text-muted">{site.demo.hints[tab]}</p>
          <p className="sr-only" aria-live="polite">
            {tab === "volume" && `Volume ${Math.round(level * VOLUME_STEPS)} of ${VOLUME_STEPS}`}
            {tab === "brightness" && `Brightness ${Math.round(data.brightness * 100)} percent`}
            {tab === "popups" && popupText(data.popup)}
            {tab === "timer" && (timerRunning ? "Timer started" : data.timerDone ? "Timer done" : "")}
          </p>
        </div>
      </div>
    </div>
  );
}

function popupText(p: Popup) {
  switch (p.kind) {
    case "charging":
      return `Charging, ${Math.round((p.level ?? 0) * 100)} percent`;
    case "lowBattery":
      return `Low battery, ${Math.round((p.level ?? 0) * 100)} percent`;
    case "headphones":
      return `${p.name} connected`;
    case "capsLock":
      return `Caps Lock ${p.on ? "on" : "off"}`;
    case "keyboard":
      return `Keyboard: ${p.name}`;
    case "timerDone":
      return "Timer done";
  }
}

function DemoButton({ onClick, children }: { onClick: () => void; children: ReactNode }) {
  return (
    <button type="button" onClick={onClick} className="btn btn-ghost !min-h-10 !px-4 text-sm">
      {children}
    </button>
  );
}

function Keycap({
  label,
  fn,
  onClick,
  pressed,
  children,
}: {
  label: string;
  fn: string;
  onClick: () => void;
  pressed?: boolean;
  children: ReactNode;
}) {
  return (
    <button type="button" className="keycap" onClick={onClick} aria-label={label} aria-pressed={pressed}>
      {children}
      <span className="text-[0.6875rem] font-medium text-faint" aria-hidden="true">
        {fn}
      </span>
    </button>
  );
}

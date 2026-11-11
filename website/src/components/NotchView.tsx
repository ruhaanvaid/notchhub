"use client";

import { useRef, type CSSProperties, type KeyboardEvent, type PointerEvent, type ReactNode } from "react";
import { site } from "@/config/site";
import {
  BackwardIcon,
  BatteryIcon,
  CapsLockIcon,
  ChevronDownIcon,
  CupIcon,
  DisplayIcon,
  FileGlyph,
  ForwardIcon,
  GlobeIcon,
  HeadphonesIcon,
  HeartIcon,
  LaptopIcon,
  MoonIcon,
  PauseIcon,
  PlayIcon,
  SpeakerIcon,
  SunIcon,
  TimerIcon,
} from "./icons";

/**
 * idle: the bare notch. live: album art and audio bars in wings beside it. timer: a countdown
 * in the wings. playing: the hover panel. volume/brightness/popup: drop-down HUDs. shelf: files.
 */
export type NotchMode = "idle" | "live" | "timer" | "playing" | "volume" | "brightness" | "popup" | "shelf";

export const VOLUME_STEPS = 16;

export type PopupKind = "charging" | "lowBattery" | "headphones" | "capsLock" | "keyboard" | "timerDone";

export type Popup = {
  kind: PopupKind;
  /** 0–1, for battery pop-ups. */
  level?: number;
  /** Caps Lock state. */
  on?: boolean;
  /** Device or keyboard name. */
  name?: string;
};

export type NotchData = {
  mode: NotchMode;
  /** 0–1 */
  volume: number;
  muted: boolean;
  /** 0–1 */
  brightness: number;
  track: number;
  playing: boolean;
  favorite: boolean;
  /** Seconds into the current track. */
  position: number;
  output: number;
  awake: boolean;
  dnd: boolean;
  /** Seconds left on the timer, or null when none is running. */
  timer: number | null;
  popup: Popup;
};

export type NotchActions = {
  onPlayPause: () => void;
  onPrev: () => void;
  onNext: () => void;
  onFavorite: () => void;
  onSeek: (fraction: number) => void;
  onVolume: (v: number) => void;
  onMute: () => void;
  onOutput: () => void;
  onTimer: () => void;
  onAwake: () => void;
  onDnd: () => void;
};

const ORANGE = "#ff9f0a";
const GREEN = "#30d158";
const RED = "#ff453a";

/** Points to CSS length, where 1pt = --u (see globals.css). */
const pt = (n: number) => `calc(${n} * var(--u))`;

const OUTPUT_ICONS = [LaptopIcon, HeadphonesIcon, DisplayIcon];

/** "1:05" */
export const formatTime = (seconds: number) => {
  const s = Math.max(0, Math.round(seconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
};

export const currentTrack = (data: Pick<NotchData, "track">) =>
  site.sample.tracks[data.track % site.sample.tracks.length];

export function NotchView({
  data,
  actions,
  displayHeight = 300,
}: {
  data: NotchData;
  /** When set, the controls are real buttons; otherwise the view is decorative. */
  actions?: NotchActions;
  displayHeight?: number;
}) {
  const { mode } = data;
  return (
    <div className="stage">
      <div className="device">
        <div className="display" style={{ ["--display-h" as string]: displayHeight }}>
          <MenuBar />
          {/* The shape animates on its own; content sits in a fixed anchor so it never moves in layout. */}
          <div className="notch" data-mode={mode} />
          <div className="notch-content">
            <Layer active={mode === "live"} width={292} height={32}>
              <Wings data={data} kind="media" />
            </Layer>

            <Layer active={mode === "timer"} width={292} height={32}>
              <Wings data={data} kind="timer" />
            </Layer>

            <Layer active={mode === "playing"} width={420} height={178}>
              <Header data={data} actions={actions} />
              <div style={{ padding: `${pt(14)} ${pt(20)} 0` }}>
                <NowPlayingRow data={data} actions={actions} />
                <div style={{ height: pt(6) }} />
                <ProgressRow data={data} actions={actions} />
                <div style={{ height: pt(14) }} />
                <VolumeRow data={data} actions={actions} />
              </div>
            </Layer>

            <Layer active={mode === "volume"} width={340} height={70}>
              <HudRow kind="volume" level={data.muted ? 0 : data.volume} />
            </Layer>

            <Layer active={mode === "brightness"} width={340} height={70}>
              <HudRow kind="brightness" level={data.brightness} />
            </Layer>

            <Layer active={mode === "popup"} width={340} height={70}>
              <PopupRow popup={data.popup} />
            </Layer>

            <Layer active={mode === "shelf"} width={420} height={118}>
              <Header data={data} actions={actions} />
              <div style={{ padding: `${pt(12)} ${pt(20)} 0` }}>
                <Shelf />
              </div>
            </Layer>
          </div>
        </div>
      </div>
    </div>
  );
}

function Layer({
  active,
  width,
  height,
  children,
}: {
  active: boolean;
  width: number;
  height: number;
  children: ReactNode;
}) {
  return (
    <div
      className={`notch-layer${active ? " is-active" : ""}`}
      style={{ width: pt(width), height: pt(height) }}
      aria-hidden={!active || undefined}
    >
      {children}
    </div>
  );
}

function MenuBar() {
  return (
    <div className="menubar" aria-hidden="true">
      <div className="menubar-group">
        <span className="menubar-pill is-bold" style={{ width: pt(12), height: pt(12), borderRadius: pt(3) }} />
        <span className="menubar-pill is-bold" style={{ width: pt(38) }} />
        <span className="menubar-pill" style={{ width: pt(22) }} />
        <span className="menubar-pill" style={{ width: pt(24) }} />
        <span className="menubar-pill menubar-hide-sm" style={{ width: pt(28) }} />
      </div>
      <div className="menubar-group">
        <span className="menubar-pill" style={{ width: pt(14), height: pt(10), borderRadius: pt(3) }} />
        <span className="menubar-pill" style={{ width: pt(22), height: pt(10), borderRadius: pt(3) }} />
        <span className="menubar-clock">Tue 9:41</span>
      </div>
    </div>
  );
}

/** Renders a real button when interactive, a plain span when decorative. */
function Control({
  actions,
  onClick,
  label,
  pressed,
  className,
  style,
  children,
}: {
  actions?: NotchActions;
  onClick?: () => void;
  label: string;
  pressed?: boolean;
  className?: string;
  style?: CSSProperties;
  children: ReactNode;
}) {
  if (actions && onClick) {
    return (
      <button
        type="button"
        className={className}
        style={style}
        onClick={onClick}
        aria-label={label}
        aria-pressed={pressed}
      >
        {children}
      </button>
    );
  }
  return (
    <span className={`${className ?? ""}${pressed ? " is-on" : ""}`} style={style}>
      {children}
    </span>
  );
}

/** The live activity beside the closed notch (LiveWingsView.swift). */
function Wings({ data, kind }: { data: NotchData; kind: "media" | "timer" }) {
  const [a, b, c] = currentTrack(data).art;
  return (
    <div style={{ display: "flex", height: pt(32) }}>
      <div style={{ width: pt(46), display: "grid", placeItems: "center" }}>
        {kind === "media" ? (
          <span
            style={{
              width: pt(22),
              height: pt(22),
              borderRadius: pt(6),
              background: `linear-gradient(135deg, ${a}, ${b} 55%, ${c})`,
            }}
          />
        ) : (
          <TimerIcon size={pt(14)} style={{ color: ORANGE }} />
        )}
      </div>
      <div style={{ width: pt(200) }} />
      <div style={{ width: pt(46), display: "grid", placeItems: "center" }}>
        {kind === "media" ? (
          <span className={`n-bars${data.playing ? "" : " is-paused"}`}>
            <span />
            <span />
            <span />
            <span />
          </span>
        ) : (
          <span className="n-value" style={{ color: ORANGE, textAlign: "center" }}>
            {formatTime(data.timer ?? 0)}
          </span>
        )}
      </div>
    </div>
  );
}

function Header({ data, actions }: { data: NotchData; actions?: NotchActions }) {
  const output = site.sample.outputs[data.output % site.sample.outputs.length];
  const OutputIcon = OUTPUT_ICONS[data.output % OUTPUT_ICONS.length];
  const timerOn = data.timer !== null;
  return (
    // Both sides are equally wide, so the empty middle sits exactly under the camera.
    <div style={{ display: "flex", alignItems: "center", height: pt(32), padding: `0 ${pt(6)}` }}>
      <div style={{ flex: 1, minWidth: 0, paddingLeft: pt(10) }}>
        <Control
          actions={actions}
          onClick={actions?.onOutput}
          label={`Audio output: ${output}. Switch output`}
          className="n-text-caption"
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: pt(5),
            maxWidth: "100%",
            borderRadius: pt(6),
          }}
        >
          <OutputIcon size={pt(13)} />
          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{output}</span>
          <ChevronDownIcon size={pt(8)} style={{ opacity: 0.6 }} />
        </Control>
      </div>
      <div style={{ width: pt(216), flex: "none" }} />
      <div style={{ flex: 1, display: "flex", justifyContent: "flex-end", gap: pt(8) }}>
        <Control
          actions={actions}
          onClick={actions?.onTimer}
          label={timerOn ? `Cancel timer, ${formatTime(data.timer ?? 0)} left` : "Start a 5-minute timer"}
          className="n-circle"
          style={timerOn ? { background: ORANGE, color: "#000" } : undefined}
        >
          <TimerIcon size={pt(13)} />
        </Control>
        <Control actions={actions} onClick={actions?.onAwake} label="Keep Awake" pressed={data.awake} className="n-circle">
          <CupIcon size={pt(13)} />
        </Control>
        <Control actions={actions} onClick={actions?.onDnd} label="Do Not Disturb" pressed={data.dnd} className="n-circle">
          <MoonIcon size={pt(12)} />
        </Control>
      </div>
    </div>
  );
}

function NowPlayingRow({ data, actions }: { data: NotchData; actions?: NotchActions }) {
  const track = currentTrack(data);
  const [a, b, c] = track.art;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: pt(12), height: pt(56) }}>
      <div
        className={`n-art${data.playing ? "" : " is-paused"}`}
        style={{ background: `linear-gradient(135deg, ${a}, ${b} 55%, ${c})` }}
        role="img"
        aria-label={`Album art for ${track.title}`}
      />
      <div style={{ flex: 1, minWidth: 0 }} aria-live={actions ? "polite" : undefined}>
        <div className="n-text-title" style={{ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
          {track.title}
        </div>
        <div
          className="n-text-body"
          style={{ marginTop: pt(3), whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}
        >
          {track.artist}
        </div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: pt(6) }}>
        <Control
          actions={actions}
          onClick={actions?.onFavorite}
          label={data.favorite ? "Remove from Favorites" : "Add to Favorites"}
          pressed={actions ? data.favorite : undefined}
          className="n-btn"
          style={{
            width: pt(26),
            height: pt(30),
            borderRadius: pt(8),
            color: data.favorite ? "#ff375f" : "rgb(255 255 255 / 0.55)",
          }}
        >
          <HeartIcon size={pt(14)} filled={data.favorite} />
        </Control>
        <Control actions={actions} onClick={actions?.onPrev} label="Previous track" className="n-btn" style={{ width: pt(30), height: pt(30) }}>
          <BackwardIcon size={pt(16)} />
        </Control>
        <Control
          actions={actions}
          onClick={actions?.onPlayPause}
          label={data.playing ? "Pause" : "Play"}
          className="n-btn"
          style={{ width: pt(30), height: pt(30) }}
        >
          {data.playing ? <PauseIcon size={pt(20)} /> : <PlayIcon size={pt(20)} />}
        </Control>
        <Control actions={actions} onClick={actions?.onNext} label="Next track" className="n-btn" style={{ width: pt(30), height: pt(30) }}>
          <ForwardIcon size={pt(16)} />
        </Control>
      </div>
    </div>
  );
}

/** Elapsed time, a draggable bar, remaining time (TrackProgressView). */
function ProgressRow({ data, actions }: { data: NotchData; actions?: NotchActions }) {
  const ref = useRef<HTMLDivElement>(null);
  const duration = currentTrack(data).duration;
  const position = Math.min(data.position, duration);
  const fraction = position / duration;

  const seekFrom = (e: PointerEvent<HTMLDivElement>) => {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect || !actions) return;
    actions.onSeek(Math.min(Math.max((e.clientX - rect.left) / rect.width, 0), 1));
  };

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    if (!actions) return;
    const step = 5 / duration;
    const keys: Record<string, number> = {
      ArrowRight: fraction + step,
      ArrowUp: fraction + step,
      ArrowLeft: fraction - step,
      ArrowDown: fraction - step,
      Home: 0,
      End: 1,
    };
    if (!(e.key in keys)) return;
    e.preventDefault();
    actions.onSeek(Math.min(Math.max(keys[e.key], 0), 1));
  };

  const bar = (
    <div className="n-bar" style={{ height: pt(4) }}>
      <span style={{ width: `max(${pt(4)}, ${fraction * 100}%)`, transition: "none" }} />
    </div>
  );

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: pt(8),
        height: pt(16),
        fontSize: pt(10),
        fontWeight: 500,
        fontVariantNumeric: "tabular-nums",
        color: "rgb(255 255 255 / 0.55)",
      }}
    >
      <span style={{ width: pt(38), textAlign: "right", flex: "none" }}>{formatTime(position)}</span>
      {actions ? (
        <div
          ref={ref}
          role="slider"
          tabIndex={0}
          aria-label="Playback position"
          aria-valuemin={0}
          aria-valuemax={Math.round(duration)}
          aria-valuenow={Math.round(position)}
          aria-valuetext={`${formatTime(position)} of ${formatTime(duration)}`}
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture(e.pointerId);
            seekFrom(e);
          }}
          onPointerMove={(e) => {
            if (e.currentTarget.hasPointerCapture(e.pointerId)) seekFrom(e);
          }}
          onKeyDown={onKeyDown}
          style={{ flex: 1, display: "flex", alignItems: "center", height: pt(16), cursor: "pointer", touchAction: "none", borderRadius: pt(4) }}
        >
          {bar}
        </div>
      ) : (
        <div style={{ flex: 1, display: "flex", alignItems: "center" }}>{bar}</div>
      )}
      <span style={{ width: pt(42), flex: "none" }}>-{formatTime(duration - position)}</span>
    </div>
  );
}

function VolumeRow({ data, actions }: { data: NotchData; actions?: NotchActions }) {
  const level = data.muted ? 0 : data.volume;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: pt(10), height: pt(20) }}>
      <Control
        actions={actions}
        onClick={actions?.onMute}
        label={data.muted ? "Unmute" : "Mute"}
        pressed={actions ? data.muted : undefined}
        className="n-btn"
        style={{ width: pt(20), height: pt(20), color: "rgb(255 255 255 / 0.55)", borderRadius: pt(5) }}
      >
        <SpeakerIcon size={pt(14)} level={level > 0 ? 0.2 : 0} />
      </Control>
      <SegmentedLevel level={level} square={15} onChange={actions?.onVolume} />
      <span className="n-value" style={{ width: pt(28) }}>
        {Math.round(level * VOLUME_STEPS)}
      </span>
    </div>
  );
}

/** Apple's 16-square volume meter. Becomes an ARIA slider when `onChange` is set. */
function SegmentedLevel({
  level,
  square,
  onChange,
}: {
  level: number;
  square: number;
  onChange?: (v: number) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const filled = Math.min(Math.max(level, 0), 1) * VOLUME_STEPS;
  const step = Math.round(filled);

  const squares = Array.from({ length: VOLUME_STEPS }, (_, i) => {
    const fraction = Math.min(Math.max(filled - i, 0), 1);
    return (
      <span key={i} style={{ width: pt(square), height: pt(square) }}>
        <span style={{ width: `${fraction * 100}%` }} />
      </span>
    );
  });

  if (!onChange) {
    return (
      <div className="n-seg" style={{ height: pt(square) }}>
        {squares}
      </div>
    );
  }

  const fromPointer = (e: PointerEvent<HTMLDivElement>) => {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect) return;
    const x = Math.min(Math.max(e.clientX - rect.left, 0), rect.width);
    const s = x < 3 ? 0 : Math.min(VOLUME_STEPS, Math.floor((x / rect.width) * VOLUME_STEPS) + 1);
    onChange(s / VOLUME_STEPS);
  };

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    const keys: Record<string, number> = {
      ArrowRight: step + 1,
      ArrowUp: step + 1,
      ArrowLeft: step - 1,
      ArrowDown: step - 1,
      PageUp: step + 4,
      PageDown: step - 4,
      Home: 0,
      End: VOLUME_STEPS,
    };
    if (!(e.key in keys)) return;
    e.preventDefault();
    onChange(Math.min(Math.max(keys[e.key], 0), VOLUME_STEPS) / VOLUME_STEPS);
  };

  return (
    <div
      ref={ref}
      className="n-seg"
      role="slider"
      tabIndex={0}
      aria-label="Volume"
      aria-valuemin={0}
      aria-valuemax={VOLUME_STEPS}
      aria-valuenow={step}
      aria-valuetext={`${step} of ${VOLUME_STEPS}`}
      style={{ height: pt(20), cursor: "pointer", touchAction: "none", borderRadius: pt(4) }}
      onPointerDown={(e) => {
        e.currentTarget.setPointerCapture(e.pointerId);
        fromPointer(e);
      }}
      onPointerMove={(e) => {
        if (e.currentTarget.hasPointerCapture(e.pointerId)) fromPointer(e);
      }}
      onKeyDown={onKeyDown}
    >
      {squares}
    </div>
  );
}

/** The row below the camera, shared by every drop-down HUD. */
function DropRow({ children }: { children: ReactNode }) {
  return (
    <div style={{ paddingTop: pt(32) }}>
      <div style={{ display: "flex", alignItems: "center", gap: pt(10), height: pt(32), padding: `0 ${pt(18)}` }}>
        {children}
      </div>
    </div>
  );
}

const hudIcon = (icon: ReactNode) => (
  <span style={{ width: pt(24), display: "grid", placeItems: "center", flex: "none" }}>{icon}</span>
);

/** Volume and brightness share one row: icon, Apple's 16 squares, step count (NotchHUDView). */
function HudRow({ kind, level }: { kind: "volume" | "brightness"; level: number }) {
  return (
    <DropRow>
      {hudIcon(kind === "volume" ? <SpeakerIcon size={pt(18)} level={level} /> : <SunIcon size={pt(18)} level={level} />)}
      <SegmentedLevel level={level} square={12} />
      <span className="n-value" style={{ width: pt(28), flex: "none" }}>
        {Math.round(level * VOLUME_STEPS)}
      </span>
    </DropRow>
  );
}

/** Charging, low battery, headphones, Caps Lock, keyboard and timer pop-ups (NotchHUDView). */
function PopupRow({ popup }: { popup: Popup }) {
  const label = (text: string) => (
    <span
      style={{
        flex: 1,
        minWidth: 0,
        fontSize: pt(13),
        fontWeight: 600,
        whiteSpace: "nowrap",
        overflow: "hidden",
        textOverflow: "ellipsis",
      }}
    >
      {text}
    </span>
  );
  const value = (text: string) => (
    <span className="n-value" style={{ flex: "none" }}>
      {text}
    </span>
  );

  switch (popup.kind) {
    case "charging":
    case "lowBattery": {
      const charging = popup.kind === "charging";
      const level = popup.level ?? 0.5;
      const color = charging ? GREEN : level <= 0.1 ? RED : level <= 0.2 ? ORANGE : "#fff";
      return (
        <DropRow>
          {hudIcon(<BatteryIcon size={pt(20)} level={level} charging={charging} style={{ color }} />)}
          <span style={{ flex: "none", fontSize: pt(13), fontWeight: 600 }}>{charging ? "Charging" : "Low Battery"}</span>
          <div className="n-bar">
            <span style={{ width: `${level * 100}%`, background: color }} />
          </div>
          <span className="n-value" style={{ width: pt(38), flex: "none" }}>
            {Math.round(level * 100)}%
          </span>
        </DropRow>
      );
    }
    case "headphones":
      return (
        <DropRow>
          {hudIcon(<HeadphonesIcon size={pt(17)} />)}
          {label(popup.name ?? "Headphones")}
          {value("Connected")}
        </DropRow>
      );
    case "capsLock":
      return (
        <DropRow>
          {hudIcon(<CapsLockIcon size={pt(17)} on={popup.on} />)}
          {label("Caps Lock")}
          {value(popup.on ? "On" : "Off")}
        </DropRow>
      );
    case "keyboard":
      return (
        <DropRow>
          {hudIcon(<GlobeIcon size={pt(17)} />)}
          {label(popup.name ?? "ABC")}
          {value("Keyboard")}
        </DropRow>
      );
    case "timerDone":
      return (
        <DropRow>
          {hudIcon(<TimerIcon size={pt(17)} style={{ color: ORANGE }} />)}
          {label("Timer done")}
          {value("00:00")}
        </DropRow>
      );
  }
}

function Shelf() {
  return (
    <div className="n-shelf">
      {site.sample.files.map((f) => (
        <div key={f.name} className="n-file">
          <span style={{ width: pt(30), height: pt(30), display: "block" }}>
            <FileGlyph kind={f.kind} />
          </span>
          <span className="n-file-name">{f.name}</span>
        </div>
      ))}
    </div>
  );
}

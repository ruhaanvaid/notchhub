"use client";

import { useEffect, useRef, type CSSProperties, type KeyboardEvent, type PointerEvent, type ReactNode } from "react";
import { site } from "@/config/site";
import {
  BackwardIcon,
  BatteryIcon,
  AlarmIcon,
  BellIcon,
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
  SparklesIcon,
  SpeakerIcon,
  SunIcon,
  TimerIcon,
} from "./icons";

/**
 * idle: the bare notch. live: album art and audio bars in wings beside it. timer: a countdown
 * in the wings. playing: the hover panel. timerPage: the panel's timer page (wheels or ring).
 * volume/brightness/popup: drop-down HUDs. ai: the two-line AI alert. shelf: files.
 */
export type NotchMode =
  | "idle"
  | "live"
  | "timer"
  | "playing"
  | "timerPage"
  | "volume"
  | "brightness"
  | "popup"
  | "ai"
  | "shelf";

export type TimerUnit = "hours" | "minutes" | "seconds";
export type Wheels = Record<TimerUnit, number>;

export const VOLUME_STEPS = 16;

export type PopupKind = "charging" | "lowBattery" | "headphones" | "capsLock" | "keyboard" | "timerAlarm";

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
  /** Length of the running timer, in seconds (for the countdown ring). */
  timerTotal: number;
  timerPaused: boolean;
  /** The timer page's wheels (hours, minutes, seconds). */
  wheels: Wheels;
  popup: Popup;
  /** Index into site.sample.aiAlerts. */
  alert: number;
};

export type NotchActions = {
  onPlayPause: () => void;
  onPrev: () => void;
  onNext: () => void;
  onFavorite: () => void;
  onSeek: (fraction: number) => void;
  onMute: () => void;
  onOutput: () => void;
  /** The header's timer button: opens the timer page. */
  onTimer: () => void;
  onTimerStart: () => void;
  onTimerCancel: () => void;
  onTimerPause: () => void;
  onWheel: (unit: TimerUnit, value: number) => void;
  /** The timer alarm pop-up's buttons (0.9). */
  onAlarmStop: () => void;
  onAlarmRepeat: () => void;
  onAwake: () => void;
  onDnd: () => void;
};

const ORANGE = "#ff9f0a";
const GREEN = "#30d158";
const RED = "#ff453a";

/** Points to CSS length, where 1pt = --u (see globals.css). */
const pt = (n: number) => `calc(${n} * var(--u))`;

const OUTPUT_ICONS = [LaptopIcon, HeadphonesIcon, DisplayIcon];

/** "1:05", or "1:02:05" from an hour up (TimerService.format). */
export const formatTime = (seconds: number) => {
  const s = Math.max(0, Math.round(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor(s / 60) % 60;
  const sec = String(s % 60).padStart(2, "0");
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

/** The demo's clock reads 9:41, like the menu bar; the ring shows when the timer ends. */
const CLOCK_START = 9 * 3600 + 41 * 60;
const endTime = (remaining: number) => {
  const t = Math.floor(CLOCK_START + remaining) % (24 * 3600);
  const h24 = Math.floor(t / 3600);
  const h = h24 % 12 || 12;
  return `${h}:${String(Math.floor(t / 60) % 60).padStart(2, "0")} ${h24 < 12 ? "AM" : "PM"}`;
};

const TIMER_MAX: Wheels = { hours: 23, minutes: 59, seconds: 59 };

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

            {/* Since 0.7.1 the panel has no volume row: volume only pops up from the keys. */}
            <Layer active={mode === "playing"} width={420} height={144}>
              <Header data={data} actions={actions} />
              <div style={{ padding: `${pt(14)} ${pt(20)} 0` }}>
                <NowPlayingRow data={data} actions={actions} />
                <div style={{ height: pt(6) }} />
                <ProgressRow data={data} actions={actions} />
              </div>
            </Layer>

            <Layer active={mode === "timerPage"} width={420} height={170}>
              <Header data={data} actions={actions} timerOpen />
              <div style={{ padding: `${pt(8)} ${pt(20)} 0` }}>
                <TimerPage data={data} actions={actions} />
              </div>
            </Layer>

            <Layer active={mode === "volume"} width={340} height={70}>
              <HudRow kind="volume" level={data.muted ? 0 : data.volume} />
            </Layer>

            <Layer active={mode === "brightness"} width={340} height={70}>
              <HudRow kind="brightness" level={data.brightness} />
            </Layer>

            <Layer active={mode === "popup"} width={340} height={70}>
              <PopupRow popup={data.popup} actions={actions} />
            </Layer>

            <Layer active={mode === "ai"} width={390} height={88}>
              <AIAlertRow index={data.alert} />
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
          <TimerIcon size={pt(14)} style={{ color: ORANGE, opacity: data.timerPaused ? 0.55 : 1 }} />
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
          <span className="n-value" style={{ color: ORANGE, textAlign: "center", opacity: data.timerPaused ? 0.55 : 1 }}>
            {formatTime(data.timer ?? 0)}
          </span>
        )}
      </div>
    </div>
  );
}

function Header({ data, actions, timerOpen = false }: { data: NotchData; actions?: NotchActions; timerOpen?: boolean }) {
  const output = site.sample.outputs[data.output % site.sample.outputs.length];
  const OutputIcon = OUTPUT_ICONS[data.output % OUTPUT_ICONS.length];
  const timerOn = data.timer !== null;
  // Orange while a timer runs or is paused, white while the timer page is open (TimerButton).
  const timerStyle: CSSProperties | undefined = timerOn
    ? { background: ORANGE, color: "#000" }
    : timerOpen
      ? { background: "#fff", color: "#000" }
      : undefined;
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
          label={timerOn ? `Timer, ${formatTime(data.timer ?? 0)} left` : "Set a timer"}
          className="n-circle"
          style={timerStyle}
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

/** Apple's 16-square meter, shared by the volume and brightness HUDs. */
function SegmentedLevel({ level, square }: { level: number; square: number }) {
  const filled = Math.min(Math.max(level, 0), 1) * VOLUME_STEPS;
  return (
    <div className="n-seg" style={{ height: pt(square) }}>
      {Array.from({ length: VOLUME_STEPS }, (_, i) => (
        <span key={i} style={{ width: pt(square), height: pt(square) }}>
          <span style={{ width: `${Math.min(Math.max(filled - i, 0), 1) * 100}%` }} />
        </span>
      ))}
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
function PopupRow({ popup, actions }: { popup: Popup; actions?: NotchActions }) {
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
    case "timerAlarm":
      // Rings until Stop or Repeat (0.9): a wiggling alarm, "Timer", and two capsule buttons.
      return (
        <DropRow>
          {hudIcon(<AlarmIcon size={pt(17)} className="n-ringing" style={{ color: ORANGE }} />)}
          {label("Timer")}
          <AlarmButton actions={actions} onClick={actions?.onAlarmRepeat} label="Repeat" tint="#fff" fill="rgb(255 255 255 / 0.14)" />
          <AlarmButton actions={actions} onClick={actions?.onAlarmStop} label="Stop" tint="#000" fill={ORANGE} />
        </DropRow>
      );
  }
}

/** Capsule button in the alarm pop-up (AlarmButton). */
function AlarmButton({
  actions,
  onClick,
  label,
  tint,
  fill,
}: {
  actions?: NotchActions;
  onClick?: () => void;
  label: string;
  tint: string;
  fill: string;
}) {
  const style: CSSProperties = {
    flex: "none",
    display: "grid",
    placeItems: "center",
    height: pt(24),
    padding: `0 ${pt(12)}`,
    borderRadius: 999,
    background: fill,
    color: tint,
    fontSize: pt(12),
    fontWeight: 600,
    whiteSpace: "nowrap",
  };
  if (actions && onClick) {
    return (
      <button type="button" onClick={onClick} style={{ ...style, cursor: "pointer" }}>
        {label}
      </button>
    );
  }
  return <span style={style}>{label}</span>;
}

/** The two-line AI alert pop-up (AIAlertRow): tool icon, who and what, and a status badge. */
function AIAlertRow({ index }: { index: number }) {
  const alerts = site.sample.aiAlerts;
  const alert = alerts[index % alerts.length];
  const badge = { needs: ["Needs you", ORANGE], done: ["Done", GREEN], error: ["Error", RED] }[alert.kind];
  return (
    <div style={{ paddingTop: pt(32) }}>
      <div style={{ display: "flex", alignItems: "center", gap: pt(10), height: pt(48), padding: `0 ${pt(18)}` }}>
        {/* Stands in for the tool's own app icon. */}
        <span
          style={{
            width: pt(30),
            height: pt(30),
            flex: "none",
            display: "grid",
            placeItems: "center",
            borderRadius: pt(7),
            background: "linear-gradient(160deg, #3a3a46, #16161c)",
            boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.08)",
            color: "#fff",
          }}
        >
          <SparklesIcon size={pt(16)} />
        </span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              fontSize: pt(11),
              fontWeight: 600,
              color: "rgb(255 255 255 / 0.55)",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {alert.source} · {alert.project}
          </div>
          <div
            style={{
              marginTop: pt(2),
              fontSize: pt(13),
              fontWeight: 600,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {alert.message}
          </div>
        </div>
        <span
          style={{
            flex: "none",
            padding: `${pt(3)} ${pt(7)}`,
            borderRadius: 999,
            background: badge[1],
            color: "#000",
            fontSize: pt(10),
            fontWeight: 700,
            whiteSpace: "nowrap",
          }}
        >
          {badge[0]}
        </span>
      </div>
    </div>
  );
}

/** The panel's timer page (TimerPageView): wheels before it starts, a countdown ring while it runs. */
function TimerPage({ data, actions }: { data: NotchData; actions?: NotchActions }) {
  const active = data.timer !== null;
  const picked = data.wheels.hours * 3600 + data.wheels.minutes * 60 + data.wheels.seconds;
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", height: pt(110) }}>
      {active ? (
        <>
          <RoundButton actions={actions} onClick={actions?.onTimerCancel} label="Cancel" tint="#fff" fill="rgb(255 255 255 / 0.16)" />
          <CountdownRing data={data} />
          {data.timerPaused ? (
            <RoundButton actions={actions} onClick={actions?.onTimerPause} label="Resume" tint={GREEN} fill="rgb(48 209 88 / 0.22)" />
          ) : (
            <RoundButton actions={actions} onClick={actions?.onTimerPause} label="Pause" tint={ORANGE} fill="rgb(255 159 10 / 0.22)" />
          )}
        </>
      ) : (
        <>
          <RoundButton actions={actions} onClick={actions?.onTimerCancel} label="Cancel" tint="#fff" fill="rgb(255 255 255 / 0.16)" />
          <DurationWheels data={data} actions={actions} />
          <RoundButton
            actions={actions}
            onClick={actions?.onTimerStart}
            label="Start"
            tint={GREEN}
            fill="rgb(48 209 88 / 0.22)"
            disabled={picked === 0}
          />
        </>
      )}
    </div>
  );
}

/** A Clock-style round button: a tinted disc with a thin dark ring just inside its edge. */
function RoundButton({
  actions,
  onClick,
  label,
  tint,
  fill,
  disabled = false,
}: {
  actions?: NotchActions;
  onClick?: () => void;
  label: string;
  tint: string;
  fill: string;
  disabled?: boolean;
}) {
  const style: CSSProperties = {
    position: "relative",
    display: "grid",
    placeItems: "center",
    flex: "none",
    width: pt(54),
    height: pt(54),
    borderRadius: 999,
    background: fill,
    color: tint,
    // Longer labels shrink a little to stay inside the ring (minimumScaleFactor in the app).
    fontSize: pt(label.length > 5 ? 10.5 : 12),
    fontWeight: 500,
    opacity: disabled ? 0.45 : 1,
    cursor: actions && !disabled ? "pointer" : undefined,
  };
  const ring = (
    <span
      aria-hidden="true"
      style={{ position: "absolute", inset: pt(2.5), borderRadius: 999, border: `${pt(1.5)} solid #000` }}
    />
  );
  if (actions && onClick) {
    return (
      <button type="button" onClick={onClick} disabled={disabled} style={style}>
        {ring}
        <span style={{ position: "relative" }}>{label}</span>
      </button>
    );
  }
  return (
    <span style={style}>
      {ring}
      <span style={{ position: "relative" }}>{label}</span>
    </span>
  );
}

/** Hours / min / sec wheels with the selected row highlighted, like the Clock app (DurationWheels). */
function DurationWheels({ data, actions }: { data: NotchData; actions?: NotchActions }) {
  return (
    <div style={{ position: "relative", width: pt(228), height: pt(110), display: "flex", gap: pt(4) }}>
      <span
        aria-hidden="true"
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: pt(43),
          height: pt(24),
          borderRadius: pt(8),
          background: "rgb(255 255 255 / 0.12)",
        }}
      />
      <WheelColumn unit="hours" label="hours" data={data} actions={actions} />
      <WheelColumn unit="minutes" label="min" data={data} actions={actions} />
      <WheelColumn unit="seconds" label="sec" data={data} actions={actions} />
    </div>
  );
}

const WHEEL_NAMES: Record<TimerUnit, string> = { hours: "Hours", minutes: "Minutes", seconds: "Seconds" };

/** One wheel: five rows that tilt and fade away from the middle, like a drum. Click a number,
 * scroll, or use the arrow keys to pick. */
function WheelColumn({
  unit,
  label,
  data,
  actions,
}: {
  unit: TimerUnit;
  label: string;
  data: NotchData;
  actions?: NotchActions;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const value = data.wheels[unit];
  const max = TIMER_MAX[unit];
  const set = (v: number) => actions?.onWheel(unit, Math.min(Math.max(v, 0), max));

  // Scroll to turn the wheel. A native listener, so the page doesn't scroll at the same time.
  const latest = useRef({ value, set });
  useEffect(() => {
    latest.current = { value, set };
  });
  useEffect(() => {
    const el = ref.current;
    if (!el || !actions) return;
    let carry = 0;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      // A mouse-wheel click (a big jump, or line-based scrolling) moves exactly one row, as in
      // 0.8.1; trackpad scrolling adds up and moves a row every 28px.
      if (e.deltaMode !== 0 || Math.abs(e.deltaY) >= 50) {
        carry = 0;
        latest.current.set(latest.current.value + Math.sign(e.deltaY));
        return;
      }
      carry += e.deltaY;
      const steps = Math.trunc(carry / 28);
      if (steps !== 0) {
        carry -= steps * 28;
        latest.current.set(latest.current.value + steps);
      }
    };
    el.addEventListener("wheel", onWheel, { passive: false });
    return () => el.removeEventListener("wheel", onWheel);
  }, [actions]);

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    const keys: Record<string, number> = {
      ArrowUp: value + 1,
      ArrowRight: value + 1,
      ArrowDown: value - 1,
      ArrowLeft: value - 1,
      PageUp: value + 10,
      PageDown: value - 10,
      Home: 0,
      End: max,
    };
    if (!(e.key in keys)) return;
    e.preventDefault();
    set(keys[e.key]);
  };

  const rows = [-2, -1, 0, 1, 2].map((offset) => {
    const n = value + offset;
    // How far from the middle row, 0–1 (WheelRow.drum).
    const t = Math.min((Math.abs(offset) * 22) / 55, 1);
    return (
      <div
        key={offset}
        onClick={actions && n >= 0 && n <= max ? () => set(n) : undefined}
        style={{
          height: pt(22),
          display: "flex",
          alignItems: "center",
          justifyContent: "flex-end",
          fontSize: pt(18),
          fontVariantNumeric: "tabular-nums",
          transform: `scale(${1 - t * 0.1}, ${Math.cos((t * Math.PI) / 2.6)})`,
          transformOrigin: "100% 50%",
          opacity: 1 - t * 0.8,
          cursor: actions ? "pointer" : undefined,
          visibility: n >= 0 && n <= max ? "visible" : "hidden",
        }}
      >
        {n >= 0 && n <= max ? n : ""}
      </div>
    );
  });

  return (
    <div style={{ position: "relative", flex: 1, display: "flex", alignItems: "center", gap: pt(5) }}>
      <div
        ref={ref}
        role={actions ? "spinbutton" : undefined}
        tabIndex={actions ? 0 : undefined}
        aria-label={actions ? WHEEL_NAMES[unit] : undefined}
        aria-valuemin={actions ? 0 : undefined}
        aria-valuemax={actions ? max : undefined}
        aria-valuenow={actions ? value : undefined}
        onKeyDown={actions ? onKeyDown : undefined}
        style={{ width: pt(30), flex: "none", borderRadius: pt(6) }}
      >
        {rows}
      </div>
      <span aria-hidden="true" style={{ width: pt(38), fontSize: pt(13), fontWeight: 600 }}>
        {label}
      </span>
    </div>
  );
}

/** Orange ring that empties as the timer runs, with the time left and when it ends (CountdownRing). */
function CountdownRing({ data }: { data: NotchData }) {
  const remaining = data.timer ?? 0;
  const progress = data.timerTotal > 0 ? remaining / data.timerTotal : 0;
  return (
    <div style={{ position: "relative", width: pt(106), height: pt(106), flex: "none" }}>
      <svg viewBox="0 0 106 106" width="100%" height="100%" aria-hidden="true" style={{ transform: "rotate(-90deg)" }}>
        <circle cx="53" cy="53" r="51" fill="none" stroke="rgb(255 255 255 / 0.12)" strokeWidth="4" />
        <circle
          cx="53"
          cy="53"
          r="51"
          fill="none"
          stroke={ORANGE}
          strokeWidth="4"
          strokeLinecap="round"
          pathLength={100}
          strokeDasharray={`${progress * 100} 100`}
          style={{ transition: "stroke-dasharray 1s linear" }}
        />
      </svg>
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: pt(2),
        }}
      >
        <span style={{ fontSize: pt(remaining >= 3600 ? 19 : 24), fontWeight: 300, fontVariantNumeric: "tabular-nums" }}>
          {formatTime(remaining)}
        </span>
        <span
          style={{
            display: "flex",
            alignItems: "center",
            gap: pt(3),
            fontSize: pt(10),
            fontWeight: 500,
            fontVariantNumeric: "tabular-nums",
            color: data.timerPaused ? "rgb(255 255 255 / 0.3)" : "rgb(255 255 255 / 0.55)",
          }}
        >
          <BellIcon size={pt(8)} />
          {endTime(remaining)}
        </span>
      </div>
    </div>
  );
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

import { useId, type SVGProps } from "react";
import type { FeatureIcon } from "@/config/site";

type IconProps = SVGProps<SVGSVGElement> & { size?: number | string };

function Svg({ size = "1em", children, ...rest }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      focusable="false"
      {...rest}
    >
      {children}
    </svg>
  );
}

/* ---------- Notch glyphs (filled, SF Symbols-like) ---------- */

export function SpeakerIcon({ level = 1, ...p }: IconProps & { level?: number }) {
  return (
    <Svg {...p}>
      <path d="M3.5 9.2c0-.6.5-1.1 1.1-1.1h2.6l4.3-3.6c.7-.6 1.8-.1 1.8.8v13.4c0 .9-1.1 1.4-1.8.8l-4.3-3.6H4.6c-.6 0-1.1-.5-1.1-1.1V9.2Z" />
      {level <= 0 ? (
        <path
          d="m16.2 9.6 4.8 4.8m0-4.8-4.8 4.8"
          stroke="currentColor"
          strokeWidth="1.9"
          strokeLinecap="round"
          fill="none"
        />
      ) : (
        <g stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" fill="none">
          <path d="M15.6 9.4a3.6 3.6 0 0 1 0 5.2" />
          {level > 0.34 && <path d="M18 7.2a6.8 6.8 0 0 1 0 9.6" />}
          {level > 0.67 && <path d="M20.3 5a10 10 0 0 1 0 14" opacity="0.95" />}
        </g>
      )}
    </Svg>
  );
}

/** sun.min.fill (dotted rays) below half, sun.max.fill (long rays) at half or above. */
export function SunIcon({ level = 1, ...p }: IconProps & { level?: number }) {
  const rays = Array.from({ length: 8 }, (_, i) => (i * Math.PI) / 4);
  if (level < 0.5) {
    return (
      <Svg {...p}>
        <circle cx="12" cy="12" r="4.2" />
        {rays.map((a, i) => (
          <circle key={i} cx={12 + Math.cos(a) * 8} cy={12 + Math.sin(a) * 8} r="1.25" />
        ))}
      </Svg>
    );
  }
  return (
    <Svg {...p}>
      <circle cx="12" cy="12" r="4.6" />
      <g stroke="currentColor" strokeWidth="2.1" strokeLinecap="round">
        {rays.map((a, i) => (
          <line key={i} x1={12 + Math.cos(a) * 7.4} y1={12 + Math.sin(a) * 7.4} x2={12 + Math.cos(a) * 10.4} y2={12 + Math.sin(a) * 10.4} />
        ))}
      </g>
    </Svg>
  );
}

export function CupIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M5 7.5h11.2v5.2a5 5 0 0 1-5 5H10a5 5 0 0 1-5-5V7.5Z" />
      <path
        d="M16 9.3h1.3a2.3 2.3 0 0 1 0 4.6H16"
        stroke="currentColor"
        strokeWidth="1.8"
        fill="none"
      />
      <path d="M3.2 19.3h15.4c.5 0 .8.4.6.8-.4.6-1.1 1-1.9 1H4.5c-.8 0-1.5-.4-1.9-1-.2-.4.1-.8.6-.8Z" />
    </Svg>
  );
}

export function MoonIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M14.6 3.2a.6.6 0 0 1 .7-.8 9.6 9.6 0 1 1-12.9 12.9.6.6 0 0 1 .8-.7 7.6 7.6 0 0 0 11.4-11.4Z" />
    </Svg>
  );
}

export function LaptopIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path
        d="M5 6.5c0-.8.7-1.5 1.5-1.5h11c.8 0 1.5.7 1.5 1.5V15H5V6.5Z"
        stroke="currentColor"
        strokeWidth="1.8"
        fill="none"
      />
      <path d="M2 16.2c0-.4.3-.7.7-.7h18.6c.4 0 .7.3.7.7 0 1-.8 1.8-1.8 1.8H3.8c-1 0-1.8-.8-1.8-1.8Z" />
    </Svg>
  );
}

export function HeadphonesIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path
        d="M4.5 14.5V12a7.5 7.5 0 0 1 15 0v2.5"
        stroke="currentColor"
        strokeWidth="1.8"
        fill="none"
      />
      <rect x="3.5" y="13" width="4.5" height="7" rx="1.8" />
      <rect x="16" y="13" width="4.5" height="7" rx="1.8" />
    </Svg>
  );
}

export function DisplayIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <rect x="3" y="4" width="18" height="12.5" rx="1.8" stroke="currentColor" strokeWidth="1.8" fill="none" />
      <path d="M9 20h6M12 16.5V20" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </Svg>
  );
}

export function ChevronDownIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="m6 9 6 6 6-6" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </Svg>
  );
}

export function PlayIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M7 4.9c0-1 1.1-1.6 1.9-1.1l11 6.9c.8.5.8 1.7 0 2.2l-11 6.9C8.1 20.3 7 19.7 7 18.7V4.9Z" />
    </Svg>
  );
}

export function PauseIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <rect x="5.5" y="3.5" width="4.5" height="17" rx="1.3" />
      <rect x="14" y="3.5" width="4.5" height="17" rx="1.3" />
    </Svg>
  );
}

export function ForwardIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M1.5 7.2c0-.9 1-1.4 1.7-.9l7.5 4.8c.7.4.7 1.4 0 1.8l-7.5 4.8c-.7.5-1.7 0-1.7-.9V7.2Z" />
      <path d="M12 7.2c0-.9 1-1.4 1.7-.9l7.5 4.8c.7.4.7 1.4 0 1.8l-7.5 4.8c-.7.5-1.7 0-1.7-.9V7.2Z" />
    </Svg>
  );
}

export function BackwardIcon(p: IconProps) {
  return (
    <Svg {...p} style={{ transform: "scaleX(-1)", ...p.style }}>
      <path d="M1.5 7.2c0-.9 1-1.4 1.7-.9l7.5 4.8c.7.4.7 1.4 0 1.8l-7.5 4.8c-.7.5-1.7 0-1.7-.9V7.2Z" />
      <path d="M12 7.2c0-.9 1-1.4 1.7-.9l7.5 4.8c.7.4.7 1.4 0 1.8l-7.5 4.8c-.7.5-1.7 0-1.7-.9V7.2Z" />
    </Svg>
  );
}

export function FileGlyph({ kind, ...p }: IconProps & { kind: string }) {
  const colors: Record<string, [string, string]> = {
    pdf: ["#ff5a52", "#d8302b"],
    image: ["#5ac8fa", "#2f7cf6"],
    doc: ["#f2f2f7", "#c7c7d1"],
    zip: ["#b9b9c6", "#7d7d8c"],
  };
  const [a, b] = colors[kind] ?? colors.doc;
  const id = `fg${useId().replace(/[^a-zA-Z0-9]/g, "")}`;
  return (
    <svg viewBox="0 0 30 30" width="100%" height="100%" aria-hidden="true" focusable="false" {...p}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={a} />
          <stop offset="1" stopColor={b} />
        </linearGradient>
      </defs>
      <path d="M7 2.5h11l6 6v18a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 6 26.5V4a1.5 1.5 0 0 1 1-1.5Z" fill={`url(#${id})`} />
      <path d="M18 2.5v4.5a1.5 1.5 0 0 0 1.5 1.5H24" fill="rgb(255 255 255 / 0.45)" />
      {kind === "image" && <path d="m9 23 4-5 3 3.5 2-2.2L22 23H9Z" fill="rgb(255 255 255 / 0.85)" />}
      {kind === "pdf" && (
        <text x="15" y="22" textAnchor="middle" fontSize="6" fontWeight="800" fill="#fff" fontFamily="system-ui">
          PDF
        </text>
      )}
      {kind === "doc" && (
        <g stroke="#8e8e9b" strokeWidth="1.3" strokeLinecap="round">
          <path d="M10 14h10M10 17.5h10M10 21h6" />
        </g>
      )}
      {kind === "zip" && (
        <g fill="#fff" opacity="0.8">
          <rect x="14" y="11" width="2" height="2" />
          <rect x="14" y="15" width="2" height="2" />
          <rect x="13" y="19" width="4" height="4" rx="1" />
        </g>
      )}
    </svg>
  );
}

/* ---------- Feature icons (line) ---------- */

const line = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

export function FeatureGlyph({ name, ...p }: IconProps & { name: FeatureIcon }) {
  switch (name) {
    case "island":
      return (
        <Svg {...p} fill="none">
          <rect x="2.5" y="3.5" width="19" height="14" rx="2.5" {...line} />
          <path d="M8 3.5h8v2.2a2.3 2.3 0 0 1-2.3 2.3h-3.4A2.3 2.3 0 0 1 8 5.7V3.5Z" fill="currentColor" />
          <path d="M8 21h8" {...line} />
        </Svg>
      );
    case "ai":
      return (
        <Svg {...p} fill="none">
          <path d="M5 3.5h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-6l-4.5 3.8v-3.8H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2Z" {...line} />
          <path d="M12 6.5c.3 1.9 1.1 2.8 3 3.2-1.9.4-2.7 1.3-3 3.2-.3-1.9-1.1-2.8-3-3.2 1.9-.4 2.7-1.3 3-3.2Z" fill="currentColor" />
        </Svg>
      );
    case "volume":
      return (
        <Svg {...p} fill="none">
          <path d="M4 9.5h3l4.5-3.8v12.6L7 14.5H4z" {...line} />
          <path d="M15 9.5a3.5 3.5 0 0 1 0 5M17.8 7a7 7 0 0 1 0 10" {...line} />
        </Svg>
      );
    case "controls":
      return (
        <Svg {...p} fill="none">
          <circle cx="7" cy="7" r="3.5" {...line} />
          <circle cx="17" cy="7" r="3.5" {...line} />
          <rect x="3.5" y="14" width="17" height="6" rx="3" {...line} />
          <circle cx="17.5" cy="17" r="1.6" fill="currentColor" />
        </Svg>
      );
    case "motion":
      return (
        <Svg {...p} fill="none">
          <path d="M3 18c4 0 5-12 9-12s5 12 9 12" {...line} />
          <circle cx="12" cy="6" r="1.6" fill="currentColor" />
        </Svg>
      );
    case "native":
      return (
        <Svg {...p} fill="none">
          <rect x="6" y="6" width="12" height="12" rx="2.5" {...line} />
          <path d="M9.5 2.5v3.5M14.5 2.5v3.5M9.5 18v3.5M14.5 18v3.5M2.5 9.5H6M2.5 14.5H6M18 9.5h3.5M18 14.5h3.5" {...line} />
          <path d="M10 12h4" {...line} />
        </Svg>
      );
    case "sliders":
      return (
        <Svg {...p} fill="none">
          <path d="M4 7h9M17 7h3M4 17h3M11 17h9" {...line} />
          <circle cx="15" cy="7" r="2" {...line} />
          <circle cx="9" cy="17" r="2" {...line} />
        </Svg>
      );
  }
}

export function ArrowDownIcon(p: IconProps) {
  return (
    <Svg {...p} fill="none">
      <path d="M12 4v14m0 0-5.5-5.5M12 18l5.5-5.5" {...line} strokeWidth={2} />
    </Svg>
  );
}

export function PlusIcon(p: IconProps) {
  return (
    <Svg {...p} fill="none">
      <path d="M12 5v14M5 12h14" {...line} strokeWidth={1.8} />
    </Svg>
  );
}

export function GitHubIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M12 2a10 10 0 0 0-3.2 19.5c.5.1.7-.2.7-.5v-1.7c-2.8.6-3.4-1.3-3.4-1.3-.4-1.2-1.1-1.5-1.1-1.5-.9-.6.1-.6.1-.6 1 .1 1.5 1 1.5 1 .9 1.6 2.4 1.1 3 .8.1-.7.4-1.1.6-1.4-2.2-.2-4.6-1.1-4.6-5 0-1.1.4-2 1-2.7-.1-.3-.4-1.3.1-2.7 0 0 .8-.3 2.8 1a9.6 9.6 0 0 1 5 0c1.9-1.3 2.8-1 2.8-1 .5 1.4.2 2.4.1 2.7.6.7 1 1.6 1 2.7 0 3.9-2.4 4.7-4.6 5 .4.3.7.9.7 1.9V21c0 .3.2.6.7.5A10 10 0 0 0 12 2Z" />
    </Svg>
  );
}

export function TimerIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M9.5 2.2h5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <circle cx="12" cy="13.2" r="8" stroke="currentColor" strokeWidth="2" fill="none" />
      <path d="M12 13.2V8.8" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
      <path d="m18.6 5.6 1.4-1.4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </Svg>
  );
}

export function HeartIcon({ filled = false, ...p }: IconProps & { filled?: boolean }) {
  return (
    <Svg {...p}>
      <path
        d="M12 20.3s-7.8-4.6-9.2-9.6C1.9 7.4 4 4.2 7.3 4.2c2 0 3.6 1.1 4.7 2.7 1.1-1.6 2.7-2.7 4.7-2.7 3.3 0 5.4 3.2 4.5 6.5-1.4 5-9.2 9.6-9.2 9.6Z"
        fill={filled ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

export function BatteryIcon({ level = 1, charging = false, ...p }: IconProps & { level?: number; charging?: boolean }) {
  const w = Math.max(1.5, 13 * Math.min(Math.max(level, 0), 1));
  return (
    <Svg {...p}>
      <rect x="2" y="7" width="17.5" height="10" rx="2.6" stroke="currentColor" strokeWidth="1.8" fill="none" />
      <path d="M21.2 10.2v3.6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      {charging ? (
        <path d="m11.6 8.2-3.4 4.6h3l-.9 3 3.5-4.6h-3l.8-3Z" />
      ) : (
        <rect x="4.2" y="9.2" width={w} height="5.6" rx="1.2" />
      )}
    </Svg>
  );
}

export function CapsLockIcon({ on = false, ...p }: IconProps & { on?: boolean }) {
  return (
    <Svg {...p}>
      <path
        d="M12 3.5 3.8 12h4.4v4.2h7.6V12h4.4L12 3.5Z"
        fill={on ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
      <rect x="8.2" y="18.3" width="7.6" height="2.4" rx="0.8" />
    </Svg>
  );
}

export function GlobeIcon(p: IconProps) {
  return (
    <Svg {...p} fill="none">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.8" />
      <path d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9s-1.2 6.4-3.8 9c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3Z" stroke="currentColor" strokeWidth="1.8" />
    </Svg>
  );
}

export function SparklesIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M10 2.5c.4 3.9 2.1 6.1 6.5 7-4.4.9-6.1 3.1-6.5 7-.4-3.9-2.1-6.1-6.5-7 4.4-.9 6.1-3.1 6.5-7Z" />
      <path d="M18 13c.2 2.1 1.1 3.2 3.5 3.7-2.4.5-3.3 1.6-3.5 3.8-.2-2.2-1.1-3.3-3.5-3.8 2.4-.5 3.3-1.6 3.5-3.7Z" />
      <path d="M18.5 2.5c.1 1.3.7 2 2 2.3-1.3.3-1.9 1-2 2.3-.1-1.3-.7-2-2-2.3 1.3-.3 1.9-1 2-2.3Z" />
    </Svg>
  );
}

export function BellIcon(p: IconProps) {
  return (
    <Svg {...p}>
      <path d="M12 2.5a1.4 1.4 0 0 1 1.4 1.4v.5a6.2 6.2 0 0 1 4.8 6v4.3l1.9 2.3c.5.6.1 1.5-.7 1.5H4.6c-.8 0-1.2-.9-.7-1.5l1.9-2.3v-4.3a6.2 6.2 0 0 1 4.8-6v-.5A1.4 1.4 0 0 1 12 2.5Z" />
      <path d="M9.4 19.8h5.2a2.6 2.6 0 0 1-5.2 0Z" />
    </Svg>
  );
}

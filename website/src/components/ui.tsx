import type { ReactNode } from "react";
import { site } from "@/config/site";

export function SectionHeading({
  id,
  eyebrow,
  title,
  emphasis,
  intro,
  align = "center",
}: {
  id: string;
  eyebrow: string;
  title: string;
  emphasis: string;
  intro?: string;
  align?: "center" | "left";
}) {
  const centered = align === "center";
  return (
    <div className={centered ? "mx-auto max-w-2xl text-center" : "max-w-xl"} data-reveal>
      <p className="eyebrow">{eyebrow}</p>
      <h2
        id={id}
        className="font-display mt-4 text-[clamp(2.5rem,6vw,4.25rem)] leading-[1.02] text-ink text-balance"
      >
        {title} <em className="text-gradient">{emphasis}</em>
      </h2>
      {intro && <p className="mt-5 text-lg leading-relaxed text-muted text-pretty">{intro}</p>}
    </div>
  );
}

export function DownloadButton({ className = "", children }: { className?: string; children?: ReactNode }) {
  return (
    <a href={site.downloadUrl} className={`btn btn-primary ${className}`}>
      <DownloadGlyph />
      {children ?? site.hero.primaryCta}
    </a>
  );
}

/** A small download-arrow glyph (deliberately not the Apple logo). */
function DownloadGlyph() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 3.5v11m0 0-4.5-4.5M12 14.5l4.5-4.5M4.5 16.5v1.8c0 1.2 1 2.2 2.2 2.2h10.6c1.2 0 2.2-1 2.2-2.2v-1.8"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function Requirements({ className = "" }: { className?: string }) {
  return (
    <p className={`text-sm text-faint ${className}`}>
      {site.requirements.map((r, i) => (
        <span key={r}>
          {i > 0 && (
            <span aria-hidden="true" className="mx-2 text-white/25">
              •
            </span>
          )}
          {r}
        </span>
      ))}
    </p>
  );
}

export function Container({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 ${className}`}>{children}</div>;
}

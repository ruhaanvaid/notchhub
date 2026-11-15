import type { ReactNode } from "react";
import Image from "next/image";
import { site } from "@/config/site";
import { HeroDemo } from "./HeroDemo";
import { InteractiveDemo } from "./InteractiveDemo";
import { CupIcon, FeatureGlyph, GitHubIcon, MoonIcon, PauseIcon, PlusIcon, SparklesIcon, TimerIcon } from "./icons";
import { Container, DownloadButton, Requirements, SectionHeading } from "./ui";

/* ---------------- Nav ---------------- */

export function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-line bg-bg/70 backdrop-blur-xl backdrop-saturate-150">
      <Container className="flex h-16 items-center justify-between gap-4">
        <a href="#top" className="flex items-center gap-2.5 rounded-lg" aria-label={`${site.name} home`}>
          <Image src="/notchhub-icon.png" alt="" width={28} height={28} unoptimized priority className="h-7 w-7" />
          <span className="text-[1.0625rem] font-semibold tracking-tight">{site.name}</span>
        </a>
        <nav aria-label="Primary" className="hidden md:block">
          <ul className="flex items-center gap-8 text-sm text-muted">
            {site.nav.map((item) => (
              <li key={item.href}>
                <a href={item.href} className="rounded transition-colors hover:text-ink">
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
        <a href={site.downloadUrl} className="btn btn-primary !min-h-9 !px-4 text-sm">
          Download
        </a>
      </Container>
    </header>
  );
}

/* ---------------- Hero ---------------- */

export function Hero() {
  const { hero } = site;
  return (
    <section id="top" aria-labelledby="hero-title" className="relative overflow-hidden pb-12 pt-12 sm:pt-20 md:pb-24">
      <div
        aria-hidden="true"
        className="glow left-1/2 top-[38%] h-[420px] w-[min(900px,90vw)] -translate-x-1/2"
        style={{ background: "radial-gradient(closest-side, rgb(127 168 255 / 0.55), rgb(167 139 250 / 0.35), transparent)" }}
      />
      <Container className="relative">
        <div className="grid items-end gap-8 lg:grid-cols-[1.25fr_1fr] lg:gap-14">
          <div>
            <p className="inline-flex items-center gap-2 rounded-full bg-white/[0.04] py-1.5 pl-2 pr-3.5 text-[0.8125rem] font-medium text-muted ring-1 ring-line">
              <span className="relative flex h-2 w-2">
                <span className="absolute inset-0 rounded-full bg-accent-1 opacity-60 motion-safe:animate-ping" />
                <span className="relative h-2 w-2 rounded-full bg-accent-1" />
              </span>
              {hero.eyebrow} · v{site.version}
            </p>
            <h1
              id="hero-title"
              className="font-display mt-6 text-[clamp(3.25rem,9.5vw,7.25rem)] leading-[0.92] text-ink"
            >
              {hero.headline.before}{" "}
              <br className="hidden sm:block" />
              <em className="text-gradient">{hero.headline.emphasis}</em> {hero.headline.after}
            </h1>
          </div>
          <div className="lg:pb-3">
            <p className="text-lg leading-relaxed text-muted text-pretty sm:text-xl">{hero.subhead}</p>
            <div className="mt-8 flex flex-wrap items-center gap-3">
              <DownloadButton />
              <a href="#features" className="btn btn-ghost">
                {hero.secondaryCta}
              </a>
            </div>
            <Requirements className="mt-5" />
          </div>
        </div>

        <div className="relative mx-auto mt-14 max-w-[1040px] sm:mt-20">
          <HeroDemo />
        </div>
      </Container>
    </section>
  );
}

/* ---------------- Features ---------------- */

export function Features() {
  const { features } = site;
  const [island, volume, ai, controls, motion, native, sliders] = features.items;
  return (
    <section id="features" aria-labelledby="features-title" className="relative py-20 md:py-32">
      <Container>
        <SectionHeading
          id="features-title"
          eyebrow={features.eyebrow}
          title={features.title}
          emphasis={features.titleEmphasis}
          intro={features.intro}
        />

        <ul className="mt-14 grid gap-4 md:mt-20 md:grid-cols-3">
          <FeatureCard feature={island} className="md:col-span-2" delay={0}>
            <MiniIsland />
          </FeatureCard>
          <FeatureCard feature={volume} delay={1}>
            <MiniVolume />
          </FeatureCard>
          <FeatureCard feature={ai} className="md:col-span-2" delay={0}>
            <MiniAlert />
          </FeatureCard>
          <FeatureCard feature={controls} delay={1}>
            <MiniControls />
          </FeatureCard>
          <FeatureCard feature={motion} delay={0}>
            <MiniMotion />
          </FeatureCard>
          <FeatureCard feature={native} delay={1}>
            <MiniNative />
          </FeatureCard>
          <FeatureCard feature={sliders} delay={2}>
            <MiniSettings />
          </FeatureCard>
          <li className="card p-6 sm:p-8 md:col-span-3" data-reveal>
            <h3 className="text-sm font-semibold uppercase tracking-[0.14em] text-muted">Also included</h3>
            <dl className="mt-5 grid gap-x-8 gap-y-5 sm:grid-cols-2 lg:grid-cols-4">
              {features.extras.map((x) => (
                <div key={x.title}>
                  <dt className="font-semibold text-ink">{x.title}</dt>
                  <dd className="mt-1 text-[0.9375rem] leading-relaxed text-muted">{x.body}</dd>
                </div>
              ))}
            </dl>
          </li>
          {features.comingSoon.length > 0 && (
            <li className="card p-6 sm:p-8 md:col-span-3" data-reveal>
              <h3 className="flex items-center gap-3 text-sm font-semibold uppercase tracking-[0.14em] text-muted">
                On the way
                <span className="rounded-full bg-accent-2/15 px-2.5 py-1 text-xs font-semibold normal-case tracking-normal text-accent-3">
                  Coming soon
                </span>
              </h3>
              <dl className="mt-5 grid gap-x-8 gap-y-5 md:grid-cols-3">
                {features.comingSoon.map((x) => (
                  <div key={x.title}>
                    <dt className="font-semibold text-ink">{x.title}</dt>
                    <dd className="mt-1 text-[0.9375rem] leading-relaxed text-muted">{x.body}</dd>
                  </div>
                ))}
              </dl>
            </li>
          )}
        </ul>
      </Container>
    </section>
  );
}

function FeatureCard({
  feature,
  className = "",
  delay,
  children,
}: {
  feature: (typeof site.features.items)[number];
  className?: string;
  delay: number;
  children?: ReactNode;
}) {
  return (
    <li
      className={`card card-glow group flex flex-col overflow-hidden p-6 sm:p-8 ${className}`}
      data-reveal
      style={{ ["--reveal-delay" as string]: delay }}
    >
      {children && <div className="mb-8 flex-1">{children}</div>}
      <div className="mt-auto">
        <div className="flex items-center gap-3">
          <span className="grid h-10 w-10 place-items-center rounded-xl bg-white/[0.05] text-accent-1 ring-1 ring-line">
            <FeatureGlyph name={feature.icon} size={22} />
          </span>
          {feature.comingSoon && (
            <span className="rounded-full bg-accent-2/15 px-2.5 py-1 text-xs font-semibold text-accent-3">
              Coming soon
            </span>
          )}
        </div>
        <h3 className="mt-5 text-xl font-semibold tracking-tight text-ink">{feature.title}</h3>
        <p className="mt-2 leading-relaxed text-muted text-pretty">{feature.body}</p>
      </div>
    </li>
  );
}

/** Static notch silhouette expanding into a panel, for the large feature card. */
function MiniIsland() {
  return (
    <div aria-hidden="true" className="relative h-full min-h-40 overflow-hidden rounded-2xl bg-gradient-to-b from-[#1b1f45] to-[#141029] ring-1 ring-line sm:h-48">
      <div className="absolute inset-x-0 top-0 h-6 bg-black/25" />
      <div className="absolute left-1/2 top-0 w-[min(78%,420px)] -translate-x-1/2 rounded-b-[26px] bg-black px-5 pb-4 pt-8 shadow-[0_18px_40px_rgb(0_0_0/0.55)] transition-transform duration-700 ease-spring group-hover:scale-[1.03]">
        <div className="flex items-center gap-3">
          <div className="h-11 w-11 shrink-0 rounded-[10px] bg-[linear-gradient(135deg,#ff9a4c,#ff3d81_55%,#b347ff)] shadow-[0_0_24px_rgb(255_61_129/0.45)]" />
          <div className="min-w-0 flex-1">
            <div className="h-2.5 w-28 max-w-full rounded-full bg-white/90" />
            <div className="mt-2 h-2 w-20 max-w-full rounded-full bg-white/35" />
          </div>
          <div className="hidden gap-2 sm:flex">
            <span className="h-2.5 w-2.5 rounded-full bg-white/70" />
            <span className="h-2.5 w-2.5 rounded-full bg-white" />
            <span className="h-2.5 w-2.5 rounded-full bg-white/70" />
          </div>
        </div>
        {/* Track progress: elapsed, bar, remaining (the panel has no volume row since 0.7.1). */}
        <div className="mt-4 flex items-center gap-2 text-[0.625rem] font-medium tabular-nums text-white/55">
          <span>1:24</span>
          <span className="relative h-1 flex-1 rounded-full bg-white/15">
            <span className="absolute inset-y-0 left-0 w-[39%] rounded-full bg-white" />
          </span>
          <span>-2:12</span>
        </div>
      </div>
    </div>
  );
}

/** A Claude Code alert dropping out of the notch, for the AI alerts card. */
function MiniAlert() {
  const a = site.sample.aiAlerts[0];
  return (
    <div
      aria-hidden="true"
      className="relative flex h-full min-h-40 justify-center overflow-hidden rounded-2xl bg-gradient-to-b from-[#1b1f45] to-[#141029] ring-1 ring-line sm:min-h-48"
    >
      <div className="absolute inset-x-0 top-0 h-6 bg-black/25" />
      <div className="relative mt-0 flex h-fit w-[min(86%,400px)] items-center gap-3 rounded-b-[22px] bg-black px-4 pb-4 pt-9 shadow-[0_18px_40px_rgb(0_0_0/0.55)] transition-transform duration-700 ease-spring group-hover:translate-y-1">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-[9px] bg-gradient-to-br from-[#3a3a46] to-[#16161c] text-white ring-1 ring-white/10">
          <SparklesIcon size={18} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-xs font-semibold text-white/55">
            {a.source} · {a.project}
          </span>
          <span className="block truncate text-[0.9375rem] font-semibold text-white">{a.message}</span>
        </span>
        <span className="shrink-0 rounded-full bg-[#ff9f0a] px-2 py-0.5 text-[0.6875rem] font-bold text-black">Needs you</span>
      </div>
    </div>
  );
}

function MiniVolume() {
  return (
    <div aria-hidden="true" className="flex h-full min-h-40 items-center justify-center rounded-2xl bg-white/[0.025] px-4 ring-1 ring-line sm:min-h-48">
      <div className="w-full max-w-[260px] rounded-[20px] bg-black px-4 pb-4 pt-9 shadow-[0_18px_40px_rgb(0_0_0/0.5)] ring-1 ring-white/5">
        <div className="flex items-center gap-3">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff">
            <path d="M3.5 9.2c0-.6.5-1.1 1.1-1.1h2.6l4.3-3.6c.7-.6 1.8-.1 1.8.8v13.4c0 .9-1.1 1.4-1.8.8l-4.3-3.6H4.6c-.6 0-1.1-.5-1.1-1.1V9.2Z" />
            <path d="M15.6 9.4a3.6 3.6 0 0 1 0 5.2M18 7.2a6.8 6.8 0 0 1 0 9.6" stroke="#fff" strokeWidth="1.9" strokeLinecap="round" fill="none" />
          </svg>
          <div className="flex flex-1 justify-between">
            {Array.from({ length: 16 }, (_, i) => (
              <span
                key={i}
                className={`h-2 w-2 rounded-[2px] transition-colors duration-300 ${
                  i < 11 ? "bg-white" : "bg-white/15 group-hover:bg-white/15"
                } ${i === 11 ? "group-hover:bg-white" : ""}`}
                style={{ transitionDelay: i === 11 ? "100ms" : undefined }}
              />
            ))}
          </div>
          <span className="w-5 text-right text-xs font-semibold tabular-nums text-white/55">11</span>
        </div>
      </div>
    </div>
  );
}

const miniFrame = "flex h-28 items-center justify-center rounded-2xl bg-white/[0.025] ring-1 ring-line";

function MiniControls() {
  return (
    <div aria-hidden="true" className={miniFrame}>
      <div className="flex items-center gap-2 rounded-full bg-black p-2 shadow-[0_10px_30px_rgb(0_0_0/0.5)] ring-1 ring-white/5">
        <span className="grid h-9 w-9 place-items-center rounded-full bg-white text-black transition-transform duration-500 ease-spring group-hover:scale-110">
          <PauseIcon size={14} />
        </span>
        <span className="grid h-9 w-9 place-items-center rounded-full bg-[#ff9f0a] text-black">
          <TimerIcon size={16} />
        </span>
        <span className="grid h-9 w-9 place-items-center rounded-full bg-white text-black">
          <CupIcon size={16} />
        </span>
        <span className="grid h-9 w-9 place-items-center rounded-full bg-white/15 text-white transition-colors duration-300 group-hover:bg-white group-hover:text-black">
          <MoonIcon size={14} />
        </span>
      </div>
    </div>
  );
}

function MiniMotion() {
  return (
    <div aria-hidden="true" className={`${miniFrame} !items-start overflow-hidden`}>
      <div className="mini-breathe" />
    </div>
  );
}

function MiniNative() {
  return (
    <div aria-hidden="true" className={`${miniFrame} flex-wrap content-center gap-2 px-4`}>
      {["Swift", "SwiftUI", "0 dependencies"].map((t) => (
        <span key={t} className="rounded-full bg-white/[0.06] px-3 py-1.5 font-mono text-xs text-ink ring-1 ring-line">
          {t}
        </span>
      ))}
    </div>
  );
}

function MiniSettings() {
  return (
    <div aria-hidden="true" className={`${miniFrame} flex-col !items-stretch gap-2.5 px-5`}>
      {[
        ["Volume HUD", true],
        ["File shelf", false],
      ].map(([label, on]) => (
        <div key={String(label)} className="flex items-center justify-between text-sm text-muted">
          {label}
          <span
            className={`relative h-5 w-9 rounded-full transition-colors duration-300 ${
              on ? "bg-accent-1" : "bg-white/15 group-hover:bg-accent-1"
            }`}
          >
            <span
              className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-all duration-300 ${
                on ? "left-[18px]" : "left-0.5 group-hover:left-[18px]"
              }`}
            />
          </span>
        </div>
      ))}
    </div>
  );
}

/* ---------------- How it works ---------------- */

export function HowItWorks() {
  const { howItWorks } = site;
  return (
    <section id="how-it-works" aria-labelledby="how-title" className="relative py-20 md:py-32">
      <Container>
        <SectionHeading
          id="how-title"
          eyebrow={howItWorks.eyebrow}
          title={howItWorks.title}
          emphasis={howItWorks.titleEmphasis}
        />
        <div className="relative mt-14 md:mt-20">
          <div
            aria-hidden="true"
            className="absolute left-0 right-0 top-[2.1rem] hidden h-px bg-gradient-to-r from-transparent via-white/15 to-transparent md:block"
          />
          <ol className="relative grid gap-10 md:grid-cols-3 md:gap-8">
          {howItWorks.steps.map((step, i) => (
            <li key={step.title} className="relative" data-reveal style={{ ["--reveal-delay" as string]: i }}>
              <span className="font-display relative inline-grid h-[4.25rem] w-[4.25rem] place-items-center rounded-full bg-bg text-[2.25rem] leading-none text-ink ring-1 ring-line-strong">
                <span className="text-gradient">{String(i + 1).padStart(2, "0")}</span>
              </span>
              <h3 className="mt-6 text-xl font-semibold tracking-tight text-ink">
                {step.title}
                {i === 0 && site.downloadSize && (
                  <span className="ml-2 align-middle text-sm font-medium text-faint">{site.downloadSize}</span>
                )}
              </h3>
              <p className="mt-2 max-w-sm leading-relaxed text-muted text-pretty">{step.body}</p>
            </li>
          ))}
          </ol>
        </div>
      </Container>
    </section>
  );
}

/* ---------------- Interactive demo ---------------- */

export function Demo() {
  const { demo } = site;
  return (
    <section id="demo" aria-labelledby="demo-title" className="relative py-20 md:py-32">
      <div
        aria-hidden="true"
        className="glow left-1/2 top-1/2 h-[380px] w-[min(820px,90vw)] -translate-x-1/2 -translate-y-1/2 opacity-30"
        style={{ background: "radial-gradient(closest-side, rgb(167 139 250 / 0.6), transparent)" }}
      />
      <Container className="relative">
        <SectionHeading
          id="demo-title"
          eyebrow={demo.eyebrow}
          title={demo.title}
          emphasis={demo.titleEmphasis}
          intro={demo.intro}
        />
        <div className="mt-12 md:mt-16" data-reveal>
          <InteractiveDemo />
        </div>
      </Container>
    </section>
  );
}

/* ---------------- FAQ ---------------- */

export function FAQ() {
  const { faq } = site;
  return (
    <section id="faq" aria-labelledby="faq-title" className="relative py-20 md:py-32">
      <Container className="grid gap-12 lg:grid-cols-[1fr_1.6fr] lg:gap-20">
        <div className="lg:sticky lg:top-28 lg:self-start">
          <SectionHeading id="faq-title" eyebrow={faq.eyebrow} title={faq.title} emphasis={faq.titleEmphasis} align="left" />
          <p className="mt-5 text-muted" data-reveal>
            Something else?{" "}
            <a href={`mailto:${site.contactEmail}`} className="font-medium text-ink underline decoration-white/30 underline-offset-4 hover:decoration-white">
              Get in touch
            </a>
            .
          </p>
        </div>
        <div className="border-t border-line" data-reveal>
          {faq.items.map((item, i) => (
            <details key={item.q} name="faq" className="faq-item border-b border-line" open={i === 0}>
              <summary className="flex items-center justify-between gap-6 rounded-lg py-6 text-left text-lg font-medium text-ink transition-colors hover:text-white">
                {item.q}
                <span className="faq-icon grid h-8 w-8 shrink-0 place-items-center rounded-full bg-white/[0.05] text-muted ring-1 ring-line">
                  <PlusIcon size={16} />
                </span>
              </summary>
              <p className="max-w-2xl pb-6 pr-10 leading-relaxed text-muted text-pretty">{item.a}</p>
            </details>
          ))}
        </div>
      </Container>
    </section>
  );
}

/* ---------------- CTA + footer ---------------- */

export function FinalCTA() {
  const { cta } = site;
  return (
    <section id="download" aria-labelledby="cta-title" className="relative py-20 md:py-28">
      <Container>
        <div className="card relative overflow-hidden px-6 pb-14 pt-24 text-center sm:px-12 sm:pb-20 sm:pt-28" data-reveal>
          <div
            aria-hidden="true"
            className="glow -bottom-40 left-1/2 h-[360px] w-[80%] -translate-x-1/2 opacity-60"
            style={{ background: "radial-gradient(closest-side, rgb(127 168 255 / 0.6), rgb(167 139 250 / 0.4), transparent)" }}
          />
          {/* The notch, cut into the top of the banner. */}
          <div aria-hidden="true" className="absolute left-1/2 top-0 h-8 w-44 -translate-x-1/2 rounded-b-[14px] bg-black ring-1 ring-white/5 sm:w-52">
            <span className="absolute -left-2 top-0 h-2 w-2 bg-[radial-gradient(circle_at_0_100%,transparent_7.5px,#000_8px)]" />
            <span className="absolute -right-2 top-0 h-2 w-2 bg-[radial-gradient(circle_at_100%_100%,transparent_7.5px,#000_8px)]" />
          </div>
          <div className="relative">
            <h2 id="cta-title" className="font-display mx-auto max-w-3xl text-[clamp(2.5rem,7vw,5rem)] leading-[1] text-ink text-balance">
              {cta.title} <em className="text-gradient">{cta.titleEmphasis}</em>
            </h2>
            <p className="mx-auto mt-5 max-w-md text-lg text-muted">{cta.body}</p>
            <div className="mt-9 flex flex-col items-center gap-4">
              <DownloadButton className="!min-h-12 !px-7 !text-base" />
              <Requirements />
              <p className="text-xs text-faint">Version {site.version}</p>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}

export function Footer() {
  return (
    <footer className="border-t border-line py-10">
      <Container className="flex flex-col gap-6 text-sm text-faint md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-2.5">
          <Image src="/notchhub-icon.png" alt="" width={22} height={22} unoptimized className="h-[22px] w-[22px]" />
          <span>
            © {site.copyrightYear} {site.copyrightHolder}
          </span>
        </div>
        <ul className="flex flex-wrap items-center gap-x-6 gap-y-2">
          <li>
            <a href={site.githubUrl} className="inline-flex items-center gap-1.5 rounded transition-colors hover:text-ink">
              <GitHubIcon size={16} />
              GitHub
            </a>
          </li>
          <li>
            <a href={`mailto:${site.contactEmail}`} className="rounded transition-colors hover:text-ink">
              {site.contactEmail}
            </a>
          </li>
        </ul>
      </Container>
      <Container>
        <p className="mt-6 text-xs leading-relaxed text-faint">{site.footer.disclaimer}</p>
      </Container>
    </footer>
  );
}

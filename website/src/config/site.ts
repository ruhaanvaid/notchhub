/**
 * Everything editable on the site lives here: copy, links, version and requirements.
 * Components read from this file and contain no hard-coded marketing text.
 */

export const site = {
  name: "NotchHub",
  /** Public URL of the deployed site. Used for canonical and Open Graph links. */
  url: "https://notchhub-one.vercel.app",
  /** Current release, shown near the download buttons. */
  version: "0.6.0",
  /** Download size of the release zip, shown in "How it works". Set to "" to hide. */
  downloadSize: "1.5 MB",
  /** Replace with the real release URL, e.g. a GitHub "releases/latest" link. */
  downloadUrl: "#download",
  githubUrl: "#",
  contactEmail: "hello@example.com",
  copyrightHolder: "Ruhaan Vaid",
  copyrightYear: 2026,

  /** Shown under the hero buttons and in the final banner, joined with " • ". */
  requirements: ["Free", "macOS 14+", "Apple Silicon & Intel"],

  seo: {
    title: "NotchHub: your notch, finally useful",
    description:
      "NotchHub turns the MacBook notch into a Dynamic Island-style control panel for music, volume, timers and quick toggles. Free and open source for macOS.",
    ogAlt: "NotchHub: a Dynamic Island-style panel growing out of a MacBook notch",
  },

  nav: [
    { label: "Features", href: "#features" },
    { label: "How it works", href: "#how-it-works" },
    { label: "FAQ", href: "#faq" },
  ],

  hero: {
    eyebrow: "Free and open source for Mac",
    /** The word in `emphasis` is set in italic with the accent gradient. */
    headline: { before: "Your notch,", emphasis: "finally", after: "useful." },
    subhead:
      "NotchHub turns the notch into a Dynamic Island-style panel for your music, volume, timers and quick toggles, and puts a cleaner volume HUD right where you're already looking.",
    primaryCta: "Download for Mac",
    secondaryCta: "See features",
    demoLabel:
      "Animated demo: album art and audio bars sit beside the MacBook notch, which expands to show what's playing, then a volume HUD, a charging pop-up, a timer countdown and a shelf of files.",
  },

  features: {
    eyebrow: "Features",
    title: "Everything you reach for,",
    titleEmphasis: "one hover away.",
    intro: "Built around the notch you already have. Useful the moment it launches.",
    items: [
      {
        icon: "island",
        title: "A panel that grows from the notch",
        body: "Hover the notch and it opens into a Dynamic Island-style panel. Closed, it keeps a live activity beside the camera: album art and audio bars while music plays, or a countdown while a timer runs.",
      },
      {
        icon: "volume",
        title: "Volume where you're looking",
        body: "Press a volume or brightness key and a HUD drops out of the notch instead of the middle of your screen, on Apple's 16-step scale. Pop-ups for charging, low battery, headphones, Caps Lock and keyboard language appear in the same spot.",
      },
      {
        icon: "controls",
        title: "Quick controls",
        body: "Play, pause, skip and drag to seek in Music, Spotify, or YouTube and Netflix in your browser. Start a 5, 10 or 25-minute timer, switch audio output, keep your Mac awake, or turn on Do Not Disturb.",
      },
      {
        icon: "motion",
        title: "Fluid by default",
        body: "The notch reshapes with spring animations that feel like part of macOS, not a window sitting on top of it.",
      },
      {
        icon: "native",
        title: "Light and native",
        body: "Written in Swift and SwiftUI with zero third-party dependencies. No Dock icon, and it only checks what's playing while the panel is open or music is on.",
      },
      {
        icon: "sliders",
        title: "Yours to tune",
        body: "Show or hide each section, choose which overlays to replace, and set how long the HUD stays on screen.",
      },
    ] as Feature[],
    /** Smaller extras listed under the grid. */
    extras: [
      { title: "File shelf", body: "Drag files onto the notch to park them, then drag them out anywhere." },
      { title: "No notch? No problem", body: "Macs without a notch, and external displays, get a slim pill at the top of the screen." },
      { title: "Out of your way", body: "Hides automatically while a full-screen app covers the screen." },
      { title: "Updates itself", body: "Checks for new versions once a day and installs them in place." },
    ],
    /** In development, not in the current release. Shown with a "Coming soon" badge. Empty the list to hide it. */
    comingSoon: [] as { title: string; body: string }[],
  },

  howItWorks: {
    eyebrow: "How it works",
    title: "Up and running",
    titleEmphasis: "in a minute.",
    steps: [
      {
        title: "Download",
        body: "Grab the latest version. It's free, with no account and nothing to sign up for.",
      },
      {
        title: "Move to Applications",
        body: "Unzip and drag NotchHub into Applications. The first time, click Open Anyway in System Settings › Privacy & Security, since NotchHub isn't notarized by Apple.",
      },
      {
        title: "Grant one permission",
        body: "Allow Accessibility so NotchHub can take over the volume and brightness keys. Then hover your notch. That's it.",
      },
    ],
  },

  demo: {
    eyebrow: "Try it",
    title: "Take it",
    titleEmphasis: "for a spin.",
    intro: "Click through the states and play with the controls. It's the same layout you'll see on your Mac.",
    tabs: {
      playing: "Now playing",
      volume: "Volume",
      brightness: "Brightness",
      popups: "Pop-ups",
      timer: "Timer",
      shelf: "File shelf",
    },
    /** Hero loop labels. */
    heroLabels: {
      live: "Live activity",
      playing: "Now playing",
      volume: "Volume",
      popup: "Pop-ups",
      timer: "Timer",
      shelf: "File shelf",
    },
    hints: {
      playing: "Try play, skip, the heart, the progress bar, the volume squares, the output menu and the toggles.",
      volume: "Press the keys. On your Mac, these are the volume keys on your keyboard.",
      brightness: "Press the keys. On your Mac, these are the brightness keys on your keyboard.",
      popups: "Trigger a pop-up. On your Mac, these appear on their own when something changes.",
      timer: "Pick a preset. While it runs, the countdown sits beside the closed notch, and a sound plays when it's done.",
      shelf: "On your Mac, drag files onto the notch to park them here, and drag them out to drop them anywhere.",
    },
  },

  faq: {
    eyebrow: "FAQ",
    title: "Questions,",
    titleEmphasis: "answered.",
    items: [
      {
        q: "Is NotchHub really free?",
        a: "Yes. NotchHub is free and open source under the MIT license. There's no account, no ads and nothing to buy.",
      },
      {
        q: "Which Macs are supported?",
        a: "Any Mac running macOS 14 Sonoma or later, on Apple silicon or Intel. On MacBooks with a notch, the panel grows right out of it. On Macs without one, and on external displays, NotchHub shows a slim pill at the top of the main display that works the same way.",
      },
      {
        q: "Does it replace the system volume HUD?",
        a: "Yes, if you want it to. With the Accessibility permission, NotchHub shows its own volume and brightness HUD in the notch instead of Apple's overlay, and you can switch each one on or off. If your output has no software volume control, like some HDMI displays, the key goes to macOS as usual.",
      },
      {
        q: "What permissions does it need, and why?",
        a: "Accessibility, so it can catch the volume and brightness keys and notice Caps Lock; every other key passes straight through. Automation for Music, Spotify and your browser, so it can show what's playing and control playback. Everything except the HUD works without Accessibility. There are no accounts or analytics. NotchHub checks GitHub once a day for updates (you can turn this off), loads site icons for browser media, and sends only a song's title and artist to Apple's iTunes Search to find album art.",
      },
      {
        q: "Does it slow my Mac down?",
        a: "It's built to stay out of the way. NotchHub is a native Swift app with no third-party dependencies and no Dock icon. It only checks what's playing while the panel is open or something is playing, and it hides while a full-screen app covers the screen.",
      },
      {
        q: "Why does macOS say it can't verify NotchHub?",
        a: "NotchHub isn't notarized by Apple, which requires a paid developer account. The first time you open it, go to System Settings › Privacy & Security and click Open Anyway. You only do this once; updates install in place after that.",
      },
    ],
  },

  cta: {
    title: "Give your notch",
    titleEmphasis: "something to do.",
    body: "Free for everyone, with no account and no ads.",
  },

  footer: {
    disclaimer:
      "NotchHub is not affiliated with Apple Inc. Mac, MacBook and macOS are trademarks of Apple Inc.",
  },

  /** Sample content for the notch demos. Fictional tracks and files. */
  sample: {
    tracks: [
      { title: "Golden Hour Tapes", artist: "Lumen Park", art: ["#ff9a4c", "#ff3d81", "#b347ff"], duration: 216 },
      { title: "Night Swim", artist: "The Paper Moons", art: ["#3dd6ff", "#3d6bff", "#7a3dff"], duration: 241 },
      { title: "Slow Static", artist: "Juniper Coast", art: ["#c6ff6b", "#2fd6a3", "#1f7aff"], duration: 189 },
    ],
    outputs: ["Speakers", "AirPods", "Display"],
    /** Keyboard input sources the demo cycles through. */
    keyboards: ["ABC", "French", "Japanese"],
    headphones: "AirPods",
    files: [
      { name: "Report.pdf", kind: "pdf" },
      { name: "Hero.png", kind: "image" },
      { name: "Notes.md", kind: "doc" },
      { name: "Assets.zip", kind: "zip" },
    ],
  },
} as const;

export type FeatureIcon = "island" | "volume" | "controls" | "motion" | "native" | "sliders";

export type Feature = {
  icon: FeatureIcon;
  title: string;
  body: string;
  /** Set for anything not shipped yet; the card gets a "Coming soon" badge. */
  comingSoon?: boolean;
};

export type Site = typeof site;

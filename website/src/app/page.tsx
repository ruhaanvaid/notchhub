import { RevealObserver } from "@/components/Reveal";
import { Demo, FAQ, Features, FinalCTA, Footer, Hero, HowItWorks, Nav } from "@/components/sections";

export default function Home() {
  return (
    <>
      <a
        href="#main"
        className="sr-only z-[100] rounded-full bg-white px-4 py-2 font-semibold text-bg focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
      >
        Skip to content
      </a>
      <Nav />
      <main id="main">
        <Hero />
        <Features />
        <HowItWorks />
        <Demo />
        <FAQ />
        <FinalCTA />
      </main>
      <Footer />
      <RevealObserver />
    </>
  );
}

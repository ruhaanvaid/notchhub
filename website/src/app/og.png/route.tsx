import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { site } from "@/config/site";

/** Generates /og.png at build time (Open Graph and Twitter card image). */
export const dynamic = "force-static";

const size = { width: 1200, height: 630 };

const fontDir = join(process.cwd(), "node_modules/@fontsource/instrument-serif/files");

export async function GET() {
  const [serif, serifItalic, icon] = await Promise.all([
    readFile(join(fontDir, "instrument-serif-latin-400-normal.woff")),
    readFile(join(fontDir, "instrument-serif-latin-400-italic.woff")),
    readFile(join(process.cwd(), "public/notchhub-icon.png")),
  ]);
  const iconSrc = `data:image/png;base64,${icon.toString("base64")}`;
  const { before, emphasis, after } = site.hero.headline;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          background:
            "radial-gradient(ellipse 60% 55% at 50% 30%, rgba(127,168,255,0.35), rgba(167,139,250,0.18) 55%, rgba(7,7,10,0) 100%), #07070a",
          fontFamily: "system-ui",
          color: "#f3f3f7",
        }}
      >
        {/* The notch, opened into a panel. */}
        <div style={{ display: "flex", position: "relative" }}>
          <div
            style={{
              width: 560,
              display: "flex",
              flexDirection: "column",
              background: "#000",
              borderBottomLeftRadius: 40,
              borderBottomRightRadius: 40,
              padding: "56px 30px 28px",
              boxShadow: "0 30px 80px rgba(0,0,0,0.6)",
            }}
          >
            <div style={{ display: "flex", alignItems: "center" }}>
              <div
                style={{
                  width: 76,
                  height: 76,
                  borderRadius: 18,
                  background: "linear-gradient(135deg, #ff9a4c, #ff3d81 55%, #b347ff)",
                  boxShadow: "0 0 40px rgba(255,61,129,0.5)",
                }}
              />
              <div style={{ display: "flex", flexDirection: "column", marginLeft: 20, flex: 1 }}>
                <div style={{ width: 210, height: 16, borderRadius: 8, background: "#fff" }} />
                <div style={{ width: 140, height: 12, borderRadius: 6, marginTop: 12, background: "rgba(255,255,255,0.4)" }} />
              </div>
              <div style={{ display: "flex", gap: 14 }}>
                <div style={{ width: 14, height: 14, borderRadius: 7, background: "rgba(255,255,255,0.7)" }} />
                <div style={{ width: 14, height: 14, borderRadius: 7, background: "#fff" }} />
                <div style={{ width: 14, height: 14, borderRadius: 7, background: "rgba(255,255,255,0.7)" }} />
              </div>
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", marginTop: 26 }}>
              {Array.from({ length: 16 }, (_, i) => (
                <div
                  key={i}
                  style={{
                    width: 22,
                    height: 22,
                    borderRadius: 5,
                    background: i < 11 ? "#fff" : "rgba(255,255,255,0.15)",
                  }}
                />
              ))}
            </div>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            marginTop: 64,
            fontFamily: "Instrument Serif",
            fontSize: 112,
            lineHeight: 1.25,
            letterSpacing: "-0.01em",
          }}
        >
          <span>{before}&nbsp;</span>
          <span
            style={{
              fontStyle: "italic",
              backgroundImage: "linear-gradient(100deg, #7fa8ff, #a78bfa 55%, #d4a5ff)",
              backgroundClip: "text",
              color: "transparent",
              paddingRight: 10,
            }}
          >
            {emphasis}
          </span>
          <span>&nbsp;{after}</span>
        </div>

        <div style={{ display: "flex", alignItems: "center", marginTop: 40, fontSize: 32, color: "#a6a6b3" }}>
          {/* eslint-disable-next-line @next/next/no-img-element -- rendered by ImageResponse, not the browser */}
          <img src={iconSrc} width={44} height={44} alt="" style={{ marginRight: 14 }} />
          <span style={{ color: "#f3f3f7", fontWeight: 600, marginRight: 18 }}>{site.name}</span>
          <span>{site.requirements.join("  •  ")}</span>
        </div>
      </div>
    ),
    {
      ...size,
      fonts: [
        { name: "Instrument Serif", data: serif, style: "normal", weight: 400 },
        { name: "Instrument Serif", data: serifItalic, style: "italic", weight: 400 },
      ],
    },
  );
}

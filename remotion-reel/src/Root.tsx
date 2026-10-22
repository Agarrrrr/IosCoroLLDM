import React from 'react';
import { Composition, AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';

const HUMAN_SINGING_SVG_PATH =
  'M 306.41,435.50 C 323.75,432.34 353.20,420.92 359.69,414.82 C 362.75,411.95 363.47,407.81 361.55,404.10 C 358.48,398.17 352.59,397.40 344.62,401.89 C 324.57,413.19 293.17,420.19 270.04,418.51 C 251.56,417.17 230.97,412.08 218.64,405.81 C 215.18,404.05 214.84,403.55 215.37,400.90 C 216.28,396.36 220.98,387.39 224.76,382.97 C 231.62,374.95 236.91,373.23 261.11,371.13 C 276.63,369.79 285.43,365.28 288.05,357.34 C 288.98,354.53 288.72,352.56 286.37,344.76 C 284.26,337.72 283.59,333.34 283.55,326.50 L 283.50,317.50 L 272.50,317.00 L 261.50,316.50 L 270.93,311.43 C 276.12,308.65 280.80,305.68 281.33,304.84 C 282.02,303.74 281.65,302.45 280.01,300.22 C 278.20,297.78 277.83,296.28 278.26,293.10 C 279.24,285.79 281.96,281.79 288.20,278.47 C 301.11,271.62 301.87,268.26 293.32,255.79 C 279.44,235.53 276.62,231.03 273.03,223.50 C 270.93,219.10 268.23,211.22 267.01,206.00 C 262.64,187.15 259.79,177.35 256.24,169.00 C 252.55,160.30 243.78,144.60 241.99,143.50 C 241.45,143.16 241.00,142.49 241.00,142.02 C 241.00,140.65 253.75,138.12 266.06,137.04 C 291.90,134.77 318.93,140.25 343.24,152.69 C 353.00,157.68 355.96,157.80 360.10,153.39 C 363.05,150.25 363.30,144.10 360.61,141.12 C 357.44,137.62 342.06,130.34 327.99,125.69 C 308.03,119.08 298.85,117.62 277.50,117.63 C 257.11,117.65 248.39,118.93 230.00,124.63 C 204.01,132.68 184.17,144.73 164.42,164.44 C 144.91,183.91 132.65,204.11 124.63,230.00 C 118.94,248.36 117.65,257.12 117.62,277.50 C 117.59,298.62 119.53,310.57 126.09,329.70 C 133.67,351.80 145.15,370.64 161.50,387.82 C 188.30,415.98 221.08,432.31 261.00,437.37 C 268.19,438.29 297.78,437.06 306.41,435.50 Z M 388.56,392.79 C 391.67,391.37 405.15,375.53 411.69,365.60 C 422.30,349.51 432.15,325.01 435.45,306.50 C 444.24,257.32 429.18,205.35 395.76,169.47 C 388.45,161.62 385.57,160.32 380.33,162.51 C 376.53,164.09 375.00,166.65 375.00,171.40 C 375.00,174.35 376.09,176.14 381.58,182.22 C 418.45,223.00 428.65,279.60 408.28,330.50 C 401.82,346.67 393.26,360.02 380.25,374.24 C 375.85,379.05 375.00,380.60 375.00,383.77 C 375.00,391.57 381.60,395.96 388.56,392.79 Z M 366.65,360.25 C 373.48,353.13 383.86,337.74 387.89,328.76 C 403.59,293.72 402.68,255.37 385.35,221.81 C 378.85,209.22 368.19,195.05 361.92,190.66 C 356.55,186.89 348.65,190.04 347.45,196.42 C 346.75,200.15 348.46,204.31 352.02,207.50 C 359.18,213.93 368.39,228.94 373.42,242.34 C 383.51,269.30 381.78,298.12 368.50,324.27 C 364.43,332.29 357.47,342.26 352.99,346.50 C 346.53,352.62 345.42,357.97 349.59,362.92 C 351.77,365.52 352.88,366.00 356.65,366.00 C 360.80,366.00 361.54,365.57 366.65,360.25 Z M 333.83,337.59 C 340.39,334.19 351.27,317.39 356.02,303.31 C 365.59,274.91 357.50,239.77 336.95,220.55 C 332.29,216.19 331.51,215.82 328.17,216.35 C 323.20,217.14 320.00,220.95 320.00,226.08 C 320.00,229.27 320.74,230.87 323.83,234.27 C 330.02,241.10 333.98,247.59 337.29,256.32 C 340.18,263.94 340.39,265.39 340.40,277.50 C 340.41,289.16 340.13,291.27 337.68,297.99 C 334.42,306.94 330.43,313.74 324.44,320.50 C 318.83,326.84 318.37,331.53 322.92,336.08 C 326.17,339.32 329.57,339.79 333.83,337.59 Z';

const SAMPLE_SONGS = [
  { id: '1', canto: 'A Dónde Iré', temas: 'Confianza · Petición' },
  { id: '2', canto: 'A los Pies del Salvador', temas: 'Confianza · Esperanza' },
  { id: '3', canto: 'A solas al Huerto', temas: 'Confianza' },
  { id: '4', canto: 'Al Gran Señor', temas: 'Adoración' },
  { id: '5', canto: 'Al Huerto Van a Visitar', temas: 'Resurrección' },
  { id: '6', canto: 'Alabad a Jehová', temas: 'Alabanza' },
  { id: '7', canto: 'Alabad, Aleluya', temas: 'Elección' },
  { id: '8', canto: 'Alcancé Salvación', temas: 'Libertad' },
  { id: '9', canto: 'Aleluya a nuestro Dios', temas: 'Alabanza' },
  { id: '10', canto: 'Aleluya al Cordero de Dios', temas: 'Santa Cena' },
  { id: '11', canto: 'Aleluya al Rey', temas: 'Alabanza' },
  { id: '12', canto: 'Aleluya, oh Creador', temas: 'Alabanza' },
  { id: '13', canto: 'Amado Incomparable', temas: 'Elección' },
  { id: '14', canto: 'Amado Salvador', temas: 'Gratitud · Salvación' },
];

export const SingingIconSvg: React.FC<{ size?: number; color?: string }> = ({
  size = 38,
  color = '#D4AF37',
}) => (
  <svg width={size} height={size} viewBox="0 0 554 554" fill={color}>
    <path d={HUMAN_SINGING_SVG_PATH} fillRule="evenodd" />
  </svg>
);

export const PianoIconSvg: React.FC<{ size?: number; color?: string }> = ({
  size = 38,
  color = '#D4AF37',
}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
    <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-5 11.5h.25V19h-4.5v-4.5H10c.55 0 1-.45 1-1V5h2v8.5c0 .55.45 1 1 1zM5 5h2v8.5c0 .55.45 1 1 1h.25V19H5V5zm14 14h-3.25v-4.5H16c.55 0 1-.45 1-1V5h2v14z" />
  </svg>
);

export const CatalogScrollScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  const scrollY = interpolate(
    frame,
    [0, 60, 140, durationInFrames],
    [0, 260, 580, 1180],
    { extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#F8F8F8',
        fontFamily: 'Roboto, Segoe UI, sans-serif',
      }}
    >
      {/* Lista de ScoreCards idéntica a lib/features/dashboard/widgets/score_card.dart */}
      <div
        style={{
          flex: 1,
          overflow: 'hidden',
          padding: '260px 36px 140px 36px',
        }}
      >
        <div
          style={{
            transform: `translateY(-${scrollY}px)`,
            display: 'flex',
            flexDirection: 'column',
            gap: 24,
          }}
        >
          {SAMPLE_SONGS.map((song) => (
            <div
              key={song.id}
              style={{
                backgroundColor: '#D4AF37',
                borderRadius: 34,
                paddingLeft: 10,
                boxShadow: '0 8px 16px rgba(0, 0, 0, 0.04)',
              }}
            >
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  borderTopLeftRadius: 24,
                  borderBottomLeftRadius: 24,
                  borderTopRightRadius: 34,
                  borderBottomRightRadius: 34,
                  padding: '28px 34px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                }}
              >
                <div>
                  <div style={{ fontSize: 36, fontWeight: 600, color: '#333333' }}>
                    {song.canto}
                  </div>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 12,
                      marginTop: 10,
                    }}
                  >
                    <PianoIconSvg size={36} color="#D4AF37" />
                    <SingingIconSvg size={36} color="#D4AF37" />
                    <span style={{ fontSize: 28, color: '#666666' }}>{song.temas}</span>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="CoroReelClip03"
        component={CatalogScrollScene}
        durationInFrames={202}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};

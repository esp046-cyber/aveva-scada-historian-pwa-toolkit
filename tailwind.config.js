// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: ['./src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        gunmetal: '#0A0E12',   // base canvas
        graphite: '#131A21',   // panel fill
        steelline: '#1F2A33',  // grid/border lines
        offwhite: '#E6EDF0',   // primary text
        cyan: {
          DEFAULT: '#2DE1E8',
          dim: '#1B7E82',
        },
        amber: {
          DEFAULT: '#FFB020',
          dim: '#8C6314',
        },
        crimson: {
          DEFAULT: '#FF3B4E',
          dim: '#8C1D29',
        },
      },
      fontFamily: {
        sans: ['"IBM Plex Sans"', 'system-ui', 'sans-serif'],
        mono: ['"IBM Plex Mono"', 'ui-monospace', 'monospace'],
      },
      backgroundImage: {
        'schematic-grid':
          'linear-gradient(rgba(45,225,232,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(45,225,232,0.06) 1px, transparent 1px)',
      },
      backgroundSize: {
        grid: '32px 32px',
      },
      boxShadow: {
        glass: '0 8px 32px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.04)',
      },
      keyframes: {
        pulseLive: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.35' },
        },
      },
      animation: {
        'pulse-live': 'pulseLive 1.8s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};

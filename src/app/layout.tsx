// src/app/layout.tsx
import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AGC SCADA Ops | Al Gurg Automation & Controls',
  description:
    'Field companion dashboard for AVEVA SCADA, System Platform, and Historian — Al Gurg Automation & Controls, Dubai.',
  manifest: '/manifest.json',
  applicationName: 'AGC SCADA Ops',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'AGC SCADA Ops',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  themeColor: '#0A0E12',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="bg-gunmetal text-offwhite antialiased">
        {children}
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', () => {
                  navigator.serviceWorker.register('/sw.js').catch(console.error);
                });
              }
            `,
          }}
        />
      </body>
    </html>
  );
}

// src/components/icons/ScadaIcons.tsx
// Inline SVG icon set for the SCADA dashboard nav rail and panel headers.
// All icons use currentColor so they inherit Tailwind text-* utility colors.

import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement>;

export function TelemetryIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path
        d="M3 17L8 10L12 14L21 4"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M15 4H21V10" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="8" cy="10" r="1.4" fill="currentColor" />
      <circle cx="12" cy="14" r="1.4" fill="currentColor" />
      <path d="M3 21H21" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" opacity="0.35" />
    </svg>
  );
}

export function AlarmIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path
        d="M12 3L21.5 20H2.5L12 3Z"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinejoin="round"
      />
      <path d="M12 9.5V14" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" />
      <circle cx="12" cy="17" r="1.1" fill="currentColor" />
    </svg>
  );
}

export function DatabaseIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <ellipse cx="12" cy="5.5" rx="8" ry="3" stroke="currentColor" strokeWidth="1.75" />
      <path d="M4 5.5V18.5C4 20.1569 7.58172 21.5 12 21.5C16.4183 21.5 20 20.1569 20 18.5V5.5" stroke="currentColor" strokeWidth="1.75" />
      <path d="M4 12C4 13.6569 7.58172 15 12 15C16.4183 15 20 13.6569 20 12" stroke="currentColor" strokeWidth="1.75" />
    </svg>
  );
}

export function SettingsIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <circle cx="12" cy="12" r="3.25" stroke="currentColor" strokeWidth="1.75" />
      <path
        d="M12 2.75V5.25M12 18.75V21.25M21.25 12H18.75M5.25 12H2.75M18.01 5.99L16.25 7.75M7.75 16.25L5.99 18.01M18.01 18.01L16.25 16.25M7.75 7.75L5.99 5.99"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function SignalWifiIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M3 8.5C8.5 3.5 15.5 3.5 21 8.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" opacity="0.4" />
      <path d="M6 12.2C9.8 8.8 14.2 8.8 18 12.2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" opacity="0.7" />
      <path d="M9 15.8C10.8 14.2 13.2 14.2 15 15.8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      <circle cx="12" cy="19" r="1.3" fill="currentColor" />
    </svg>
  );
}

export function ExpandPanelIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M9 3H3V9" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M15 3H21V9" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M9 21H3V15" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M15 21H21V15" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

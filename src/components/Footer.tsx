// src/components/Footer.tsx
import { LinkedInIcon, XIcon, GitHubIcon } from './icons/SocialIcons';

const SOCIAL_LINKS = [
  { label: 'LinkedIn', href: 'https://www.linkedin.com', Icon: LinkedInIcon },
  { label: 'X', href: 'https://www.x.com', Icon: XIcon },
  { label: 'GitHub', href: 'https://www.github.com', Icon: GitHubIcon },
] as const;

export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="shrink-0 border-t border-steelline bg-graphite/80 backdrop-blur-md px-4 sm:px-6 py-3 flex flex-col sm:flex-row items-center justify-between gap-2">
      <p className="text-[11px] text-text-dim text-center sm:text-left">
        © {year} Al Gurg Automation &amp; Controls — Dubai, UAE. Internal engineering tool, not for public distribution.
      </p>

      <div className="flex items-center gap-3">
        {SOCIAL_LINKS.map(({ label, href, Icon }) => (
          <a
            key={label}
            href={href}
            target="_blank"
            rel="noreferrer noopener"
            aria-label={label}
            className="text-text-dim hover:text-cyan transition-colors"
          >
            <Icon className="w-4 h-4" />
          </a>
        ))}
      </div>
    </footer>
  );
}

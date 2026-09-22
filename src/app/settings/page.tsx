export default function SettingsPage() {
  return (
    <div className="p-6 flex flex-col gap-4">
      <h1 className="text-lg font-medium text-white">PWA & SCADA Settings</h1>
      <p className="text-xs text-text-dim">Configure polling intervals, SQL endpoints, and offline cache sync.</p>
    </div>
  );
}

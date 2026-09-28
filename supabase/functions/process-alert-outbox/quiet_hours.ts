// Absolute-time scan applies IANA daylight-saving rules for each candidate.
export function quietHoursReleaseTime(
  now: Date, zone: string, startText: string, endText: string,
): Date | null {
  const parse = (value: string): number => {
    const match = /^(\d{1,2}):(\d{2})/.exec(value);
    if (!match) throw new Error("Invalid quiet-hours time");
    const hour = Number(match[1]);
    const minute = Number(match[2]);
    if (hour >= 24 || minute >= 60) throw new Error("Invalid quiet-hours time");
    return hour * 60 + minute;
  };
  const start = parse(startText);
  const end = parse(endText);
  if (start === end) return null;
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: zone, hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  });
  const isQuiet = (instant: Date): boolean => {
    const parts = formatter.formatToParts(instant);
    const hour = Number(parts.find((part) => part.type === "hour")?.value) % 24;
    const minute = Number(parts.find((part) => part.type === "minute")?.value);
    const local = hour * 60 + minute;
    return start < end ? local >= start && local < end : local >= start || local < end;
  };
  if (!isQuiet(now)) return null;
  for (let minutes = 1; minutes <= 26 * 60; minutes++) {
    const candidate = new Date(now.getTime() + minutes * 60000);
    if (!isQuiet(candidate)) return candidate;
  }
  throw new Error("Could not determine quiet-hours release");
}

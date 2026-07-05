async function submit41(pw) {
  const body = new URLSearchParams();
  body.set("submission", pw);
  body.set("action", "submit");

  const res = await fetch("/41_lap5f87vo6k6vgb0s3.php", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  });

  const raw = await res.text();

  const clean = raw
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  const passcodeMatch =
    raw.match(/Passcode:\s*([A-Za-z0-9_{}\-]+)/i) ||
    clean.match(/Passcode:\s*([A-Za-z0-9_{}\-]+)/i);

  const levelMatch =
    clean.match(/ae27ff\s+(\d+)\s+([A-Za-z0-9_+\- ]+)/i);

  return {
    pw,
    status: res.status,
    len: raw.length,
    passcode: passcodeMatch ? passcodeMatch[1] : null,
    level: levelMatch ? levelMatch[1] : null,
    title: levelMatch ? levelMatch[2].trim() : null,
    clean: clean.slice(0, 1200),
    raw: raw.slice(0, 3000)
  };
}

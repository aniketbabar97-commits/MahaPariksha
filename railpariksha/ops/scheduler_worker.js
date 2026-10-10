// RailPariksha scheduler: a Cloudflare Worker with one cron trigger that starts the Telegram and Shorts workflows on
// the minute. GitHub's own `schedule:` is best effort and, in this repository, runs hours late or not at all, which
// cannot carry an hourly Telegram quiz and six Shorts a day. See railpariksha/docs/SCHEDULER.md for the 3-minute setup.
//
// Cron trigger (UTC): "30 0-17 * * *"  = every hour from 06:00 to 23:00 IST (IST = UTC + 5:30).
// Secrets / variables on the Worker:
//   GH_TOKEN  (secret)    fine-grained GitHub token, this repository only, permission "Actions: read and write"
//   RUN_KEY   (secret)    optional; lets you test by opening  https://<worker>/?run=<RUN_KEY>
//   REPO      (variable)  default aniketbabar97-commits/MahaPariksha
//   REF       (variable)  default aniketai/relaxed-albattani-6kjmc7  (the repository's default branch)

const SHORT_SLOTS = { 7: "1", 10: "2", 13: "3", 16: "4", 19: "5", 22: "6" }; // IST hour -> Shorts slot

// What to start at a given moment: [{workflow, inputs}]. Pure, so it can be tested.
export function plan(date) {
  const ist = new Date(date.getTime() + 5.5 * 3600 * 1000);
  const hour = ist.getUTCHours();
  const sunday = ist.getUTCDay() === 0;
  const jobs = [];
  if (hour >= 6 && hour <= 23) {
    let slot = "quiz";
    if (hour === 11) slot = "fact";
    else if (hour === 17) slot = "tip";
    else if (hour === 19 && sunday) slot = "weekly";
    jobs.push({ workflow: "railpariksha_telegram.yml", inputs: { slot } });
  }
  if (SHORT_SLOTS[hour]) {
    jobs.push({ workflow: "railpariksha_shorts.yml", inputs: { slot: SHORT_SLOTS[hour], lang: "auto" } });
  }
  return jobs;
}

async function dispatch(env, job) {
  const repo = env.REPO || "aniketbabar97-commits/MahaPariksha";
  const ref = env.REF || "aniketai/relaxed-albattani-6kjmc7";
  const url = `https://api.github.com/repos/${repo}/actions/workflows/${job.workflow}/dispatches`;
  let last = "";
  for (let attempt = 1; attempt <= 3; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GH_TOKEN}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "railpariksha-scheduler",
      },
      body: JSON.stringify({ ref, inputs: job.inputs }),
    });
    if (res.status === 204) return `${job.workflow} ${JSON.stringify(job.inputs)}: started`;
    last = `${res.status} ${(await res.text()).slice(0, 200)}`;
    if (res.status < 500 && res.status !== 429) break; // a refusal will not change on retry
    await new Promise((r) => setTimeout(r, attempt * 2000));
  }
  return `${job.workflow} ${JSON.stringify(job.inputs)}: FAILED ${last}`;
}

async function run(date, env) {
  const out = [];
  for (const job of plan(date)) out.push(await dispatch(env, job));
  console.log(out.join("\n") || "nothing to start at this hour");
  return out;
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(run(new Date(event.scheduledTime), env));
  },
  // Opening  /?run=<RUN_KEY>  starts what is due now (for a first test); anything else just says the Worker is alive.
  async fetch(request, env) {
    const key = new URL(request.url).searchParams.get("run");
    if (key && env.RUN_KEY && key === env.RUN_KEY) {
      return new Response((await run(new Date(), env)).join("\n") || "nothing due at this hour", { status: 200 });
    }
    return new Response("RailPariksha scheduler is running", { status: 200 });
  },
};

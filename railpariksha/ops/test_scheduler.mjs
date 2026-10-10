// node railpariksha/ops/test_scheduler.mjs
import assert from "node:assert/strict";
import { plan } from "./scheduler_worker.js";

const at = (iso) => plan(new Date(iso)); // iso in UTC; IST = +5:30
const one = (iso, workflow) => at(iso).filter((j) => j.workflow === workflow);

// 2026-10-12 is a Monday. 01:30 UTC = 07:00 IST.
assert.deepEqual(at("2026-10-12T01:30:00Z"), [
  { workflow: "railpariksha_telegram.yml", inputs: { slot: "quiz" } },
  { workflow: "railpariksha_shorts.yml", inputs: { slot: "1", lang: "auto" } },
]);
// quiz at 06:00 IST and no Short
assert.deepEqual(at("2026-10-12T00:30:00Z"), [{ workflow: "railpariksha_telegram.yml", inputs: { slot: "quiz" } }]);
// 11:00 IST is the fact, 17:00 IST the tip
assert.equal(one("2026-10-12T05:30:00Z", "railpariksha_telegram.yml")[0].inputs.slot, "fact");
assert.equal(one("2026-10-12T11:30:00Z", "railpariksha_telegram.yml")[0].inputs.slot, "tip");
// Sunday 19:00 IST is the weekly recap, with Short 5 as well; Monday 19:00 IST is a quiz
assert.equal(one("2026-10-11T13:30:00Z", "railpariksha_telegram.yml")[0].inputs.slot, "weekly");
assert.equal(one("2026-10-11T13:30:00Z", "railpariksha_shorts.yml")[0].inputs.slot, "5");
assert.equal(one("2026-10-12T13:30:00Z", "railpariksha_telegram.yml")[0].inputs.slot, "quiz");
// 22:00 IST is Short 6; 23:00 IST is a quiz; outside 06:00-23:00 IST nothing is started
assert.equal(one("2026-10-12T16:30:00Z", "railpariksha_shorts.yml")[0].inputs.slot, "6");
assert.equal(at("2026-10-12T17:30:00Z").length, 1);
assert.equal(at("2026-10-12T18:30:00Z").length, 0);
// six Shorts across a day
let shorts = 0;
for (let h = 0; h < 24; h++) shorts += one(`2026-10-12T${String(h).padStart(2, "0")}:30:00Z`, "railpariksha_shorts.yml").length;
assert.equal(shorts, 6);
console.log("scheduler plan: all checks passed");

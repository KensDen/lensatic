# Agentic SecOps Tradecraft Field Card

© 2026 Ken Connell. All rights reserved.

*A two-page distillation of the Agentic SecOps Tradecraft Playbook — the operational spine across all seven themes. **Load it into an agent's context** to apply these controls during design and operations; **read it in one sitting** as a field reference. The full playbook is the source of truth for depth, sources, and rationale.*

---

## The thesis in five lines
- Agentic AI security is **continuous, not point-in-time** — no finite guardrail set is universally robust, so static deploy-and-forget safety is formally insufficient.
- Build **containment-first** — assume compromise; favor resilience, reversibility, and isolation over efficiency.
- Keep the **human in command** — rising autonomy *shifts* oversight, it does not remove it.
- The defining identity problem is **attribution** — controlling your own signature and attributing others are two ends of one chain.
- The bottleneck has moved from **finding to validating** — the post-Mythos SOC runs on confidence, not alert volume.

## Foundations (know cold)
- **LLM vs. agent** — an agent plans, uses tools, and acts in a loop. Autonomy is a dial (none → prescribed → supervised → full agency), not a switch.
- **Equal-privilege input** is the architectural root of prompt injection: models process instructions and data at the same privilege. Treat all untrusted content as potentially hostile.
- **Dual-use reality** — the same capabilities that defend can attack; tradecraft is the discipline that decides which.
- **The lethal trifecta** — private-data access + untrusted-content exposure + external communication = exfiltration risk. Break at least one leg in every agent design.

## The teaming loop (red → blue → purple, continuous)
- **Red** — emulate agentic adversaries: multi-step, tool-using, intelligence-driven (agents acting as named threat actors using your own CTI).
- **Blue** — defend *with* agents, but validate everything. Detection-as-code: version-controlled, peer-reviewed, CI/CD-tested — not console-tuned.
- **Purple** — close the loop: every red finding becomes a tested detection; re-run emulation to prove it fires. Point-in-time assessment is dead; the loop is the product.
- **Continuous agent evaluation** — agents degrade. Keep checking they're still good.

## Defensive controls (the agent-security checklist)
1. **Tool least-privilege** — scope tools tightly; excessive agency is the core agent risk.
2. **Input validation** — defend the prompt-injection surface; sanitize retrieved and untrusted content.
3. **Memory & context isolation** — memory, hooks, and retrieved context are attack surface that persists across sessions.
4. **Human-in-the-loop** — gate consequential actions on human judgment.
5. **Output validation & guardrails** — verify before acting; enforcement hot-updateable, not static.
6. **Monitoring & observability** — log agent reasoning and actions, and expose them — visible reasoning is what earns trust.
7. **Multi-agent trust boundaries** — treat inter-agent messages as untrusted; contain cascading failures.
8. **Data protection** — data is the new perimeter; propagate identity, don't over-share.
9. **Authorization lives outside the model**: the user, the agent and the delegated scope go to a PDP on every tool call (CoSAI, Zero Trust for AI Systems).

## Containment & incident response
- **Cryptographically anchored agent identity** with short-lived credentials.
- **Assume-compromise** — vulnerability management and IR converge: patch the asset, then determine whether an adversary beat the patch there.
- **Agent IR** — reversibility and rapid rollback; isolate and contain, don't only prevent.

## Governance, GRC & federal
- **NIST AI RMF** — GOVERN / MAP / MEASURE / MANAGE: the backbone to align to.
- **Anchor frameworks** — OWASP LLM Top 10 + Agentic (ASI) Top 10 + NHI Top 10; MITRE ATT&CK + ATLAS; NIST SP 800-207 (zero trust); Google SAIF; ISO 42001; EU AI Act.
- **Policy = tool arrangement** — an agent's effective policy is what it may do, which tools and data it can reach, and how memory and updates land. The arrangement diagram is the governance artifact.
- **Federal** — RMF / cATO and continuous monitoring; emergency-patch criteria redesigned for machine-speed exploitation.

## The CI / tradecraft lens (the differentiator)
- **Two ends of one attribution chain** — managed attribution / signature reduction / UTS (controlling your own signature) ↔ UEBA / pattern-of-life / network profiling (attributing others).
- **Non-repudiation** is the counterintelligence-relevant identity problem in agentic systems — *who or what acted, and can you prove it.*
- Operate as if under **ubiquitous technical surveillance** — assume correlation, reduce signature, protect the digital force.

## Strategy & cadence
- **Maturity** — anchor to the SEI AI Adoption Maturity Model (Accenture + CMU); know where you are before you build.
- **Roadmap** — 87 actions across **Now (40) / Next (37) / Later (10)**. Sequence deliberately; don't boil the ocean.
- **Metrics** — pair speed with quality, coverage, and cost. Speed alone hides risk.

## The frontier reality (why continuous wins)
- **N-day → N-hour** — working exploits can land within hours of a public patch; the patch race is now machine-speed.
- **Validation is the bottleneck** — frontier AI exposes SOC weaknesses rather than replacing the SOC.
- **No single model catches everything** — run a collection of models across multiple passes, under human supervision.

---
*This card is the map, not the territory. The playbook carries the depth, the sources, and the rationale behind every line above.*

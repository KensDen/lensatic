# Agentic SecOps: Red / Blue / Purple Team Study Guide

© 2026 Ken Connell. All rights reserved.

Companion to the [Agentic SecOps playbook](https://kensden.github.io/lensatic/playbook/Playbook/).

*A self-study guide to red, blue, and purple teaming of Agentic AI systems.*

This guide assumes you already understand SOC fundamentals (alerts, telemetry, the kill chain, MITRE ATT&CK, EDR/SIEM) but are newer to AI/ML security specifically. It builds from "what is an AI agent" up to running red, blue, and purple exercises against agentic systems, and it points you to the current frameworks, tools, and certifications. Where it helps, it connects concepts to the Microsoft security stack (Defender, Sentinel, Security Copilot), which many enterprises run.

This edition has been expanded to map directly against three SANS offensive/automation AI courses: **SEC536** (attacking AI systems), **SEC535** (AI as an offensive weapon), and **SEC598** (automating red/blue/purple with AI), so the topics here line up with where the formal training is heading. See Part 9 for that course map.

Everything reflects the state of the field as of mid-2026. This space moves fast: frameworks get renumbered and tools ship monthly, so treat the linked primary sources as the authority and this guide as the map.

-----

## Contents

|# |Part                     |What you get                                                                       |
|--|-------------------------|-----------------------------------------------------------------------------------|
|0 |Foundations              |What an AI agent is, and why it's uniquely hard to secure                          |
|1 |The two framing questions|The matrix that organizes the whole field                                          |
|2 |Frameworks               |OWASP (LLM, ASI, NHI), MITRE ATLAS, NIST, SAIF, CSA MAESTRO: the shared vocabulary|
|3 |The attack surface       |How AI and agentic systems fail, layer by layer                                    |
|4 |Red team                 |Attacking AI systems, and using AI as a weapon                                     |
|5 |Blue team                |Defending AI, and defending with AI (the agentic SOC)                              |
|6 |Purple team              |Closing the red/blue loop with automation                                          |
|7 |Hands-on practice        |Safe labs that build real skill                                                    |
|8 |Certifications & sources |SANS SEC536 / SEC535 / SEC598, HTB, primary docs                                   |
|9 |SANS course map          |How the SANS courses map onto this guide                                           |
|  |Glossary + self-check    |Quick reference, plus active-recall questions grouped by Part                      |

-----

## How to use this guide

A realistic pace is three to four weeks of part-time study. You don't need to read it linearly, but the foundations (Parts 0 - 3) make the team-specific parts (4 - 6) much easier to absorb.

|Week|Focus                                                                                 |Sections            |
|----|--------------------------------------------------------------------------------------|--------------------|
|1   |Foundations: what agents are, the framing, the core frameworks                       |Parts 0, 1, 2       |
|2   |The attack surface: how agentic and AI systems actually fail                         |Part 3              |
|3   |Offense and defense: red and blue methodologies, tooling, automation                 |Parts 4, 5          |
|4   |Integration and practice: purple teaming, hands-on labs, certs, course map           |Parts 6, 7, 8, 9    |

Keep the glossary handy as you read. The self-check at the end is grouped by Part, so when you finish a section you can jump straight to its questions and test yourself. If you can answer them in plain language without looking, that Part has landed.

-----

## About this edition

**October 1, 2026 addendum (public edition).** This guide tracks the Agentic SecOps playbook, a living reference that changes in dated passes. This public edition is an independent personal project: it keeps the guide's substance and sources and leaves out the working change log behind them. The guide and the app stay in lockstep, and the app's counts are: 87 actions (40 Now / 37 Next / 10 Later), 243 sources / 13 groups, 89 glossary terms, 34 tools.

-----

## Part 0: Foundations, what "Agentic AI" actually is

The single most important distinction to internalize is the difference between a **language model** and an **agent**.

A plain large language model (LLM) takes text in and produces text out. It has no hands. The worst it can do on its own is say something wrong or harmful.

An **Agentic AI system** wraps an LLM in machinery that lets it *act*. A useful mental model is four components working in a loop:

- **Reasoning core**: the LLM that interprets goals, plans steps, and decides what to do next.
- **Tools**: functions the agent can call to affect the world: search the web, run code, query a database, send an email, hit an internal API, move money. In modern systems these tools are increasingly exposed through the **Model Context Protocol (MCP)**, a standard that lets agents discover and call external tools/servers, which is powerful, and a major new attack surface (Part 3).
- **Memory**: state the agent carries across steps or sessions, often backed by a vector database (the store behind retrieval-augmented generation, or RAG).
- **Orchestration / planning**: the logic that chains steps together and, in multi-agent systems, lets agents delegate to and call one another.

The **agent loop** runs roughly: *perceive* (read input or a tool result) → *reason/plan* (decide next step) → *act* (call a tool) → *observe* (read the result) → repeat until the goal is met.

Why this matters for security, in one sentence: **an agent can take real actions with real side effects, autonomously, in a loop, so an attack that would have produced only a bad sentence in a chatbot can instead exfiltrate data, execute code, or trigger a chain of downstream actions.** Three properties make agentic systems uniquely hard to defend:

1. **Probabilistic behavior.** The same input can produce different outputs on different runs. There's no deterministic "if-then" you can fully test or rely on. A system prompt is not a firewall.
1. **A blurred instruction/data boundary.** LLMs read instructions and the content they're processing through the same channel. The model often can't tell "this is data to summarize" from "this is a command to obey", which is the root cause of prompt injection.
1. **Compounding autonomy.** Because the agent acts in a loop and can chain tools (and other agents), a single compromise can amplify into cascading effects far beyond the entry point.

-----

## Part 1: The two questions that frame everything

Almost everything in Agentic AI security falls into one of two questions, and most real work touches both. Keep this framing in your head constantly, because people routinely talk past each other by conflating them.

**Question A: How do we secure the AI agents themselves?** Here the agent is the *target*. You're protecting an autonomous system that customers, employees, or other systems interact with.

**Question B: How do we use AI agents to do security work?** Here the agent is the *tool*. You're using autonomous AI to run offense or defense faster and at greater scale than humans can.

The red/blue/purple lens applies to both questions. This matrix is the backbone of the whole guide:

|                                     |Red (offense)                                                                                      |Blue (defense)                                                                            |Purple (integration)                                                  |
|-------------------------------------|---------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|----------------------------------------------------------------------|
|**A: Securing AI agents**           |Attack the agent: prompt injection, tool/MCP misuse, memory poisoning, jailbreaks, model extraction|Defend the agent: guardrails, least-privilege tools, sandboxing, monitoring agent behavior|Feed red's findings into the agent's defenses and re-test continuously|
|**B: AI agents doing security work**|Use AI agents for recon, exploit generation, deepfakes, autonomous attack simulation               |Use AI agents in the SOC: autonomous triage, investigation, response (the "agentic SOC")  |Use AI to run the red→blue→red loop end-to-end at machine speed       |

Two points leaders will care about. First, these questions are converging: defensive AI agents (Question B) are themselves agentic systems that need securing (Question A). The agent that triages your alerts can itself be prompt-injected through a malicious log entry. Second, the SANS course portfolio maps cleanly onto this matrix: **SEC536** lives in cell A-Red, **SEC535** in cell B-Red, and **SEC598** spans both questions across all three teams with an automation emphasis (Part 9).

-----

## Part 2: Frameworks you need to know cold

Seven bodies of work define the vocabulary of this field. You will hear these referenced constantly; know what each one is *for*.

|Framework                                     |Maintainer                         |What it is                                                        |Best used for                                                         |
|----------------------------------------------|-----------------------------------|------------------------------------------------------------------|----------------------------------------------------------------------|
|OWASP Top 10 for LLM Applications (2026)      |OWASP GenAI Security Project       |The 10 most critical risks for LLM-based apps                     |Common language for app-level LLM risk                                |
|OWASP Agentic Security Initiative (ASI)       |OWASP GenAI Security Project       |Threat taxonomy + Top 10 specific to *autonomous agents*          |Reasoning about multi-step, tool-using, multi-agent risk              |
|OWASP Non-Human Identities (NHI) Top 10 (2025)|OWASP                              |The top risks for machine/agent identities                        |Securing per-agent identity, secrets, and privileges                  |
|MITRE ATLAS                                   |MITRE                              |Adversary tactics & techniques vs AI systems (the "ATT&CK for AI")|Threat modeling, red teaming, mapping detections                      |
|NIST AI RMF + AI 100-2                        |NIST                               |Governance framework + formal adversarial-ML taxonomy             |Risk management, compliance, shared terminology                       |
|Google Secure AI Framework (SAIF)             |Google                             |Conceptual framework of secure-AI best practices                  |High-level program design; basis of some training                     |
|CSA MAESTRO                                   |Cloud Security Alliance (Ken Huang)|A 7-layer threat-modeling method for Agentic AI                   |Architecturally threat-modeling a specific agent or multi-agent system|

A note before the lists: the SANS adversarial course (SEC536) makes a point of teaching attacks that fall **beyond the OWASP Top 10**: MCP-specific abuse, side channels, weight theft, vision evasion, and classic appsec bugs reappearing in AI plumbing. The frameworks are necessary scaffolding, not a complete map of the attack surface. Treat them as the shared language, and Part 3 as the fuller terrain.

### OWASP Top 10 for LLM Applications (2026)

The foundational list for *application-level* LLM risk. The 2026 edition (published August 2026) keeps the ten risks but re-ranks them: Excessive Agency rises to LLM03, System Prompt Leakage is re-scoped as Hidden Context Exposure (LLM08), and Improper Output Handling moves to LLM10. The playbook's action tags keep the 2025 numbering. The categories, in 2026 order, are:

- **LLM01: Prompt Injection.** Attacker input is interpreted as an instruction. Still the #1 risk. Includes *direct* (user types the injection) and *indirect* (injection hidden in content the model later reads: a web page, a document, an email).
- **LLM02: Sensitive Information Disclosure.** The model reveals PII, secrets, or proprietary data.
- **LLM03: Excessive Agency.** Giving an LLM/agent too much functionality, permission, or autonomy, so a manipulation becomes a damaging action. *This is the bridge concept to agentic security.*
- **LLM04: Supply Chain.** Compromised third-party models, datasets, or adapters (e.g., a poisoned model pulled from a public hub).
- **LLM05: Data and Model Poisoning.** Corrupting training/fine-tuning data to plant backdoors or "sleeper" behavior.
- **LLM06: Unbounded Consumption.** Uncontrolled resource use leading to denial-of-service or "denial-of-wallet" (runaway compute cost).
- **LLM07: Misinformation.** The model produces confident, wrong, or fabricated output that users over-trust.
- **LLM08: Hidden Context Exposure.** Formerly System Prompt Leakage, now re-scoped more broadly. Treating the hidden system prompt as a security control; if a secret is in the prompt, assume it's already exposed.
- **LLM09: Vector and Embedding Weaknesses.** Attacks on the RAG layer: poisoning vector stores, weak access controls across tenants, manipulating retrieval.
- **LLM10: Improper Output Handling.** Trusting model output and passing it unsanitized into downstream systems (leading to XSS, SQL injection, command execution).

### OWASP Agentic Security Initiative (ASI): the Agentic Top 10

This is the framework most directly tied to agentic work. The ASI extends OWASP's LLM work specifically to *autonomous agents*, where the threat model is no longer a single inference but a system that plans, remembers, chooses tools, and coordinates with other agents. (For *architectural* threat modeling of a specific agentic system, the widely used complementary method is **CSA's MAESTRO**, described below: it is not part of OWASP, but the two are frequently paired.)

The ten ranked agentic risks (ASI01 - ASI10) cover, in broad strokes:

1. **Agent Goal Hijacking**: manipulating the agent's objective via prompt injection or indirect manipulation.
1. **Tool Misuse**: unsafe delegation and parameter injection that turn legitimate tools into weapons.
1. **Identity and Privilege Abuse**: exploiting how permissions flow through delegation chains.
1. **Agentic Supply Chain Vulnerabilities**: risk from dynamically composed tools and plugins at execution time (the MCP problem lives largely here).
1. **Unexpected Code Execution**: sandboxing failures that let the agent run attacker code (RCE).
1. **Memory and Context Poisoning**: corrupting persistent or shared memory/knowledge stores.
1. **Insecure Inter-Agent Communication**: attacks on how agents talk to each other.
1. **Cascading Failures / Blast Radius**: one compromised agent amplifying impact across systems.
1. **Human-Agent Trust Exploitation**: decision-fatigue and over-trust attacks against the human in the loop.
1. **Rogue Agents**: a misaligned or hijacked agent acting like an insider threat.

> Note: the list above paraphrases the OWASP Top 10 for Agentic Applications for 2026, released December 9, 2025; earlier drafts used different titles and "AAI0xx" labels. Confirm the exact titles on the OWASP GenAI Security Project site before citing it formally.

### OWASP Non-Human Identities (NHI) Top 10 (2025)

Agents authenticate as software, not people: they hold their own secrets, tokens, and keys, so the OWASP NHI Top 10 is the dedicated framework for the identity layer that the LLM and ASI lists only touch lightly. It matters here because per-agent identity is central to securing agentic systems. The 2025 risks are: **NHI1** Improper Offboarding, **NHI2** Secret Leakage, **NHI3** Vulnerable Third-Party NHI, **NHI4** Insecure Authentication, **NHI5** Overprivileged NHI, **NHI6** Insecure Cloud Deployment Configurations, **NHI7** Long-Lived Secrets, **NHI8** Environment Isolation, **NHI9** NHI Reuse, and **NHI10** Human Use of NHI. In practice this is the checklist behind "give every agent its own least-privileged, short-lived, properly offboarded identity", and several real breaches (Microsoft's Midnight Blizzard via a legacy OAuth app, Okta's compromised service account) were fundamentally NHI failures.

### MITRE ATLAS

ATLAS (Adversarial Threat Landscape for Artificial-Intelligence Systems) is the AI counterpart to MITRE ATT&CK: a living knowledge base of real-world adversary tactics and techniques against AI systems, complete with mitigations and documented case studies. As of September 2026 (ATLAS v2026.09) it spans 16 tactics, 120 techniques and 88 sub-techniques, and it has been expanding aggressively to cover generative-AI and agent-specific techniques (RAG poisoning, indirect prompt injection, memory manipulation, agent tool abuse). Because it mirrors ATT&CK's structure, it slots naturally into work you already know: threat modeling, red-team planning, and mapping techniques to detections.

Notable case studies worth knowing by name:

- **Morris II**: a self-replicating prompt "worm" that propagates through RAG-enabled email systems without user interaction.
- **ShadowRay**: an in-the-wild campaign targeting exposed AI compute infrastructure.
- **PoisonGPT**: demonstration of distributing a backdoored open-source model.

### NIST AI RMF and AI 100-2

Two complementary NIST documents:

- **AI RMF 1.0 (NIST AI 100-1)**: a voluntary governance framework organized around four functions: **Govern, Map, Measure, Manage.** This is the program/risk-management layer. NIST states that AI RMF 1.0 (January 2023) is being revised under the White House AI Action Plan.
- **NIST AI 100-2 (E2025 edition)**: a formal *Adversarial Machine Learning* taxonomy and terminology. It classifies attacks by lifecycle stage and by attacker goal/capability/knowledge, and it covers generative-AI attacks (prompt injection, RAG poisoning) alongside the classic predictive-AI attacks (**evasion, poisoning, privacy**); the 2025 edition adds a section on the security of agents and a misuse-enablement objective. This is the document that grounds the vision/evasion attacks in Part 3, and it's the U.S. federal reference vocabulary, relevant if your work touches government contexts.

### Google SAIF

The Secure AI Framework is Google's high-level set of secure-AI principles. You'll mostly encounter it as the conceptual basis for certain training paths (notably some Hack The Box content), rather than as an operational checklist.

### CSA MAESTRO (threat modeling)

MAESTRO (Multi-Agent Environment, Security, Threat, Risk, and Outcome) is a threat-modeling framework from the **Cloud Security Alliance**, created by Ken Huang. It is *not* an OWASP project, but it pairs naturally with the OWASP ASI: where ASI gives you a ranked risk list, MAESTRO gives you a **7-layer architecture** (from foundation models up through ecosystem integration) to walk an individual agent or multi-agent system layer by layer and find where threats live. It extends classic methods (STRIDE, PASTA, LINDDUN) with AI-specific concerns. Reach for it when you need to threat-model a specific deployment rather than reason about risks in the abstract.

-----

## Part 3: The attack surface

The cleanest way to learn the threats is by *where the adversary injects influence*: that is, by component. For each layer below: what it is, a concrete attack, and roughly where it maps in the frameworks. This part has been expanded to cover the full enterprise AI attack surface (LLMs, RAG pipelines, ML/vision models, agents, MCP, and the surrounding infrastructure), which is exactly the scope SANS SEC536 attacks.

**Input / prompt layer.** The agent reads instructions and data through one channel.

- *Direct prompt injection*: the user crafts input that overrides the agent's instructions ("ignore previous instructions and…").
- *Indirect prompt injection*. The payload is hidden in content the agent will later ingest: a web page it browses, a PDF it summarizes, a calendar invite, a support ticket. The agent reads it as a command. This is the dominant agentic threat because the attacker never needs to talk to the agent directly. Chained across multiple agents, indirect injection can reach deep targets: SEC536 teaches chaining indirect injections, and shows how one injection in an agentic system inherits all of the agent's capabilities.
- *Jailbreaks*: bypassing safety alignment to elicit prohibited behavior, including persuasion-style and multi-turn techniques.
- Maps to: OWASP LLM01, ASI01, ATLAS prompt-injection techniques.

**Tool / action layer.** The agent's hands, including the API plumbing behind every tool call.

- *Tool misuse*: manipulating the agent into invoking a legitimate tool for a malicious end.
- *Parameter / context injection*: controlling the arguments passed to a tool, or the context returned from one (e.g., bending a "send email" call to an attacker address, or turning a "query DB" call into data theft).
- *Excessive agency*: the agent simply has more power or autonomy than the task requires, widening the blast radius of any manipulation.
- *Sandbox escape / unexpected code execution*: when an agent that can run code breaks out of its container.
- *LLM/AI API attacks*. The AI service layer is still a web API, and classic appsec bugs reappear there: **role confusion** (blurring system/user/assistant role boundaries to smuggle privileged instructions), **path traversal**, **missing authentication / broken object-level authorization**, **mass assignment** (overposting parameters to set fields you shouldn't, like model config or privileges), and **hidden/undocumented endpoints or features** (debug routes, unlisted tools). SEC536's point: AI systems fail in novel ways *and* in old familiar ones that teams forget to test.
- Maps to: OWASP LLM03/LLM10, ASI02/ASI04/ASI05, plus the OWASP API Security Top 10 applied to AI endpoints.

**MCP (Model Context Protocol) layer.** *New and important.* MCP is the emerging standard for connecting agents to external tools and data servers. It dramatically expands what agents can do, and introduces a distinct class of attacks that SEC536 covers explicitly:

- *Tool shadowing (incl. homoglyph shadowing)*: a malicious tool whose name visually mimics a trusted one (using lookalike Unicode characters), or whose description overrides a legitimate tool's behavior, so the agent invokes the attacker's tool.
- *Name collision*: two tools/servers sharing a name; the attacker exploits the ambiguity to get theirs selected.
- *Dynamic tool-discovery abuse*: agents that discover tools at runtime can be fed malicious tool definitions.
- *Injection through MCP servers*: backends that build SQL or shell commands from tool parameters without sanitization (classic SQL injection reached *through* the agent).
- *Context injection / poisoned tool results*: the data a tool returns is fed back into the agent's context, making it another indirect-injection vector.
- *Rug pulls and confused-deputy issues*: a tool that changes behavior after approval, or one that abuses the agent's authority to reach resources the user can't.
- Maps to: ASI02/ASI04/ASI07; treat MCP servers as untrusted, third-party, runtime-composed supply chain.

**Memory / knowledge layer.** What the agent remembers and retrieves.

- *Memory poisoning*: planting malicious content in the agent's persistent memory so it influences future decisions.
- *RAG / knowledge-base poisoning*: injecting adversarial entries into the vector store so they're retrieved during legitimate queries (false-entry injection, retrieval-content crafting).
- *RAG retrieval-boundary and exfiltration attacks*: abusing weak retrieval scoping to pull documents across tenant/permission boundaries, then using an outbound channel (a tool call, a crafted link, an email) to exfiltrate them. SEC536 treats this as a primary data-theft path.
- Maps to: OWASP LLM09, ASI06, NIST/ATLAS RAG-poisoning techniques.

**Multi-agent layer.** Systems of agents that delegate and coordinate.

- *Inter-agent exploitation*: abusing the trust one agent places in another's output.
- *Orchestration abuse*: manipulating the planning/delegation logic.
- *Cascading failure / blast radius amplification*: a compromise in one agent propagating across the network (the Morris II worm is the canonical demonstration).
- Maps to: ASI07/ASI08, ATLAS multi-agent techniques.

**Identity / privilege layer.** How the agent authenticates and what it's allowed to do.

- *Privilege abuse in delegation chains*: permissions escalating or leaking as tasks pass between agents/tools.
- *Non-human identity (NHI) sprawl*: agents hold their own credentials and tokens; these are high-value, often poorly governed, and frequently over-permissioned.
- *Impersonation*: an agent or attacker posing as a trusted entity.
- *NHI lifecycle failures*, the OWASP NHI Top 10 catalog: improper offboarding, secret leakage, long-lived secrets, overprivileged and reused identities, and humans borrowing an agent's credentials.
- Maps to: ASI03, the OWASP NHI Top 10, ATLAS impersonation techniques.

**Model / supply chain layer.** The components you didn't build, and the model itself as stealable IP.

- *Data and model poisoning*: corrupting training/fine-tuning data.
- *Backdoors / "sleeper agents"*: models that behave normally until a hidden trigger fires; nearly invisible to standard evaluation.
- *Poisoned third-party artifacts*: malicious models, datasets, or fine-tuning adapters from public repositories.
- *Model extraction and weight theft*: reconstructing a model's behavior through systematic querying (extraction), or exfiltrating the actual weights (theft). Weights are crown-jewel intellectual property; SEC536 treats protecting model weights, training data, and the AI supply chain as a core defensive objective, and demonstrates offensive paths to reach them. Mitigations include query rate-limiting and anomaly monitoring, output controls, and locking down weight storage and access.
- Maps to: OWASP LLM04/LLM05, NIST poisoning/privacy taxonomy, ATLAS model-theft techniques.

**Vision and multimodal layer.** *Often overlooked, and a full module in SEC536.* Not all enterprise AI is text. Facial recognition, identity/liveness checks, document/image classifiers, and vision-language models are everywhere, and they fail to a distinct attack family rooted in classic adversarial ML:

- *Adversarial examples / evasion attacks*: inputs with carefully crafted, often imperceptible perturbations that cause a model to misclassify (the classic "stop sign read as a speed-limit sign"). This is the heart of the NIST AML evasion taxonomy.
- *Adversarial patches*: physical or digital patches that reliably fool a detector or classifier (e.g., a printed pattern that defeats a person detector or facial-recognition gate).
- *Defeating facial recognition / identity verification*: using perturbations, patches, or presentation attacks to evade or spoof face-based identity and liveness checks (directly relevant to KYC and fraud).
- *Multimodal prompt injection*: instructions hidden inside an image (or audio) that a vision-/speech-language model reads and obeys, smuggling prompt injection past text filters.
- Maps to: NIST AI 100-2 evasion attacks, ATLAS evasion/adversarial-example techniques.

**Infrastructure / implementation layer.** *Where AI meets the real world*: the surrounding architecture, not the model.

- *Architecture and configuration flaws*: exposed buckets and model stores, misconfigured services, weak network segmentation around AI workloads (ShadowRay is the infrastructure cautionary tale).
- *Side-channel attacks*: leaking information about inputs, prompts, or models through timing, response-length/streaming, caching, or (for edge AI) power and electromagnetic signals.
- *Alignment failures as an attack surface*, exploiting the gap between a model's intended and actual behavior: refusal bypasses, instruction-hierarchy weaknesses, and "alignment faking." SEC536 includes a dedicated alignment-issues module.
- Maps to: OWASP LLM04, ATLAS infrastructure techniques, NIST AML.

**Human-agent trust layer.** The person supervising the agent.

- *Decision-fatigue / over-trust attacks*: exploiting that humans rubber-stamp agent recommendations, especially at volume.
- Maps to: ASI09.

**Rogue agents.** The agentic equivalent of an insider threat: a misaligned or hijacked agent whose individual actions look legitimate in isolation. The most reliable way to catch one is behavioral: monitor what it accesses, where it sends data, which tools it invokes, and how that differs from a stable baseline over time. Maps to: ASI10.

-----

## Part 4: Red team, attacking AI

### What makes AI red teaming genuinely different

Traditional red teaming hunts for vulnerabilities in code and configuration along a kill chain. AI red teaming is different in three ways you should be able to articulate:

1. **You probe behavior, not just code.** The question is "what harmful or unintended *output/action* can I provoke from ostensibly innocuous input?"
1. **You test two surfaces at once:** security vulnerabilities (prompt injection, data exfiltration, tool/MCP abuse) *and* responsible-AI harms (bias, toxicity, manipulation, unsafe content). Traditional pen testers usually own only the first.
1. **Targets are probabilistic.** The same attack may succeed one run and fail the next, so you think in terms of *success rates across many trials*, not a single pass/fail. This is why automation and scoring matter so much.

### Two distinct offensive scopes

It helps to separate two things people both call "offensive AI," because they map to different cells of the Part 1 matrix and to different SANS courses:

- **Attacking AI systems (A-Red).** The target is the AI deployment. You attempt prompt injection, RAG exfiltration, MCP compromise, API abuse, vision evasion, and weight theft. This is the SEC536 domain.
- **Using AI as an offensive weapon (B-Red).** AI is your tooling. Adversaries use it for AI-accelerated reconnaissance and OSINT, RAG-powered pentest assistants, AI-enhanced exploitation, deepfake phishing and voice-cloned vishing, AI-assisted patch diffing and vulnerability discovery, and AI-assisted malware engineering and evasion. This is the SEC535 domain, and it's why "the attacker now has an LLM" is the premise behind machine-speed purple teaming (Part 6).

### A workable methodology

A red-team engagement against an AI system roughly follows:

1. **Rules of engagement and isolation**: authorization, scope, and a contained test environment.
1. **Reconnaissance against the AI system**: fingerprint the model/provider and version, map exposed endpoints and tools, infer the system prompt and guardrails, enumerate connected MCP servers and data sources, and identify the surrounding infrastructure. AI recon is its own skill (SEC536 dedicates a lab to it) and shapes everything downstream.
1. **Objectives mapped to framework risks**: e.g., "achieve indirect prompt injection that triggers an unauthorized tool call" (ASI01+ASI02), or "exfiltrate a cross-tenant document via the RAG boundary" (LLM09).
1. **Attack execution**: run attack strategies, often thousands of variants, automated.
1. **Scoring**: measure success rates; verify whether the agent stayed within approved tool use, actions, and behavioral boundaries.
1. **Reporting**: reproducible evidence, severity, and a mapping of each finding to architectural and detection controls (so blue can act).

### Tooling to know

|Tool                              |Type                           |What it does                                                                                                                                                                                                                                                  |
|----------------------------------|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**PyRIT**                         |Open source (Microsoft)        |The Python Risk Identification Toolkit for generative AI. Defines targets, builds prompt datasets, runs single- and multi-turn attacks, and scores results. Battle-tested by the Microsoft AI Red Team, which has red-teamed 100+ GenAI products including Copilot. The de facto starting point.|
|**AI Red Teaming Agent**          |Microsoft Foundry (formerly Azure AI Foundry)               |Productized, partly no-code automation built on PyRIT for scanning models and agents inside Foundry; integrates into CI/CD.                                                                                                                                   |
|**RAMPART**                       |Open source (Microsoft)        |Risk Assessment and Measurement Platform for Agentic Red Teaming: a `pytest` framework on PyRIT that embeds adversarial tests (prompt injection, tool-boundary checks) into the development pipeline.                                                        |
|**Clarity**                       |Open source (Microsoft)        |Design-review tool released alongside RAMPART: it checks engineering assumptions and runs failure analysis before implementation.                                                                                                                                                                                         |
|**garak**                         |Open source                    |LLM vulnerability scanner with a wide library of probes.                                                                                                                                                                                                      |
|**DeepTeam**                      |Open source                    |LLM red-teaming framework with built-in OWASP Top 10 assessments.                                                                                                                                                                                             |
|**Counterfit**                    |Open source (Microsoft, legacy)|Earlier automation framework aimed at *classical* ML; largely superseded by PyRIT for generative AI.                                                                                                                                                          |
|**SPLX.AI Agentic Radar / Pensar**|Open source (Agentic Radar) / commercial (Pensar)                     |Tools that operationalize the OWASP agentic taxonomy into developer and red-team workflows.                                                                                                                                                                   |

A note on **dual use**: AI red-team tooling lowers the barrier for attackers too. The same agents that simulate attacks can be repurposed for real reconnaissance, phishing generation, and evasive code. Strict authorization, isolation, and scoping aren't bureaucracy: they're what keeps your testing lawful and safe.

-----

## Part 5: Blue team, defending AI

The blue team has two distinct jobs that mirror the framing from Part 1: defending the agents, and defending *with* agents.

### A) Defending the AI system (Question A)

The hard lesson the field has internalized: **the LLM is not a trust boundary.** You cannot make an agent secure by asking it nicely in the system prompt. Security controls must live *outside* the model, in deterministic, auditable layers. Core controls, roughly by layer:

- **Input/output handling.** Treat all model output as untrusted; sanitize and validate before it flows into any downstream system. Constrain and classify inputs where possible.
- **Least privilege for tools, MCP, and identity.** Give the agent only the tools and permissions the task needs. Treat MCP servers as untrusted third parties: pin and verify tool definitions, watch for name collisions/homoglyphs, and don't auto-approve dynamically discovered tools. Scope credentials tightly and govern non-human identities like the high-value targets they are.
- **API hardening.** The AI service is a web API: enforce authentication and object-level authorization, lock down role boundaries, validate parameters (block mass assignment), and remove hidden/debug endpoints.
- **Sandboxing and isolation.** Run code-executing agents in contained environments to limit the damage of an escape.
- **Human-in-the-loop gates.** Require explicit human approval for high-impact, irreversible actions (sending money, deleting data, changing permissions, publishing). Beware decision fatigue: too many approvals trains humans to rubber-stamp.
- **Memory and retrieval integrity.** Validate and provenance-track what goes into memory and vector stores; enforce access controls and tight retrieval scoping across tenants.
- **Model and weight protection.** Rate-limit and monitor queries for extraction patterns; lock down weight storage and access.
- **Blast-radius limits.** Isolation, strict inter-agent trust policies, and message authentication so one compromised agent can't cascade.
- **Observability.** Log every tool call, parameter, MCP interaction, and inter-agent message. You can't detect what you don't record.

### B) Defending with agents: the "agentic SOC" (Question B)

The industry is moving from "AI that summarizes an alert" toward autonomous agents that run multi-step SOC work while humans supervise. In the Microsoft stack specifically (much of this is recent/preview: verify current availability):

- **Security Copilot agents**: purpose-built agents for areas like phishing triage, data security, and identity. The control plane for AI agents has been consolidated under **Agent 365** (generally available for commercial customers since May 1, 2026), which treats AI agents with the same governance rigor as human identities and includes **shadow-AI detection** (finding unsanctioned agents in your environment).
- **In Microsoft Defender**: the **Security Alert Triage Agent** (preview) autonomously classifies and resolves low-value alerts, and the newer **Security Analyst Agent** performs deep, multi-step investigations across Defender and Sentinel telemetry, returning prioritized findings with reasoning and evidence.
- **In Microsoft Sentinel**: the Sentinel data lake provides long-term retention that Microsoft describes as cost-effective, and Security Copilot agents continuously analyze that telemetry (e.g., surfacing anomalous admin-identity behavior) to catch issues earlier in the kill chain.

For a SOC analyst, the practical impact is that pre-assembled evidence and auto-triaged noise change what lands in your queue, and your judgment shifts toward validating agent findings and handling what the agents escalate.

### Detection engineering as code

A theme SEC598 drives hard: modern detection engineering should be **detection-as-code**, detections written, version-controlled, peer-reviewed, and tested through CI/CD pipelines like software, rather than hand-edited in a console. Related practices to know:

- **Detection-as-code pipelines**: detections in source control, validated automatically against emulated techniques before deployment.
- **LLM-assisted detection**: using LLMs to *generate* candidate detections, *enrich* alerts with context, and *test* detections (e.g., generating variant attack telemetry to check coverage), with a human reviewing.
- **SOAR playbooks**: orchestrated, automated response workflows (in tools like Tines) that execute or recommend containment and enrichment steps.
- **AI-augmented response**: RAG-based investigation agents that assemble context and propose next steps to cut detection-and-response time.
- **Countering adversarial automation**: assume attackers are automated too; defensive automation has to keep pace, which is the bridge to purple teaming.

### Detection engineering for agents

Because rogue/hijacked agents look legitimate action-by-action, detection is **behavioral and baseline-driven**. Useful signals: tool-call sequences that deviate from a learned baseline, unusual data egress, access to resources outside the agent's normal scope, inter-agent or MCP messages that don't fit expected patterns, and spikes in consumption (the denial-of-wallet signal). The mindset is the same anomaly-detection instinct you already use for user and entity behavior, applied to non-human, autonomous identities.

### Resilience and dependency: defending availability

Defending the AI system has a dimension that isn't about attackers at all: can you still operate if the model goes away? A frontier capability your program depends on can be withdrawn with little warning: a vendor deprecating or restricting a model, a government export-control or sanctions directive, or a regulatory suspension, and no technical control prevents the action itself. The exposure *is* the dependency, and it concentrates wherever a mission-critical function leans on a single model or provider. There's a genuine tension: the most capable model is often the one most exposed to being pulled. So treat model access as a single point of failure in critical infrastructure. Design for portability so a model can be swapped without re-architecting; keep a tested fallback (ideally a different provider, or an on-prem/open-weight option); add "a model becomes unavailable" as an explicit continuity/DR scenario with a defined switchover target; and keep prompts, tools, and guardrails behind a model-abstraction layer rather than hard-wired to one vendor's API. On the procurement side this is a vendor-assessment criterion: weigh concentration risk and switching cost up front, and require a documented continuity plan for loss of access, not just an uptime SLA. The playbook carries this as a consideration on the Risks & Ethics tab and a procurement criterion on the Procurement & Vendor Risk tab; it matters most for federal and national-security-adjacent work, where directives can apply abruptly.

-----

## Part 6: Purple team, closing the loop

### The core idea

Red finds weaknesses but disengages after the exercise; blue is strong on detection but may never see the gap a red team would have found. Purple teaming makes them one feedback loop: **red's findings automatically become blue's tests; blue's gaps become red's next exercise.** Historically this stayed aspirational, a quarterly calendar event glued together by humans typing into ticketing systems. What changed is that attackers now move at machine speed (CrowdStrike's 2026 Global Threat Report puts the fastest observed eCrime breakout at 27 seconds), so a loop that closes only quarterly is too slow. Autonomous agents let the loop run continuously.

### Automation engineering for purple (the SEC598 heart)

SEC598's whole thesis is that continuous purple teaming is an *automation-engineering* discipline. The practices and tools worth knowing:

- **Adversary-emulation-as-code**: encode adversary techniques (mapped to MITRE ATT&CK) as version-controlled, repeatable tests. Tools: **Atomic Red Team** (atomic technique tests), **Caldera** (automated breach-and-attack emulation), and orchestration of emulation through SOAR (e.g., "adversary emulation as code using Tines").
- **AI-powered red-team agents**: autonomous adversaries that plan and execute multi-step attack flows; SEC598 builds these with frameworks like **CrewAI** and validates cloud detections against them (including AI agents targeting Kubernetes).
- **Continuous validation in CI/CD**: emulation runs on a pipeline, not a calendar; every change is re-tested.
- **Detection-as-code feedback**: each red finding becomes a new or improved detection in source control, and emulation re-runs to prove it fires (SEC598's "Detection as Code" labs, including LLM-assisted detection testing).
- **The supporting stack**: infrastructure-as-code (**Terraform**, **Ansible**) to stand up consistent environments, **Python/Jupyter** for enrichment and analysis, SOAR (**Tines**) for orchestration, and DFIR tooling (**Velociraptor**, **Timesketch**) for automated triage. Jason Ostrom's open-source **PurpleCloud** and **Automated Emulation** projects are purpose-built for scalable cloud adversary emulation.

A useful distinction: the emulation/automation side leans on **MITRE ATT&CK** (the system/network TTPs you're validating detections against), while the AI-attack side leans on **MITRE ATLAS** and the OWASP/NIST AI taxonomies. A mature Agentic-AI purple program uses both: ATLAS-mapped attacks against the AI system, ATT&CK-mapped emulation for the surrounding environment.

### The autonomy dial: crawl, walk, run

This dial is separate from the playbook's four-level Maturity Model, which runs from Level 1 (AI-Assisted) to Level 4 (Autonomous SecOps). Autonomy is a dial, not a switch:

- **Crawl**: manual exercises; humans run each handoff.
- **Walk**: scheduled, AI-assisted; agents help but humans gate.
- **Run**: end-to-end automated loop, with human review only where it matters, and every step auditable so you can override, retune, or roll back.


### Metrics that matter

A purple program should move measurable numbers: mean time to detect and respond (MTTD/MTTR), detection coverage against the relevant ATLAS/ATT&CK techniques, and the percentage of red-team findings converted into durable detections. "We ran an exercise" is not a metric; "we closed N detection gaps and cut MTTD by X" is.

### A worked example on an agentic system

Red achieves an indirect prompt injection (via a poisoned document the target agent summarizes) that coerces an unauthorized tool call. Purple turns that into: a detection-as-code rule for the anomalous tool-call pattern (committed, reviewed, and tested in the pipeline), a guardrail that blocks the specific tool/parameter abuse, and a regression test (e.g., in RAMPART) that runs on every build. An emulation job re-runs the technique to confirm the detection fires; red then re-attacks with a variant; the loop continues.

-----

## Part 7: Hands-on practice (do this safely)

Reading gets you fluent; building gets you dangerous (in the good way). Everything below should run in an **isolated, authorized lab**, never against production or third-party systems you don't own.

- **Install PyRIT** and run a basic red-team pass against a model endpoint you control. Build a small dataset of injection prompts and use the scoring engine to measure success rates.
- **Stand up a deliberately vulnerable agent**, a simple LLM with one or two tools (a web fetcher and a "send message" function), and try to achieve indirect prompt injection through content it ingests. This makes the instruction/data boundary problem visceral.
- **Attack an MCP setup.** Run a local MCP server with a couple of tools and try tool shadowing (a homoglyph name), a name collision, and a parameter-injection path. This teaches the newest and least-understood agentic surface.
- **Try a vision evasion attack.** Use an open adversarial-examples library against an image classifier you control, and build a simple adversarial patch. Seeing a confident misclassification from a tiny perturbation is the best way to understand the vision/multimodal layer.
- **Run a model-extraction experiment.** Query a small model you own systematically and observe how behavior can be approximated, then add rate-limiting and watch the detection signal appear.
- **Build an automated firing range with infrastructure-as-code.** Use Terraform (and Ansible for hardening baselines) to stand up a disposable, isolated test environment you can rebuild on demand: the SEC598 approach to safe, repeatable labs.
- **Run continuous adversary emulation.** Use Atomic Red Team or Caldera to execute ATT&CK-mapped techniques against your range, and confirm what your logging catches.
- **Wire detection-as-code.** Put a detection in source control, then prove it fires against an emulated technique in a pipeline (and add a RAMPART/pytest check so a known prompt injection is caught on every build).
- **Map your findings to frameworks.** For each successful attack, write down the OWASP/ASI and ATLAS (or ATT&CK) IDs. This builds the shared vocabulary for reporting findings.
- **Run a mini purple loop.** Take one red finding, build a detection and a guardrail, and prove the detection fires on re-attack.

If you have access to a Microsoft tenant for learning, explore the AI Red Teaming Agent in Microsoft Foundry (formerly Azure AI Foundry) and the Security Copilot agent experiences to connect the open-source concepts to the products.

-----

### Tabletop scenarios: run these, don't just read them

Three written walkthroughs to exercise the program. Each is a 60 - 90 minute table exercise: a facilitator plays the injects, blue responds with what they would *actually* do (name the tool, the command, the person), and purple scores the gaps. Feed every gap into the loop as a detection, an authorization change, or a staffing decision.

**Scenario 1: The Vulnerability Storm** *(after the CSA Mythos-ready brief: tabletop the storm, not the incident)*

**Setup:** A normal Tuesday, one on-call analyst, agents in production for triage and enrichment.

**Injects (drop at 0, 20, and 35 minutes):** (1) A vendor email carries an indirect prompt injection; your triage agent begins summarizing ticket contents to an external webhook. (2) Public Glasswing-class scanning drops a working exploit for a library inside your detection stack: patch does not exist yet. (3) The OT historian starts receiving and answering queries from an IT-side service account that has never touched it.

**What good looks like:** Egress cut and identity revoked on the triage agent inside minutes, *before* diagnosis; agent memory and tool logs preserved before any restart; pre-staged compensating controls (egress cutoff, isolation) applied to the vulnerable detection component rather than waiting on a patch; the Purdue 3.5 boundary held and the historian session terminated while scoping proceeds; a deliberate, stated prioritization call among the three, not paralysis.

**Debrief:** Which incident would you have deprioritized, and what would it have cost? Where did the single analyst become the bottleneck? Did evidence survive responder actions? What gets pre-staged before next quarter?

**Scenario 2: The Orphaned Agent** *(NHI lifecycle and the non-human insider)*

**Setup:** Six months ago a contractor stood up an enrichment agent with a shared service credential. The contractor rolled off; the agent did not.

**Injects:** (1) UEBA flags the agent querying HR records it has never touched. (2) Its credential turns up in a public paste. (3) When asked who owns it, three teams answer "not us."

**What good looks like:** The agent is locatable in the AIBOM inventory within minutes; an owner of record exists (or the gap is named on the spot); the credential is revoked and rotated without breaking unrelated workloads, because it was never shared; tamper-evident logs answer what it accessed and when; offboarding sweeps are scheduled as a recurring control, not a one-time fix.

**Debrief:** How many agents would fail the "who owns this" question today? What breaks if you revoke a shared credential right now? Is provisioning gated on owner-of-record and expiry?

**Scenario 3: The Hallucinated Commitment** *(harm with no attacker anywhere)*

**Setup:** A customer-facing assistant, grounded on your policy corpus, has been answering benefits questions for months.

**Injects:** (1) A customer screenshot shows the assistant inventing a reimbursement policy that does not exist, phrased confidently, with a fabricated policy number. (2) Legal asks how many other users received the same answer. (3) A journalist emails for comment.

**What good looks like:** Interaction logging can actually answer "how many" and "what exactly was said" (the AeGIS telemetry-first lesson); a kill-switch or scoped rollback exists for the answer domain, not just the whole assistant; the eval suite gains this failure as a permanent regression case before return-to-duty; comms and legal work from the log record, not from memory. The Air Canada tribunal ruling (Moffatt v. Air Canada, 2024) is the reference case: the organization owns what its agent says.

**Debrief:** Could you reconstruct every affected conversation? Who decides the assistant goes back online, against what evidence? Which policy domains are too consequential for generative answers at all?

-----

## Part 8: Certifications, courses, and primary sources

### Certifications and structured training

|Course                                                                      |Focus                                                                                                                    |Format                       |Cert                                            |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|-----------------------------|------------------------------------------------|
|SANS **SEC536**: Adversarial AI: Penetration Testing AI Systems            |Attacking enterprise AI: LLMs, RAG, ML/vision models, agents, MCP (A-Red)                                                |3 days / 15 labs (new)|**GIAC AI Penetration Tester (GAIPT)** (presale; GA Feb 9, 2027)                                        |
|SANS **SEC535**: Offensive AI: Attack Tools and Techniques |AI as an offensive weapon: AI recon, deepfakes, AI-assisted malware (B-Red) |3 days / ~14 labs |**GIAC Offensive AI Analyst (GOAA)**|
|SANS **SEC565**: Red Team Operations and Adversary Emulation |Full-scope adversary emulation; 2026 refresh threads AI through planning, CTI-to-TTP extraction, evasion, and MCP-driven C2 (B-Red) |6 days / 28 labs |**GIAC Red Team Professional (GRTP)**|
|SANS **SEC545**: GenAI and LLM Application Security |Defending the GenAI stack end-to-end: RAG, agents, MLOps, MAESTRO threat modeling (Blue) |5 days / 20 labs |**GIAC AI Platform Security (GAIPS)**|
|SANS **SEC598**: AI and Security Automation for Red, Blue, and Purple Teams|Automating and operationalizing red/blue/purple with GenAI and agents |6 days / 25 labs |**GIAC AI Security Automation Engineer (GASAE)**|
|Hack The Box **AI Red Teamer** Job Role Path                                |Hands-on, ML-heavy AI red teaming (adversarial ML, prompt injection, evasion, MCP), built with Google and aligned to SAIF|Self-paced path              |HTB Certified Offensive AI Expert (**COAE**)    |
|Vendor learning paths                                                       |Microsoft Learn (AI red teaming, Security Copilot, Defender/Sentinel)                                                    |Self-paced                   |                                                |

Notes: SEC598's GIAC certification is **GASAE** (AI Security Automation Engineer). If you see SEC598 paired elsewhere with the Offensive AI Analyst (GOAA) cert, that is a mix-up: GOAA belongs to SEC535. The Hack The Box path's credential is the **COAE** (Certified Offensive AI Expert), validated by a multi-day hands-on practical exam and launched in early 2026. SEC535 now maps to the GIAC Offensive AI Analyst (GOAA) certification, part of GIAC's 2026 rollout of AI-focused certifications; SEC536 now maps to the GIAC AI Penetration Tester (GAIPT), in presale as of September 2026 with general purchase opening February 9, 2027. SEC565 maps to the GIAC Red Team Professional (GRTP). On the defensive (Blue) side, SEC545: GenAI and LLM Application Security is the counterpart to the offensive AI courses, mapping to the new GIAC AI Platform Security (GAIPS) certification (open for registration as of September 2026); together with SEC598 (purple/automation) it rounds the cert map out across all three teaming colors. SANS groups all of these under a dedicated AI security focus area (`https://www.sans.org/artificial-intelligence`), which is the best place to confirm current offerings, certs, and prerequisites.

### Primary sources to read (free)

These are the documents to actually open, not just cite:

- OWASP Top 10 for LLM Applications (2026) and the OWASP Agentic Security Initiative materials: `https://genai.owasp.org`
- MITRE ATLAS knowledge base and case studies: `https://atlas.mitre.org`
- MITRE ATT&CK (for the emulation/automation side): `https://attack.mitre.org`
- NIST AI 100-2 (E2025), Adversarial Machine Learning taxonomy: `https://csrc.nist.gov` (search "AI 100-2")
- NIST AI RMF 1.0 (AI 100-1): `https://www.nist.gov`
- Cloud Security Alliance: the MAESTRO threat-modeling framework and the CSA Agentic AI Red Teaming Guide, `https://cloudsecurityalliance.org`
- Microsoft on PyRIT, RAMPART, the AI Red Teaming Agent, and the agentic SOC: Microsoft Security Blog and Microsoft Learn

### Hands-on & community training (BHIS / Antisyphon)

Formal certifications are one track; the Black Hills Information Security (BHIS) / Antisyphon / Active Countermeasures ecosystem is the other: practical, instructor-led, and radically accessible (a select group of courses run on a Pay-What-You-Can model). Two AI-focused courses map directly to this guide:

- Antisyphon: Agentic AI for Threat Hunting, `https://www.antisyphontraining.com/product/agentic-ai-for-threat-hunting/`
- Antisyphon: Attacking, Defending & Leveraging AI-LLM Systems, `https://www.antisyphontraining.com/product/attacking-defending-and-leveraging-ai-llm-systems/`
- Antisyphon Pay-What-You-Can catalog: `https://www.antisyphontraining.com/pay-what-you-can/`

### Immersive: Enterprise Hands-On Ranges
Immersive (formerly Immersive Labs) runs offensive and defensive cyber ranges across adversary simulation, offensive malware, and exploit development, plus live CVE labs in paired attack/defend variants mapped to MITRE ATT&CK. Like the BHIS and HTB tracks, it builds hands-on offensive/defensive tradecraft, the foundation beneath the AI-specific work, for teams that already hold enterprise licenses.
- Immersive (Immersive One platform): `https://www.immersivelabs.com/`

### The full Resource Index: mirrored from the playbook

**1. Frameworks & Standards**

*Evaluation Corpora & Testbeds*

- [NIST SARD: Software Assurance Reference Dataset](https://samate.nist.gov/SARD/)
- [Juliet Test Suite (within NIST SARD)](https://samate.nist.gov/SARD/test-suites/112)
- [OWASP Benchmark: SAST/DAST Accuracy Testbed](https://owasp.org/projects/benchmark)
- [AISI: Engineering Playbook (Frontier-Eval Infrastructure)](https://engineering-playbook.aisi.org.uk/)

*Agent Standards & Formats*

- [AGENTS.md: Open Standard for Agent Instructions](https://agents.md/)
- [SOUL.md: Agent Persona and Identity Format](https://soul.md/)

*CSA*

- [CSA: AI Controls Matrix (AICM)](https://cloudsecurityalliance.org/artifacts/ai-controls-matrix)
- [CSA: MAESTRO (Agentic AI Threat Modeling)](https://cloudsecurityalliance.org/blog/2025/02/06/agentic-ai-threat-modeling-framework-maestro)

*NIST*

- [NIST: AI 100-1 (AI Risk Management Framework)](https://www.nist.gov/itl/ai-risk-management-framework)
- [NIST: AI 100-2 (Adversarial Machine Learning Taxonomy)](https://csrc.nist.gov/pubs/ai/100/2/e2025/final)
- [NIST: AI 600-1 (GenAI Profile)](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf)
- [NIST: Cybersecurity Framework 2.0 (CSF)](https://www.nist.gov/cyberframework)
- [NIST: SP 1800-35 (Implementing a Zero Trust Architecture)](https://csrc.nist.gov/pubs/sp/1800/35/final)
- [NIST: SP 800-207 (Zero Trust Architecture)](https://csrc.nist.gov/pubs/sp/800/207/final)
- [NIST: SP 800-61r3 (Incident Response Recommendations)](https://csrc.nist.gov/pubs/sp/800/61/r3/final)

*OWASP*

- [OWASP: Agentic Top 10 (2026)](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [OWASP: AI Agent Security Cheat Sheet](https://github.com/OWASP/CheatSheetSeries/blob/master/cheatsheets/AI_Agent_Security_Cheat_Sheet.md)
- [OWASP: AI Exchange (324-page PDF)](https://owaspai.org/OWASP-AI-Exchange.pdf)
- [OWASP: AI Exchange Threat Advisor](https://owaspai.org/docs/ai_security_overview/)
- [OWASP: AI Exchange Threat Model & Decision Tree](https://owaspai.org/images/threattree.png)
- [OWASP: AI Security Verification Standard (AISVS) 1.0](https://github.com/OWASP/AISVS)
- [OWASP: GenAI Security Project (hub)](https://genai.owasp.org)
- [OWASP: LLM Top 10 (2025)](https://genai.owasp.org/llm-top-10/)
- [OWASP: LLM Top 10 (2026)](https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/)
- [OWASP: LLM Top 10 Deep Dive (Oligo)](https://www.oligo.security/academy/owasp-top-10-llm-updated-2025-examples-and-mitigation-strategies)
- [OWASP: MCP Top 10 (2025, beta)](https://owasp.org/projects/mcp-top-10)
- [OWASP: Memory Is a Feature, and an Attack Surface (ASI06, May 2026)](https://genai.owasp.org/2026/05/13/memory-is-a-feature-it-is-also-an-attack-surface/)
- [OWASP: Non-Human Identities (NHI) Top 10](https://owasp.org/projects/non-human-identities-top-10)

*Other Frameworks, Matrices & Models*

- [AI Defense Matrix (Zeltser & Yu)](https://aidefensematrix.com)
- [CIS: CIS Controls v8.1 AI Companion Guides (AI/LLM, Agents, MCP)](https://www.cisecurity.org/insights/blog/applying-controls-real-world-ai-environments)
- [ENISA: Multilayer Framework for Good Cybersecurity Practices for AI (FAICP)](https://www.enisa.europa.eu/publications/multilayer-framework-for-good-cybersecurity-practices-for-ai)
- [GAIA Top 10 (Mandiant): Good AI Assessment](https://cloud.google.com/blog/topics/threat-intelligence/securing-ai-pipeline)
- [Google: SAIF (Secure AI Framework)](https://saif.google)
- [Microsoft: Threat Modeling AI/ML Systems](https://learn.microsoft.com/en-us/security/engineering/threat-modeling-aiml)
- [MITRE: ATLAS](https://atlas.mitre.org)
- [SANS: AI Security Maturity Model (2026)](https://www.sans.org/mlp/2026-ai-security-maturity-model-ebook)
- [Toreon: Meta Threat Modeling: Using AI to Threat Model Your AI System](https://www.toreon.com/using-ai-to-threat-model-your-ai-system/)

**2. Community & Collective Resources**

- [AI Incident Database (AIID)](https://incidentdatabase.ai)
- [Anthropic-Cybersecurity-Skills (community; NOT Anthropic)](https://github.com/mukul975/Anthropic-Cybersecurity-Skills)
- [Mapping AI](https://mapping-ai.org/about)
- [MIT: AI Incident Tracker (validated Jun 2026)](https://airisk.mit.edu/ai-incident-tracker)
- [MIT: AI Risk Repository](https://airisk.mit.edu)
- [Responsible AI Collaborative](https://raicollab.org)

**3. Federal & DoW Standards**

*Standards & Authorization*

- [DISA: DoD Cloud Computing SRG (Impact Levels)](https://www.cyber.mil/dccs/dccs-documents/)
- [DoD: JSIG (Joint SAP Implementation Guide)](https://www.dcsa.mil/portals/91/documents/ctp/nao/JSIG_2016April11_Final_%2853Rev4%29.pdf)
- [FedRAMP: Program & Marketplace](https://www.fedramp.gov/)
- [NIST: SP 800-171 (Protecting CUI)](https://csrc.nist.gov/pubs/sp/800/171/r3/final)
- [NIST: SP 800-37 (Risk Management Framework)](https://csrc.nist.gov/pubs/sp/800/37/r2/final)

*NIST*

- [NIST NCCoE: Software and AI Agent Identity and Authorization (Concept Paper, Feb 2026)](https://csrc.nist.gov/pubs/other/2026/02/05/accelerating-the-adoption-of-software-and-ai-agent/ipd)
- [NIST: IR 8547: Transition to Post-Quantum Cryptography Standards (draft)](https://csrc.nist.gov/pubs/ir/8547/ipd)
- [NIST: Post-Quantum Cryptography Standards (FIPS 203/204/205, Aug 2024)](https://csrc.nist.gov/pubs/fips/203/final)

*NSA*

- [NSA: CNSA 2.0 (Commercial National Security Algorithm Suite)](https://www.nsa.gov/Cybersecurity/Post-Quantum-Cybersecurity-Resources/)
- [NSA: MCP Security Design Considerations for AI-Driven Automation (May 2026)](https://www.nsa.gov/Press-Room/Press-Releases-Statements/Press-Release-View/Article/4496698/nsa-releases-security-design-considerations-for-ai-driven-automation-leveraging/)

*Counterintelligence & Insider Threat*

- [CDSE: Insider Threat & CI Toolkits (DCSA)](https://www.cdse.edu/Training/Toolkits/Insider-Threat-Toolkit/)
- [DCSA: Adjudication and Vetting Services (AVS)](https://www.dcsa.mil/Trust-Decision-Adjudications/About-Adjudication-and-Vetting-Services-AVS/)
- [DCSA: Counterintelligence & Insider Threat (DITMAC)](https://www.dcsa.mil/CI-Insider-Threat/)
- [NITTF: National Insider Threat Policy & Minimum Standards](https://archive.dni.gov/index.php/ncsc-how-we-work/ncsc-nittf)

*Federal AI Guidance & Partnerships*

- [Anthropic: DoD / CDAO Partnership](https://www.anthropic.com/news/anthropic-and-the-department-of-defense-to-advance-responsible-ai-in-defense-operations)
- [ASD ACSC: Opportunities for AI in Cyber Defence (May 2026)](https://www.cyber.gov.au/business-government/secure-design/artificial-intelligence/opportunities-for-ai-in-cyber-defence)
- [CISA: Adapting Zero Trust Principles to Operational Technology (Apr 2026)](https://www.cisa.gov/resources-tools/resources/adapting-zero-trust-principles-operational-technology)
- [CISA: BOD 26-04 Implementation Guidance: Forensic Triage (Jun 2026)](https://www.cisa.gov/news-events/directives/bod-26-04-implementation-guidance-prioritizing-security-updates-based-risk)
- [CISA: BOD 26-04: Prioritizing Security Updates Based on Risk (Jun 2026)](https://www.cisa.gov/news-events/news/cisa-issues-new-directive-improving-how-federal-agencies-prioritize-mitigation-cyber-vulnerabilities)
- [CISA: CI Fortify: Advice for Isolating Vital Systems (Jul 2026)](https://www.cisa.gov/resources-tools/resources/ci-fortify-advice-isolating-vital-systems)
- [CISA: Principles for the Secure Integration of AI in OT (2025)](https://www.cisa.gov/news-events/news/new-joint-guide-advances-secure-integration-artificial-intelligence-operational-technology)
- [Five Eyes: Careful Adoption of Agentic AI Services (May 2026)](https://www.cisa.gov/resources-tools/resources/careful-adoption-agentic-ai-services)
- [Microsoft: A CISO's Guide to Securing AI (Federal & DIB)](https://techcommunity.microsoft.com/blog/publicsectorblog/a-cisos-guide-to-securing-ai---securing-ai-for-federal-dib-and-dow-entities/4464081)
- [NSA AISC: AI Data Security (May 2025)](https://www.cisa.gov/resources-tools/resources/ai-data-security-best-practices-securing-data-used-train-operate-ai-systems)
- [NSA AISC: Deploying AI Systems Securely (Apr 2024)](https://www.cisa.gov/news-events/alerts/2024/04/15/joint-guidance-deploying-ai-systems-securely)

**4. Frontier Labs & National-Security Research**

*Anthropic*

- [Anthropic + NNSA: Nuclear Safeguards](https://www.anthropic.com/research/nuclear-safeguards-for-ai)
- [Anthropic + PNNL: Critical Infrastructure](https://www.anthropic.com/research/critical-infrastructure-defense)
- [Anthropic: AI models on realistic cyber ranges (Jan 2026)](https://www.anthropic.com/research/cyber-toolkits-update)
- [Anthropic: Auto Mode Is Now the Default in Claude Code (Aug 2026)](https://claude.com/blog/auto-mode-default-in-claude-code)
- [Anthropic: Claude Code Security (defenders)](https://www.anthropic.com/news/claude-code-security)
- [Anthropic: Containing Claude (engineering)](https://www.anthropic.com/engineering/how-we-contain-claude)
- [Anthropic: Disrupting AI Espionage (GTG-1002)](https://www.anthropic.com/news/disrupting-AI-espionage)
- [Anthropic: Fable 5 Cyber Safeguards & Cyber Jailbreak Severity Framework (Jul 2026)](https://www.anthropic.com/news/fable-safeguards-jailbreak-framework)
- [Anthropic: Frontier Red Team](https://www.anthropic.com/research/team/frontier-red-team)
- [Anthropic: Introducing Claude Fable 5.1 and Claude Mythos 5.1 (Sep 2026)](https://www.anthropic.com/claude-fable-and-mythos-5-1)
- [Anthropic: LLM ATT&CK Navigator (2026)](https://www.anthropic.com/research/attack-navigator)
- [Anthropic: Mapping a Year of AI-Enabled Threats](https://www.anthropic.com/news/AI-enabled-cyber-threats-mitre-attack)
- [Anthropic: Measuring LLMs' impact on N-day exploits (Jun 2026)](https://www.anthropic.com/research/n-days)
- [Anthropic: Mythos Preview & Project Glasswing](https://www.anthropic.com/research/mythos-preview)
- [Anthropic: Project Glasswing: Securing critical software for the AI era (Apr 2026)](https://www.anthropic.com/glasswing)
- [Anthropic: Redeploying Fable 5 (Jun 2026)](https://www.anthropic.com/news/redeploying-fable-5)
- [Anthropic: When AI Builds Itself (Recursive Self-Improvement)](https://www.anthropic.com/institute/recursive-self-improvement)

*More Labs & Research*

- [Alan Turing Institute: CETaS (Emerging Technology & Security)](https://cetas.turing.ac.uk/)
- [DOE: Genesis Mission](https://www.energy.gov/undersecretaryforscience/articles/us-department-energy-announces-more-800-million-partner)
- [FLI: AI Safety Index (Summer 2026)](https://futureoflife.org/ai-safety-index-summer-2026/)
- [Germany: DE-AISI (KI-Sicherheitsinstitut, Jun 2026)](https://www.heise.de/news/Bundesregierung-will-KI-Sicherheitsinstitut-gruenden-11326247.html)
- [NIST: Gödel Proof: Continuous Monitor-and-Update for AI (Jun 2026)](https://www.nist.gov/news-events/news/2026/06/nist-mathematical-proof-supports-transition-continuous-monitor-and-update)
- [RAND: Advancing U.S.-UK Cooperation to Secure Frontier AI (2026)](https://www.rand.org/pubs/research_reports/RRA4764-1.html)
- [Small Wars Journal: Ubiquitous Technical Surveillance & Signature Reduction](https://smallwarsjournal.com/2026/02/13/ubiquitous-technical-surveillance/)

**5. Human-Centric AI Adoption**

- [Microsoft: Towards Humanist Superintelligence](https://mustafa-suleyman.ai/a-humanist-future)
- [Stanford HAI: Human-Centered AI](https://hai.stanford.edu/)

**6. The Offense-Defense Balance**

- [Anthropic: Expanding Project Glasswing (Jun 2026)](https://www.anthropic.com/news/expanding-project-glasswing)
- [Anthropic: Project Glasswing: An initial update (May 2026)](https://www.anthropic.com/research/glasswing-initial-update)
- [Cotool: BlueBench (Windows Enterprise Intrusion)](https://www.cotool.ai/research/windows-enterprise-intrusion)
- [CSA: NIST's Gödel Proof: Static Guardrails Are Insufficient (Jun 2026)](https://labs.cloudsecurityalliance.org/research/csa-research-note-nist-continuous-ai-monitoring-godel-proof/)
- [CSA: Project Glasswing: Discovery Outpaces Patching](https://labs.cloudsecurityalliance.org/research/csa-research-note-glasswing-ai-vuln-patching-deficit-2026060/)
- [CSA: The AI Vulnerability Storm (VulnOps / Mythos-ready)](https://labs.cloudsecurityalliance.org/mythos-ciso/)
- [CSO Online: When AI Safety Constrains Defenders](https://www.csoonline.com/article/4138149/when-ai-safety-constrains-defenders-more-than-attackers.html)
- [IAPS: Asymmetry by Design (differential access)](https://www.iaps.ai/research/differential-access)
- [International AI Safety Report 2026](https://internationalaisafetyreport.org)
- [International AI Safety Report: Second Key Update: Technical Safeguards and Risk Management (Nov 2025)](https://internationalaisafetyreport.org/publication/second-key-update-technical-safeguards-and-risk-management)
- [NIST: NVD Operations Update for Record CVE Growth (Apr 2026)](https://www.nist.gov/news-events/news/2026/04/nist-updates-nvd-operations-address-record-cve-growth)
- [OpenAI: GPT-Red: Self-Improvement via Automated Red Teaming (Jul 2026)](https://openai.com/index/unlocking-self-improvement-gpt-red/)
- [Palo Alto Networks: Beyond Human Oversight (Frontier AI Era, Jun 2026)](https://www.paloaltonetworks.com/blog/2026/06/beyond-human-oversight-adapting-to-the-frontier-ai-era/)
- [The Weather Report (AI security newsletter): Anthropic Agent Containment](https://theweatherreport.ai/posts/anthropic-agent-containment/)

**7. Practitioner & Industry Insights**

*Context Graph*

- [Foundation Capital: Context Graphs: AI's Trillion-Dollar Opportunity](https://foundationcapital.com/ideas/context-graphs-ais-trillion-dollar-opportunity)
- [SOCAutomators (Palitto): The Context Graph: The Missing System of Record for the Agentic SOC](https://socautomators.substack.com/p/deep-dive-the-context-graph-the-missing)

*Disesdi*

- [Disesdi: Agentic Top 10: ASI04 Supply Chain](https://disesdi.substack.com/p/attacking-and-threat-modeling-the-603)
- [Disesdi: AI Red Teaming Has a Subspace Problem](https://disesdi.substack.com/p/ai-red-teaming-has-a-subspace-problem)
- [Disesdi: Angles of Attack](https://disesdi.substack.com/)
- [Disesdi: Dear NSA: The AI Threat Model You Need](https://disesdi.substack.com/p/dear-nsa-heres-the-ai-threat-model)

*Ken Huang*

- [Ken Huang: Agentic AI security (Substack)](https://kenhuangus.substack.com/)
- [Ken Huang: MAESTRO operationalized (CI/CD)](https://cloudsecurityalliance.org/blog/2026/02/11/applying-maestro-to-real-world-agentic-ai-threat-models-from-framework-to-ci-cd-pipeline)

*Shawnee Delaney*

- [Shawnee Delaney: Human Risk & Insider Threat](https://www.linkedin.com/in/shawnee-delaney)
- [Shawnee Delaney: Insider Threat at SANS](https://www.sans.org/profiles/shawnee-delaney)

*More from the Field*

- [Adam Krivka & Ondrej Vlcek (AISLE): AI Found 12 Zero-Days in OpenSSL ([un]prompted 2026)](https://www.youtube.com/watch?v=IjL2qN1KDe8)
- [Andrew Bullen (Stripe): Breaking the Lethal Trifecta ([un]prompted 2026)](https://www.youtube.com/watch?v=cNE7P5FkqR8)
- [Anton Chuvakin: Stop Building a 2003 SOC with AI (Part 1, Jun 2026)](https://medium.com/anton-on-security/stop-building-a-2003-soc-with-ai-a-modern-people-process-framework-part-1-7220513c9de1)
- [Aurora: Automated Cyberattack Emulation from CTI (classical planning + LLM)](https://arxiv.org/pdf/2407.16928)
- [Avishai Efrat & Roey Ben Chaim (Zenity): Total Recon ([un]prompted 2026)](https://www.youtube.com/watch?v=N0DukgZSREo)
- [Binary Defense: NightBeacon CMD: The Glass-Box SOC Workbench (webinar)](https://binarydefense.com/webinars/nightbeacon-cmd-the-glass-box-soc-workbench-that-keeps-humans-in-command)
- [Caroline Wong (The AI Cybersecurity Handbook): When You Turn On AI, Who Owns the New Signals? (Jul 2026)](https://www.theaicyberhandbook.com/when-you-turn-on-ai-who-owns-the-new-signals/)
- [CSA: State of AI Cybersecurity 2026 (survey)](https://cloudsecurityalliance.org/blog/2026/04/02/the-state-of-ai-cybersecurity-2026-unveiling-insights-from-over-1-500-security-leaders)
- [CSO Online: AI Red Teaming Comes of Age (2026)](https://www.csoonline.com/article/4181930/ai-red-teaming-comes-of-age.html)
- [IBM X-Force (Patrick Fussell): The Front of the Cyber Kill Chain Just Moved (Jun 2026)](https://www.ibm.com/think/x-force/The-front-of-the-cyber-kill-chain-just-moved)
- [Joshua Saxe: The Hard Part Isn't Building the Agent ([un]prompted 2026)](https://www.youtube.com/watch?v=rO2yA52U_i4)
- [Matt Maisel (Sondera): Hooking Coding Agents with the Cedar Policy Language ([un]prompted 2026)](https://www.youtube.com/watch?v=m6pzrqFJ6hE)
- [Microsoft CTI-REALM: Benchmark for CTI-to-Detection Agents](https://www.microsoft.com/en-us/security/blog/2026/03/20/cti-realm-a-new-benchmark-for-end-to-end-detection-rule-generation-with-ai-agents/)
- [Nicholas Carlini (Anthropic): Black-hat LLMs ([un]prompted 2026)](https://www.youtube.com/watch?v=1sd26pWhfmg)
- [NOVA & PromptIntel: Adversarial-Prompt Detection & IoPC Feed (Roccia)](https://promptintel.novahunting.ai)
- [Purple Book: From Snapshots to Living Intelligence (Threat Modeling, Jun 2026)](https://www.thepurplebook.club/blog-posts/from-snapshots-to-living-intelligence-ai-driven-threat-modeling-in-the-world-of-cyber-centric-frontier-models)
- [Rob T. Lee: Sleep. Diet. Exercise. AI. (SANS)](https://robtlee73.substack.com/)
- [SANS: The AI-Enabled Vulnerability Analysis Loop (SEC543 × Anthropic, Jun 2026)](https://www.sans.org/blog/ai-enabled-source-code-vulnerability-analysis-loop-sec543-and-anthropics-guidance)
- [Sergej Epp (Sysdig): 8 Minutes to Admin ([un]prompted 2026)](https://www.youtube.com/watch?v=xCtcQkJBReQ)
- [Stephen Tate (infosecuriosity): Most SOCs Are Thinking About AI the Wrong Way (Jun 2026)](https://www.infosecuriosity.co.uk/posts/2026-06-28-Most-SOCs-Are-Thinking-About-AI-the-Wrong-Way/)
- [Sublime Security: Trust, Then Autonomy (Evaluating Security AI)](https://sublime.security/resources/trust-then-autonomy-a-new-framework-for-evaluating-security-ai/)
- [Torq: 20 Questions for AI SOC Vendors (Apocalypse Manifesto, Jun 2026)](https://torq.io/resources/ai-soc-apocalypse/)
- [Wes Ring & Josiah Peedikayil (Block): Operation Pale Fire ([un]prompted 2026)](https://www.youtube.com/watch?v=SUa1nta8FGQ)
- [Wiz: Red Agent POV: Autonomous Offensive AI (2026)](https://www.wiz.io/blog/red-agent-pov-series)

**8. Regulatory & Compliance**

- [EU: AI Act (Regulation 2024/1689)](https://artificialintelligenceact.eu/)
- [EU: Digital Omnibus on AI (Regulation (EU) 2026/1744)](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32026R1744)
- [EU: NIS2 Directive (2022/2555)](https://eur-lex.europa.eu/eli/dir/2022/2555)
- [White House: AI Innovation & Security EO (Jun 2026)](https://www.whitehouse.gov/presidential-actions/2026/06/promoting-advanced-artificial-intelligence-innovation-and-security/)

**9. Research & Reference**

- [A CPU-Centric Perspective on Agentic AI (Georgia Tech + Intel)](https://arxiv.org/abs/2511.00739v1)
- [Agents of Chaos (Northeastern/Harvard/MIT/Stanford/CMU)](https://arxiv.org/abs/2602.20021)
- [Chen et al.: AgentPoison](https://arxiv.org/abs/2407.12784)
- [Cox & Bunzel: Quantifying Transferred Black-Box Attacks](https://arxiv.org/abs/2511.05102)
- [Debenedetti et al.: CaMeL (Defeating Prompt Injections)](https://arxiv.org/abs/2503.18813)
- [Dux et al.: Governance by Design (Agentic AI)](https://arxiv.org/abs/2605.20210)
- [Feffer et al.: Silver Bullet or Security Theater?](https://arxiv.org/abs/2401.15897)
- [Forough, Kogias & Haddadi: When Agents Handle Secrets (arXiv)](https://arxiv.org/abs/2605.03213)
- [Hackett & Garraghan (Mindgard / Lancaster): Behind the Refusal: Determining Guardrail Activation via Behavioral Monitoring (Jul 2026)](https://arxiv.org/abs/2607.02121)
- [MIT: AI Agent Index (2025)](https://aiagentindex.mit.edu/)
- [Narajala & Narayan: Securing Agentic AI (ATFAA+SHIELD)](https://arxiv.org/abs/2504.19956)
- [Singer et al. (CMU + Anthropic): Autonomous Multi-Host Attacks](https://arxiv.org/abs/2501.16466)
- [Stanford HAI: AI Index 2026](https://hai.stanford.edu/ai-index)
- [Vassilev (NIST): Robust AI Security & Alignment: A Sisyphean Endeavor?](https://arxiv.org/abs/2512.10100)
- [Wikipedia: Adversarial Machine Learning](https://en.wikipedia.org/wiki/Adversarial_machine_learning)
- [Wikipedia: Prompt Injection](https://en.wikipedia.org/wiki/Prompt_injection)

**10. Threat Intelligence & Industry Reports**

- [Anthropic: Government of Alberta Cybersecurity Case Study](https://www.anthropic.com/news/alberta-government-claude-cybersecurity)
- [Anthropic: Zero Trust for AI Agents (eBook)](https://claude.com/blog/zero-trust-for-ai-agents)
- [CASP: How Boko Haram Uses Frontier AI (Juelich, Jul 2026)](https://casp.ac/reports/ai-enabled-terrorism)
- [Check Point Research: VoidLink: AI-Authored Malware Framework (Jan 2026)](https://research.checkpoint.com/2026/voidlink-early-ai-generated-malware-framework/)
- [CrowdStrike: 2026 Global Threat Report (Feb 2026)](https://www.crowdstrike.com/en-us/global-threat-report/)
- [CSA + OWASP: Agentic AI Red Teaming Guide](https://cloudsecurityalliance.org/artifacts/agentic-ai-red-teaming-guide)
- [CSA: Evaluating PyRIT for Agentic AI Red Teaming](https://cloudsecurityalliance.org/artifacts/evaluating-pyrit-for-agentic-ai-red-teaming)
- [Gambit Security: The AI-Assisted Breach of Mexico's Government Infrastructure (Apr 2026)](https://gambit.security/ai-assisted-breach-of-mexicos-government-infrastructure)
- [Google GTIG: Adversarial Misuse of Generative AI (Jan 2025)](https://cloud.google.com/blog/topics/threat-intelligence/adversarial-misuse-generative-ai)
- [Government of Alberta: The Velocity White Papers (open source)](https://github.com/GovAlta/the-velocity-white-papers)
- [Mandiant: AI Risk & Resilience (special report)](https://cloud.google.com/transform/new-mandiant-report-boost-basics-with-ai-to-counter-adversaries)
- [Mandiant: M-Trends 2026 (frontline IR)](https://cloud.google.com/blog/topics/threat-intelligence/m-trends-2026/)
- [Microsoft: AI as Tradecraft (2026)](https://www.microsoft.com/en-us/security/blog/2026/03/06/ai-as-tradecraft-how-threat-actors-operationalize-ai/)
- [MOSAIC Standards: AI Security Framework Alignment](https://mosaicstandards.org)
- [0DIN: Clone This Repo and I Own Your Machine](https://0din.ai/blog/clone-this-repo-and-i-own-your-machine)
- [0DIN: Jailbreak Feed](https://0din.ai/marketing/threat_intel)
- [Recorded Future: The Intelligence Handbook](https://www.recordedfuture.com/resources/guides/the-intelligence-handbook-fourth-edition)
- [requie: AI-Red-Teaming-Guide](https://github.com/requie/AI-Red-Teaming-Guide)
- [SANS: Critical AI Security Guidelines v1.4](https://www.sans.org/mlp/critical-ai-security-guidelines)
- [SANS: Cyber Threat Intelligence (FOR578 / CTI)](https://www.sans.org/cyber-security-courses/cyber-threat-intelligence)
- [SANS: Protocol SIFT & the Find Evil! Hackathon (RSAC 2026)](https://www.sans.org/press/announcements/two-words-changed-cybersecurity-find-evil-builders-answer-call-defend-infrastructure)
- [SecurityWeek: Hackers Weaponize Claude Code in Mexican Government Cyberattack (Mar 2026)](https://www.securityweek.com/hackers-weaponize-claude-code-in-mexican-government-cyberattack/)
- [Torq: 2026 AI SOC Leadership Report](https://torq.io/resources/ai-soc-leadership-report-2026/)
- [Unit 42 (Palo Alto): Dual-Use Dilemma (Malicious LLMs)](https://unit42.paloaltonetworks.com/dilemma-of-ai-malicious-llms/)
- [Unit 42 (Palo Alto): Global IR Report 2026](https://www.paloaltonetworks.com/resources/research/unit-42-incident-response-report)
- [Unit 42 (Palo Alto): Threat Research](https://unit42.paloaltonetworks.com/)
- [Verizon: 2026 Data Breach Investigations Report](https://www.verizon.com/business/resources/reports/dbir/)
- [VulnCheck: 2025 Q1 Trends in Vulnerability Exploitation (Apr 2025)](https://www.vulncheck.com/blog/exploitation-trends-q1-2025)
- [Zenity Labs: AI Security Research Out of the Lab and Into the Wild (Jun 2026)](https://labs.zenity.io/post/why-ai-security-research-needs-to-move-out-of-the-lab-and-into-the-wild)

**11. Vendor & Platform Security**

*Authentic8*

- [Authentic8: Silo for Research (Managed Attribution)](https://authentic8.com/products/silo-workspace/)

*AWS*

- [AWS + SANS: AI for Security and Security for AI (Nov 2025)](https://d1.awsstatic.com/onedam/marketing-channels/website/aws/en_US/whitepapers/compliance/AI-for-Security-and-Security-for-AI_Navigating-Opportunities-and-Challenges.pdf)
- [AWS: Agentic AI Security Scoping Matrix (Nov 2025)](https://aws.amazon.com/blogs/security/the-agentic-ai-security-scoping-matrix-a-framework-for-securing-autonomous-ai-systems/)
- [AWS: AI Security Framework](https://aws.amazon.com/blogs/security/the-aws-ai-security-framework-securing-ai-with-the-right-controls-at-the-right-layers-at-the-right-phases/)
- [AWS: Amazon Bedrock Guardrails](https://aws.amazon.com/bedrock/guardrails/)
- [AWS: Continuum (Jun 2026)](https://aws.amazon.com/blogs/security/introducing-aws-continuum-security-at-machine-speed/)

*Cisco & Splunk*

- [Cisco: Shields Up: Defending Against AI-Enabled Attacks (2026)](https://www.cisco.com/c/dam/en_us/about/doing_business/trust-center/docs/cisco-defending-against-ai-attacks-guidance.pdf)
- [Cisco: 8 Years of Security Research in 8 Weeks (2026)](https://blogs.cisco.com/news/8-years-of-security-research-in-8-weeks-transforming-cybersecurity-with-ai)
- [Splunk: Defending in the Post-Mythos Era (Jun 2026)](https://www.splunk.com/en_us/blog/artificial-intelligence/defending-in-the-post-mythos-era.html)

*Google*

- [Google: AI Threat Defense](https://cloud.google.com/blog/products/identity-security/introducing-google-ai-threat-defense)
- [Google: Implementing SAIF Controls in Google Cloud (Dec 2025)](https://services.google.com/fh/files/misc/ociso_2025_saif_cloud_paper.pdf)
- [Google: SecOps Agents for AI-Powered Threat Containment (Jun 2026)](https://cloud.google.com/blog/products/identity-security/detecting-and-containing-powered-threats-with-google-security-operations-agents)
- [Google: Securing the AI Frontier (CodeMender, AI VRP, SAIF 2.0)](https://blog.google/innovation-and-ai/technology/safety-security/ai-security-frontier-strategy-tools/)

*Meta*

- [Meta: Purple Llama (Llama Guard 4, LlamaFirewall, CyberSecEval 4)](https://dev.meta.ai/llama/llama-protections)

*Microsoft*

- [Microsoft: Codename MDASH Brings Agentic AI Security Scanning to US Government (Sep 2026)](https://www.microsoft.com/en-us/microsoft-cloud/blog/us-government/2026/09/08/codename-mdash-brings-agentic-ai-security-scanning-to-us-government/)
- [Microsoft: MAI-Cyber-1-Flash & Project Perception (Jul 2026)](https://microsoft.ai/news/introducing-mai-cyber-1-flash-inside-mdash/)
- [Microsoft: MDASH Agentic Security](https://www.microsoft.com/en-us/security/blog/2026/05/12/defense-at-ai-speed-microsofts-new-multi-model-agentic-security-system-tops-leading-industry-benchmark/)
- [Microsoft: See What Happened: AI Investigation Playbook (Jun 2026)](https://cdn-dynmedia-1.microsoft.com/is/content/microsoftcorp/microsoft/bade/documents/products-and-services/en-us/security/See-What-Happened-AI-Investigation-Playbook.pdf)

*OpenAI*

- [OpenAI: Prompt Injection: A Frontier Challenge](https://openai.com/index/prompt-injections/)
- [OpenAI: Trusted Access for Cyber (GPT-5.5 / GPT-5.5-Cyber, May 2026)](https://openai.com/index/gpt-5-5-with-trusted-access-for-cyber/)

*Palo Alto Networks*

- [Palo Alto Networks: Defender's Guide to the Frontier AI Impact on Cybersecurity (May 2026)](https://www.paloaltonetworks.com/blog/2026/05/defenders-guide-frontier-ai-impact-cybersecurity-may-2026-update/)

*SentinelOne*

- [SentinelOne: The Autonomous SOC, Revisited (Jul 2026)](https://www.sentinelone.com/blog/the-autonomous-soc-revisited-what-18-months-on-the-road-has-taught-us/)

*Wiz (Google Cloud)*

- [Wiz (Google Cloud): AI-SPM & State of AI in the Cloud](https://www.wiz.io/academy/ai-security/what-is-ai-security-posture-management-ai-spm)

**12. Voices to Follow**

- [Disesdi Susanna Cox: AI security architect (OWASP AI Exchange)](https://disesdi.substack.com/)
- [Shawnee Delaney: human risk & insider threat](https://www.linkedin.com/in/shawnee-delaney)
- [Jennifer Ewbank: An Intelligence Warning Hidden in Agentic AI Guidance (Jun 2026)](https://www.linkedin.com/pulse/intelligence-warning-hidden-agentic-ai-guidance-jennifer-ewbank-fr2uc)
- [Ken Huang: creator of CSA MAESTRO](https://kenhuangus.substack.com/)
- [Rob T. Lee: SANS Chief AI Officer](https://robtlee73.substack.com/)
- [Ipek Ozkaya: Carnegie Mellon SEI](https://www.sei.cmu.edu/authors/ipek-ozkaya/)
- [Wendi Whitmore: Chief Security Intelligence Officer, Palo Alto Networks](https://www.linkedin.com/in/wendiwhitmore2)

**13. Zero Trust & Agentic Insider Risk**

- [Cisco: Zero Trust for Agentic AI (white paper)](https://www.cisco.com/c/en/us/solutions/collateral/artificial-intelligence/security/zero-trust-agentic-ai-wp.html)
- [CoSAI: Zero Trust for AI Systems (v1.0, Sep 2026)](https://github.com/cosai-oasis/ws2-defenders/blob/main/zero-trust/Zero-Trust-for-AI-Systems.pdf)
- [Google DeepMind: AI Control Roadmap (v0.1)](https://deepmind.google/blog/securing-the-future-of-ai-agents/)
- [Google DeepMind: Three Layers of Agentic Security](https://storage.googleapis.com/deepmind-media/DeepMind.com/Blog/securing-the-future-of-ai-agents/three-layers-of-agent-security.pdf)
- [IETF: RFC 8693 (OAuth 2.0 Token Exchange)](https://datatracker.ietf.org/doc/html/rfc8693)
- [Ken Connell: Lensatic Field Guides: Zero Trust (Sep 2026)](https://kensden.github.io/lensatic/guides/zero-trust/)
- [Microsoft: Announcing Zero Trust for AI](https://www.microsoft.com/en-us/security/blog/2026/03/19/new-tools-and-guidance-announcing-zero-trust-for-ai/)
- [Microsoft: Defense in Depth for Autonomous Agents](https://www.microsoft.com/en-us/security/blog/2026/05/14/defense-in-depth-autonomous-ai-agents/)
- [NSA: Zero Trust Implementation Guidelines (ZIGs, 2026)](https://www.nsa.gov/Press-Room/Press-Releases-Statements/Press-Release-View/Article/4496862/nsa-launches-zero-trust-implementation-guidelines-resource-webpage/)
- [OpenID Foundation: Identity Management for Agentic AI (Oct 2025)](https://openid.net/wp-content/uploads/2025/10/Identity-Management-for-Agentic-AI.pdf)
- [Valente & Zalewski: Beyond Zero: Enterprise Security for the AI Era (May 2026)](https://arxiv.org/abs/2605.22985)

-----

## Part 9: SANS AI course map and advanced topics to study

This part exists because SEC536 and SEC598, plus the closely related SEC535, define where formal training is going. Here's how they map to this guide and the specific advanced topics they add.

### How the three courses fit the Part 1 matrix

- **SEC536, Adversarial AI (A-Red):** attacking the AI system itself. This is the course most aligned with Question A of the Part 1 matrix (securing Agentic AI), viewed from the attacker's seat.
- **SEC535, Offensive AI (B-Red):** using AI as a weapon. This rounds out the offensive picture and explains the AI-accelerated adversary your blue and purple work has to keep pace with.
- **SEC598, AI and Security Automation (all teams, both questions):** the automation and purple-teaming backbone, with the GASAE certification. This is the course most aligned with the purple, operationalize-it work.

### SEC536 syllabus at a glance

- *Section 1: Foundations of Attack Techniques.* How LLMs process input and why each mechanism is an attack primitive; AI-specific reconnaissance; direct and indirect injection; memory and RAG poisoning; multimodal evasion. Labs include abusing AI assistants, reconnaissance against AI systems, prompt injection, AI memory and context poisoning, and computer-vision evasion attacks.
- *Section 2: Infrastructure, Integrations, and Advanced Attacks.* Jailbreak techniques and guardrail evasion; exposed inference hosts and ML platforms; timing side channels, API authorization flaws, and weight extraction. Labs include jailbreaks and weight theft, AI architecture flaws, timing side channels, exploiting mass assignments and hidden features, and model theft and extraction.
- *Section 3: Alignment, Interfaces, Agents, and MCP.* Alignment failures as a testable surface (reward hacking, goal misgeneralization, sandbagging); sycophancy and constitutional AI abuse; stored XSS and SSRF through AI interfaces; agentic attacks, multi-agent topologies, and MCP exploitation. Labs include AI alignment issues discovery, weaponizing a sycophantic AI, stored XSS via AI chat, attacking Agentic AI, and attacking MCP servers.

### SEC598 syllabus at a glance

- *Section 1, Foundations of GenAI, LLMs, and Security Automation:* why automation/AI now; security engineering the CI/CD approach; configuration management and policy-as-code at scale; automation triggers and SOAR; foundations of detection-as-code, GenAI, and LLMs.
- *Section 2, Security Automation Engineering and AI Workflows:* PowerShell automation for offense and defense; infrastructure-as-code with Terraform; building automated firing ranges; Python/Jupyter for SOC enrichment; SOAR tooling, playbook automation, and Agentic AI engineering.
- *Section 3, Cloud Automation and AI Security Services:* cloud governance (Azure and AWS); cloud-native automated monitoring and enforcement; intelligent automation with Microsoft AI and AWS Bedrock; cloud-native incident response; AWS AI agents targeting Kubernetes and continuous security testing.
- *Section 4, Red Team Automation and Offensive AI Agents:* adversary emulation and purple methodologies; MITRE ATT&CK-driven offensive frameworks; AI-powered red-team agents and autonomous adversaries; cloud-native emulation and detection validation; continuous adversary simulation in CI/CD. Labs use Atomic Red Team, Caldera, and CrewAI red-team agents.
- *Section 5, Defensive Automation and AI-Augmented Response:* modern SOC evolution; defensible architectures with embedded automation; modular incident response and SOAR; AI-infused detection-as-code; countering adversarial automation. Labs use Velociraptor, Timesketch, and Tines.
- *Section 6, Capstone:* a full-day, mission-based exercise applying the whole pipeline.

### Specific advanced topics these courses add to your study list

The following are concrete things worth being able to explain or attempt, informed by the three syllabi and woven into Parts 3 - 7 above:

- **MCP attacks**: homoglyph tool shadowing, name collision, dynamic tool-discovery abuse, SQL injection through MCP servers, context injection. (Part 3, MCP layer.)
- **Vision/multimodal attacks**: adversarial examples, evasion, adversarial patches, defeating facial recognition and identity checks, image-borne prompt injection. (Part 3, vision layer.)
- **Model extraction and weight theft**, including jailbreak chains that end in stealing a model's weights, and the controls that protect them. (Part 3, model layer.)
- **LLM API attacks**: role confusion, path traversal, missing authentication, mass assignment, hidden features/endpoints. (Part 3, tool/API layer.)
- **Side-channel and infrastructure attacks** and **alignment failures** as exploitable surfaces. (Part 3, infrastructure layer.)
- **Reconnaissance against AI systems** as an explicit offensive phase. (Part 4.)
- **AI-as-weapon tradecraft**: AI-accelerated recon/OSINT, RAG pentest assistants, deepfake phishing and voice-cloned vishing, AI-assisted patch diffing, AI-assisted malware and evasion. (Part 4, B-Red.)
- **Automation engineering**: policy-as-code, infrastructure-as-code (Terraform/Ansible), automated firing ranges, SOAR playbooks, detection-as-code with CI/CD, LLM-assisted detection generation and testing. (Parts 5 - 6.)
- **Adversary-emulation-as-code**: Atomic Red Team, Caldera, CrewAI red-team agents, PurpleCloud, Automated Emulation, ATT&CK-mapped continuous validation. (Part 6.)

-----

## Glossary

- **Agent / Agentic AI**: an AI system that can plan and take actions via tools, with memory and (often) multi-step autonomy, not just produce text.
- **Agent loop**: perceive → reason → act → observe, repeated until a goal is met.
- **Direct prompt injection**: malicious instructions supplied directly by the user.
- **Jailbreak**: bypassing a model's safety alignment.
- **Excessive agency**: an agent having more capability/permission/autonomy than its task requires.
- **MCP (Model Context Protocol)**: a standard for connecting agents to external tools/data servers; powerful and a significant new attack surface.
- **Tool shadowing**: a malicious tool that mimics or overrides a trusted one (often via homoglyph names) so the agent invokes it.
- **Name collision**: exploiting two tools/servers sharing a name to get the attacker's tool selected.
- **RAG (retrieval-augmented generation)**: supplementing an LLM with retrieved documents, typically from a vector database.
- **Vector store**: the database of embeddings behind RAG; a poisoning and exfiltration target.
- **Adversarial example**: an input with crafted perturbations that causes a model to misclassify (an evasion attack).
- **Adversarial patch**: a physical or digital pattern engineered to reliably fool a classifier or detector.
- **Evasion attack**: manipulating an input at inference time to change a model's output (classic predictive-AI/vision attack).
- **Model extraction**: reconstructing a model's behavior through systematic querying.
- **Weight theft**: exfiltrating a model's actual parameters (crown-jewel IP).
- **Side-channel attack**: leaking information via timing, response length, caching, power, or EM signals.
- **Alignment failure**: the exploitable gap between a model's intended and actual behavior.
- **Blast radius**: the scope of damage one compromise can reach; cascading failure is its multi-agent form.
- **Rogue agent**: a hijacked or misaligned agent acting like an insider threat.
- **Non-human identity (NHI)**: credentials/tokens belonging to an agent or service rather than a person.
- **OWASP NHI Top 10**: OWASP's 2025 list of the top risks for non-human (machine/agent) identities, from improper offboarding to human use of NHI.
- **Red / Blue / Purple team**: offense / defense / the integrated feedback loop between them.
- **PyRIT**: Microsoft's open-source AI red-teaming toolkit.
- **RAMPART**: Microsoft's pytest-based agentic red-teaming framework (built on PyRIT).
- **MAESTRO**: a Cloud Security Alliance (Ken Huang) 7-layer threat-modeling framework for Agentic AI; complementary to OWASP's work, not part of it.
- **ATLAS**: MITRE's adversarial-techniques knowledge base for AI ("ATT&CK for AI").
- **AI RMF**: NIST's AI Risk Management Framework (Govern, Map, Measure, Manage).
- **Detection-as-code**: detections written, version-controlled, reviewed, and tested through CI/CD like software.
- **Policy-as-code**: security/configuration policy expressed and enforced as version-controlled code.
- **SOAR**: Security Orchestration, Automation, and Response; automated response workflows/playbooks.
- **Adversary emulation**: running known adversary techniques (mapped to ATT&CK) to validate detections.
- **Firing range / cyber range**: an isolated, often disposable environment for safe security testing.
- **Atomic Red Team / Caldera**: open-source frameworks for executing/automating ATT&CK-mapped emulation.
- **Agentic SOC**: a security operations model where autonomous AI agents run SOC workflows alongside humans.
- **Shift-left**: embedding security testing (e.g., red-team checks) early in the development pipeline.
- **GASAE**: GIAC AI Security Automation Engineer, the certification tied to SANS SEC598.
- **COAE**: HTB Certified Offensive AI Expert, the certification tied to the Hack The Box AI Red Teamer path.

-----

### Agentic security terms

- **Autonomy Spectrum**: The range from guided assistant to end-to-end agent. Autonomy is earned through eval evidence, and every notch up the dial pairs with tighter circuit breakers.
- **Confused Deputy**: A privileged component tricked into using its authority on an attacker's behalf, the classic frame for most agent abuse: the agent is the deputy, the injected content is the trick.
- **Indirect Prompt Injection**: Malicious instructions planted in content the agent will later read (web page, email, document, tool output) rather than typed by a user: the primary exploitation path for tool-using agents.
- **Memory Poisoning (Agentic)**: Implanting false or malicious entries in an agent's persistent memory or knowledge store so the corruption survives sessions and steers future actions (e.g., AgentPoison).
- **Slopsquatting**: Registering packages under names LLMs tend to hallucinate so AI-generated code imports attacker malware: supply-chain squatting aimed at machine-written software.
- **Tool Poisoning (MCP)**: Hiding malicious instructions or behavior inside a tool's description or output so any agent that loads the tool is compromised: the MCP-era supply-chain variant of injection.
- **AI Firewall / LLM Gateway**: An inspection layer in front of the model that screens prompts and outputs for injection, data leakage, and policy violations: it pairs with, never replaces, network egress controls.
- **Capability-Based Control**: Granting an agent explicit, scoped capabilities (what data may flow where) instead of trusting model judgment; the design behind DeepMind's CaMeL. Deterministic bounds over probabilistic defenses.
- **Circuit Breaker**: An automatic, threshold-triggered halt on agent activity (spend, action rate, anomaly score): the machine-speed kill switch pre-wired before an incident, not improvised during one.
- **Egress Filtering**: Default-deny outbound network control with destination allowlisting: the concrete defense that breaks the lethal trifecta's external-communication leg.
- **Shadow AI / Shadow Agents**: Ungoverned models, bots, or agents adopted outside security's view: unowned non-human identities with real access and no lifecycle; the agentic twin of shadow IT.
- **VulnOps**: Operating vulnerability response as a continuous, AI-accelerated discipline: triaging, patching, and validating at the cadence AI-driven discovery now forces (CSA's Mythos-ready framing).
- **Tradecraft (Agentic)**: The practiced discipline of operating without exposing yourself; in Agentic SecOps, the habits that separate operators from tool users: identity hygiene, containment-first defaults, eval-gated autonomy, evidence preserved before action.
- **Time-to-Exploit / Patching Deficit**: The collapsing gap between disclosure and exploitation (M-Trends 2026 estimates a mean of minus seven days) set against fixed patching capacity: Glasswing's core math, and why containment comes before cleverness.
- **Agency vs. Autonomy**: Two separately governed axes of an agent: agency is the scope of actions it is permitted to take (needs boundaries and permission systems); autonomy is its independence in deciding when to act (needs oversight and behavioral controls). The axes of AWS's four-scope agentic matrix.
- **Automated Reasoning (Formal Verification)**: Proving an AI output correct against a formal logic model of policy rather than sampling it for quality: deterministic where evals are probabilistic; the guardrail class behind Cedar-style verified authorization. Requires formalizable policy and a sound model of the environment.
- **Continuous Threat Exposure Management (CTEM)**: Replacing periodic, cycle-based patching with a standing loop (discover exposures, prioritize by real-world exploitability and asset exposure, validate, remediate, verify) run continuously; the organizing frame for machine-speed vulnerability management (Gartner, 2022).

-----

## Self-check (grouped by Part)

Use these for active recall. After finishing a Part, answer its questions in plain language without looking: the answers all live within that Part.

**Part 0: Foundations**

1. In one sentence, what's the difference between an LLM and an agent, and why does it matter for security?
1. Name the four components of an agentic system and the four steps of the agent loop.
1. What are the three properties that make agents uniquely hard to defend?

**Part 1: Framing**

4. State the two framing questions, and give one example of how they converge.

**Part 2: Frameworks**

5. In a sentence each, what are OWASP LLM Top 10, OWASP ASI, OWASP NHI Top 10, MITRE ATLAS, NIST AI RMF / AI 100-2, SAIF, and CSA MAESTRO *for*?
6. What does "excessive agency" mean, and which OWASP LLM item is it?
7. Who maintains MAESTRO, and what does it add that the OWASP lists don't?

**Part 3: Attack surface**

8. Explain direct vs indirect prompt injection, and why indirect is the dominant agentic threat.
9. Why is a system prompt *not* a security control?
10. What is MCP, and name three MCP-specific attacks.
11. Give two ways the memory/RAG layer is attacked, including a cross-tenant exfiltration path.
12. What is an adversarial patch, and what kind of system does it defeat?
13. What's the difference between model extraction and weight theft?
14. Name four classic API/appsec bugs that reappear in the AI service layer.
15. What is the blast-radius problem, and which real-world worm demonstrates it?

**Part 4: Red team**

16. Name two ways AI red teaming differs from traditional pen testing.
17. Distinguish "attacking AI systems" from "AI as an offensive weapon," and name the SANS course for each.
18. What is reconnaissance against an AI system, and what would you try to learn?
19. What is PyRIT, and what are RAMPART and the AI Red Teaming Agent built on?

**Part 5: Blue team**

20. List four controls for defending an agentic system, and say which layer each protects.
21. What is detection-as-code, and why does SEC598 emphasize it?
22. What is the "agentic SOC," and name two Microsoft agents that exemplify it.
23. How do you detect a rogue agent whose individual actions look legitimate?

**Part 6: Purple team**

24. Describe the purple-team feedback loop in one sentence, and name two adversary-emulation tools.
25. When would you map to ATLAS versus ATT&CK in an Agentic-AI purple program?
26. What are the crawl/walk/run stages of purple-team autonomy?

**Part 7: Hands-on practice**

27. Where must every exercise in this Part run, and what must it never be pointed at?
28. Name the three MCP attacks this Part has you try against a local MCP server.
29. In the Hallucinated Commitment tabletop, what must interaction logging be able to answer, and what does the Air Canada ruling establish?

**Part 8: Certifications**

30. Which GIAC cert is tied to SANS SEC598, and which cert crowns the HTB AI Red Teamer path?

**Part 9: SANS course map**

31. Which SANS course covers attacking the AI system itself, which covers AI as an offensive weapon, and which covers automation and purple teaming?
32. Name the tools the SEC598 labs use for adversary emulation, and the tools they use for defensive automation.
33. Name four MCP attacks on this Part's advanced-topics list.

-----

*This guide is a study aid, not operational authorization. Any hands-on red-team activity must be performed only in isolated, explicitly authorized environments.*
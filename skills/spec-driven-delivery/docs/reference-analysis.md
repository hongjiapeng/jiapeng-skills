# Reference Analysis

This research was used to design a lightweight Spec-Driven Delivery skill. The goal is to borrow practical workflow structure without copying text, code, CLIs, command systems, dashboards, or heavy orchestration.

## github/spec-kit

- Source: https://github.com/github/spec-kit
- What it is: An open-source toolkit for Spec-Driven Development with CLI setup, project principles, spec, plan, tasks, implementation, and validation commands.
- Useful ideas to borrow: Separate "what and why" from technical planning, use explicit phases, keep specs as shared intent, and add optional validation and convergence checks.
- What to avoid: Installing a CLI, creating a `.specify` runtime, adopting command naming, or treating this first version as an executable SDD platform.
- Lightweight fit: High as an influence, low as a direct dependency.
- Influence on this skill: The workflow keeps the spec -> plan -> tasks/checks -> implementation prompt progression, but reduces it to reusable Markdown artifacts.

## addyosmani/agent-skills

- Source: https://github.com/addyosmani/agent-skills
- What it is: A collection of production-oriented Markdown skills for AI coding agents.
- Useful ideas to borrow: Skills should encode senior-engineer workflow discipline, be specific, verifiable, battle-tested, and minimal.
- What to avoid: Importing a broad lifecycle pack, multiple companion skills, hooks, or tool-specific command layers.
- Lightweight fit: High.
- Influence on this skill: The main skill is written as a direct operating procedure with quality gates instead of methodology exposition.

## addyosmani/agent-skills/skills/spec-driven-development/SKILL.md

- Source: https://raw.githubusercontent.com/addyosmani/agent-skills/main/skills/spec-driven-development/SKILL.md
- What it is: A concise skill that tells agents to create a spec before coding and use gated phases.
- Useful ideas to borrow: Make assumptions visible, require human-checkable success criteria, define boundaries, and avoid code before a validated spec.
- What to avoid: Copying its exact template, assuming web-project defaults, or making implementation part of this skill.
- Lightweight fit: Very high.
- Influence on this skill: This skill adopts the "do not guess; state assumptions; gate the handoff" posture and adds repository-boundary language for multi-repo agent work.

## gotalab/cc-sdd

- Source: https://github.com/gotalab/cc-sdd
- What it is: A cross-agent, Kiro-inspired SDD harness for discovery, requirements, design, tasks, and long-running autonomous implementation.
- Useful ideas to borrow: Discovery should route the request before committing to a spec, boundaries matter, tasks should be restartable, and implementation notes should feed later review.
- What to avoid: Long-running autonomous implementation, subagent orchestration, multi-command installation, and feature-scale process overhead.
- Lightweight fit: Medium.
- Influence on this skill: The implementation plan template asks for file boundaries, dependencies, and rollback considerations, but leaves execution to the target coding agent.

## SpillwaveSolutions/sdd-skill

- Source: https://github.com/SpillwaveSolutions/sdd-skill
- What it is: A comprehensive Claude Code skill for guiding users through GitHub Spec Kit and SDD methodology.
- Useful ideas to borrow: Brownfield and greenfield differences, structured summaries, feature status awareness, and keeping the user oriented after artifact generation.
- What to avoid: Progress dashboards, extensive status management, many triggers, installation guidance, and rich feature-management operations.
- Lightweight fit: Medium.
- Influence on this skill: The final response format summarizes artifacts, decisions, influences, and next use without becoming a tracking system.

## Microsoft Developer Blog: A Spec-First Approach to AI-Native Engineering

- Source: https://developer.microsoft.com/blog/spec-driven-development-ai-native-engineering
- What it is: An engineering article explaining SDD as a shared source of truth across requirements, architecture, implementation, and validation.
- Useful ideas to borrow: Avoid translation loss between stakeholder needs, requirements, design, implementation, and validation.
- What to avoid: Broad organizational framing that does not help an individual coding-agent handoff.
- Lightweight fit: High.
- Influence on this skill: The workflow explicitly maps requirements to acceptance criteria, and implementation tasks back to requirements.

## GitHub Blog: Spec-driven development with AI

- Source: https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/
- What it is: A practical introduction to using Spec Kit with AI coding agents.
- Useful ideas to borrow: The human's role is to verify at every phase, not just steer. The agent can generate artifacts, but the human must critique them.
- What to avoid: Tying this skill to `/specify`, `/plan`, `/tasks`, or a specific setup flow.
- Lightweight fit: High.
- Influence on this skill: The quality gates require reviewable specs, concrete checks, and explicit verification before handoff.

## Addy Osmani blog: How to write a good spec for AI agents

- Source: https://addyosmani.com/blog/good-spec/
- What it is: A guide to writing useful specs for AI agents without overwhelming context.
- Useful ideas to borrow: Start with a high-level vision, structure the spec, include commands and tests, define boundaries, keep tasks small, and iterate with feedback.
- What to avoid: Overloaded spec documents and advanced multi-agent management for normal feature work.
- Lightweight fit: Very high.
- Influence on this skill: Templates stay short, require concrete commands/checks, and include allowed/disallowed changes.

## Addy Osmani blog: Agent Skills

- Source: https://addyosmani.com/blog/agent-skills/
- What it is: An article arguing that Markdown skills can carry reusable engineering workflow discipline across tools.
- Useful ideas to borrow: Plain Markdown is portable across Codex, Claude Code, Cursor, Copilot-style tools, and team docs.
- What to avoid: Assuming the user must install any particular runtime.
- Lightweight fit: Very high.
- Influence on this skill: Everything is Markdown-based, portable, and designed as an operating procedure rather than software.

## Design Conclusion

This skill should be strict about handoff quality and light about machinery. The durable unit is a delivery packet, not a platform. The useful borrowings are phase gates, assumptions, traceability, boundaries, and verification. The avoided parts are CLIs, slash-command ecosystems, status dashboards, subagent orchestration, and executable spec frameworks.

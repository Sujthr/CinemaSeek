# ReAct: Synergizing Reasoning and Acting in Language Models

**Authors:** Shunyu Yao, Jeffrey Zhao, Dian Yu, Nan Du, Izhak Shafran, Karthik Narasimhan, Yuan Cao  
**Year:** 2022  
**Venue:** ICLR 2023  

## Abstract

This paper proposes ReAct, a framework in which large language models generate both reasoning traces and task-specific actions in an interleaved manner. Reasoning traces allow the model to induce, track, and update action plans, while actions allow the model to gather information from external sources such as search engines or knowledge bases. Evaluated on question answering, fact verification, and interactive decision-making tasks, ReAct outperforms approaches that use either reasoning or acting alone, and is more interpretable and trustworthy.

## Motivation

Two parallel lines of work had emerged by 2022. Chain-of-thought prompting showed that reasoning traces — sequences of intermediate thoughts generated in natural language — could substantially improve performance on multi-step problems. Separately, work on action-generation for language models showed that models could be prompted to produce sequences of actions (API calls, search queries, navigation commands) to interact with external environments.

The two approaches address different failure modes. Pure reasoning, without access to external information, is prone to hallucination and factual drift — the model reasons fluently from false premises because it cannot verify intermediate conclusions. Pure action generation, without accompanying reasoning, produces reactive sequences that lack a coherent plan, making the model brittle in novel situations where the expected action sequence is not directly retrievable.

The hypothesis of ReAct is that reasoning and acting are mutually reinforcing. Reasoning helps the model decide which action to take next; the results of actions provide grounding that constrains subsequent reasoning. The two modalities should interleave rather than alternate in stages.

## The ReAct Framework

ReAct prompts the model to generate trajectories consisting of three types of tokens in alternation: Thought, Action, and Observation.

A **Thought** is a free-text reasoning step in which the model reflects on the current state of the task, interprets the most recent observation, and decides what to do next. Thoughts are never sent to the environment — they exist only in the model's context as reasoning scaffolding.

An **Action** is a structured command sent to an external tool. In the question-answering setting, the available actions are Search (a Wikipedia query), Lookup (a forward search within the current Wikipedia page), and Finish (submitting the final answer). The action format is fixed and parseable.

An **Observation** is the environment's response to the action. For Search, the observation is the first paragraph of the most relevant Wikipedia page. Observations are appended to the context verbatim.

The key architectural insight is that Observations serve as **intermediate signals** that anchor subsequent reasoning. After the model receives an observation, the next Thought can explicitly refer to what was found, identify whether it resolved the current sub-question, and plan the next step accordingly. This creates a feedback loop in which each action-observation pair provides a calibration point for the ongoing reasoning chain.

This is fundamentally different from chain-of-thought prompting, where reasoning is entirely self-contained. In ReAct, the reasoning trace is grounded at every action step by an external information source. The model cannot sustain a hallucination across an observation boundary without it being visible in the trace.

## Role of Intermediate Observations in Learning

The interleaved structure of thought-action-observation sequences has implications for how the model distributes its reasoning effort across the trajectory. Each observation provides a checkpoint — a piece of externally verified information — that the model's subsequent reasoning must integrate. The responsibility for correct reasoning is therefore distributed across multiple grounded checkpoints rather than concentrated in a single output.

From an error-propagation perspective, when the model's reasoning goes wrong between two observations, the next observation either confirms or contradicts it. If the observation contradicts the reasoning, the model has a visible signal at a specific point in the trajectory that its prior reasoning was incorrect. The model can then revise its plan in the next Thought step. This makes errors both local and visible, unlike in closed-context reasoning where an incorrect intermediate step may silently propagate to an incorrect final answer.

The intermediate observations act as correction opportunities distributed through the trajectory. The denser the action steps, the shorter the interval between external checks, and the more constrained the reasoning must be. This is analogous to how frequent checkpoints in any sequential decision process allow more responsive adjustment to new information.

## Empirical Results

On HotpotQA, a multi-hop question answering benchmark requiring synthesis across multiple Wikipedia articles, ReAct achieves 35.1% exact match with only six in-context examples, compared to 33.4% for chain-of-thought alone and 29.4% for action generation alone. On FEVER, a fact verification benchmark, ReAct reaches 71.8% accuracy versus 65.4% for chain-of-thought.

On ALFWorld, an interactive household task environment requiring agents to navigate and manipulate objects through text commands, ReAct achieves 71% task success compared to 45% for the action-only baseline. On WebShop, a product search and purchase environment, ReAct reaches 40.2% success versus 35.5% for imitation learning baselines trained on human demonstrations.

## Interpretability and Human Correction

A secondary contribution of ReAct is interpretability. Because every action is preceded by a Thought that explains the model's reasoning, a human observer can read the trajectory and identify exactly where the model went wrong. In contrast, pure action-generation trajectories offer no explanation for individual action choices.

The paper demonstrates that human annotators can edit individual Thought steps in a trajectory to correct errors, and the corrected trajectory leads to substantially higher task success rates. This human-in-the-loop correction is only possible because the reasoning is externalised.

## Limitations

ReAct is bounded by the quality of its action space and the reliability of its observation sources. If the available tools cannot retrieve the information needed to resolve a sub-question, the model may loop through multiple search attempts without making progress. The paper notes that ReAct sometimes falls into repetition loops on difficult questions, a failure mode that subsequent work addresses with additional planning structure.

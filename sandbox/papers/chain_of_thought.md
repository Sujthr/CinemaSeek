# Chain-of-Thought Prompting Elicits Reasoning in Large Language Models

**Authors:** Jason Wei, Xuezhi Wang, Dale Schuurmans, Maarten Bosma, Brian Ichter, Fei Xia, Ed Chi, Quoc Le, Denny Zhou  
**Year:** 2022  
**Venue:** NeurIPS 2022  

## Abstract

This paper shows that generating a chain of intermediate reasoning steps before producing a final answer substantially improves the ability of large language models to perform complex reasoning. The technique, called chain-of-thought prompting, requires no fine-tuning — it is applied by including examples with intermediate reasoning traces in the few-shot prompt. The method yields striking improvements on arithmetic, commonsense, and symbolic reasoning benchmarks, and these improvements emerge only at sufficient model scale.

## Motivation

Large language models achieve strong performance on many natural language tasks when prompted with a few input-output examples. However, tasks requiring multi-step reasoning — arithmetic word problems, logical inference chains, commonsense reasoning — remained difficult even for very large models under standard prompting. The failure mode was consistent: the model would map a complex question directly to a final answer, skipping the intermediate steps that a human would use to work through the problem.

The authors hypothesised that if the model were encouraged to articulate intermediate reasoning steps explicitly, it could effectively decompose difficult problems and avoid the errors that come from attempting to compress multi-step inference into a single direct output.

## The Chain-of-Thought Technique

Chain-of-thought prompting works by augmenting the few-shot examples in the prompt with explicit intermediate reasoning steps written in natural language. Instead of showing only question-answer pairs, the prompt shows question, intermediate reasoning trace, and then answer. The model, when given a new question, is expected to generate a similar reasoning trace before producing its answer.

The intermediate reasoning trace serves multiple functions. It forces the model to externalise each step of the reasoning process as a discrete token sequence. Each step can build on the previous steps, allowing the model to propagate information across reasoning stages rather than holding the entire computation in a compressed representation. Errors at any stage become visible in the generated text, making it possible to inspect where reasoning went wrong.

Critically, this approach redistributes the reasoning burden across many sequential generation steps. Instead of asking the model to compress a multi-step derivation into a single output token probability, the model can attribute each sub-conclusion to the tokens that support it. The error signal that would otherwise need to propagate backward through an opaque single-step prediction is instead divided across multiple generation steps, each of which has a clearer local objective.

## Backpropagation Through Reasoning Steps

From a learning perspective, chain-of-thought reasoning changes how intermediate computation steps contribute to the final prediction. In a standard answer-only setup, the model must learn to encode all intermediate reasoning implicitly in its weights. When the model is trained or evaluated on chain-of-thought examples, each intermediate reasoning step generates a sequence of tokens, and the loss is computed over those tokens as well as the final answer tokens.

This means the gradient signal flows backward through every token in the reasoning trace, not just the final answer. Each intermediate step receives its own error signal proportional to how well it predicted the next token in the reasoning chain. The model can therefore learn to produce better intermediate steps by adjusting parameters that influence those specific reasoning tokens, rather than relying on a single backward pass through an uninterpretable latent state.

This stands in contrast to the approach taken by symbolic planners, which maintain an explicit intermediate state that is fully interpretable but requires a predefined grammar. Chain-of-thought uses the model's own generation vocabulary as the reasoning language, requiring no external structure.

## Empirical Findings

The paper evaluates chain-of-thought prompting on three categories of benchmarks. For arithmetic reasoning (GSM8K, SVAMP, ASDiv, AQuA, MAWPS), chain-of-thought prompting with PaLM 540B achieves 58% on GSM8K, compared to 17% for standard prompting — a gain of 41 percentage points.

For commonsense reasoning (CommonsenseQA, StrategyQA, Date Understanding, Sports Understanding), the gains are smaller but consistent, as these tasks require fewer sequential inference steps.

For symbolic reasoning (last letter concatenation, coin flip), chain-of-thought enables near-perfect performance on tasks that are completely unsolvable with standard prompting at any scale.

The scale dependency is striking. Chain-of-thought prompting provides no benefit for models below approximately 100 billion parameters. For smaller models, the intermediate steps generated are not coherent reasoning traces but rather superficially similar strings that do not actually track the underlying computation. The ability to generate useful intermediate reasoning appears to be an emergent capability that arises only at sufficient scale.

## Comparison with ReAct

Chain-of-thought reasoning is a purely internal, linguistic process. The reasoning trace is generated entirely within the model's context window and does not interact with external tools or environments. Each reasoning step refers only to information available in the prompt and the previously generated tokens.

This is the defining limitation that subsequent work on grounded reasoning addressed. A model reasoning in a closed context can produce plausible-sounding chains that nonetheless contain factual errors, because it has no mechanism to verify intermediate conclusions against external facts.

## Implications for Reasoning Architecture

Chain-of-thought prompting establishes that breaking reasoning into sequential, verbalised steps is a practical strategy for improving multi-step inference in large language models. The technique demonstrates that the linear structure of a generated token sequence can serve as an effective working memory for complex reasoning, provided the model is large enough to generate coherent intermediate steps.

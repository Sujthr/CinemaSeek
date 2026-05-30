# LoRA: Low-Rank Adaptation of Large Language Models

**Authors:** Edward J. Hu, Yelong Shen, Phillip Wallis, Zeyuan Allen-Zhu, Yuanzhi Li, Shean Wang, Lu Wang, Weizhu Chen  
**Year:** 2021  
**Venue:** ICLR 2022  

## Abstract

This paper proposes Low-Rank Adaptation (LoRA), a technique for adapting large pre-trained language models to downstream tasks by training a small number of additional parameters while keeping the pre-trained weights frozen. LoRA decomposes the weight update for each target matrix into two low-rank matrices whose product approximates the full-rank update, reducing the number of trainable parameters by a factor of up to 10,000 while achieving comparable or superior performance to full fine-tuning across a range of NLP tasks.

## The Fine-Tuning Problem at Scale

Full fine-tuning of large pre-trained language models requires updating all model parameters, which number in the hundreds of billions for the largest models. This creates two practical problems.

The first is computational: storing the optimizer state for all parameters during training requires memory proportional to the number of parameters times the optimizer's state size. For Adam, this is three times the parameter count (gradients, first moment, second moment), making full fine-tuning of a 175 billion parameter model impractical on standard research hardware.

The second is deployment: if a base model must be fine-tuned separately for each downstream task, each task requires its own full copy of the model parameters. Serving multiple tasks simultaneously requires proportional storage and memory for each task-specific model. This makes per-task fine-tuning economically and logistically expensive at deployment scale.

## The Low-Rank Hypothesis

LoRA is motivated by a hypothesis about the structure of fine-tuning updates. When a large pre-trained model is adapted to a downstream task, the change in model weights has a low intrinsic dimensionality. That is, although the weight matrices are large (e.g., 768 × 768 or 12288 × 12288), the update ΔW that moves the pre-trained weights to the fine-tuned weights lies in a low-dimensional subspace.

This hypothesis is supported by prior work on the intrinsic dimensionality of objective landscapes, which showed that many fine-tuning tasks can be solved by optimising in a random subspace of dimension 100 to 1000, far smaller than the full parameter count.

If ΔW is approximately low-rank, it can be decomposed as ΔW ≈ BA, where B is a d × r matrix and A is an r × d' matrix, with r ≪ min(d, d'). The number of trainable parameters falls from d × d' to r × (d + d'). For a 768 × 768 matrix with rank 4, this is a reduction from 589,824 to 6,144 parameters — a factor of 96.

## Parameter-Efficient Gradient Distribution

The LoRA training procedure freezes all pre-trained weights and introduces the low-rank matrices A and B as new parameters alongside each target weight matrix. During the forward pass, the effective weight is W + BA, where W is the frozen pre-trained weight and BA is the low-rank adaptation. During the backward pass, gradients flow only to A and B, not to W.

This creates a structured gradient distribution. Instead of computing and storing a dense gradient for each large weight matrix, the optimiser computes gradients for only the low-rank factors. The rank r controls how many directions in the weight space can receive gradient updates. With rank 4, only 4 independent directions of the weight update matrix receive gradient information.

The implications for how the model adjusts to task-specific information are significant. The low-rank constraint forces the adaptation to concentrate its representational capacity in the directions most relevant to the downstream task. Rather than distributing small updates uniformly across the entire weight matrix, LoRA forces the updates into a compressed subspace where each update direction must be maximally informative.

This compression acts as an inductive bias. The model cannot waste gradient capacity on directions that are irrelevant to the task, because the rank budget limits the total number of independent directions that can be updated. Each of the r directions must carry signal. This is analogous to how sparse representations force the model to select the most relevant features rather than distributing weight across all available features equally.

From the perspective of how gradient information propagates back from task outputs to model parameters, LoRA changes the structure of this propagation. In full fine-tuning, every parameter receives an independent gradient signal whose magnitude reflects how much that parameter contributed to the loss. In LoRA, the gradient is projected onto the low-rank subspace defined by A and B. Parameters outside this subspace receive no gradient; parameters within it receive an amplified signal because the full loss gradient must be expressed through the limited rank-r basis.

## Merging Adapters at Inference

A practical advantage of LoRA is that the adaptation matrices can be merged into the original weight matrix after training: W_new = W + BA. This merged weight has exactly the same shape as the original weight, so no additional latency is added at inference time. Serving a LoRA-adapted model is identical to serving a full fine-tuned model from a computational perspective.

Multiple LoRA adapters can be maintained simultaneously — one per task — and swapped without storing multiple full-weight copies. The storage cost per adapter is proportional to r × (d + d') per target matrix, which for typical settings is 0.01% to 1% of the full model size.

## Empirical Results

On natural language generation tasks (E2E NLG, WebNLG, DART), LoRA with rank 4 applied to the query and value projection matrices of GPT-2 Large achieves comparable or superior performance to full fine-tuning while training only 0.35% of the parameters. On RoBERTa and GPT-3, similar gains are observed: LoRA matches or exceeds fine-tuned baselines including adapter layers and prefix tuning, with fewer trainable parameters than either alternative.

## Choosing Rank and Target Matrices

The paper's ablations show that applying LoRA to both query and value projection matrices (Wq and Wv) of the attention layers yields the best performance for a given parameter budget. Applying it to all four projection matrices (Wq, Wk, Wv, Wo) with a smaller rank per matrix does not consistently outperform the two-matrix strategy. Increasing rank beyond 4 to 8 yields diminishing returns for most tasks, consistent with the low intrinsic dimensionality hypothesis.

## Limitations

LoRA does not reduce training latency because the forward and backward passes still compute the full activations; only the optimizer step and gradient storage are reduced. For latency-critical training pipelines, additional techniques are required. LoRA also does not adapt the frozen weights themselves, which limits performance on tasks that require large departures from the pre-training distribution.

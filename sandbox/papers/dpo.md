# Direct Preference Optimization: Your Language Model is Secretly a Reward Model

**Authors:** Rafael Rafailov, Archit Sharma, Eric Mitchell, Stefano Ermon, Christopher D. Manning, Chelsea Finn  
**Year:** 2023  
**Venue:** NeurIPS 2023  

## Abstract

This paper presents Direct Preference Optimization (DPO), a stable, performant, and computationally lightweight algorithm for training language models to align with human preferences. Unlike existing methods based on reinforcement learning from human feedback (RLHF), DPO does not require training a separate reward model or running a reinforcement learning loop. Instead, it directly optimises a policy using a contrastive loss over preference pairs, which is equivalent to optimising the RLHF objective under a particular parameterisation.

## Background: RLHF and Its Costs

Reinforcement learning from human feedback has been the dominant paradigm for aligning large language models with human preferences. The standard RLHF pipeline consists of three stages. First, a supervised fine-tuned policy is trained on demonstration data. Second, a reward model is trained on human preference comparisons — pairs of outputs where a human annotator has indicated which is preferred. Third, the policy is fine-tuned using proximal policy optimisation (PPO) to maximise the reward model's predictions while staying close to the original supervised policy.

This pipeline has produced capable aligned models, but it carries substantial computational and engineering complexity. Training the reward model requires a separate training run on the preference data. Running PPO requires generating samples from the policy at each training step, scoring them with the reward model, and computing policy gradients — a process that consumes four to eight times more GPU memory than standard supervised training. The reward model and the policy must be maintained simultaneously during the PPO phase.

The instability of PPO training for large language models is a known practical challenge. Reward hacking — where the policy learns to produce outputs that score well under the reward model but are not actually preferred by humans — requires careful engineering of the KL divergence penalty and reward shaping to prevent. The shaping of the reward signal to produce stable, well-calibrated policy updates is an ongoing engineering burden throughout the PPO training phase.

## The DPO Reparameterisation

DPO observes that the optimal policy under the standard RLHF objective has a closed-form expression in terms of the reward function and the reference policy. Given a reward function r and a reference policy π_ref, the optimal policy under the KL-constrained RLHF objective is:

π*(y|x) ∝ π_ref(y|x) · exp(r(y,x) / β)

where β is the KL penalty coefficient. This can be rearranged to express the reward in terms of the optimal policy, the reference policy, and the partition function.

DPO substitutes this reward parameterisation into the Bradley-Terry preference model used to train the reward model. The resulting objective is a binary cross-entropy loss over preference pairs that depends only on the policy being trained and the reference policy — with no reward model appearing explicitly.

The practical consequence is that DPO can be trained with a single forward-backward pass over preference pairs, using the same infrastructure as standard supervised fine-tuning. No separate reward model needs to be trained. No PPO loop needs to run.

## Reward Shaping Without Explicit Rewards

A conceptually important aspect of DPO is that it achieves reward shaping implicitly through the contrastive loss. When a preference pair (y_w, y_l) is presented — where y_w is the preferred output and y_l is the dispreferred output — the DPO loss increases the log-probability of y_w relative to the reference policy and decreases the log-probability of y_l relative to the reference policy.

This contrastive adjustment shapes the policy's probability distribution to reflect the preference signal without ever computing an explicit reward. The shaping is local to each preference pair at training time, but the cumulative effect across the training dataset produces a global shift in the policy toward preferred behaviours.

The gradient of the DPO loss shows that updates are weighted by the degree to which the current policy is surprised by the preference. If the model already assigns higher probability to the preferred output, the gradient magnitude is small. If the model assigns higher probability to the dispreferred output, the gradient magnitude is large. This automatic weighting ensures that the reward signal is concentrated where the policy most needs correction.

From an error-correction perspective, the DPO loss functions like a distributed preference signal. Each training example contributes a gradient that adjusts the policy proportional to how far it is from the preference boundary. The shaping is not concentrated in a single scalar reward passed through a reinforcement learning estimator; it is distributed across the preference examples in the training batch, each of which contributes a local correction.

## Stability and Performance

Empirical results show that DPO matches or exceeds PPO-based RLHF on a range of alignment benchmarks while requiring substantially less compute. On sentiment control tasks, DPO achieves higher reward at a given KL divergence from the reference policy than PPO. On summarisation, DPO trained models are preferred by human annotators at rates comparable to PPO-trained models.

DPO training is also more stable than PPO training. Because no reinforcement learning estimator is used, there is no reward hacking, no need for reward model regularisation, and no PPO clipping to tune. The loss surface is smooth and the training dynamics are similar to those of standard supervised fine-tuning.

## Limitations and Extensions

DPO assumes that preference pairs are drawn independently from a fixed distribution, which may not capture the sequential nature of multi-turn conversations. Extensions such as RAFT and IPO address cases where the preference distribution depends on the policy.

DPO also requires paired preference data, whereas some alignment settings produce only scalar reward scores. Extensions that bridge this gap have been developed but involve trade-offs in the simplicity of the original formulation.

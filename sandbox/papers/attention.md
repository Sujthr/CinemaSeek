# Attention Is All You Need

**Authors:** Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszkoreit, Llion Jones, Aidan N. Gomez, Łukasz Kaiser, Illia Polosukhin  
**Year:** 2017  
**Venue:** NeurIPS 2017  

## Abstract

This paper introduces the Transformer, a novel sequence-to-sequence architecture built entirely on attention mechanisms, dispensing with recurrence and convolutions. Evaluated on English-to-German and English-to-French translation tasks, the Transformer achieves state-of-the-art results while training significantly faster than architectures based on recurrent or convolutional layers.

## The Problem with Recurrent Architectures

Prior to the Transformer, sequence modelling relied heavily on recurrent neural networks (RNNs), long short-term memory networks (LSTMs), and gated recurrent units (GRUs). These architectures process tokens sequentially — the hidden state at position t depends on the hidden state at position t−1. This sequential dependency creates two fundamental problems.

First, it prevents parallelisation during training. Because each step depends on the previous step, computation cannot be distributed across time steps within a single sequence. Long sequences therefore require long sequential computation chains, making training slow and difficult to scale.

Second, long-range dependencies are hard to learn. Information from early positions must pass through many intermediate states to influence later positions. During backpropagation, gradients must flow backward through each of those intermediate states, making it difficult for the network to adjust early weights in response to errors observed at later positions. This vanishing gradient problem limits the effective context window the model can exploit.

## Key Contribution 1: The Self-Attention Mechanism

The central innovation is scaled dot-product self-attention. Rather than propagating information through sequential hidden states, self-attention computes relationships between every pair of positions in a sequence in a single step. For a sequence of length n, each position attends to all n positions simultaneously, producing a weighted mixture of their value representations.

The attention weight between positions i and j is computed as the dot product of their query and key vectors, scaled by the square root of the dimension, then passed through a softmax. This produces a distribution over all positions, determining how much each position contributes to the output at position i.

Multi-head attention runs this operation h times in parallel with different learned projections, allowing the model to jointly attend to information from different representation subspaces at different positions. The outputs are concatenated and projected back to the original dimension.

Self-attention collapses the path length between any two positions to a constant O(1) number of operations, regardless of sequence length. This is in contrast to RNNs where the path length grows linearly with sequence distance. The shorter path makes it substantially easier for the model to learn dependencies between distant tokens.

## Key Contribution 2: Fully Parallel Computation Replacing Sequential Recurrence

The Transformer architecture eliminates recurrence entirely. The encoder and decoder each consist of stacked layers of multi-head self-attention followed by position-wise feed-forward networks. Because there is no sequential dependency between positions, all positions in a layer can be computed simultaneously.

This parallelism has a dramatic effect on training speed. The authors report that a single Transformer model for English-to-German translation can be trained to state-of-the-art quality in twelve hours on eight P100 GPUs. Equivalent RNN-based models required several days on similar hardware. The parallelism is not an engineering convenience — it is a direct consequence of replacing the sequential state-passing mechanism with attention.

The encoder processes all input positions in parallel within each layer. The decoder uses masked self-attention to prevent positions from attending to future positions during training, preserving the autoregressive property while still computing all positions in parallel across the training batch.

## Key Contribution 3: Positional Encoding

Because the Transformer contains no recurrence and no convolution, it has no inherent notion of token order. Without intervention, the model would treat the same set of tokens identically regardless of their sequence order.

The paper addresses this with positional encodings added to the input embeddings before the first encoder or decoder layer. The encodings use sine and cosine functions of different frequencies: for position pos and dimension i, the encoding is sin(pos / 10000^(2i/d_model)) for even dimensions and cos(pos / 10000^(2i/d_model)) for odd dimensions.

This encoding is deterministic and requires no learned parameters. The authors hypothesise that sinusoidal encodings allow the model to learn to attend by relative position, because for any fixed offset k, the encoding at position pos+k can be expressed as a linear function of the encoding at position pos.

## Results and Impact

On WMT 2014 English-to-German translation, the Transformer achieves 28.4 BLEU, surpassing all previously reported models including ensembles, at a fraction of the training cost. On WMT 2014 English-to-French, it reaches 41.0 BLEU with a single model.

Beyond machine translation, the attention mechanism introduced in this paper has become the foundation of virtually every large language model developed since 2018, including BERT, GPT, T5, and their successors. The architecture scales efficiently to billions of parameters and has proven effective across modalities including text, images, audio, and protein sequences.

## Limitations Noted

The authors note that self-attention is O(n²) in sequence length for both time and memory, because every pair of positions is compared. For very long sequences this becomes expensive. Subsequent work has addressed this with sparse attention, linear attention approximations, and sliding-window attention patterns.

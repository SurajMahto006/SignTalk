# SignTalk professor-PC training

This file is the handoff for a 1–2 hour training session on a computer with an NVIDIA GPU. The pose clips are already converted and stored in this repository. The professor’s computer does not need the Downloads dataset.

## What this project is

SignTalk is a video-call app. One person signs. The app names the sign, joins several signs into one line, sends that line to the other phone, and reads it aloud.

The current call still uses an older browser model. A newer model trained on this laptop reached about 65% on unseen INCLUDE word clips and then stopped improving. The older downloaded checkpoint still names the checked clips wrong, so do not use it for the result.

## What to train

Train the INCLUDE word signs only. Do not train the alphabet folder. That folder has only a few videos per letter.

The saved pose features are in:

`tools/isl-sidecar/experiment-results/combined_call_lstm/features.pt`

The script reads that cache first. It uses the NVIDIA GPU when CUDA is available. The result file for this run is:

`tools/isl-sidecar/experiment-results/combined_call_lstm/include_words_best.pt`

The matching names are in `include_words_labels.json` in the same folder.

## After the good result

1. Commit only `include_words_best.pt` and `include_words_labels.json`.
2. Push that commit.
3. On the home PC, pull the same branch.
4. Ask Cursor to export that checkpoint into `web/include/lstm_weights.bin` and `web/include/lstm_manifest.json`.

Until that export, the video call keeps using the old model. Training does not change the call by itself.

An accuracy near 80% means about 4 of 5 saved test signs are named correctly. In the call, each held sign can become a word. A pause starts the next word. The words are sent to the other phone as one line. A few pairs already become sentences such as “Hello, friend.” Other pairs stay in word order.

## Paste this prompt on the professor’s computer

Open the cloned SignTalk folder in Cursor and paste the block below.

```
Train SignTalk's INCLUDE word model on this computer. Read PROFESSOR_TRAINING.md and follow it.

1. Check Python with: py -3 -c "import torch; print(torch.__version__, torch.cuda.is_available())"
   The NVIDIA GPU must be visible. If CUDA is false, install the CUDA build of PyTorch for this Python, then check again. Do not train on the processor.
2. From the SignTalk folder, run:
   $env:PYTHONDONTWRITEBYTECODE='1'
   $env:PYTHONUNBUFFERED='1'
   $env:INCLUDE_ONLY='1'
   $env:EPOCH_COUNT='120'
   $env:BATCH_SIZE='32'
   $env:PATIENCE='30'
   py -3 .\tools\isl-sidecar\scripts\train_combined_signs.py
3. Use the cached file tools/isl-sidecar/experiment-results/combined_call_lstm/features.pt. Do not download a dataset. Do not look for the Downloads folder. Do not train the alphabet or number classes.
4. Leave the test clips out of training. The script already does that.
5. Stop when the script prints best_val. The saved model is include_words_best.pt. Do not overwrite the old OpenHands checkpoint. Do not edit the Flutter app. Do not export into web/include during this session.
6. Commit and push only:
   tools/isl-sidecar/experiment-results/combined_call_lstm/include_words_best.pt
   tools/isl-sidecar/experiment-results/combined_call_lstm/include_words_labels.json
7. In the final message, report the best include accuracy, the epoch, the GPU name, and the pushed commit.
```

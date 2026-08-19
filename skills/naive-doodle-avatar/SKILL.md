---
name: naive-doodle-avatar
description: Transform one uploaded portrait into one matching naive-doodle avatar image. Keep the same person, preserve key identity cues, and render in a childlike fashion-doodle style.
metadata:
  version: 3.0.0
  category: image
  model: gpt-image-2
---

# Naive Doodle Avatar — single-image version

## Purpose
Convert **one uploaded image** into **one corresponding output image** in a naive doodle / fashion-chibi style.

This skill is for **single-image transformation**, not for generating multiple variations by default.

## Trigger
Use this skill when the user asks for:
- turn this photo into a doodle avatar;
- make this portrait into a cute hand-drawn profile image;
- convert this person into a naive doodle / fashion chibi illustration;
- stylize this uploaded image while keeping the same person.

Do not use this skill for:
- photorealistic retouching;
- multi-image avatar sheets unless the user explicitly asks;
- 3D character generation;
- polished anime rendering;
- unrelated character invention when a real photo is provided.

## Required input
- One uploaded portrait or person image.

Best results:
- face clearly visible;
- simple or moderately clean framing;
- single subject preferred.

## Default behavior
Given one uploaded image, generate:
- **one output image**;
- same person / same recognizable identity;
- bust or headshot composition unless the user requests otherwise;
- clean light background;
- naive doodle / fashion-chibi stylization.

## Core rules

### 1) Preserve identity
Keep the same person. Preserve the most recognizable visible traits, especially:
- hair silhouette and parting;
- face shape;
- glasses if present;
- major accessories if present;
- clothing family and dominant colors when visible;
- overall vibe / expression.

### 2) Apply style
Render the person as:
- naive childlike doodle;
- fashion-forward chibi portrait;
- oversized head with simplified body if body is visible;
- rough marker / dry-brush contour lines;
- slightly uneven hand-drawn edges;
- restrained watercolor or gouache-like fills;
- flat graphic hair shapes;
- clean negative space;
- charming imperfection.

### 3) Keep the output simple
By default, produce **one** clean avatar image.
Do not make a grid, collage, contact sheet, or multi-panel layout unless the user explicitly asks.

### 4) Strong negatives
Avoid:
- photorealistic skin texture;
- glossy 3D rendering;
- Pixar-like appearance;
- polished anime conventions;
- overly detailed eyes or eyelashes;
- dramatic cinematic lighting;
- cluttered scenery;
- text, captions, labels, watermarks, signatures;
- identity drift.

## Execution instruction
When the user uploads an image, use that uploaded image as the main reference and generate one stylized output image using the prompt template in `references/single-image.md`.

If the result is too realistic, too anime, too 3D, or no longer looks like the same person, retry once using the relevant correction from `references/retry.md`.

## Output
Return the generated image first.
Optionally offer small follow-up adjustments such as:
- more like the person;
- rougher brushwork;
- cleaner background;
- stronger doodle feeling;
- different crop.

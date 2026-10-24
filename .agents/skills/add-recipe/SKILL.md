---
name: add-recipe
description: >-
  Use this skill when adding, modifying, or reviewing recipes in this Hugo recipes repository.
  Covers creating templates with Hugo archetypes, formatting front matter and shortcodes,
  culinary sanity checks, typo validation, and testing with Hugo commands.
---

# Recipe Management Workflow

This skill outlines the standard workflow for adding, modifying, and verifying recipes in this Hugo repository.

## 1. Creating a Recipe Template

Always use the Hugo CLI to generate the template so the archetype is respected:

```bash
hugo new <recipe-slug>.md
```

- `<recipe-slug>.md` must be lowercase and hyphen-separated (e.g., `garlic-sesame-turkey-bowl.md`).
- This automatically creates the file under `content/<recipe-slug>.md`.

---

## 2. Front Matter Specifications

The front matter must adhere to the following schema:

```yaml
---
title: "Recipe Title"
date: <TIMESTAMP_FROM_HUGO_NEW>
draft: false
serves: 4
total_time_to_make: 35
time_to_prepare: 10
time_to_cook: 25
tags:
- gluten-free
meal-types:
- dinner
---
```

### Guidelines:
- **`serves`**, **`total_time_to_make`**, **`time_to_prepare`**, **`time_to_cook`**:
  - Always use plain integers (minutes for time values). Do not append "min" or "minutes" in the front matter, as the template handles rendering.
- **`meal-types`**:
  - Valid meal types in this repo: `dinner`, `lunch`, `breakfast`, `dessert`, `snack`, `side`, `appetizer`, `brunch`.
- **`tags`**:
  - Common tags in this repo: `gluten-free`, `instant-pot`, `leftovers`, `soup`, `salad`, `sauce`, `vegan`, `crock-pot`, `spice-blend`.

---

## 3. Recipe Content Structure & Shortcodes

Content is divided into two shortcodes: `{{% ingredients %}}` and `{{% instructions %}}`.

```markdown
{{% ingredients %}}
#### Subheading (optional, for multi-part dishes)
- 1 lb chicken thighs
- 2 TBSP olive oil
- 1 tsp salt

#### Sauce
- 1/4 cup coconut aminos
{{% /ingredients %}}

{{% instructions %}}
- Step 1
- Step 2
{{% /instructions %}}
```

### Formatting Conventions:
- **Ingredients Subheadings**: Use `#### Component Name` (e.g., `#### Chicken`, `#### White Sauce`, `#### Marinade`, `#### Dressing`, `#### Rice / Quinoa`) if the recipe has distinct parts. If simple, a single flat bullet list is fine.
- **Standard Abbreviations**:
  - `TBSP` for tablespoon (uppercase is standard in this repo)
  - `tsp` for teaspoon
  - `cup` / `cups`
  - `oz`
  - `lb` / `lbs`
  - `sriracha` (lowercase)
- **Instructions Format**:
  - Always use unordered markdown lists (`- `) instead of numbered steps (`1. `). The theme's HTML/CSS automatically styles instructions.

---

## 4. Culinary Sanity & Logic Checks

Before finalizing any recipe, review the culinary workflow:

1. **Ingredient Accounting**:
   - Check every ingredient in the list against the instructions. Ensure no seasonings, aromatics, garnishes, or oils are left out of the steps.
2. **Sauces & Dressings**:
   - When a sauce, dressing, or marinade has multiple ingredients, include an explicit step to whisk/combine them in a bowl before adding to the pan or assembling.
3. **Thickeners / Cornstarch Slurries**:
   - For creamy or broth-based sauces (~2 to 3.5 cups of liquid), standard thickening uses **1 to 2 TBSP cornstarch** dissolved as a slurry in cold milk or water.
   - Clarify that the sauce must be brought to a boil/simmer to activate the starch.
4. **Liquid Ratios & Grains**:
   - **Pressure Cooker / Instant Pot Rice/Quinoa**: Typically a **1:1 ratio** of grain to liquid (e.g., 2 cups dry rice to 2 cups broth) cooked 3–5 minutes at high pressure with a 10-minute natural release.
   - **Stovetop Rice**: Typically a **1.5:1 to 2:1 ratio** of liquid to grain.
5. **Cookware Clarification**:
   - Note specific vessels when appropriate (e.g., large stainless steel skillet, Dutch oven, baking sheet, pressure cooker).
6. **Pasta / Noodles**:
   - Specify boiling water, cooking al dente (or slightly under if finishing in a simmering sauce), and draining before tossing with the sauce.

---

## 5. Spelling & Typo Prevention

Check for common culinary misspellings in submitted recipes:
- `turmeric` (not `tumeric`)
- `broccoli` (not `brocoli`)
- `hoisin` (not `hoison`)
- `separated` (not `separted`)
- `al dente` (not `aldente`)
- `crispy` (not `cripsy`)
- `with` (not `witih`)
- `lactose-free` (hyphenated)
- `bite-size pieces` (hyphenated)

---

## 6. Hugo Build & Verification

After editing or adding recipes, verify the Hugo site build:

```bash
hugo --minify
```

1. Ensure the command exits with code 0 and reports no errors or warnings.
2. Verify the generated output in `public/<recipe-slug>/index.html` to confirm:
   - Front matter values (Serves, Prep Time, Cook Time, Total Time) render cleanly.
   - Ingredients appear in `<div class="ingredients col-md-4 col-sm-12">`.
   - Instructions appear in `<div class="col-md-7 offset-md-1 col-sm-12 instructions">`.
   - The recipe appears in relevant taxonomy pages (`public/tags/...` and `public/meal-types/...`).

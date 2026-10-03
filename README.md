# Baby Names Project

This is the Social Security Administration's well-known baby names dataset, one of the most popular public datasets for teaching data analysis. Here's the rundown.

## What it is

It contains four fields (name, year of birth, sex, and count) drawn from a 100 percent sample of Social Security card applications from 1880 onward. It covers the United States from 1880 through the end of 2025, is updated annually, and was last refreshed on May 8, 2026. It's released under a CC0 public domain license, so you can use it freely.

Source: [SSA — Baby Names from Social Security Card Applications - National Data](https://catalog.data.gov/dataset/baby-names-from-social-security-card-applications-national-data)

## How to get it

There are two resources: the SSA's interactive [Popular Baby Names website](https://www.ssa.gov/oact/babynames) and a downloadable ZIP file at [ssa.gov/oact/babynames/names.zip](https://www.ssa.gov/oact/babynames/names.zip). The ZIP holds one small text file per year (named like `yob2025.txt`), each a headerless CSV with rows like `Olivia,F,14000`, sorted by sex and then by count. That makes it easy to load and stack in pandas or R.

## Origins

The project traces back to a 1997 actuarial note by SSA actuary Michael W. Shackleford on the distribution of given names among Social Security number holders, which gave birth to the website. See [SSA background](https://www.ssa.gov/oact/babynames/background.html).

## Caveats worth knowing before you analyze it

These matter a lot for interpretation:

- **The early years are undercounted.** Many people born before 1937 never applied for a Social Security card, so their names aren't included. Raw counts from 1880–1930s aren't comparable to modern counts, so use proportions within each year instead.
- **Rare names are hidden.** To protect privacy, names with fewer than 5 occurrences are excluded, so the long tail of very unusual names is missing.
- **The data is raw and unedited.** The sex associated with a name may be incorrect, and entries like "Unknown" and "Baby" aren't removed. Hyphens and spaces are stripped, so Julie-Anne, Julie Anne, and Julieanne all count as one entry.
- **Spellings aren't merged.** Caitlin, Caitlyn, Kaitlin, Kaitlyn, Katelyn and similar variants are each counted and ranked separately, which can make a name family look less popular than it really is.
- **Geography is limited.** The national data covers only the 50 states and DC; U.S. territories are reported separately and aren't included. The SSA also publishes a separate state-level dataset if you want regional breakdowns.

(Source for caveats: [SSA background](https://www.ssa.gov/oact/babynames/background.html))

## What people do with it

Common projects include:

- Tracking a name's popularity over time
- Spotting names that rose with pop culture (movie or TV characters)
- Measuring how names shift between boys and girls over decades
- Estimating someone's likely age from their first name
- Measuring name diversity (the top names cover a much smaller share of babies today than in the 1950s)

## Project files

- `name_lenght.sql`, `top_names.sql`, `new_names.sql`: BigQuery analysis queries (table `example-501820.babynames.names_all`).
- `classify_names.py`: LangChain + Claude script that tags names as `nature` / `religion` / `other` and saves them to `babynames.name_themes`, so theme queries don't need hard-coded name lists. Needs `ANTHROPIC_API_KEY` set in your environment (never commit it).
- `exploratory_queries.sql`: 10 starter queries to adapt in the BigQuery console (name rank over time, concentration, gender-neutral and gender-flipped names, biggest jumps, theme shares, first-letter trends).

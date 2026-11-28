# GENESIS Skills Passport v2

## Sources
NICE Components 2.2.0 (2026-04-28): https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center/nice-framework-current-versions
ENISA ECSF role profiles: https://www.enisa.europa.eu/sites/default/files/publications/European%20Cybersecurity%20Skills%20Framework%20Role%20Profiles.pdf

## Requirements
Independent NICE and ECSF views. Import complete official NICE roles, categories, competency areas, TKS and authoritative relationship records; support legacy ability statements separately, with version labels. ENISA: all 12 profiles, tasks, knowledge, skills, deliverables and source-listed e-CF codes and levels. Internal ECSF item IDs explicitly labeled GENESIS. Preserve source English text where licensing permits, Polish translation and provenance. No invented official IDs.

## Data model
Versioned catalogs, roles, elements, role-element relations, operation-element mappings with exact stage, assessment method, evidence and reviewer; member assessment evidence, hint exposure before stage completion, resource links with provider, language, cost, date checked. Separate catalog coverage, learner demonstrated coverage and assisted practice. Deduplicate by element ID, use full role membership denominator and display uncovered items. Missing mapping is not evidence of missing ability. Reading full review before completion must mark attempt as instructional. RLS for private learner records; server-verified completion only, no client self-award. Existing historical results with unknown assistance labeled unknown.

## UI
NICE and ENISA independent pages with full role catalog including zero coverage; search/filter by role, element kind, status, code. Role detail lists exact items and missing items, recommended available operations, planned operations, future external resources. No official certification claims. Separate learning center: choose target role, prioritize gaps and compare free/paid resources. PDF export later.

## Acceptance
Import checks: counts from source manifest, unique IDs, valid relationships, source versions. Validate OP001–014 mappings against actual observable assessments; distinguish exposure from demonstrated knowledge/skill. Test independent and assisted results, repeated element deduplication, user isolation, role denominator, zero states, missing mappings and mobile UI. Do not label catalog complete before source import and validation.

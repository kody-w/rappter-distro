# Using This Repo as a Template

This is the RAPP species root. Variants spawned directly from here become **direct children of rapp** in the lineage tree — siblings of `wildhaven-ai-homes-twin` and any other top-level variant.

## When to template from RAPP (vs. a downstream variant)

Template from RAPP when:
- Your variant is structurally different from any existing variant pattern (not a Pre-Founder twin, not a memorial twin, etc.) — you want the full RAPP layout to remix from scratch.
- Your variant is a *platform fork* — you intend to maintain a parallel evolution of the brainstem itself.
- You want `parent_rappid` to point at rapp directly, with no intermediate ancestor.

Template from a downstream (e.g., [wildhaven-ai-homes-twin](https://github.com/kody-w/wildhaven-ai-homes-twin)) when:
- You want to inherit a specific pattern (Pre-Founder twin, etc.) — the downstream's installer scaffolds that pattern's content for you.
- Your variant is a sibling of the downstream's existing variants. The chain becomes `you → downstream → rapp`.

## Single-parent rule

Per [Constitution Article XXXIV](./CONSTITUTION.md), every variant's `parent_rappid` declares the repo whose code it inherited at template time — no exceptions. There is no "claim a different ancestor" flag. If you template from RAPP, your parent is rapp; if you template from wildhaven, your parent is wildhaven.

This is enforced by `rapp_brainstem/utils/lineage_check.py`, which the brainstem boot guard (`rapp_brainstem/boot.py`) calls before serving. An uninitialized template clone — one whose `rappid.json` still carries the parent's rappid but whose git remote points elsewhere — refuses to boot until `installer/initialize-variant.sh` regenerates the rappid.

## The flow

### 1. Click "Use this template"

On the RAPP GitHub page, click **Use this template** → **Create a new repository**, choose owner / name / visibility, and create.

### 2. Clone your new repo

```bash
git clone https://github.com/<your-user>/<your-repo>.git
cd <your-repo>
```

### 3. Run the initialization script

```bash
bash installer/initialize-variant.sh
```

This will:

1. Run `rapp_brainstem/utils/lineage_check.py` to verify this is a fresh template clone (refuses to run on the species root itself, or on an already-initialized variant without confirmation).
2. Generate a fresh rappid (UUIDv4).
3. Rewrite `rappid.json` with `parent_rappid = 0b635450-c042-49fb-b4b1-bdb571044dec` (rapp's species root) and `parent_repo = https://github.com/kody-w/RAPP.git`.
4. Record the parent commit.

### 4. Customize

The variant inherits the full RAPP layout. Strip whatever you don't need (`rapp_swarm`, `pages`, etc.) and edit `README.md` / `CLAUDE.md` to describe your variant.

### 5. Optional: become a template yourself

```bash
gh repo edit <your-user>/<your-repo> --template=true
```

Then add your rappid + canonical owner/repo to `KNOWN_TEMPLATE_REPOS` in `rapp_brainstem/utils/lineage_check.py` so descendants of your variant get the same uninitialized-clone detection.

## See also

- [`rappid.json`](./rappid.json) — the species-root anchor.
- [`rapp_brainstem/utils/lineage_check.py`](./rapp_brainstem/utils/lineage_check.py) — the boot guard.
- [`installer/initialize-variant.sh`](./installer/initialize-variant.sh) — this template's variant-init script.
- [Constitution Article XXXIV](./CONSTITUTION.md) — variant lineage protocol.

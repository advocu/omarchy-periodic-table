# Autonomous Publishing Instructions for Grok Bot (or Antigravity `agy`)

This bundle contains two folders:
1. **`omarchy-periodic-table/`** — The exact root files for the public GitHub repository (`manifest.json`, `BarWidget.qml`, `Panel.qml`, `BohrCanvas.qml`, `ElementsData.js`, `preview.png`, `README.md`, `LICENSE`).
2. **`publishing_kit/`** — This agentic runbook, the pre-formatted Marketplace submission issue (`SUBMISSION_ISSUE_BODY.md`), and the automated `publish-with-gh.sh` script.

---

## Option A: Copy-Paste Prompt for Grok Bot

Attach `omarchy-periodic-table.zip` to Grok Bot and paste this exact prompt:

> **Prompt for Grok Bot:**
> "I have attached `omarchy-periodic-table.zip`, which contains an Omarchy Quattro top-bar plugin in the `omarchy-periodic-table/` folder and a marketplace submission template in `publishing_kit/SUBMISSION_ISSUE_BODY.md`.
>
> Please perform the following end-to-end publishing workflow using my saved GitHub credentials:
> 1. Inspect my GitHub username (`<GITHUB_USERNAME>`). In `omarchy-periodic-table/manifest.json`, `omarchy-periodic-table/BarWidget.qml`, `omarchy-periodic-table/Panel.qml`, and `omarchy-periodic-table/README.md`, replace `advocatus` in `io.github.advocatus.periodic-table` and the repo URL with my actual lowercase GitHub username (`io.github.<username>.periodic-table`).
> 2. Create a new **public** GitHub repository named `omarchy-periodic-table` at `https://github.com/<username>/omarchy-periodic-table`.
> 3. Commit and push **only** the root files inside `omarchy-periodic-table/` (`manifest.json`, `BarWidget.qml`, `Panel.qml`, `BohrCanvas.qml`, `ElementsData.js`, `preview.png`, `README.md`, `LICENSE`) to the root of the `main` branch (do not push the `publishing_kit/` helper folder into the plugin repo).
> 4. Open `publishing_kit/SUBMISSION_ISSUE_BODY.md`, replace `GITHUB_USERNAME` with my actual GitHub username, preserve all 6 `###` headings and all 5 checked `[x]` checklist items verbatim, and create a new GitHub Issue on `https://github.com/omacom/omarchy-plugin-marketplace/issues` with the exact title:
>    `[Plugin]: Periodic Table`
> 5. Monitor the issue for the automated marketplace validation and Security Baseline V3 bot comment. If any formatting or manifest adjustment is requested, update the repo, push the commit, and reply on the issue until validation passes."

---

## Option B: Run Locally on Omarchy via `agy` or Terminal (`publish-with-gh.sh`)

If you want to test the plugin on your Omarchy top bar first and publish straight from your machine:

```bash
# 1. Unzip the bundle in ~/Work
unzip omarchy-periodic-table.zip -d ~/Work/periodic-table-bundle
cd ~/Work/periodic-table-bundle

# 2. Run the automated local validator + GitHub publisher script
chmod +x publishing_kit/publish-with-gh.sh
./publishing_kit/publish-with-gh.sh YOUR_GITHUB_USERNAME
```

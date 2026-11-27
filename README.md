# NEO Fundamentals lab files

Follow-along lab files, diagrams, and scripts for the **NEO Fundamentals** video lessons.

Addresses in every pack are private lab ranges (RFC 1918) only. Names are fictional. These files are for learning, not a real network.

## Start here: the Containerlab labs (current)

Every current lesson lab is in the [`containerlab/`](containerlab/) folder, with a step-by-step beginner guide (`containerlab/NEO-Containerlab-Beginner-Guide.pdf`).

1. On this page, click the green **Code** button, then **Download ZIP**. You get `labs-main.zip` with every lab in it.
2. Extract it to your Home folder. It unpacks to `labs-main`.
3. In VS Code, open the folder `~/labs-main/containerlab` (**File > Open Folder**).
4. In the Containerlab panel, right-click your lesson's lab file, for example `labs/ebgp-two-sites/ebgp-two-sites.clab.yml`, and click **Deploy**.

The kit version, lesson index and changelog are in [`containerlab/README.md`](containerlab/README.md). The first deploy downloads free router images from the internet; after that, lab traffic stays inside your VM.

## Legacy: Getting Started free-VM kit (older version of lesson 01)

This is the earlier kit for the first version of **Build Your Own NEO Lab** (a free VM, Wireshark and a small check lab). It does **not** contain the Containerlab labs. If you're following the current videos, use the green **Code > Download ZIP** above instead.

| # | Title | Pack | Zip |
|---|---|---|---|
| 01 (legacy) | Build Your Own NEO Lab: Wireshark, a Free VM, and a Check Lab | [getting-started/01_build-your-own-neo-lab/](getting-started/01_build-your-own-neo-lab/) | [01_build-your-own-neo-lab.zip](getting-started/01_build-your-own-neo-lab.zip) (legacy) |

- Folder: https://github.com/NEO-Fundamentals/labs/tree/main/getting-started/01_build-your-own-neo-lab
- Legacy zip (direct download): https://github.com/NEO-Fundamentals/labs/raw/main/getting-started/01_build-your-own-neo-lab.zip

The legacy zip SHA-256 is `244822b5e8b9422977682677e0f77a221062aac6f76dc93c0c3e90f5f8ed2e5d`. See `MANIFEST.tsv` for its file list and sanitize result.

## License

The lab files, captures, and diagrams in this repository are licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Attribution: NEO Fundamentals. They are provided as-is for learning.

See [LICENSE](LICENSE) for the full legal text.

# carbonhv-guest-grapheneos

CI that builds the **CarbonHV GrapheneOS-derived virtual-device guest** (CVD1: ARM64, virtio-gpu,
virtio-input, virtio-net, virtio-blk, virtio-snd, vsock) and publishes the bundle by hash.

This image is a CarbonHV-maintained port derived from GrapheneOS sources. It is **not** an
official GrapheneOS device target and inherits no GrapheneOS hardware-security claim. That wording
is not decoration: it is the bundle's identity, and the workflow records it in provenance so a
downstream consumer cannot lose it.

## The recipe is not duplicated here

`guest/android/build.sh`, the device overlay and the kernel fragments live in
[CarbonHV](https://github.com/itsrhotaudevvy/CarbonHV). This repository only *runs* them: it checks
out CarbonHV at a pinned commit, sets the build environment, and publishes what came out. One
source of truth, no drift, and the pin is visible in every run's provenance.

## Runner requirements, stated plainly

| Resource | Requirement | Why |
| --- | --- | --- |
| Disk | **≈400 GB free** | AOSP/GrapheneOS sync plus object files and images |
| RAM | **≥32 GB** (64 GB recommended) | Soong, ninja and the dex2oat/boot-image steps |
| CPUs | ≥8 | `m -j8`; less works but a full build runs for many hours |
| OS | Linux x86_64 | `guest/android/build.sh` refuses anything else, by design |

A standard GitHub-hosted runner (`ubuntu-24.04`: 4 vCPU, 16 GB RAM, ~70 GB free) **cannot** do
this. So the workflow:

* `preflight` measures disk, RAM and CPUs on whatever runner it was given, prints the table above
  and **fails** if the runner cannot do the job. It does not start a six-hour build to find out;
* `build` runs only when preflight says the runner is sufficient, on
  `vars.CARBONHV_BUILDER_LABEL` when set (a self-hosted or larger runner) and on `ubuntu-24.04`
  otherwise, so the preflight failure message is what you see by default.

Set the label once you have a capable machine:

```
gh variable set CARBONHV_BUILDER_LABEL --repo itsrhotaudevvy/carbonhv-guest-grapheneos \
    --body '["self-hosted","linux","x64","carbonhv-builder"]'
```

## How to run it

```
gh workflow run build.yml -f carbonhv_ref=main
```

Inputs: `carbonhv_ref` (the CarbonHV commit whose recipe to follow), `graphene_ref` (the GrapheneOS
manifest branch/tag), `target` (the CVD1 product), `jobs` (ninja parallelism).

Output: a `bundle.toml` with real hashes, `boot.img`, `system.img`, the prebuilt kernel config that
`carbonctl guest kernel-config` accepted, and `source-manifest.xml` (`repo manifest -r`) — the only
honest way to say which sources produced the image.

## Status

* Recipe: present in CarbonHV, kernel contract enforced by `carbonctl guest kernel-config android`.
* Image: **not built yet.** No run has had a runner with 400 GB of disk, so the workflow has only
  ever produced preflight reports. When it does build, the report goes in CarbonHV under
  `qualification/emu/reports/` — not here.

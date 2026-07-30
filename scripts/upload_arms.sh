#!/bin/bash
# Upload one policy version per A/B arm.
#
# Every arm is the SAME source built through the restored nimby.lock; the only
# thing that differs between control and treatment is the secret env the arm
# carries. That is the cleanest form of this experiment -- one binary, one
# lever -- and it is why the control has to be uploaded as its own version
# rather than reused from a previous session: a head-to-head whose two sides
# share a policy_version_id is scored as a mirror and thrown away.
#
# Base config C0 is the v9-equivalent champion configuration on a correctly
# pinned build: the two aim fixes off, ARCRAID off (v9 has no arc raid), and
# every opt-in lever at its default off.
set -u
OUT=xp-requests/arms-v2.tsv
C0="--secret-env CTF_FIX_AIMBAND=0 --secret-env CTF_FIX_STAREBREAK=0 --secret-env CTF_LEVER_ARCRAID=0"

up() {  # up <arm> <image> <extra secret-env...>
  local arm="$1" img="$2"; shift 2
  local line
  line=$(coworld upload-policy "$img" -n jordan-ctf-candidate "$@" \
           --tag purpose=abv2 --tag arm="$arm" 2>&1 | tail -1)
  local ref="${line##*: }"
  printf '%s\t%s\t%s\n' "$arm" "$img" "$ref" | tee -a "$OUT"
}

# --- plain image (no -d:shoutIntel) -----------------------------------------
up arcraid    ctf-plain --secret-env CTF_FIX_AIMBAND=0 --secret-env CTF_FIX_STAREBREAK=0 --secret-env CTF_LEVER_ARCRAID=1
up aimband    ctf-plain --secret-env CTF_FIX_AIMBAND=1 --secret-env CTF_FIX_STAREBREAK=0 --secret-env CTF_LEVER_ARCRAID=0
up starebreak ctf-plain --secret-env CTF_FIX_AIMBAND=0 --secret-env CTF_FIX_STAREBREAK=1 --secret-env CTF_LEVER_ARCRAID=0
up nadeduck   ctf-plain $C0 --secret-env CTF_LEVER_NADEDUCK=1
up holdline   ctf-plain $C0 --secret-env CTF_LEVER_HOLDLINE=1
up hurtlook   ctf-plain $C0 --secret-env CTF_LEVER_HURTLOOK=1
up carriershy ctf-plain $C0 --secret-env CTF_LEVER_CARRIERSHY=1
up odds       ctf-plain $C0 --secret-env CTF_LEVER_ODDS=1
# CROSSFIRE and HOLDEVEN are both nested inside the CTF_LEVER_HOLDLINE branch
# (baseline.nim:3684). With HOLDLINE off they are unreachable, so their control
# is the holdline arm, not the plain control -- otherwise both sides of the
# head-to-head are byte-identical behaviour and the 80 episodes buy a
# guaranteed null.
up crossfire  ctf-plain $C0 --secret-env CTF_LEVER_HOLDLINE=1 --secret-env CTF_LEVER_CROSSFIRE=1
up holdeven   ctf-plain $C0 --secret-env CTF_LEVER_HOLDLINE=1 --secret-env CTF_LEVER_HOLDEVEN=1

# --- shoutIntel image -------------------------------------------------------
# CTF_LEVER_SHOUTSEEN and CTF_LEVER_SPAWNINTEL live inside `when
# defined(shoutIntel)` blocks; the plain build compiles them out entirely and
# says so ("declared but not used"). They can only be measured on this image.
up shoutctrl  ctf-shout $C0 --secret-env CTF_LEVER_SHOUTSEEN=0
up shoutseen  ctf-shout $C0 --secret-env CTF_LEVER_SHOUTSEEN=1
up shoutspawn ctf-shout $C0 --secret-env CTF_LEVER_SHOUTSEEN=1 --secret-env CTF_LEVER_SPAWNINTEL=1

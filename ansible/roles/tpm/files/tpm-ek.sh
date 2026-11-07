#!/usr/bin/env bash
# Managed by Ansible (labstack-infra), role tpm. Prints this host's TPM endorsement key as one JSON object.
# Prefers an EK certificate stored in NV (Proxmox vTPMs have one, signed by the node's swtpm local CA; many
# discrete TPMs too). Without one, the EK public key the TPM derives from its seed (tpm2_createek, a transient
# object that /dev/tpmrm0 flushes when the tool exits; nothing is written to the TPM).
set -euo pipefail
export TPM2TOOLS_TCTI="device:${TPM_DEVICE:-/dev/tpmrm0}"
tmp=$(mktemp -d /run/tpm-ek.XXXXXX)
trap 'rm -rf "$tmp"' EXIT

# NV holds the certificate padded to the index size: keep the DER object only
der_trim() {
  python3 - "$1" "$2" << 'PY'
import sys
b = open(sys.argv[1], "rb").read()
if len(b) < 4 or b[0] != 0x30:
    sys.exit(1)
n = b[1]
size = 2 + n if n < 0x80 else 2 + (n & 0x7F) + int.from_bytes(b[2:2 + (n & 0x7F)], "big")
open(sys.argv[2], "wb").write(b[:size])
PY
}


emit() { # source alg index pubkey_pem [cert_pem]
  python3 - "$@" << 'PY'
import hashlib, json, subprocess, sys
source, alg, index, pub = sys.argv[1:5]
cert = sys.argv[5] if len(sys.argv) > 5 else ""
der = subprocess.run(["openssl", "pkey", "-pubin", "-in", pub, "-outform", "DER"], check=True, capture_output=True).stdout
out = {"source": source, "alg": alg, "nv_index": index, "key_sha256": hashlib.sha256(der).hexdigest(),
       "public_key_pem": open(pub).read()}
if cert:
    def x(*a):
        return subprocess.run(["openssl", "x509", "-in", cert, "-noout", *a], check=True, capture_output=True, text=True).stdout.strip()
    out.update({"certificate_pem": open(cert).read(), "issuer": x("-issuer", "-nameopt", "RFC2253").removeprefix("issuer="),
                "not_after": x("-enddate").removeprefix("notAfter=")})
print(json.dumps(out))
PY
}

# EK certificate indices, preferred first: ECC P-384, ECC P-256, RSA 2048, RSA 3072 (TCG EK profile)
declare -A alg_of=([0x1c00016]=ecc-p384 [0x1c0000a]=ecc-p256 [0x1c00002]=rsa-2048 [0x1c0001c]=rsa-3072)
defined=$(tpm2_nvreadpublic 2> /dev/null | sed -n 's/^\(0x[0-9a-fA-F]*\):.*/\1/p' | tr 'A-F' 'a-f' || true)
for idx in 0x1c00016 0x1c0000a 0x1c00002 0x1c0001c; do
  grep -qx "$idx" <<< "$defined" || continue
  tpm2_nvread "$idx" -o "$tmp/nv.bin" 2> /dev/null || continue
  der_trim "$tmp/nv.bin" "$tmp/ek.der" || continue
  openssl x509 -inform DER -in "$tmp/ek.der" -out "$tmp/ek.pem" 2> /dev/null || continue
  openssl x509 -in "$tmp/ek.pem" -pubkey -noout > "$tmp/ek.pub"
  emit nv-certificate "${alg_of[$idx]}" "$idx" "$tmp/ek.pub" "$tmp/ek.pem"
  exit 0
done

# No certificate in NV: derive the ECC EK public key, then RSA if the TPM refuses ECC
for g in ecc rsa; do
  if tpm2_createek -c "$tmp/ek.ctx" -G "$g" -u "$tmp/ek.pub" -f pem > /dev/null 2>&1; then
    emit createek "$g" "" "$tmp/ek.pub"
    exit 0
  fi
done
echo '{"error": "no EK certificate in NV and tpm2_createek failed"}'
exit 1

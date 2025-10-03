#!/usr/bin/env bash
set -euo pipefail

TALOSCFG="${1:-$HOME/vixens/talos/vixens-dev/talosconfig}"
OUTDIR="${2:-.}"

if [ ! -f "$TALOSCFG" ]; then
  echo "Fichier talosconfig introuvable: $TALOSCFG" >&2
  exit 2
fi

# create temporary files
CA_B64=$(grep "^[[:space:]]*ca:" "$TALOSCFG" | awk '{print $2}')
CRT_B64=$(grep "^[[:space:]]*crt:" "$TALOSCFG" | awk '{print $2}')
KEY_B64=$(grep "^[[:space:]]*key:" "$TALOSCFG" | awk '{print $2}')

# decode
echo "$CA_B64" | base64 -d > "$OUTDIR/ca.crt"
echo "$CRT_B64" | base64 -d > "$OUTDIR/client.crt"
echo "$KEY_B64" | base64 -d > "$OUTDIR/client.key"
chmod 600 "$OUTDIR/client.key"

# produce terraform.tfvars with PEM embedded
cat > "$OUTDIR/terraform.tfvars" <<TFVARS
cluster_endpoint = "https://192.168.111.160:6443"

talos_certs = {
  ca   = <<'EOT'
$(cat "$OUTDIR/ca.crt")
EOT
  cert = <<'EOT'
$(cat "$OUTDIR/client.crt")
EOT
  key  = <<'EOT'
$(cat "$OUTDIR/client.key")
EOT
}

# Exemple controlplanes — adapte si besoin
controlplanes = {
  obsy = {
    ip           = "192.168.111.162"
    hostname     = "obsy"
    install_disk = "/dev/sda"
    interfaces = [
      {
        interface = "enx00155d00cb0a"
        addresses = ["192.168.208.162/24"]
        gateway   = "192.168.208.1"
      },
      {
        interface = "enx00155d00cb10"
        addresses = ["192.168.111.162/24"]
        vip       = "192.168.111.160"
      }
    ]
  }
  onyx = {
    ip           = "192.168.111.164"
    hostname     = "onyx"
    install_disk = "/dev/sda"
    interfaces = [
      {
        interface = "enx00155d00cb09"
        addresses = ["192.168.208.164/24"]
        gateway   = "192.168.208.1"
      },
      {
        interface = "enx00155d00cb11"
        addresses = ["192.168.111.164/24"]
        vip       = "192.168.111.160"
      }
    ]
  }
  opale = {
    ip           = "192.168.111.163"
    hostname     = "opale"
    install_disk = "/dev/sda"
    interfaces = [
      {
        interface = "enx00155d00cb0b"
        addresses = ["192.168.208.163/24"]
        gateway   = "192.168.208.1"
      },
      {
        interface = "enx00155d00cb0f"
        addresses = ["192.168.111.163/24"]
        vip       = "192.168.111.160"
      }
    ]
  }
}
TFVARS

echo "Generated files in $OUTDIR:"
echo " - $OUTDIR/ca.crt"
echo " - $OUTDIR/client.crt"
echo " - $OUTDIR/client.key"
echo " - $OUTDIR/terraform.tfvars"

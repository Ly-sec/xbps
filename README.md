
# void-repo — Custom Void Linux repository

This is a minimal overlay repository for Void Linux custom packages and selected upstream overrides.


## Installation

1. **Add the repository**

```sh
echo "repository=https://xbps.lysec.dev/" | sudo tee /etc/xbps.d/20-lysec.conf
```

2. **Sync and import the key**

```sh
sudo xbps-install -S
```

XBPS will ask to import our RSA key. Confirm the fingerprint:

Signed by: Ly-sec <void@lysec.dev>
Fingerprint: 02:7a:c5:f7:1d:02:cc:84:3a:88:a0:64:7f:34:f1:71:3d:77:d1:ff:c2:4a:cd:0b:44:fa:b5:34:68:01:ac:69

## About package overrides

Some packages in this repository override upstream Void Linux packages with custom versions or patches. All custom templates are in the `pkgs/` directory. See the template files for details on each override.

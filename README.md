# miharp-ovlens

Installs [ovlens](https://github.com/miharp/ovlens) on an OpenVox server and
keeps the documentation for the deployed Puppet code up to date. Pre-release.

ovlens runs openvox-strings over every module in an environment and serves the
result to AI assistants through a read-only MCP server. This module:

- installs the `ovlens` package from the harpworks repository
- regenerates the documentation from a systemd timer
- optionally adds an account that can only run the MCP server over SSH

## Usage

Document every environment, every five minutes:

```puppet
include ovlens
```

A run with nothing to do is cheap: ovlens only parses modules whose files have
changed.

Pin a version and name the environments:

```puppet
class { 'ovlens':
  package_ensure => '0.1.0',
  environments   => ['production', 'staging'],
}
```

### Where the package comes from

By default the module configures the
[harpworks repository](https://packages.harpworks.org) and installs the
`ovlens` rpm or deb from it. The repository's metadata is signed, and the
module ships the public key. The package carries its own gems and depends only
on `openvox-agent`, so installing it downloads nothing else.

On a node where the codavox module already manages that repository, leave it
to codavox:

```puppet
class { 'ovlens':
  repo_manage => false,
}
```

For a mirror of the repository, set `repo_baseurl`. For a server with no
repository at all, copy the package over and install the file:

```puppet
class { 'ovlens':
  package_source => '/opt/packages/ovlens_0.1.0_linux_noarch.rpm',
}
```

### Running it from the deploy instead

To generate right after each deploy, turn the timer off and call ovlens from
the deploy tool. For r10k:

```puppet
class { 'ovlens':
  generate_ensure => 'absent',
}
```

```yaml
postrun: ['/usr/bin/ovlens', 'generate', '$modifiedenvs']
```

The module does not edit `r10k.yaml`, because another module usually owns it.

### Hiera data

With ovlens 0.3.0 or later, the timer can index each environment's Hiera data
too, for ovlens's Hiera tools:

```puppet
class { 'ovlens':
  hiera       => true,
  hiera_masks => ['*ldap*'],
}
```

Values are masked before they are written, but only eyaml values, private
keys and keys named like `*password*` or `*token*`. `hiera_masks` adds name
patterns. Anyone who can read `docs_dir` can read the rest. Setting `hiera`
back to false removes the indexed data on the next run. A deploy that runs
`ovlens generate` itself must pass `--hiera`, or it removes the data.

### MCP access over SSH

```puppet
class { 'ovlens':
  mcp_manage   => true,
  mcp_ssh_keys => {
    'alice' => { 'type' => 'ssh-ed25519', 'key' => 'AAAAC3NzaC1lZDI1NTE5AAAA...' },
  },
}
```

This creates a system account, `ovlens`, with no password. Each key is locked
to the MCP server with a forced command and `restrict`, so its holder can read
the documentation and nothing else. Keys not listed are removed from the
account.

An MCP client then starts the server with:

```json
{
  "mcpServers": {
    "ovlens": { "command": "ssh", "args": ["ovlens@openvox.example.com"] }
  }
}
```

## The timer's sandbox

`ovlens-generate.service` runs as root, so it sees the same settings and code
the server does, but with `ProtectSystem=strict` and only the documentation
directory writable.

## Reference

See [REFERENCE.md](REFERENCE.md).

## Limitations

- Needs systemd. Supported platforms are listed in `metadata.json`.
- The timer is managed with puppet/systemd, which includes that module's
  `systemd` class with whatever settings your site gives it.
- The default `docs_dir` is under `/opt/puppetlabs/server/data`, which exists
  only where openvox-server is installed. On any other node, set `docs_dir`.
- The codavox module declares the same repository resources. Both managing the
  repository on one node is a duplicate declaration; set `repo_manage` to
  false in one of them.

## Development

```shell
docker run --rm -v "$PWD:/repo" ghcr.io/voxpupuli/voxbox:8 validate lint check rubocop spec
docker run --rm -v "$PWD:/repo" ghcr.io/voxpupuli/voxbox:8 strings:generate:reference
```

## Tested

Applied on 2026-11-16 to an OpenVox 9 server (AlmaLinux 10, openvox-server
9.2.0) and an Ubuntu 24.04 agent, with ovlens 0.1.0 from the harpworks
repository:

- the package installs from the repository with its metadata signature checked
- the timer fires on activation and the sandboxed service documents every
  environment; a second run leaves them all unchanged
- a second apply changes nothing
- the MCP server answers over SSH as the `ovlens` account, and its key can
  neither run another command nor forward a port
- the service and the SSH login also work with SELinux enforcing
- `generate_ensure => 'absent'` removes the timer and keeps the documentation

Not yet tested on an OpenVox 8 server or on Debian.

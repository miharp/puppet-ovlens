# miharp-ovlens

Installs [ovlens](https://github.com/miharp/ovlens) on an OpenVox server and
keeps the documentation for the deployed Puppet code up to date. Pre-release.

ovlens runs openvox-strings over every module in an environment and serves the
result to AI assistants through a read-only MCP server. This module:

- installs the `ovlens` gem into the agent's Ruby, which already has OpenVox
- regenerates the documentation from a systemd timer
- optionally adds an account that can only run the MCP server over SSH

## Usage

Document every environment, every five minutes:

```puppet
include ovlens
```

A run with nothing to do is cheap: ovlens only parses modules whose files have
changed.

ovlens is not on RubyGems yet, so point the module at a gem file you have
copied to the server:

```puppet
class { 'ovlens':
  package_source => '/opt/ovlens/ovlens-0.1.0.gem',
  environments   => ['production', 'staging'],
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
postrun: ['/opt/puppetlabs/puppet/bin/ovlens', 'generate', '$modifiedenvs']
```

The module does not edit `r10k.yaml`, because another module usually owns it.

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
- Unit-tested only so far: the timer's sandbox and the SSH account have not
  been run on a real server.

## Development

```shell
docker run --rm -v "$PWD:/repo" ghcr.io/voxpupuli/voxbox:8 validate lint check rubocop spec
docker run --rm -v "$PWD:/repo" ghcr.io/voxpupuli/voxbox:8 strings:generate:reference
```

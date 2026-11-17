# @summary Installs ovlens and keeps the documentation for deployed OpenVox code up to date
#
# ovlens runs openvox-strings over every module in an OpenVox environment and
# serves the result to AI assistants through a read-only MCP server. On an
# OpenVox server this class installs the ovlens package, regenerates the
# documentation from a systemd timer, and can add an account that is only able
# to reach the MCP server over SSH.
#
# @example Document every environment
#   include ovlens
#
# @example Pin a version and document two environments
#   class { 'ovlens':
#     package_ensure => '0.1.0',
#     environments   => ['production', 'staging'],
#   }
#
# @example Install from a package file on a server that cannot reach the repository
#   class { 'ovlens':
#     package_source => '/opt/packages/ovlens_0.1.0_linux_noarch.rpm',
#   }
#
# @example Index Hiera data too, masking LDAP settings as well as secrets
#   class { 'ovlens':
#     hiera       => true,
#     hiera_masks => ['*ldap*'],
#   }
#
# @example Let one SSH key reach the MCP server
#   class { 'ovlens':
#     mcp_manage   => true,
#     mcp_ssh_keys => {
#       'alice' => { 'type' => 'ssh-ed25519', 'key' => 'AAAAC3NzaC1lZDI1NTE5AAAA...' },
#     },
#   }
#
# @param package_manage
#   Whether to install ovlens.
# @param package_name
#   The package to install.
# @param package_ensure
#   `installed`, `latest`, `absent` or a version.
# @param package_source
#   Install from this package file instead of from the repository, for a
#   server that cannot reach it. The repository is then not configured. The
#   package carries its own gems and depends only on openvox-agent, so a file
#   install needs nothing else.
# @param package_provider
#   The provider to use when `package_source` is set. Defaults to `rpm` or
#   `dpkg` by OS family.
# @param repo_manage
#   Whether to configure the harpworks package repository, which serves ovlens
#   and codavox. Set it to false on a node where the codavox module already
#   manages that repository. Ignored when `package_source` is set.
# @param repo_baseurl
#   Where the repository is served from. Change it only for a mirror.
# @param command
#   The installed `ovlens` command.
# @param docs_dir
#   Where the documentation is written and read. The default is under the
#   OpenVox server's data directory, which exists only where openvox-server
#   is installed; set it on any other node.
# @param generate_ensure
#   `present` regenerates the documentation from a timer. Use `absent` when
#   something else runs `ovlens generate`, such as an r10k `postrun` command.
# @param generate_interval
#   How long after one run the next starts, as a systemd time span. A run with
#   nothing to do is cheap, because unchanged modules are not parsed again.
# @param environments
#   The environments to document. Empty means all of them.
# @param environmentpath
#   The directory holding the environments. Defaults to the server's
#   `environmentpath` setting.
# @param hiera
#   Whether the timer also indexes each environment's Hiera data, for the
#   Hiera tools: where a key is set, which class parameter it feeds, and keys
#   for parameters that do not exist. Needs ovlens 0.3.0 or later. Values are
#   masked before they are written, but only eyaml values, private keys and
#   keys named like `*password*` or `*token*`; anyone who can read `docs_dir`
#   can read the rest. Turning it off removes the indexed data on the next
#   run. A deploy that runs `ovlens generate` itself must pass `--hiera`.
# @param hiera_masks
#   More patterns of key names whose values are masked, such as `*ldap*`, on
#   top of ovlens's own. Used only with `hiera`.
# @param mcp_manage
#   Whether to manage an account that can only run the MCP server over SSH.
# @param mcp_user
#   The name of that account.
# @param mcp_home
#   Its home directory.
# @param mcp_ssh_keys
#   The public keys allowed to log in as it, by a name of your choosing. Each
#   key is locked to the MCP server command. Keys not listed here are removed.
class ovlens (
  Boolean $package_manage                    = true,
  String[1] $package_name                    = 'ovlens',
  String[1] $package_ensure                  = 'installed',
  Optional[String[1]] $package_source        = undef,
  Optional[String[1]] $package_provider      = undef,
  Boolean $repo_manage                       = true,
  Stdlib::HTTPUrl $repo_baseurl              = 'https://packages.harpworks.org',
  Stdlib::Absolutepath $command              = '/usr/bin/ovlens',
  Stdlib::Absolutepath $docs_dir             = '/opt/puppetlabs/server/data/ovlens',
  Enum['present', 'absent'] $generate_ensure = 'present',
  Pattern[/\A\d+(s|sec|m|min|h|hr|d)\z/] $generate_interval = '5min',
  Array[Pattern[/\A[a-z0-9_]+\z/]] $environments = [],
  Optional[Stdlib::Absolutepath] $environmentpath = undef,
  Boolean $hiera                             = false,
  # No quotes, spaces, backslashes, % or $: systemd would read them.
  Array[Pattern[/\A[^\s"'\\%$]+\z/]] $hiera_masks = [],
  Boolean $mcp_manage                        = false,
  String[1] $mcp_user                        = 'ovlens',
  Stdlib::Absolutepath $mcp_home             = '/var/lib/ovlens',
  Hash[String[1], Struct[{ type => String[1], key => String[1] }]] $mcp_ssh_keys = {},
) {
  contain ovlens::install
  contain ovlens::generate
  contain ovlens::mcp

  # A package file needs no repository.
  if $package_manage and $repo_manage and !$package_source {
    contain ovlens::repo
    Class['ovlens::repo'] -> Class['ovlens::install']
  }

  Class['ovlens::install'] -> Class['ovlens::generate']
  Class['ovlens::install'] -> Class['ovlens::mcp']
}

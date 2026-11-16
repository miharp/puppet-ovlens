# @summary Installs ovlens and keeps the documentation for deployed OpenVox code up to date
#
# ovlens runs openvox-strings over every module in an OpenVox environment and
# serves the result to AI assistants through a read-only MCP server. On an
# OpenVox server this class installs the gem into the agent's Ruby, regenerates
# the documentation from a systemd timer, and can add an account that is only
# able to reach the MCP server over SSH.
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
# @example Install from a gem file on a server that cannot reach the repository
#   class { 'ovlens':
#     package_source          => '/opt/ovlens/ovlens-0.1.0.gem',
#     package_install_options => [],
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
#   The gem to install.
# @param package_ensure
#   `installed`, `absent` or a version. Avoid `latest`: the gem provider's
#   check for it also asks rubygems.org, whatever the source.
# @param package_provider
#   The package provider. `puppet_gem` installs into the agent's Ruby, which
#   already has OpenVox.
# @param package_source
#   The gem repository or gem file to install from. The default is the
#   harpworks repository, which carries ovlens and its dependencies. ovlens is
#   not published on RubyGems.
# @param package_install_options
#   Options for `gem install`. The default, `--clear-sources`, makes the
#   repository the only source, so a gem published on RubyGems under the same
#   name cannot be installed instead. Empty it when installing from a gem file,
#   so the dependencies can come from RubyGems.
# @param command
#   The installed `ovlens` command.
# @param docs_dir
#   Where the documentation is written and read.
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
  String[1] $package_provider                = 'puppet_gem',
  String[1] $package_source                  = 'https://packages.harpworks.org/gems',
  Array[String[1]] $package_install_options  = ['--clear-sources'],
  Stdlib::Absolutepath $command              = '/opt/puppetlabs/puppet/bin/ovlens',
  Stdlib::Absolutepath $docs_dir             = '/opt/puppetlabs/server/data/ovlens',
  Enum['present', 'absent'] $generate_ensure = 'present',
  Pattern[/\A\d+(s|sec|m|min|h|hr|d)\z/] $generate_interval = '5min',
  Array[Pattern[/\A[a-z0-9_]+\z/]] $environments = [],
  Optional[Stdlib::Absolutepath] $environmentpath = undef,
  Boolean $mcp_manage                        = false,
  String[1] $mcp_user                        = 'ovlens',
  Stdlib::Absolutepath $mcp_home             = '/var/lib/ovlens',
  Hash[String[1], Struct[{ type => String[1], key => String[1] }]] $mcp_ssh_keys = {},
) {
  contain ovlens::install
  contain ovlens::generate
  contain ovlens::mcp

  Class['ovlens::install'] -> Class['ovlens::generate']
  Class['ovlens::install'] -> Class['ovlens::mcp']
}

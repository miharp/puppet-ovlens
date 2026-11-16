# @summary Manages an account that can only run the MCP server over SSH
#
# @api private
class ovlens::mcp {
  assert_private()

  if $ovlens::mcp_manage {
    # No password is set, so the account can only be reached with one of the
    # keys below. It needs a real shell: sshd runs the forced command through it.
    user { $ovlens::mcp_user:
      ensure         => present,
      comment        => 'ovlens MCP access',
      system         => true,
      home           => $ovlens::mcp_home,
      managehome     => true,
      shell          => '/bin/sh',
      purge_ssh_keys => true,
    }

    # `restrict` turns off forwarding and terminals; `command` replaces whatever
    # the client asks to run, so a key holder can do nothing but talk to the
    # read-only MCP server.
    $options = [
      "command=\"${ovlens::command} mcp --docs-dir ${ovlens::docs_dir}\"",
      'restrict',
    ]

    $ovlens::mcp_ssh_keys.each |String[1] $key_name, Hash $key| {
      ssh_authorized_key { "ovlens-${key_name}":
        ensure  => present,
        user    => $ovlens::mcp_user,
        type    => $key['type'],
        key     => $key['key'],
        options => $options,
      }
    }
  }
}

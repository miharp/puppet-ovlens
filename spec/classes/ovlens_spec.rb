# frozen_string_literal: true

require 'spec_helper'

describe 'ovlens' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }

        it 'installs the gem into the agent Ruby, from the harpworks repository alone, before anything uses it' do
          is_expected.to contain_package('ovlens').with(
            ensure: 'installed', provider: 'puppet_gem',
            source: 'https://packages.harpworks.org/gems', install_options: ['--clear-sources']
          )
          is_expected.to contain_class('ovlens::install').that_comes_before('Class[ovlens::generate]')
          is_expected.to contain_class('ovlens::install').that_comes_before('Class[ovlens::mcp]')
        end

        it 'manages the documentation directory' do
          is_expected.to contain_file('/opt/puppetlabs/server/data/ovlens').with(ensure: 'directory', owner: 'root', mode: '0755')
        end

        it 'documents every environment from a timer' do
          is_expected.to contain_systemd__timer('ovlens-generate.timer').with(ensure: 'present', active: true, enable: true)
                                                                        .that_requires('File[/opt/puppetlabs/server/data/ovlens]')
          is_expected.to contain_systemd__timer('ovlens-generate.timer')
            .with_service_content(%r{^ExecStart=/opt/puppetlabs/puppet/bin/ovlens generate --docs-dir "/opt/puppetlabs/server/data/ovlens" --all$})
            .with_timer_content(%r{^OnUnitActiveSec=5min$})
        end

        it 'lets the generator write only its own directory' do
          is_expected.to contain_systemd__timer('ovlens-generate.timer')
            .with_service_content(%r{^ProtectSystem=strict$})
            .with_service_content(%r{^ReadWritePaths=/opt/puppetlabs/server/data/ovlens$})
            .with_service_content(%r{^NoNewPrivileges=true$})
        end

        it 'does not create the MCP account' do
          is_expected.not_to contain_user('ovlens')
          is_expected.to have_ssh_authorized_key_resource_count(0)
        end
      end

      context 'with named environments, an environmentpath and other paths' do
        let(:params) do
          {
            environments: %w[production staging],
            environmentpath: '/srv/code/environments',
            docs_dir: '/srv/ovlens docs',
            command: '/usr/local/bin/ovlens',
            generate_interval: '1h',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_systemd__timer('ovlens-generate.timer')
            .with_service_content(%r{^ExecStart=/usr/local/bin/ovlens generate --docs-dir "/srv/ovlens docs" --environmentpath "/srv/code/environments" production staging$})
            .with_service_content(%r{^ReadWritePaths=/srv/ovlens docs$})
            .with_timer_content(%r{^OnUnitActiveSec=1h$})
        end
      end

      context 'with a gem file and a pinned version' do
        let(:params) { { package_source: '/opt/ovlens/ovlens-0.1.0.gem', package_install_options: [], package_ensure: '0.1.0' } }

        it { is_expected.to contain_package('ovlens').with(ensure: '0.1.0', source: '/opt/ovlens/ovlens-0.1.0.gem', install_options: []) }
      end

      context 'with package_manage => false' do
        let(:params) { { package_manage: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('ovlens') }
      end

      context 'with generate_ensure => absent' do
        let(:params) { { generate_ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_systemd__timer('ovlens-generate.timer').with(ensure: 'absent', active: false, enable: false) }
        it { is_expected.to contain_file('/opt/puppetlabs/server/data/ovlens').with_ensure('directory') }
      end

      context 'with the MCP account' do
        let(:params) do
          {
            mcp_manage: true,
            mcp_ssh_keys: {
              'alice' => { 'type' => 'ssh-ed25519', 'key' => 'AAAAC3NzaC1lZDI1NTE5AAAAIalice' },
              'bob' => { 'type' => 'ssh-rsa', 'key' => 'AAAAB3NzaC1yc2EAAAADAQABbob' },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a system account with a shell and no stray keys' do
          is_expected.to contain_user('ovlens').with(
            ensure: 'present', system: true, home: '/var/lib/ovlens', managehome: true, shell: '/bin/sh', purge_ssh_keys: true,
          )
        end

        it 'locks every key to the MCP server' do
          options = ['command="/opt/puppetlabs/puppet/bin/ovlens mcp --docs-dir /opt/puppetlabs/server/data/ovlens"', 'restrict']
          is_expected.to contain_ssh_authorized_key('ovlens-alice').with(
            user: 'ovlens', type: 'ssh-ed25519', key: 'AAAAC3NzaC1lZDI1NTE5AAAAIalice', options: options,
          )
          is_expected.to contain_ssh_authorized_key('ovlens-bob').with(user: 'ovlens', type: 'ssh-rsa', options: options)
          is_expected.to have_ssh_authorized_key_resource_count(2)
        end
      end

      context 'with an invalid environment name' do
        let(:params) { { environments: ['production; rm -rf /'] } }

        it { is_expected.not_to compile }
      end

      context 'with an invalid interval' do
        let(:params) { { generate_interval: 'often' } }

        it { is_expected.not_to compile }
      end
    end
  end
end

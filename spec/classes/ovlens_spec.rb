# frozen_string_literal: true

require 'spec_helper'

describe 'ovlens' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:redhat) { os_facts[:os]['family'] == 'RedHat' }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }

        it 'installs the package from the harpworks repository before anything uses it' do
          is_expected.to contain_package('ovlens').with(ensure: 'installed', source: nil, provider: nil)
          is_expected.to contain_class('ovlens::repo').that_comes_before('Class[ovlens::install]')
          is_expected.to contain_class('ovlens::install').that_comes_before('Class[ovlens::generate]')
          is_expected.to contain_class('ovlens::install').that_comes_before('Class[ovlens::mcp]')
        end

        it 'configures the repository with its metadata signature checked' do
          if redhat
            is_expected.to contain_yumrepo('harpworks').with(
              baseurl: 'https://packages.harpworks.org/rpm', repo_gpgcheck: '1',
              gpgkey: 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-harpworks'
            ).that_comes_before('Package[ovlens]')
            is_expected.to contain_file('/etc/pki/rpm-gpg/RPM-GPG-KEY-harpworks').with_source('puppet:///modules/ovlens/harpworks.asc')
          else
            is_expected.to contain_file('/etc/apt/sources.list.d/harpworks.list')
              .with_content("deb [signed-by=/etc/apt/keyrings/harpworks.asc] https://packages.harpworks.org/deb stable main\n")
            is_expected.to contain_file('/etc/apt/keyrings/harpworks.asc').with_source('puppet:///modules/ovlens/harpworks.asc')
            is_expected.to contain_exec('harpworks apt-get update').with_refreshonly(true).that_comes_before('Package[ovlens]')
          end
        end

        it 'manages the documentation directory' do
          is_expected.to contain_file('/opt/puppetlabs/server/data/ovlens').with(ensure: 'directory', owner: 'root', mode: '0755')
        end

        it 'documents every environment from a timer' do
          is_expected.to contain_systemd__timer('ovlens-generate.timer').with(ensure: 'present', active: true, enable: true)
                                                                        .that_requires('File[/opt/puppetlabs/server/data/ovlens]')
          is_expected.to contain_systemd__timer('ovlens-generate.timer')
            .with_service_content(%r{^ExecStart=/usr/bin/ovlens generate --docs-dir "/opt/puppetlabs/server/data/ovlens" --all$})
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

      context 'with a mirror and a pinned version' do
        let(:params) { { repo_baseurl: 'https://mirror.example.com/harpworks', package_ensure: '0.1.0' } }

        it { is_expected.to contain_package('ovlens').with_ensure('0.1.0') }

        it do
          if redhat
            is_expected.to contain_yumrepo('harpworks').with_baseurl('https://mirror.example.com/harpworks/rpm')
          else
            is_expected.to contain_file('/etc/apt/sources.list.d/harpworks.list').with_content(%r{ https://mirror\.example\.com/harpworks/deb stable main$})
          end
        end
      end

      context 'with a package file' do
        let(:params) { { package_source: '/opt/packages/ovlens.pkg' } }

        it { is_expected.to compile.with_all_deps }

        it 'installs the file with the low-level provider and leaves the repository alone' do
          is_expected.to contain_package('ovlens').with(source: '/opt/packages/ovlens.pkg', provider: redhat ? 'rpm' : 'dpkg')
          is_expected.not_to contain_class('ovlens::repo')
        end
      end

      context 'with a package file and a pinned version' do
        let(:params) { { package_source: '/opt/packages/ovlens.pkg', package_ensure: '0.1.0' } }

        it do
          if redhat
            is_expected.to contain_package('ovlens').with(ensure: '0.1.0', provider: 'rpm')
          else
            is_expected.to compile.and_raise_error(%r{dpkg, which cannot pin a version})
          end
        end
      end

      context 'with repo_manage => false' do
        let(:params) { { repo_manage: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('ovlens::repo') }
        it { is_expected.to contain_package('ovlens') }
      end

      context 'with package_manage => false' do
        let(:params) { { package_manage: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('ovlens') }
        it { is_expected.not_to contain_class('ovlens::repo') }
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
          options = ['command="/usr/bin/ovlens mcp --docs-dir /opt/puppetlabs/server/data/ovlens"', 'restrict']
          is_expected.to contain_ssh_authorized_key('ovlens-alice').with(
            user: 'ovlens', type: 'ssh-ed25519', key: 'AAAAC3NzaC1lZDI1NTE5AAAAIalice', options: options,
          )
          is_expected.to contain_ssh_authorized_key('ovlens-bob').with(user: 'ovlens', type: 'ssh-rsa', options: options)
          is_expected.to have_ssh_authorized_key_resource_count(2)
        end
      end

      context 'with Hiera data and extra masks' do
        let(:params) { { hiera: true, hiera_masks: ['*ldap*', 'profile::*::bind_dn'] } }

        it 'indexes Hiera data, masking those patterns too' do
          is_expected.to contain_systemd__timer('ovlens-generate.timer').with_service_content(
            %r{^ExecStart=/usr/bin/ovlens generate --docs-dir "/opt/puppetlabs/server/data/ovlens" --hiera --hiera-mask "\*ldap\*" --hiera-mask "profile::\*::bind_dn" --all$},
          )
        end
      end

      context 'with masks but no Hiera data' do
        let(:params) { { hiera_masks: ['*ldap*'] } }

        it 'ignores the masks' do
          is_expected.to contain_systemd__timer('ovlens-generate.timer')
            .with_service_content(%r{^ExecStart=/usr/bin/ovlens generate --docs-dir "/opt/puppetlabs/server/data/ovlens" --all$})
        end
      end

      context 'with a mask systemd would read' do
        let(:params) { { hiera: true, hiera_masks: ['*"; rm -rf /'] } }

        it { is_expected.not_to compile }
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
